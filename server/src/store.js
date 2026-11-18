const fs = require("fs");
const path = require("path");
const bcrypt = require("bcryptjs");
const { randomUUID, randomBytes } = require("crypto");

const DATA_DIR = process.env.DATA_DIR || path.join(__dirname, "..", "data");
const DATA_PATH = path.join(DATA_DIR, "db.json");

function nowIso() {
  return new Date().toISOString();
}

function emptyDb() {
  return {
    admins: [],
    registrations: [],
    officers: [],
    stations: [],
    drafts: [],
    emails: [],
    audit: [],
  };
}

let db = emptyDb();

// Write to a temp file then rename, so a crash mid-write can never leave a truncated db.json.
function persist() {
  fs.mkdirSync(DATA_DIR, { recursive: true });
  const tmp = DATA_PATH + ".tmp";
  fs.writeFileSync(tmp, JSON.stringify(db, null, 2), "utf8");
  fs.renameSync(tmp, DATA_PATH);
}

function publicAdmin(a) {
  const { passwordHash, ...rest } = a;
  return rest;
}

function publicOfficer(o) {
  const { passwordHash, ...rest } = o;
  return rest;
}

async function seedIfNeeded() {
  if (!db.admins.length) {
    db.admins.push({
      id: randomUUID(),
      username: process.env.ADMIN_USERNAME || "admin",
      name: "NyayVanni Administrator",
      email: process.env.ADMIN_EMAIL || "admin@nyayvanni.local",
      passwordHash: await bcrypt.hash(process.env.ADMIN_PASSWORD || "Admin@12345", 10),
      createdAt: nowIso(),
      updatedAt: nowIso(),
    });
  }
  if (!db.stations.length) {
    db.stations.push({
      id: randomUUID(),
      name: "Nashik Road Police Station",
      district: "Nashik",
      state: "Maharashtra",
      createdAt: nowIso(),
      updatedAt: nowIso(),
    });
  }
  persist();
}

function load() {
  try {
    if (fs.existsSync(DATA_PATH)) {
      db = { ...emptyDb(), ...JSON.parse(fs.readFileSync(DATA_PATH, "utf8")) };
    }
  } catch (err) {
    // Never silently discard data: keep the unreadable file for recovery before starting empty.
    const backup = path.join(DATA_DIR, `db.corrupt-${Date.now()}.json`);
    try {
      fs.copyFileSync(DATA_PATH, backup);
      console.error(`db.json could not be read (${err.message}). Copy kept at ${backup}`);
    } catch {}
    db = emptyDb();
  }
}

function generateOfficerId() {
  const year = new Date().getFullYear();
  let n = db.officers.length + 1;
  let id;
  do {
    id = `NV-PO-${year}-${String(n++).padStart(4, "0")}`;
  } while (db.officers.some((o) => o.officerId.toLowerCase() === id.toLowerCase()));
  return id;
}

function generatePassword() {
  return randomBytes(5).toString("hex");
}

const store = {
  load,
  persist,
  seedIfNeeded,
  snapshot() {
    return db;
  },

  // --- Admins ---
  listAdmins() {
    return db.admins.map(publicAdmin);
  },
  findAdminByUsername(username) {
    return db.admins.find((a) => a.username.toLowerCase() === String(username).toLowerCase());
  },
  findAdminById(id) {
    return db.admins.find((a) => a.id === id);
  },
  async createAdmin(payload) {
    if (this.findAdminByUsername(payload.username)) {
      throw new Error("Username already exists");
    }
    const row = {
      id: randomUUID(),
      username: payload.username.trim(),
      name: payload.name.trim(),
      email: payload.email.trim(),
      passwordHash: await bcrypt.hash(payload.password, 10),
      createdAt: nowIso(),
      updatedAt: nowIso(),
    };
    db.admins.push(row);
    persist();
    return publicAdmin(row);
  },
  async updateAdmin(id, payload) {
    const row = this.findAdminById(id);
    if (!row) return null;
    if (payload.username) {
      const clash = this.findAdminByUsername(payload.username.trim());
      if (clash && clash.id !== row.id) throw new Error("Username already exists");
      row.username = payload.username.trim();
    }
    if (payload.name) row.name = payload.name.trim();
    if (payload.email) row.email = payload.email.trim();
    if (payload.password) row.passwordHash = await bcrypt.hash(payload.password, 10);
    row.updatedAt = nowIso();
    persist();
    return publicAdmin(row);
  },
  deleteAdmin(id) {
    if (!db.admins.some((a) => a.id === id)) return false;
    if (db.admins.length <= 1) throw new Error("Cannot delete the last admin");
    const before = db.admins.length;
    db.admins = db.admins.filter((a) => a.id !== id);
    persist();
    return db.admins.length < before;
  },

  // --- Stations ---
  listStations() {
    return db.stations;
  },
  findStation(id) {
    return db.stations.find((s) => s.id === id);
  },
  createStation(payload) {
    const row = {
      id: randomUUID(),
      name: payload.name.trim(),
      district: (payload.district || "").trim(),
      state: (payload.state || "").trim(),
      createdAt: nowIso(),
      updatedAt: nowIso(),
    };
    db.stations.push(row);
    persist();
    return row;
  },
  updateStation(id, payload) {
    const row = this.findStation(id);
    if (!row) return null;
    if (payload.name != null) row.name = payload.name.trim();
    if (payload.district != null) row.district = payload.district.trim();
    if (payload.state != null) row.state = payload.state.trim();
    row.updatedAt = nowIso();
    persist();
    return row;
  },
  deleteStation(id) {
    const before = db.stations.length;
    db.stations = db.stations.filter((s) => s.id !== id);
    persist();
    return db.stations.length < before;
  },

  // --- Registrations ---
  listRegistrations() {
    return [...db.registrations].sort((a, b) => b.createdAt.localeCompare(a.createdAt));
  },
  findRegistration(id) {
    return db.registrations.find((r) => r.id === id);
  },
  createRegistration(payload) {
    if (typeof payload.email !== "string" || typeof payload.fullName !== "string") {
      throw new Error("Full name and email are required");
    }
    const email = payload.email.trim().toLowerCase();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw new Error("Enter a valid email address");
    const existing = db.registrations.find(
      (r) => r.email === email && r.status === "pending"
    );
    if (existing) throw new Error("A pending registration already exists for this email");
    if (db.officers.find((o) => o.email === email)) {
      throw new Error("An officer account already exists for this email");
    }
    const row = {
      id: randomUUID(),
      fullName: payload.fullName.trim(),
      email,
      phone: (payload.phone || "").trim(),
      rank: (payload.rank || "").trim(),
      badgeNumber: (payload.badgeNumber || "").trim(),
      station: (payload.station || "").trim(),
      district: (payload.district || "").trim(),
      state: (payload.state || "").trim(),
      address: (payload.address || "").trim(),
      status: "pending",
      officerId: null,
      notes: "",
      createdAt: nowIso(),
      updatedAt: nowIso(),
    };
    db.registrations.push(row);
    persist();
    return row;
  },
  updateRegistration(id, payload) {
    const row = this.findRegistration(id);
    if (!row) return null;
    const fields = [
      "fullName",
      "email",
      "phone",
      "rank",
      "badgeNumber",
      "station",
      "district",
      "state",
      "address",
      "status",
      "notes",
    ];
    for (const f of fields) {
      if (payload[f] == null) continue;
      const v = String(payload[f]).trim();
      if ((f === "fullName" || f === "email") && !v) continue;
      if (f === "status" && !["pending", "approved", "rejected"].includes(v)) continue;
      row[f] = v;
    }
    if (row.email) row.email = row.email.toLowerCase();
    row.updatedAt = nowIso();
    persist();
    return row;
  },
  deleteRegistration(id) {
    const before = db.registrations.length;
    db.registrations = db.registrations.filter((r) => r.id !== id);
    persist();
    return db.registrations.length < before;
  },

  // --- Officers ---
  listOfficers() {
    return db.officers.map(publicOfficer);
  },
  findOfficerById(id) {
    return db.officers.find((o) => o.id === id);
  },
  findOfficerByLogin(officerId) {
    return db.officers.find(
      (o) => o.officerId.toLowerCase() === String(officerId).toLowerCase()
    );
  },
  findOfficerByEmail(email) {
    return db.officers.find((o) => o.email === String(email).toLowerCase());
  },
  async createOfficer(payload) {
    const officerId = (payload.officerId || generateOfficerId()).trim();
    if (db.officers.some((o) => o.officerId.toLowerCase() === officerId.toLowerCase())) {
      throw new Error("Officer ID already exists");
    }
    const email = payload.email.trim().toLowerCase();
    if (this.findOfficerByEmail(email)) {
      throw new Error("Email already in use");
    }
    const password = payload.password || generatePassword();
    const row = {
      id: randomUUID(),
      officerId,
      fullName: payload.fullName.trim(),
      email,
      phone: (payload.phone || "").trim(),
      rank: (payload.rank || "").trim(),
      badgeNumber: (payload.badgeNumber || "").trim(),
      station: (payload.station || "").trim(),
      district: (payload.district || "").trim(),
      state: (payload.state || "").trim(),
      address: (payload.address || "").trim(),
      status: payload.status === "disabled" ? "disabled" : "active",
      role: payload.role === "supervisor" ? "supervisor" : "officer",
      // Passwords chosen or generated by an administrator are temporary.
      mustChangePassword: true,
      passwordHash: await bcrypt.hash(password, 10),
      createdAt: nowIso(),
      updatedAt: nowIso(),
    };
    db.officers.push(row);
    persist();
    return { officer: publicOfficer(row), password };
  },
  async updateOfficer(id, payload) {
    const row = this.findOfficerById(id);
    if (!row) return null;
    const fields = [
      "fullName",
      "email",
      "phone",
      "rank",
      "badgeNumber",
      "station",
      "district",
      "state",
      "address",
      "status",
      "officerId",
      "role",
    ];
    const required = new Set(["fullName", "email", "officerId"]);
    const next = {};
    for (const f of fields) {
      if (payload[f] == null) continue;
      const v = String(payload[f]).trim();
      if (required.has(f) && !v) continue; // never blank out required fields
      next[f] = v;
    }
    if (next.email) {
      next.email = next.email.toLowerCase();
      const clash = this.findOfficerByEmail(next.email);
      if (clash && clash.id !== row.id) throw new Error("Email already in use");
    }
    if (next.officerId) {
      const clash = this.findOfficerByLogin(next.officerId);
      if (clash && clash.id !== row.id) throw new Error("Officer ID already exists");
    }
    if (next.status && !["active", "disabled"].includes(next.status)) {
      throw new Error("Status must be active or disabled");
    }
    if (next.role && !["officer", "supervisor"].includes(next.role)) {
      throw new Error("Role must be officer or supervisor");
    }
    Object.assign(row, next);
    let password;
    if (payload.password) {
      password = payload.password;
      row.passwordHash = await bcrypt.hash(password, 10);
      // An officer choosing their own password ends the temporary state;
      // an administrator setting one starts it again.
      row.mustChangePassword = !payload.__selfService;
    }
    row.updatedAt = nowIso();
    persist();
    return { officer: publicOfficer(row), password };
  },
  // Officers may only change their own contact details and password.
  // Name, rank, badge, station and email are controlled by the administrator.
  async updateOwnProfile(id, payload) {
    const row = this.findOfficerById(id);
    if (!row) return null;
    const safe = {};
    for (const f of ["phone", "address"]) if (payload[f] != null) safe[f] = payload[f];
    if (payload.password) {
      if (String(payload.password).length < 8) throw new Error("New password must be at least 8 characters");
      const ok = await bcrypt.compare(String(payload.currentPassword || ""), row.passwordHash);
      if (!ok) throw new Error("Current password is incorrect");
      if (String(payload.password) === String(payload.currentPassword)) {
        throw new Error("Choose a password different from the current one");
      }
      safe.password = payload.password;
      safe.__selfService = true;
    }
    return this.updateOfficer(id, safe);
  },
  deleteOfficer(id) {
    const before = db.officers.length;
    db.officers = db.officers.filter((o) => o.id !== id);
    persist();
    return db.officers.length < before;
  },

  // --- Drafts ---
  listDrafts(officerId) {
    let rows = db.drafts;
    if (officerId) rows = rows.filter((d) => d.officerId === officerId);
    return [...rows].sort((a, b) => String(b.updatedAt).localeCompare(String(a.updatedAt)));
  },
  findDraft(id) {
    return db.drafts.find((d) => d.id === id);
  },
  upsertDraft(payload) {
    const existing = this.findDraft(payload.id);
    if (existing) {
      Object.assign(existing, payload, { updatedAt: nowIso() });
      persist();
      return existing;
    }
    const row = { ...payload, createdAt: payload.createdAt || nowIso(), updatedAt: nowIso() };
    db.drafts.push(row);
    persist();
    return row;
  },
  deleteDraft(id) {
    const before = db.drafts.length;
    db.drafts = db.drafts.filter((d) => d.id !== id);
    persist();
    return db.drafts.length < before;
  },

  // --- Review workflow ---
  sameStation(a, b) {
    const n = (s) => String(s || "").trim().toLowerCase();
    return n(a.station) === n(b.station) && n(a.district) === n(b.district);
  },
  // Drafts a supervisor may review: pending, same station/district, never their own.
  listReviewQueue(supervisor) {
    return db.drafts
      .filter(
        (d) =>
          d.reviewStatus === "pending" &&
          d.officerId !== supervisor.officerId &&
          this.sameStation(d, supervisor)
      )
      .sort((a, b) => String(a.submittedAt).localeCompare(String(b.submittedAt)));
  },
  submitForReview(id) {
    const d = this.findDraft(id);
    if (!d) return null;
    d.status = "submitted";
    d.reviewStatus = "pending";
    d.reviewComment = "";
    d.submittedAt = nowIso();
    d.updatedAt = nowIso();
    persist();
    return d;
  },
  recordReview(id, { decision, comment, reviewer }) {
    const d = this.findDraft(id);
    if (!d) return null;
    d.reviewStatus = decision;
    d.reviewComment = comment || "";
    d.reviewedBy = reviewer;
    d.reviewedAt = nowIso();
    d.status = decision === "approved" ? "submitted" : "draft";
    d.updatedAt = nowIso();
    persist();
    return d;
  },

  // --- Audit log ---
  addAudit({ actor, role, action, target = "", detail = "" }) {
    db.audit.unshift({ id: randomUUID(), at: nowIso(), actor, role, action, target, detail });
    if (db.audit.length > 5000) db.audit.length = 5000;
    persist();
  },
  listAudit(limit = 500) {
    return db.audit.slice(0, limit);
  },

  addEmail(record) {
    const row = { id: randomUUID(), createdAt: nowIso(), ...record };
    db.emails.unshift(row);
    persist();
    return row;
  },
  listEmails() {
    return db.emails;
  },
  deleteEmail(id) {
    const before = db.emails.length;
    db.emails = db.emails.filter((e) => e.id !== id);
    persist();
    return db.emails.length < before;
  },

  generateOfficerId,
  generatePassword,
};

module.exports = store;
