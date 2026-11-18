const API = "";
let token = localStorage.getItem("nv_admin_token") || "";
let me = null;

const $ = (id) => document.getElementById(id);
const loginView = $("login-view");
const appView = $("app-view");
const panel = $("panel");
const flashEl = $("flash");

// Escape anything that came from user input before it is placed into innerHTML.
function esc(v) {
  return String(v ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
}

function showFlash(msg, bad = false) {
  flashEl.textContent = msg;
  flashEl.classList.remove("hidden");
  flashEl.classList.toggle("bad", bad);
  setTimeout(() => flashEl.classList.add("hidden"), 5000);
}

async function api(path, opts = {}) {
  const res = await fetch(API + path, {
    ...opts,
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(opts.headers || {}),
    },
  });
  const body = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(body.error || `Request failed (${esc(res.status)})`);
  return body;
}

function field(name, label, value = "", type = "text") {
  if (type === "textarea") {
    return `<label>${label}<textarea name="${name}" rows="3">${esc(value || "")}</textarea></label>`;
  }
  return `<label>${label}<input name="${name}" type="${type}" value="${esc(value || "")}" /></label>`;
}

function closeModal() {
  $("modal").classList.add("hidden");
}

function openModal(title, html) {
  $("modal-title").textContent = title;
  $("modal-form").innerHTML = html;
  $("modal").classList.remove("hidden");
}

function formValues(form) {
  return Object.fromEntries(new FormData(form).entries());
}

function actions(buttons) {
  return `<div class="row-actions">${buttons}</div>`;
}

async function boot() {
  if (!token) return showLogin();
  try {
    const data = await api("/api/me");
    me = data.user;
    showApp();
    render("overview");
  } catch {
    token = "";
    localStorage.removeItem("nv_admin_token");
    showLogin();
  }
}

function showLogin() {
  loginView.classList.remove("hidden");
  appView.classList.add("hidden");
}

function showApp() {
  loginView.classList.add("hidden");
  appView.classList.remove("hidden");
  $("who").textContent = me?.name || me?.username || "";
}

$("login-form").addEventListener("submit", async (e) => {
  e.preventDefault();
  $("login-error").textContent = "";
  try {
    const v = formValues(e.target);
    const data = await api("/api/admin/login", { method: "POST", body: JSON.stringify(v) });
    token = data.token;
    me = data.user;
    localStorage.setItem("nv_admin_token", token);
    showApp();
    render("overview");
  } catch (err) {
    $("login-error").textContent = err.message;
  }
});

$("logout").addEventListener("click", () => {
  token = "";
  localStorage.removeItem("nv_admin_token");
  showLogin();
});

document.querySelectorAll("nav button").forEach((btn) => {
  btn.addEventListener("click", () => {
    document.querySelectorAll("nav button").forEach((b) => b.classList.remove("active"));
    btn.classList.add("active");
    render(btn.dataset.tab);
  });
});

$("modal").addEventListener("click", (e) => {
  if (e.target.id === "modal") closeModal();
});

const titles = {
  overview: "Overview",
  registrations: "Officer registrations",
  officers: "Police officers",
  drafts: "FIR drafts",
  stations: "Police stations",
  admins: "Administrators",
  emails: "Email log",
};

async function render(tab) {
  $("page-title").textContent = titles[tab];
  panel.innerHTML = "<p class='muted'>Loading…</p>";
  try {
    if (tab === "overview") return renderOverview();
    if (tab === "registrations") return renderRegistrations();
    if (tab === "officers") return renderOfficers();
    if (tab === "drafts") return renderDrafts();
    if (tab === "stations") return renderStations();
    if (tab === "admins") return renderAdmins();
    if (tab === "emails") return renderEmails();
  } catch (err) {
    panel.innerHTML = `<p class="error">${esc(err.message)}</p>`;
  }
}

async function renderOverview() {
  const { data } = await api("/api/admin/overview");
  panel.innerHTML = `
    <div class="cards">
      <div class="stat"><span>Pending registrations</span><b>${data.pendingRegistrations}</b></div>
      <div class="stat"><span>Officers</span><b>${data.officers}</b></div>
      <div class="stat"><span>FIR drafts</span><b>${data.drafts}</b></div>
      <div class="stat"><span>Stations</span><b>${data.stations}</b></div>
      <div class="stat"><span>Emails logged</span><b>${data.emails}</b></div>
    </div>
    <p class="muted" style="margin-top:18px">Approve a registration to create an officer ID and password. Credentials are emailed to the address used at registration. If SMTP is not set, open the Email log tab.</p>
  `;
}

async function renderRegistrations() {
  const { data } = await api("/api/admin/registrations");
  panel.innerHTML = `
    <div class="toolbar">
      <button id="add-reg">Add registration</button>
    </div>
    <table>
      <thead><tr><th>Officer</th><th>Contact</th><th>Station</th><th>Status</th><th></th></tr></thead>
      <tbody>
        ${data.map((r) => `
          <tr>
            <td><strong>${esc(r.fullName)}</strong><br/><span class="muted">${esc(r.rank || "")} ${esc(r.badgeNumber || "")}</span></td>
            <td>${esc(r.email)}<br/>${esc(r.phone || "")}</td>
            <td>${esc(r.station || "")}<br/>${esc(r.district || "")}</td>
            <td><span class="badge ${esc(r.status)}">${esc(r.status)}</span></td>
            <td>${actions(`
              ${r.status === "pending" ? `<button data-approve="${esc(r.id)}" class="ok">Approve & email ID</button>
              <button data-reject="${esc(r.id)}" class="warn">Reject</button>` : ""}
              <button data-edit-reg="${esc(r.id)}">Edit</button>
              <button data-del-reg="${esc(r.id)}" class="danger">Delete</button>
            `)}</td>
          </tr>`).join("") || `<tr><td colspan="5">No registrations yet.</td></tr>`}
      </tbody>
    </table>
  `;
  $("add-reg").onclick = () => regForm();
  panel.querySelectorAll("[data-approve]").forEach((b) => b.onclick = () => approve(b.dataset.approve, data));
  panel.querySelectorAll("[data-reject]").forEach((b) => b.onclick = () => reject(b.dataset.reject));
  panel.querySelectorAll("[data-edit-reg]").forEach((b) => b.onclick = () => regForm(data.find((x) => x.id === b.dataset.editReg)));
  panel.querySelectorAll("[data-del-reg]").forEach((b) => b.onclick = () => del("/api/admin/registrations/" + b.dataset.delReg, "registrations"));
}

function regFields(r = {}) {
  return `
    ${field("fullName", "Full name", r.fullName)}
    ${field("email", "Email", r.email, "email")}
    ${field("phone", "Phone", r.phone)}
    ${field("rank", "Rank", r.rank)}
    ${field("badgeNumber", "Badge number", r.badgeNumber)}
    ${field("station", "Police station", r.station)}
    ${field("district", "District", r.district)}
    ${field("state", "State", r.state)}
    ${field("address", "Address", r.address, "textarea")}
    <div class="toolbar">
      <button type="submit">Save</button>
      <button type="button" class="ghost" id="cancel">Cancel</button>
    </div>`;
}

function regForm(row) {
  openModal(row ? "Edit registration" : "New registration", regFields(row));
  $("cancel").onclick = closeModal;
  $("modal-form").onsubmit = async (e) => {
    e.preventDefault();
    const v = formValues(e.target);
    if (row) await api("/api/admin/registrations/" + row.id, { method: "PUT", body: JSON.stringify(v) });
    else await api("/api/admin/registrations", { method: "POST", body: JSON.stringify(v) });
    closeModal();
    showFlash("Registration saved");
    render("registrations");
  };
}

async function approve(id, rows) {
  const row = rows.find((r) => r.id === id);
  openModal("Approve & issue credentials", `
    <p class="muted">ID and password will be emailed to <strong>${esc(row.email)}</strong>.</p>
    ${field("officerId", "Officer ID (leave blank to auto-generate)")}
    ${field("password", "Password (leave blank to auto-generate)")}
    <div class="toolbar">
      <button type="submit" class="ok">Create account & send email</button>
      <button type="button" class="ghost" id="cancel">Cancel</button>
    </div>
  `);
  $("cancel").onclick = closeModal;
  $("modal-form").onsubmit = async (e) => {
    e.preventDefault();
    const v = formValues(e.target);
    const res = await api("/api/admin/registrations/" + id + "/approve", { method: "POST", body: JSON.stringify(v) });
    closeModal();
    showFlash(`${esc(res.message)} Officer ID: ${esc(res.data.officerId)}  Password: ${esc(res.data.password)}`);
    render("registrations");
  };
}

async function reject(id) {
  const notes = prompt("Rejection note (optional)") || "";
  await api("/api/admin/registrations/" + id + "/reject", { method: "POST", body: JSON.stringify({ notes }) });
  showFlash("Registration rejected");
  render("registrations");
}

async function renderOfficers() {
  const { data } = await api("/api/admin/officers");
  panel.innerHTML = `
    <div class="toolbar"><button id="add-off">Add officer</button></div>
    <table>
      <thead><tr><th>Officer ID</th><th>Name</th><th>Email</th><th>Station</th><th>Status</th><th></th></tr></thead>
      <tbody>
        ${data.map((o) => `
          <tr>
            <td><code>${esc(o.officerId)}</code></td>
            <td>${esc(o.fullName)}<br/><span class="muted">${esc(o.rank || "")}</span></td>
            <td>${esc(o.email)}<br/>${esc(o.phone || "")}</td>
            <td>${esc(o.station || "")} / ${esc(o.district || "")}</td>
            <td><span class="badge ${esc(o.status)}">${esc(o.status)}</span></td>
            <td>${actions(`
              <button data-edit-off="${esc(o.id)}">Edit</button>
              <button data-del-off="${esc(o.id)}" class="danger">Delete</button>
            `)}</td>
          </tr>`).join("") || `<tr><td colspan="6">No officers yet.</td></tr>`}
      </tbody>
    </table>
  `;
  $("add-off").onclick = () => officerForm();
  panel.querySelectorAll("[data-edit-off]").forEach((b) => b.onclick = () => officerForm(data.find((x) => x.id === b.dataset.editOff)));
  panel.querySelectorAll("[data-del-off]").forEach((b) => b.onclick = () => del("/api/admin/officers/" + b.dataset.delOff, "officers"));
}

function officerForm(row) {
  openModal(row ? "Edit officer" : "New officer", `
    ${field("officerId", "Officer ID (blank = auto)", row?.officerId || "")}
    ${field("fullName", "Full name", row?.fullName)}
    ${field("email", "Email", row?.email, "email")}
    ${field("phone", "Phone", row?.phone)}
    ${field("rank", "Rank", row?.rank)}
    ${field("badgeNumber", "Badge number", row?.badgeNumber)}
    ${field("station", "Station", row?.station)}
    ${field("district", "District", row?.district)}
    ${field("state", "State", row?.state)}
    ${field("status", "Status (active/disabled)", row?.status || "active")}
    ${field("password", row ? "New password (blank = keep)" : "Password (blank = auto)", "", "text")}
    <div class="toolbar"><button type="submit">Save</button><button type="button" class="ghost" id="cancel">Cancel</button></div>
  `);
  $("cancel").onclick = closeModal;
  $("modal-form").onsubmit = async (e) => {
    e.preventDefault();
    const v = formValues(e.target);
    Object.keys(v).forEach((k) => { if (!v[k]) delete v[k]; });
    if (row) await api("/api/admin/officers/" + row.id, { method: "PUT", body: JSON.stringify(v) });
    else await api("/api/admin/officers", { method: "POST", body: JSON.stringify(v) });
    closeModal();
    showFlash("Officer saved. If a password was set, it was emailed.");
    render("officers");
  };
}

async function renderDrafts() {
  const { data } = await api("/api/drafts");
  panel.innerHTML = `
    <div class="toolbar"><button id="add-draft">Add FIR draft</button></div>
    <table>
      <thead><tr><th>Number</th><th>Officer</th><th>Complainant</th><th>Offence</th><th>Status</th><th></th></tr></thead>
      <tbody>
        ${data.map((d) => `
          <tr>
            <td>${esc(d.reportNumber || d.id)}</td>
            <td>${esc(d.officerId || "")}<br/>${esc(d.officerName || "")}</td>
            <td>${esc(d.complainantName || "")}</td>
            <td>${esc(d.natureOfOffence || d.summary || "")}</td>
            <td><span class="badge ${esc(d.status || "draft")}">${esc(d.status || "draft")}</span></td>
            <td>${actions(`
              <button data-edit-d="${esc(d.id)}">Edit</button>
              <button data-del-d="${esc(d.id)}" class="danger">Delete</button>
            `)}</td>
          </tr>`).join("") || `<tr><td colspan="6">No FIR drafts.</td></tr>`}
      </tbody>
    </table>
  `;
  $("add-draft").onclick = () => draftForm();
  panel.querySelectorAll("[data-edit-d]").forEach((b) => b.onclick = () => draftForm(data.find((x) => x.id === b.dataset.editD)));
  panel.querySelectorAll("[data-del-d]").forEach((b) => b.onclick = () => del("/api/drafts/" + b.dataset.delD, "drafts"));
}

function draftForm(row) {
  openModal(row ? "Edit FIR draft" : "New FIR draft", `
    ${field("reportNumber", "Report number", row?.reportNumber)}
    ${field("officerId", "Officer ID", row?.officerId)}
    ${field("officerName", "Officer name", row?.officerName)}
    ${field("complainantName", "Complainant", row?.complainantName)}
    ${field("complainantPhone", "Complainant phone", row?.complainantPhone)}
    ${field("station", "Station", row?.station)}
    ${field("district", "District", row?.district)}
    ${field("natureOfOffence", "Nature of offence", row?.natureOfOffence)}
    ${field("placeOfOccurrence", "Place", row?.placeOfOccurrence)}
    ${field("occurrenceDate", "Date", row?.occurrenceDate)}
    ${field("occurrenceTime", "Time", row?.occurrenceTime)}
    ${field("rawTranscript", "Transcript", row?.rawTranscript, "textarea")}
    ${field("summary", "Summary", row?.summary, "textarea")}
    ${field("status", "Status (draft/completed/submitted)", row?.status || "draft")}
    <div class="toolbar"><button type="submit">Save</button><button type="button" class="ghost" id="cancel">Cancel</button></div>
  `);
  $("cancel").onclick = closeModal;
  $("modal-form").onsubmit = async (e) => {
    e.preventDefault();
    const v = formValues(e.target);
    if (row) {
      await api("/api/drafts/" + row.id, { method: "PUT", body: JSON.stringify({ ...row, ...v }) });
    } else {
      v.id = crypto.randomUUID();
      await api("/api/drafts", { method: "POST", body: JSON.stringify(v) });
    }
    closeModal();
    showFlash("FIR draft saved");
    render("drafts");
  };
}

async function renderStations() {
  const { data } = await api("/api/admin/stations");
  panel.innerHTML = `
    <div class="toolbar"><button id="add-st">Add station</button></div>
    <table>
      <thead><tr><th>Name</th><th>District</th><th>State</th><th></th></tr></thead>
      <tbody>
        ${data.map((s) => `
          <tr>
            <td>${esc(s.name)}</td><td>${esc(s.district || "")}</td><td>${esc(s.state || "")}</td>
            <td>${actions(`<button data-edit-st="${esc(s.id)}">Edit</button><button data-del-st="${esc(s.id)}" class="danger">Delete</button>`)}</td>
          </tr>`).join("")}
      </tbody>
    </table>
  `;
  $("add-st").onclick = () => stationForm();
  panel.querySelectorAll("[data-edit-st]").forEach((b) => b.onclick = () => stationForm(data.find((x) => x.id === b.dataset.editSt)));
  panel.querySelectorAll("[data-del-st]").forEach((b) => b.onclick = () => del("/api/admin/stations/" + b.dataset.delSt, "stations"));
}

function stationForm(row) {
  openModal(row ? "Edit station" : "New station", `
    ${field("name", "Name", row?.name)}
    ${field("district", "District", row?.district)}
    ${field("state", "State", row?.state)}
    <div class="toolbar"><button type="submit">Save</button><button type="button" class="ghost" id="cancel">Cancel</button></div>
  `);
  $("cancel").onclick = closeModal;
  $("modal-form").onsubmit = async (e) => {
    e.preventDefault();
    const v = formValues(e.target);
    if (row) await api("/api/admin/stations/" + row.id, { method: "PUT", body: JSON.stringify(v) });
    else await api("/api/admin/stations", { method: "POST", body: JSON.stringify(v) });
    closeModal();
    showFlash("Station saved");
    render("stations");
  };
}

async function renderAdmins() {
  const { data } = await api("/api/admin/admins");
  panel.innerHTML = `
    <div class="toolbar"><button id="add-ad">Add admin</button></div>
    <table>
      <thead><tr><th>Name</th><th>Username</th><th>Email</th><th></th></tr></thead>
      <tbody>
        ${data.map((a) => `
          <tr>
            <td>${esc(a.name)}</td><td>${esc(a.username)}</td><td>${esc(a.email)}</td>
            <td>${actions(`<button data-edit-ad="${esc(a.id)}">Edit</button><button data-del-ad="${esc(a.id)}" class="danger">Delete</button>`)}</td>
          </tr>`).join("")}
      </tbody>
    </table>
  `;
  $("add-ad").onclick = () => adminForm();
  panel.querySelectorAll("[data-edit-ad]").forEach((b) => b.onclick = () => adminForm(data.find((x) => x.id === b.dataset.editAd)));
  panel.querySelectorAll("[data-del-ad]").forEach((b) => b.onclick = () => del("/api/admin/admins/" + b.dataset.delAd, "admins"));
}

function adminForm(row) {
  openModal(row ? "Edit admin" : "New admin", `
    ${field("name", "Name", row?.name)}
    ${field("username", "Username", row?.username)}
    ${field("email", "Email", row?.email, "email")}
    ${field("password", row ? "New password (blank = keep)" : "Password", "", "password")}
    <div class="toolbar"><button type="submit">Save</button><button type="button" class="ghost" id="cancel">Cancel</button></div>
  `);
  $("cancel").onclick = closeModal;
  $("modal-form").onsubmit = async (e) => {
    e.preventDefault();
    const v = formValues(e.target);
    if (!v.password) delete v.password;
    if (row) await api("/api/admin/admins/" + row.id, { method: "PUT", body: JSON.stringify(v) });
    else await api("/api/admin/admins", { method: "POST", body: JSON.stringify(v) });
    closeModal();
    showFlash("Admin saved");
    render("admins");
  };
}

async function renderEmails() {
  const { data } = await api("/api/admin/emails");
  panel.innerHTML = `
    <p class="muted">Every credential email is stored here. If SMTP is not configured, this is how you demonstrate delivery.</p>
    <table>
      <thead><tr><th>When</th><th>To</th><th>Subject</th><th>Delivered</th><th></th></tr></thead>
      <tbody>
        ${data.map((e) => `
          <tr>
            <td>${new Date(e.createdAt).toLocaleString()}</td>
            <td>${esc(e.to)}</td>
            <td>${esc(e.subject)}</td>
            <td>${esc(e.delivered ? "Yes" : "Log only")}</td>
            <td>${actions(`<button data-view-e="${esc(e.id)}">View</button><button data-del-e="${esc(e.id)}" class="danger">Delete</button>`)}</td>
          </tr>`).join("") || `<tr><td colspan="5">No emails yet.</td></tr>`}
      </tbody>
    </table>
  `;
  panel.querySelectorAll("[data-view-e]").forEach((b) => {
    b.onclick = () => {
      const e = data.find((x) => x.id === b.dataset.viewE);
      openModal("Email", `<pre>${esc(e.text || "")}</pre><button type="button" class="ghost" id="cancel">Close</button>`);
      $("cancel").onclick = closeModal;
    };
  });
  panel.querySelectorAll("[data-del-e]").forEach((b) => b.onclick = () => del("/api/admin/emails/" + b.dataset.delE, "emails"));
}

async function del(path, tab) {
  if (!confirm("Delete this record?")) return;
  await api(path, { method: "DELETE" });
  showFlash("Deleted");
  render(tab);
}

boot();
