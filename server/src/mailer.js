const nodemailer = require("nodemailer");
const store = require("./store");

function credentialsHtml({ fullName, officerId, password }) {
  return `
    <div style="font-family:Georgia,serif;color:#2D3748;line-height:1.6">
      <h2>NyayVanni officer account</h2>
      <p>Hello ${fullName},</p>
      <p>Your registration has been approved. Use these credentials to sign in to the NyayVanni app.</p>
      <p><strong>Officer ID:</strong> ${officerId}<br/>
      <strong>Password:</strong> ${password}</p>
      <p>Please change your password after first login if the admin provided a temporary password.</p>
      <p>— NyayVanni Admin</p>
    </div>
  `;
}

async function sendMail({ to, subject, html, text }) {
  const record = { to, subject, html, text, delivered: false, error: null };

  if (process.env.SMTP_HOST) {
    try {
      const transporter = nodemailer.createTransport({
        host: process.env.SMTP_HOST,
        port: Number(process.env.SMTP_PORT || 587),
        secure: process.env.SMTP_SECURE === "true",
        auth: process.env.SMTP_USER
          ? { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS }
          : undefined,
      });
      await transporter.sendMail({
        from: process.env.SMTP_FROM || "NyayVanni <noreply@nyayvanni.local>",
        to,
        subject,
        html,
        text,
      });
      record.delivered = true;
    } catch (err) {
      record.error = err.message;
    }
  } else {
    record.error = "SMTP not configured — stored in email log for demo";
  }

  const saved = store.addEmail(record);
  console.log(`[email] to=${to} subject=${subject} delivered=${record.delivered}`);
  return saved;
}

async function sendOfficerCredentials({ fullName, email, officerId, password }) {
  const subject = "Your NyayVanni officer ID and password";
  const text = `Hello ${fullName},\n\nOfficer ID: ${officerId}\nPassword: ${password}\n\nUse these to sign in to NyayVanni.`;
  return sendMail({
    to: email,
    subject,
    html: credentialsHtml({ fullName, officerId, password }),
    text,
  });
}

module.exports = { sendMail, sendOfficerCredentials };
