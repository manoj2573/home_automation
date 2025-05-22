const express = require("express");
const admin = require("firebase-admin");
const bodyParser = require("body-parser");
const cookieParser = require("cookie-parser");
const path = require("path");
const axios = require("axios");
const jwt = require("jsonwebtoken");
const fs = require("fs");

const app = express();
const PORT = process.env.PORT || 3000;

// === Firebase Admin Init ===
const serviceAccount = require("./serviceAccountKey.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});
const FIREBASE_API_KEY = "AIzaSyDW5glX6e8GMXtlAlyZnoDB6KfWDqw08X0"; // Replace with your Firebase Web API Key
const CLIENT_SECRET = "alexa-secret";

app.use(bodyParser.urlencoded({ extended: true }));
app.use(cookieParser());
app.use(express.static("public"));

// === Step 1: OAuth Authorization Page ===
app.get("/authorize", (req, res) => {
  const { client_id, redirect_uri, state } = req.query;

  const html = fs.readFileSync(path.join(__dirname, "login.html"), "utf8")
    .replace("{{client_id}}", client_id)
    .replace("{{redirect_uri}}", redirect_uri)
    .replace("{{state}}", state);

  res.send(html);
});

// === Step 2: Handle Login POST ===
app.post("/login", async (req, res) => {
  const { email, password, client_id, redirect_uri, state } = req.body;

  try {
    const result = await axios.post(
      `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${FIREBASE_API_KEY}`,
      {
        email,
        password,
        returnSecureToken: true,
      }
    );

    const uid = result.data.localId;
    console.log(`✅ Firebase login success. Email: ${email}, UID: ${uid}`);

    const code = jwt.sign({ uid }, CLIENT_SECRET, { expiresIn: "10m" });
    const redirectUrl = `${redirect_uri}?code=${code}&state=${state}`;
    return res.redirect(redirectUrl);
  } catch (err) {
    console.error("❌ Login failed:", err.response?.data || err.message);
    return res.send(`<script>alert("Invalid credentials. Try again."); window.history.back();</script>`);
  }
});

// === Step 3: Token Exchange ===
app.post("/token", async (req, res) => {
  const { code, grant_type } = req.body;

  if (grant_type !== "authorization_code") {
    return res.status(400).json({ error: "unsupported_grant_type" });
  }

  try {
    const decoded = jwt.verify(code, CLIENT_SECRET);
    const uid = decoded.uid;
    const access_token = jwt.sign({ uid }, CLIENT_SECRET, { expiresIn: "1h" });
    const refresh_token = jwt.sign({ uid }, CLIENT_SECRET, { expiresIn: "30d" });

    console.log(`🔐 Issued token for UID: ${uid}`);

    return res.json({
      token_type: "Bearer",
      access_token,
      refresh_token,
      expires_in: 3600,
    });
  } catch (err) {
    console.error("❌ Token exchange failed:", err.message);
    return res.status(400).json({ error: "invalid_grant" });
  }
});

// === Step 4: Refresh Token ===
app.post("/refresh", (req, res) => {
  const { refresh_token, grant_type } = req.body;

  if (grant_type !== "refresh_token") {
    return res.status(400).json({ error: "unsupported_grant_type" });
  }

  try {
    const decoded = jwt.verify(refresh_token, CLIENT_SECRET);
    const newAccessToken = jwt.sign({ uid: decoded.uid }, CLIENT_SECRET, { expiresIn: "1h" });

    return res.json({
      token_type: "Bearer",
      access_token: newAccessToken,
      refresh_token,
      expires_in: 3600,
    });
  } catch (err) {
    console.error("❌ Refresh failed:", err.message);
    return res.status(400).json({ error: "invalid_token" });
  }
});

app.listen(PORT, () => {
  console.log(`🚀 Alexa OAuth Server running at http://localhost:${PORT}`);
});
