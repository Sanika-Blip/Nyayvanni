// End-to-end API tests: starts the real server on a temporary port and data folder.
const test = require("node:test");
const assert = require("node:assert/strict");
const { spawn } = require("node:child_process");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const PORT = 3200 + Math.floor(Math.random() * 500);
const BASE = `http://127.0.0.1:${PORT}`;
const dataDir = fs.mkdtempSync(path.join(os.tmpdir(), "nv-test-"));
let child;

async function call(method, url, token, body) {
  const res = await fetch(BASE + url, {
    method,
    headers: { "content-type": "application/json", ...(token ? { authorization: "Bearer " + token } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  let json = {};
  try { json = await res.json(); } catch {}
  return { status: res.status, body: json };
}

const ctx = {};

test.before(async () => {
  child = spawn(process.execPath, [path.join(__dirname, "..", "src", "index.js")], {
    env: { ...process.env, PORT: String(PORT), DATA_DIR: dataDir, JWT_SECRET: "test-secret", ADMIN_PASSWORD: "TestAdmin#1" },
    stdio: "ignore",
  });
  for (let i = 0; i < 50; i++) {
    try { await fetch(BASE + "/api/health"); break; } catch { await new Promise((r) => setTimeout(r, 100)); }
  }
  const a = await call("POST", "/api/admin/login", null, { username: "admin", password: "TestAdmin#1" });
  ctx.admin = a.body.token;
  const mk = async (name, email, role, station) => {
    const r = await call("POST", "/api/admin/officers", ctx.admin, {
      fullName: name, email, role, station, district: "Nashik", password: "Passw0rd!x",
    });
    const id = r.body.data.officer.officerId;
    const first = await call("POST", "/api/auth/login", null, { officerId: id, password: "Passw0rd!x" });
    // Temporary passwords must be replaced before the API can be used.
    const blocked = await call("GET", "/api/drafts", first.body.token);
    if (blocked.status !== 403) throw new Error("temporary password was not enforced");
    await call("PUT", "/api/me", first.body.token, { currentPassword: "Passw0rd!x", password: "Passw0rd!y" });
    const l = await call("POST", "/api/auth/login", null, { officerId: id, password: "Passw0rd!y" });
    return { id, token: l.body.token };
  };
  ctx.o1 = await mk("Officer One", "one@x.in", "officer", "Nashik Road");
  ctx.o2 = await mk("Officer Two", "two@x.in", "officer", "Nashik Road");
  ctx.sup = await mk("Super Visor", "sup@x.in", "supervisor", "Nashik Road");
  ctx.supOther = await mk("Other Station", "other@x.in", "supervisor", "Panchavati");
});

test.after(() => {
  child && child.kill();
  fs.rmSync(dataDir, { recursive: true, force: true });
});

const draft = { id: "d1", reportNumber: "NV-FIR-1", natureOfOffence: "Theft", rawTranscript: "Phone stolen at Dadar", station: "Nashik Road", district: "Nashik", status: "draft" };

test("officer cannot overwrite or read another officer's draft", async () => {
  assert.equal((await call("POST", "/api/drafts", ctx.o1.token, draft)).status, 200);
  assert.equal((await call("POST", "/api/drafts", ctx.o2.token, { ...draft, complainantName: "x" })).status, 403);
  assert.equal((await call("PUT", "/api/drafts/d1", ctx.o2.token, { complainantName: "x" })).status, 403);
  assert.equal((await call("GET", "/api/drafts/d1", ctx.o2.token)).status, 403);
});

test("officer cannot set review fields or mark a draft submitted directly", async () => {
  const r = await call("PUT", "/api/drafts/d1", ctx.o1.token, { status: "submitted", reviewStatus: "approved" });
  assert.equal(r.body.data.reviewStatus, undefined);
  assert.equal(r.body.data.status, "draft");
});

test("only supervisors can use the review queue", async () => {
  assert.equal((await call("GET", "/api/review/queue", ctx.o1.token)).status, 403);
  assert.equal((await call("GET", "/api/review/queue", ctx.sup.token)).status, 200);
});

test("submit requires offence and narration", async () => {
  await call("POST", "/api/drafts", ctx.o1.token, { id: "empty", reportNumber: "NV-FIR-E" });
  assert.equal((await call("POST", "/api/drafts/empty/submit", ctx.o1.token)).status, 400);
});

test("submitted draft is locked, queued for the same-station supervisor only", async () => {
  assert.equal((await call("POST", "/api/drafts/d1/submit", ctx.o1.token)).status, 200);
  assert.equal((await call("PUT", "/api/drafts/d1", ctx.o1.token, { complainantName: "late edit" })).status, 409);
  assert.equal((await call("DELETE", "/api/drafts/d1", ctx.o1.token)).status, 409);
  const q = await call("GET", "/api/review/queue", ctx.sup.token);
  assert.equal(q.body.data.length, 1);
  assert.equal((await call("GET", "/api/review/queue", ctx.supOther.token)).body.data.length, 0);
  assert.equal((await call("POST", "/api/review/d1", ctx.supOther.token, { decision: "approved" })).status, 403);
  assert.equal((await call("GET", "/api/drafts/d1", ctx.sup.token)).status, 200);
});

test("returning needs a comment, then the author can edit again", async () => {
  assert.equal((await call("POST", "/api/review/d1", ctx.sup.token, { decision: "returned" })).status, 400);
  const r = await call("POST", "/api/review/d1", ctx.sup.token, { decision: "returned", comment: "Add accused details" });
  assert.equal(r.body.data.status, "draft");
  assert.equal(r.body.data.reviewComment, "Add accused details");
  assert.equal((await call("PUT", "/api/drafts/d1", ctx.o1.token, { accusedDetails: "Unknown" })).status, 200);
});

test("approval locks the FIR; reviewers cannot approve their own", async () => {
  await call("POST", "/api/drafts/d1/submit", ctx.o1.token);
  const ok = await call("POST", "/api/review/d1", ctx.sup.token, { decision: "approved" });
  assert.equal(ok.body.data.reviewStatus, "approved");
  assert.equal((await call("PUT", "/api/drafts/d1", ctx.o1.token, { summary: "x" })).status, 409);
  await call("POST", "/api/drafts", ctx.sup.token, { ...draft, id: "own", reportNumber: "NV-FIR-2" });
  await call("POST", "/api/drafts/own/submit", ctx.sup.token);
  assert.equal((await call("POST", "/api/review/own", ctx.sup.token, { decision: "approved" })).status, 403);
});

test("disabled officers lose access immediately", async () => {
  const list = await call("GET", "/api/admin/officers", ctx.admin);
  const target = list.body.data.find((o) => o.officerId === ctx.o2.id);
  await call("PUT", "/api/admin/officers/" + target.id, ctx.admin, { status: "disabled" });
  assert.equal((await call("GET", "/api/drafts", ctx.o2.token)).status, 401);
});

test("audit log records review and admin actions without passwords", async () => {
  const log = await call("GET", "/api/admin/audit", ctx.admin);
  const actions = log.body.data.map((e) => e.action);
  assert.ok(actions.includes("draft.approved"));
  assert.ok(actions.includes("draft.returned"));
  assert.ok(actions.includes("login"));
  assert.ok(!JSON.stringify(log.body.data).includes("Passw0rd"));
});

test("officer cannot change their rank or role", async () => {
  const r = await call("PUT", "/api/me", ctx.o1.token, { rank: "Commissioner", role: "supervisor" });
  assert.notEqual(r.body.data.rank, "Commissioner");
  assert.equal(r.body.data.role, "officer");
});
