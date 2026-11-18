const jwt = require("jsonwebtoken");
const bcrypt = require("bcryptjs");

const JWT_SECRET = process.env.JWT_SECRET || "nyayvanni-dev-secret-change-me";

function sign(payload) {
  return jwt.sign(payload, JWT_SECRET, { expiresIn: "7d" });
}

function authRequired(roles) {
  return (req, res, next) => {
    const header = req.headers.authorization || "";
    const token = header.startsWith("Bearer ") ? header.slice(7) : null;
    if (!token) return res.status(401).json({ error: "Sign in required" });
    try {
      const user = jwt.verify(token, JWT_SECRET);
      if (roles && !roles.includes(user.role)) {
        return res.status(403).json({ error: "Not allowed" });
      }
      req.user = user;
      next();
    } catch {
      return res.status(401).json({ error: "Invalid or expired session" });
    }
  };
}

async function checkPassword(hash, password) {
  return bcrypt.compare(password, hash);
}

module.exports = { sign, authRequired, checkPassword };
