const express = require("express");
const bodyParser = require("body-parser");
const admin = require("firebase-admin");
const axios = require("axios");
const jwt = require("jsonwebtoken");
const path = require("path");

const app = express();
const PORT = process.env.PORT || 3000;
const FIREBASE_API_KEY = "AIzaSyDW5glX6e8GMXtlAlyZnoDB6KfWDqw08X0";
const CLIENT_SECRET = "alexa-secret";

const serviceAccount = require("./serviceAccountKey.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});
console.log("✅ Firebase Admin initialized");

app.use(bodyParser.urlencoded({ extended: true }));
app.use(bodyParser.json());
app.use(express.static("public"));

app.set("views", path.join(__dirname, "views"));
app.set("view engine", "ejs");

// Step 1: Alexa authorization endpoint
app.get("/authorize", (req, res) => {
  const { client_id, redirect_uri, state } = req.query;
  res.render("login", { client_id, redirect_uri, state });
});

// Step 2: Login POST
app.post("/login", async (req, res) => {
  const { email, password, client_id, redirect_uri, state } = req.body;

  try {
    // Verify password with Firebase REST API
    const result = await axios.post(
      `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${FIREBASE_API_KEY}`,
      { email, password, returnSecureToken: true }
    );

    const uid = result.data.localId;
    console.log(`✅ Login success. UID: ${uid}, Email: ${email}`);

    // Sign the auth code (short-lived JWT)
    const code = jwt.sign({ uid }, CLIENT_SECRET, { expiresIn: "10m" });

    const redirectUrl = `${redirect_uri}?code=${code}&state=${state}`;
    console.log("🔁 Redirecting to Alexa:", redirectUrl);
    res.redirect(redirectUrl);
  } catch (err) {
    console.error("❌ Login failed:", err.response?.data || err.message);
    res.render("login", {
      client_id,
      redirect_uri,
      state,
      error: "Invalid credentials. Please try again.",
    });
  }
});

// Step 3: Token exchange
app.post("/token", (req, res) => {
  const { code, grant_type } = req.body;

  if (grant_type !== "authorization_code") {
    return res.status(400).json({ error: "unsupported_grant_type" });
  }

  try {
    const decoded = jwt.verify(code, CLIENT_SECRET);
    const uid = decoded.uid;

    const access_token = jwt.sign({ uid }, CLIENT_SECRET, { expiresIn: "1h" });
    const refresh_token = jwt.sign({ uid }, CLIENT_SECRET, { expiresIn: "30d" });

    console.log("🔑 Token issued for UID:", uid);

    return res.json({
      token_type: "Bearer",
      access_token,
      refresh_token,
      expires_in: 3600,
    });
  } catch (err) {
    console.error("❌ Invalid token code:", err.message);
    return res.status(400).json({ error: "invalid_grant" });
  }
});

// Step 4: Refresh token
app.post("/refresh", (req, res) => {
  const { refresh_token, grant_type } = req.body;

  if (grant_type !== "refresh_token") {
    return res.status(400).json({ error: "unsupported_grant_type" });
  }

  try {
    const decoded = jwt.verify(refresh_token, CLIENT_SECRET);
    const uid = decoded.uid;
    const access_token = jwt.sign({ uid }, CLIENT_SECRET, { expiresIn: "1h" });

    console.log("🔁 Refreshed token for UID:", uid);

    return res.json({
      token_type: "Bearer",
      access_token,
      refresh_token,
      expires_in: 3600,
    });
  } catch (err) {
    console.error("❌ Invalid refresh token:", err.message);
    return res.status(400).json({ error: "invalid_grant" });
  }
});

// Serve confirmation message
app.get("/callback", (req, res) => {
  res.send("<h3>✅ Alexa account linked successfully. You may now close this window.</h3>");
});

app.listen(PORT, () => {
  console.log(`🚀 Alexa OAuth server running at http://localhost:${PORT}`);
});
