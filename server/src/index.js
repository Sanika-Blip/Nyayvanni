require("dotenv").config();
const path = require("path");
const express = require("express");
const cors = require("cors");
const { parseTranscript } = require("./parser");
const store = require("./store");
const { sign, authRequired, checkPassword } = require("./auth");
const { sendOfficerCredentials } = require("./mailer");

const app = express();
const port = process.env.PORT || 3000;

// Minimal in-memory rate limiter (per IP + route) for login and public registration.
function rateLimit({ windowMs, max }) {
  const hits = new Map();
  return (req, res, next) => {
    const key = req.ip + req.path;
    const now = Date.now();
    const recent = (hits.get(key) || []).filter((t) => now - t < windowMs);
    if (recent.length >= max) {
      return res.status(429).json({ error: "Too many attempts. Please wait a few minutes and try again." });
    }
    recent.push(now);
    hits.set(key, recent);
    if (hits.size > 5000) hits.clear();
    next();
  };
}
const loginLimiter = rateLimit({ windowMs: 15 * 60 * 1000, max: 20 });
const registerLimiter = rateLimit({ windowMs: 60 * 60 * 1000, max: 10 });

app.use(cors());
app.use(express.json({ limit: "2mb" }));
app.use("/admin", express.static(path.join(__dirname, "../public/admin")));

app.get("/", (_req, res) => res.redirect("/admin"));

app.get("/api/health", (_req, res) => {
  res.json({ ok: true, service: "nyayvanni-api", store: true });
});

app.get("/api/stations", (_req, res) => {
  res.json({ data: store.listStations() });
});

app.post("/api/parse", (req, res) => {
  const transcript = req.body?.transcript || "";
  res.json({ data: parseTranscript(transcript), language: req.body?.language || "Auto-detect" });
});

// ----- Public: police registration -----
app.post("/api/registrations", registerLimiter, (req, res) => {
  try {
    const b = req.body || {};
    if (!b.fullName || !b.email) {
      return res.status(400).json({ error: "Full name and email are required" });
    }
    const row = store.createRegistration(b);
    res.status(201).json({
      ok: true,
      data: row,
      message: "Registration submitted. Admin will email your officer ID and password after approval.",
    });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// ----- Auth -----
app.post("/api/auth/login", loginLimiter, async (req, res) => {
  const { officerId, password } = req.body || {};
  if (!officerId || !password) {
    return res.status(400).json({ error: "Officer ID and password are required" });
  }
  const officer = store.findOfficerByLogin(officerId);
  if (!officer || officer.status === "disabled") {
    return res.status(401).json({ error: "Invalid officer ID or password" });
  }
  const ok = await checkPassword(officer.passwordHash, password);
  if (!ok) return res.status(401).json({ error: "Invalid officer ID or password" });
  const { passwordHash, ...publicOfficer } = officer;
  res.json({
    token: sign({ role: "officer", id: officer.id, officerId: officer.officerId }),
    user: publicOfficer,
  });
});

app.post("/api/admin/login", loginLimiter, async (req, res) => {
  const { username, password } = req.body || {};
  if (!username || !password) {
    return res.status(400).json({ error: "Username and password are required" });
  }
  const admin = store.findAdminByUsername(username);
  if (!admin) return res.status(401).json({ error: "Invalid credentials" });
  const ok = await checkPassword(admin.passwordHash, password);
  if (!ok) return res.status(401).json({ error: "Invalid credentials" });
  const { passwordHash, ...publicAdmin } = admin;
  res.json({
    token: sign({ role: "admin", id: admin.id, username: admin.username }),
    user: publicAdmin,
  });
});

app.get("/api/me", authRequired(["officer", "admin"]), (req, res) => {
  if (req.user.role === "admin") {
    const admin = store.findAdminById(req.user.id);
    if (!admin) return res.status(404).json({ error: "Not found" });
    const { passwordHash, ...rest } = admin;
    return res.json({ role: "admin", user: rest });
  }
  const officer = store.findOfficerById(req.user.id);
  if (!officer) return res.status(404).json({ error: "Not found" });
  const { passwordHash, ...rest } = officer;
  res.json({ role: "officer", user: rest });
});

app.put("/api/me", authRequired(["officer"]), async (req, res) => {
  try {
    const result = await store.updateOwnProfile(req.user.id, req.body || {});
    if (!result) return res.status(404).json({ error: "Not found" });
    res.json({ data: result.officer });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

// ----- Officer drafts -----
app.get("/api/drafts", authRequired(["officer", "admin"]), (req, res) => {
  const officerId = req.user.role === "admin" ? undefined : req.user.officerId;
  res.json({ data: store.listDrafts(officerId) });
});

app.get("/api/drafts/:id", authRequired(["officer", "admin"]), (req, res) => {
  const row = store.findDraft(req.params.id);
  if (!row) return res.status(404).json({ error: "Draft not found" });
  if (req.user.role === "officer" && row.officerId !== req.user.officerId) {
    return res.status(403).json({ error: "Not allowed" });
  }
  res.json({ data: row });
});

app.post("/api/drafts", authRequired(["officer", "admin"]), (req, res) => {
  const body = req.body || {};
  if (!body.id) return res.status(400).json({ error: "id is required" });
  if (req.user.role === "officer") {
    body.officerId = req.user.officerId;
    const officer = store.findOfficerById(req.user.id);
    if (officer) {
      body.officerName = officer.fullName;
      body.badgeNumber = officer.badgeNumber || officer.officerId;
      if (!body.station) body.station = officer.station;
      if (!body.district) body.district = officer.district;
    }
  }
  const existing = store.findDraft(body.id);
  if (existing && req.user.role === "officer" && existing.officerId !== req.user.officerId) {
    return res.status(403).json({ error: "Not allowed" });
  }
  const saved = store.upsertDraft(body);
  res.json({ ok: true, stored: true, data: saved });
});

app.put("/api/drafts/:id", authRequired(["officer", "admin"]), (req, res) => {
  const existing = store.findDraft(req.params.id);
  if (!existing) return res.status(404).json({ error: "Draft not found" });
  if (req.user.role === "officer" && existing.officerId !== req.user.officerId) {
    return res.status(403).json({ error: "Not allowed" });
  }
  const update = { ...existing, ...req.body, id: req.params.id };
  if (req.user.role === "officer") {
    // Officers cannot reassign a draft to someone else.
    update.officerId = existing.officerId;
    update.officerName = existing.officerName;
    update.badgeNumber = existing.badgeNumber;
  }
  const saved = store.upsertDraft(update);
  res.json({ ok: true, data: saved });
});

app.delete("/api/drafts/:id", authRequired(["officer", "admin"]), (req, res) => {
  const existing = store.findDraft(req.params.id);
  if (!existing) return res.status(404).json({ error: "Draft not found" });
  if (req.user.role === "officer" && existing.officerId !== req.user.officerId) {
    return res.status(403).json({ error: "Not allowed" });
  }
  store.deleteDraft(req.params.id);
  res.json({ ok: true });
});

// ----- Admin CRUD -----
app.get("/api/admin/overview", authRequired(["admin"]), (_req, res) => {
  res.json({
    data: {
      pendingRegistrations: store.listRegistrations().filter((r) => r.status === "pending").length,
      officers: store.listOfficers().length,
      drafts: store.listDrafts().length,
      stations: store.listStations().length,
      emails: store.listEmails().length,
    },
  });
});

app.get("/api/admin/registrations", authRequired(["admin"]), (_req, res) => {
  res.json({ data: store.listRegistrations() });
});

app.post("/api/admin/registrations", authRequired(["admin"]), (req, res) => {
  try {
    res.status(201).json({ data: store.createRegistration(req.body || {}) });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.put("/api/admin/registrations/:id", authRequired(["admin"]), (req, res) => {
  const row = store.updateRegistration(req.params.id, req.body || {});
  if (!row) return res.status(404).json({ error: "Not found" });
  res.json({ data: row });
});

app.delete("/api/admin/registrations/:id", authRequired(["admin"]), (req, res) => {
  if (!store.deleteRegistration(req.params.id)) return res.status(404).json({ error: "Not found" });
  res.json({ ok: true });
});

app.post("/api/admin/registrations/:id/approve", authRequired(["admin"]), async (req, res) => {
  try {
    const registration = store.findRegistration(req.params.id);
    if (!registration) return res.status(404).json({ error: "Not found" });
    if (registration.status === "approved") {
      return res.status(400).json({ error: "Already approved" });
    }
    const officerId = (req.body?.officerId || store.generateOfficerId()).trim();
    const password = req.body?.password || store.generatePassword();
    const { officer } = await store.createOfficer({
      ...registration,
      officerId,
      password,
      status: "active",
    });
    store.updateRegistration(registration.id, {
      status: "approved",
      notes: `Approved as ${officer.officerId}`,
    });
    const email = await sendOfficerCredentials({
      fullName: officer.fullName,
      email: officer.email,
      officerId: officer.officerId,
      password,
    });
    res.json({
      ok: true,
      data: { officer, officerId: officer.officerId, password, email },
      message: email.delivered
        ? "Officer created and credentials emailed."
        : "Officer created. Credentials stored in Email log (SMTP not configured).",
    });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.post("/api/admin/registrations/:id/reject", authRequired(["admin"]), (req, res) => {
  const row = store.updateRegistration(req.params.id, {
    status: "rejected",
    notes: req.body?.notes || "Rejected by admin",
  });
  if (!row) return res.status(404).json({ error: "Not found" });
  res.json({ data: row });
});

app.get("/api/admin/officers", authRequired(["admin"]), (_req, res) => {
  res.json({ data: store.listOfficers() });
});

app.post("/api/admin/officers", authRequired(["admin"]), async (req, res) => {
  try {
    const b = req.body || {};
    if (!b.fullName || !b.email) {
      return res.status(400).json({ error: "Full name and email are required" });
    }
    const result = await store.createOfficer(b);
    const email = await sendOfficerCredentials({
      fullName: result.officer.fullName,
      email: result.officer.email,
      officerId: result.officer.officerId,
      password: result.password,
    });
    res.status(201).json({
      data: { ...result, email },
      message: "Officer created and credentials sent to email log / SMTP.",
    });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.put("/api/admin/officers/:id", authRequired(["admin"]), async (req, res) => {
  try {
    const result = await store.updateOfficer(req.params.id, req.body || {});
    if (!result) return res.status(404).json({ error: "Not found" });
    if (result.password) {
      await sendOfficerCredentials({
        fullName: result.officer.fullName,
        email: result.officer.email,
        officerId: result.officer.officerId,
        password: result.password,
      });
    }
    res.json({ data: result.officer });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.delete("/api/admin/officers/:id", authRequired(["admin"]), (req, res) => {
  if (!store.deleteOfficer(req.params.id)) return res.status(404).json({ error: "Not found" });
  res.json({ ok: true });
});

app.get("/api/admin/stations", authRequired(["admin"]), (_req, res) => {
  res.json({ data: store.listStations() });
});

app.post("/api/admin/stations", authRequired(["admin"]), (req, res) => {
  if (!req.body?.name) return res.status(400).json({ error: "Name is required" });
  res.status(201).json({ data: store.createStation(req.body) });
});

app.put("/api/admin/stations/:id", authRequired(["admin"]), (req, res) => {
  const row = store.updateStation(req.params.id, req.body || {});
  if (!row) return res.status(404).json({ error: "Not found" });
  res.json({ data: row });
});

app.delete("/api/admin/stations/:id", authRequired(["admin"]), (req, res) => {
  if (!store.deleteStation(req.params.id)) return res.status(404).json({ error: "Not found" });
  res.json({ ok: true });
});

app.get("/api/admin/admins", authRequired(["admin"]), (_req, res) => {
  res.json({ data: store.listAdmins() });
});

app.post("/api/admin/admins", authRequired(["admin"]), async (req, res) => {
  try {
    const b = req.body || {};
    if (!b.username || !b.password || !b.email || !b.name) {
      return res.status(400).json({ error: "Name, username, email and password are required" });
    }
    res.status(201).json({ data: await store.createAdmin(b) });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.put("/api/admin/admins/:id", authRequired(["admin"]), async (req, res) => {
  try {
    const row = await store.updateAdmin(req.params.id, req.body || {});
    if (!row) return res.status(404).json({ error: "Not found" });
    res.json({ data: row });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.delete("/api/admin/admins/:id", authRequired(["admin"]), (req, res) => {
  try {
    if (!store.deleteAdmin(req.params.id)) return res.status(404).json({ error: "Not found" });
    res.json({ ok: true });
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.get("/api/admin/emails", authRequired(["admin"]), (_req, res) => {
  res.json({ data: store.listEmails() });
});

app.delete("/api/admin/emails/:id", authRequired(["admin"]), (req, res) => {
  if (!store.deleteEmail(req.params.id)) return res.status(404).json({ error: "Not found" });
  res.json({ ok: true });
});

// JSON/body errors and anything unexpected return JSON, not an HTML stack page.
app.use((err, _req, res, _next) => {
  const status = err.status || err.statusCode || 500;
  if (status >= 500) console.error(err);
  res.status(status).json({ error: status >= 500 ? "Server error" : "Invalid request" });
});

async function start() {
  store.load();
  await store.seedIfNeeded();

  app.listen(port, () => {
    console.log(`NyayVanni API  http://127.0.0.1:${port}`);
    console.log(`Admin panel    http://127.0.0.1:${port}/admin`);
    if (!process.env.ADMIN_PASSWORD) {
      console.warn("Using the built-in default admin password. Set ADMIN_PASSWORD in .env and change it after first sign-in.");
    }
  });
}

start().catch((err) => {
  console.error("Failed to start:", err);
  process.exit(1);
});
