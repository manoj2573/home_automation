// === index.js ===
const express = require("express");
const admin = require("firebase-admin");
const bodyParser = require("body-parser");
const cookieParser = require("cookie-parser");
const cors = require("cors");
const path = require("path");
const axios = require("axios");

const app = express();
const PORT = process.env.PORT || 3000;
const FIREBASE_API_KEY = "AIzaSyDW5glX6e8GMXtlAlyZnoDB6KfWDqw08X0"; // ✅ Replace with actual Web API key

// Firebase Admin SDK Init
const serviceAccount = require("./serviceAccountKey.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

app.set("view engine", "ejs");
app.set("views", path.join(__dirname, "views"));
app.use(express.static("public"));
app.use(bodyParser.urlencoded({ extended: true }));
app.use(cookieParser());
app.use(cors());

// === OAuth2 Authorization Endpoint ===
app.get("/authorize", (req, res) => {
  const { client_id, redirect_uri, state } = req.query;
  res.render("login", { client_id, redirect_uri, state, error: null });
});

// === Handle Login ===
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
    const code = Buffer.from(`${uid}:${client_id}`).toString("base64");
    const redirectUrl = `${redirect_uri}?code=${code}&state=${state}`;

    console.log(`✅ Login success for UID: ${uid}`);
    res.redirect(redirectUrl);
  } catch (error) {
    console.error("❌ Login failed:", error.response?.data || error.message);
    res.render("login", {
      client_id,
      redirect_uri,
      state,
      error: "Invalid email or password. Please try again.",
    });
  }
});

// === Token Exchange ===
app.post("/token", async (req, res) => {
  const { code, grant_type } = req.body;

  if (grant_type !== "authorization_code") {
    return res.status(400).json({ error: "unsupported_grant_type" });
  }

  try {
    const decoded = Buffer.from(code, "base64").toString("utf8");
    const [uid, clientId] = decoded.split(":");

    const access_token = Buffer.from(`${uid}:${Date.now()}`).toString("base64");
    const refresh_token = Buffer.from(`${uid}:refresh`).toString("base64");

    res.json({
      token_type: "Bearer",
      access_token,
      refresh_token,
      expires_in: 3600,
    });
  } catch (err) {
    console.error("❌ Token exchange failed:", err);
    res.status(400).json({ error: "invalid_grant" });
  }
});

// === Refresh Token Endpoint ===
app.post("/refresh", (req, res) => {
  const { refresh_token, grant_type } = req.body;

  if (grant_type !== "refresh_token") {
    return res.status(400).json({ error: "unsupported_grant_type" });
  }

  const uid = Buffer.from(refresh_token, "base64").toString("utf8").split(":")[0];
  const new_access_token = Buffer.from(`${uid}:${Date.now()}`).toString("base64");

  res.json({
    token_type: "Bearer",
    access_token: new_access_token,
    expires_in: 3600,
  });
});

app.listen(PORT, () => {
  console.log(`🚀 Alexa OAuth server running at http://localhost:${PORT}`);
});
