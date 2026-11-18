const crypto = require("crypto");
const jwt = require("jsonwebtoken");
const bcrypt = require("bcryptjs");
const store = require("./store");

// A missing JWT_SECRET must never fall back to a publicly known value.
// Without one, a random secret is generated per process (sessions reset on restart).
let JWT_SECRET = process.env.JWT_SECRET;
if (!JWT_SECRET) {
  JWT_SECRET = crypto.randomBytes(48).toString("hex");
  console.warn("JWT_SECRET is not set - using a temporary secret. Sessions will end when the server restarts.");
}

function sign(payload) {
  return jwt.sign(payload, JWT_SECRET, { expiresIn: "7d" });
}

function authRequired(roles) {
  return (req, res, next) => {
    const header = req.headers.authorization || "";
    const token = header.startsWith("Bearer ") ? header.slice(7) : null;
    if (!token) return res.status(401).json({ error: "Sign in required" });
    let user;
    try {
      user = jwt.verify(token, JWT_SECRET);
    } catch {
      return res.status(401).json({ error: "Invalid or expired session" });
    }
    if (roles && !roles.includes(user.role)) {
      return res.status(403).json({ error: "Not allowed" });
    }
    // Re-check the account on every request so deleted/disabled accounts lose access immediately.
    if (user.role === "admin") {
      if (!store.findAdminById(user.id)) {
        return res.status(401).json({ error: "Invalid or expired session" });
      }
    } else {
      const officer = store.findOfficerById(user.id);
      if (!officer || officer.status === "disabled") {
        return res.status(401).json({ error: "Account disabled or removed" });
      }
      user.officerId = officer.officerId; // always use the current ID, not the one baked into the token
    }
    req.user = user;
    next();
  };
}

async function checkPassword(hash, password) {
  return bcrypt.compare(password, hash);
}

module.exports = { sign, authRequired, checkPassword };
