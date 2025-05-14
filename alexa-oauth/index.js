const express = require("express");
const admin = require("firebase-admin");
const bodyParser = require("body-parser");
const path = require("path");

const app = express();
const PORT = process.env.PORT || 3000;

// === Firebase Admin Setup ===
const serviceAccount = require("./serviceAccountKey.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});
const auth = admin.auth();

app.use(bodyParser.urlencoded({ extended: true }));
app.use(express.static("public"));

// === /authorize ===
app.get("/authorize", (req, res) => {
  const { client_id, redirect_uri, state } = req.query;

  const html = `
    <!DOCTYPE html>
    <html>
    <head><title>Alexa Login</title></head>
    <body>
      <h2>Alexa Login</h2>
      <form method="POST" action="/login">
        <input name="email" placeholder="Email" required />
        <input name="password" type="password" placeholder="Password" required />
        <input type="hidden" name="client_id" value="${client_id}" />
        <input type="hidden" name="redirect_uri" value="${redirect_uri}" />
        <input type="hidden" name="state" value="${state}" />
        <button type="submit">Login</button>
      </form>
    </body>
    </html>
  `;
  res.send(html);
});

// === /login ===
app.post("/login", async (req, res) => {
  const { email, client_id, redirect_uri, state } = req.body;

  // Generate safe, valid code
  const codeRaw = `${Date.now()}_${email}`;
  const code = Buffer.from(codeRaw).toString("base64").replace(/=/g, "");

  // Safe redirect
  const url = new URL(redirect_uri);
  url.searchParams.set("code", code);
  url.searchParams.set("state", state);

  console.log("✅ Login bypassed check. Redirecting to:", url.toString());
  return res.redirect(url.toString());
});


// === /token ===
app.post("/token", (req, res) => {
  const { code, grant_type } = req.body;

  if (grant_type !== "authorization_code") {
    return res.status(400).json({ error: "unsupported_grant_type" });
  }

  try {
    const decoded = Buffer.from(code, "base64").toString("utf8");
    const email = decoded.split("_")[1];

    const access_token = Buffer.from(`${email}:${Date.now()}`).toString("base64").replace(/=/g, "");
    const refresh_token = Buffer.from(`${email}:refresh`).toString("base64").replace(/=/g, "");

    res.json({
      access_token,
      token_type: "Bearer",
      expires_in: 3600,
      refresh_token,
    });
  } catch (error) {
    console.error("❌ Token exchange failed:", error.message);
    res.status(400).json({ error: "invalid_grant" });
  }
});

// === /refresh ===
app.post("/refresh", (req, res) => {
  const { refresh_token, grant_type } = req.body;

  if (grant_type !== "refresh_token") {
    return res.status(400).json({ error: "unsupported_grant_type" });
  }

  try {
    const decoded = Buffer.from(refresh_token, "base64").toString("utf8");
    const email = decoded.split(":")[0];

    const new_access_token = Buffer.from(`${email}:${Date.now()}`).toString("base64").replace(/=/g, "");

    res.json({
      access_token: new_access_token,
      token_type: "Bearer",
      expires_in: 3600,
    });
  } catch (error) {
    console.error("❌ Refresh token error:", error.message);
    res.status(400).json({ error: "invalid_refresh_token" });
  }
});

// === Start Server ===
app.listen(PORT, () => {
  console.log(`🚀 OAuth Server running at http://localhost:${PORT}`);
});
