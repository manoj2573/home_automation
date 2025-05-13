const express = require("express");
const admin = require("firebase-admin");
const bodyParser = require("body-parser");
const cookieParser = require("cookie-parser");
const path = require("path");

const app = express();
const PORT = 3000;

// Initialize Firebase Admin SDK
const serviceAccount = require("./serviceAccountKey.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

app.use(bodyParser.urlencoded({ extended: true }));
app.use(cookieParser());
app.use(express.static("public"));

// OAuth2 authorization endpoint
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
          <input name="password" placeholder="Password" type="password" required />
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
  

// Login form POST
app.post("/login", async (req, res) => {
  const { email, password, client_id, redirect_uri, state } = req.body;

  try {
    const user = await admin.auth().getUserByEmail(email);

    // Optionally verify password with your own DB system (Firebase Admin doesn't support password auth directly)

    const code = Buffer.from(`${email}:${client_id}`).toString("base64");

    const redirectUrl = `${redirect_uri}?code=${code}&state=${state}`;
    res.redirect(redirectUrl);
  } catch (error) {
    res.send("Login failed: " + error.message);
  }
});

// Token exchange endpoint
app.post("/token", async (req, res) => {
  const { code, grant_type } = req.body;

  if (grant_type !== "authorization_code") {
    return res.status(400).json({ error: "unsupported_grant_type" });
  }

  try {
    const decoded = Buffer.from(code, "base64").toString("utf8");
    const [email, clientId] = decoded.split(":");

    const access_token = Buffer.from(`${email}:${Date.now()}`).toString("base64");
    const refresh_token = Buffer.from(`${email}:refresh`).toString("base64");

    res.json({
      token_type: "Bearer",
      access_token,
      refresh_token,
      expires_in: 3600,
    });
  } catch (error) {
    res.status(400).json({ error: "invalid_grant" });
  }
});

// Refresh token endpoint
app.post("/refresh", (req, res) => {
  const { refresh_token, grant_type } = req.body;

  if (grant_type !== "refresh_token") {
    return res.status(400).json({ error: "unsupported_grant_type" });
  }

  const email = Buffer.from(refresh_token, "base64").toString("utf8").split(":")[0];
  const new_access_token = Buffer.from(`${email}:${Date.now()}`).toString("base64");

  res.json({
    token_type: "Bearer",
    access_token: new_access_token,
    expires_in: 3600,
  });
});

app.listen(PORT, () => {
  console.log(`🚀 OAuth Server running at http://localhost:${PORT}`);
});
