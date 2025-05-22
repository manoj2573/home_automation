const express = require("express");
const bodyParser = require("body-parser");
const admin = require("firebase-admin");
const cors = require("cors");
const path = require("path");
const axios = require("axios");
const jwt = require("jsonwebtoken");

const app = express();
const PORT = process.env.PORT || 3000;
const FIREBASE_API_KEY = "AIzaSyDW5glX6e8GMXtlAlyZnoDB6KfWDqw08X0"; // Replace this
const CLIENT_SECRET = "alexa-secret"; // Same used in Lambda

const serviceAccount = require("./serviceAccountKey.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});
const firestore = admin.firestore();

app.use(cors());
app.use(bodyParser.urlencoded({ extended: true }));
app.use(bodyParser.json());
app.use(express.static("public"));
app.set("view engine", "ejs");
app.set("views", path.join(__dirname, "views"));

// === OAuth Authorization
app.get("/authorize", (req, res) => {
  const { client_id, redirect_uri, state } = req.query;
  res.render("login", { client_id, redirect_uri, state, error: null });
});

// === Login POST
app.post("/login", async (req, res) => {
  const { email, password, client_id, redirect_uri, state } = req.body;

  try {
    console.log("🔐 Attempting login for:", email);

    const user = await admin.auth().getUserByEmail(email);
    const uid = user.uid;

    // Generate code to return to Alexa
    const code = Buffer.from(`${email}:${client_id}`).toString("base64");
    console.log("✅ Generated code:", code);

    const redirectUrl = `${redirect_uri}?code=${code}&state=${state}`;
    console.log("🔁 Redirecting to:", redirectUrl);
    res.redirect(redirectUrl);
  } catch (error) {
    console.error("❌ Login failed:", error.message);
    res.send("Login failed: " + error.message);
  }
});


// === Token Exchange
app.post("/token", async (req, res) => {
  const { code, grant_type } = req.body;

  if (grant_type !== "authorization_code") {
    return res.status(400).json({ error: "unsupported_grant_type" });
  }

  try {
    const decoded = Buffer.from(code, "base64").toString("utf8");
    const [email, clientId] = decoded.split(":");

    const user = await admin.auth().getUserByEmail(email);
    const uid = user.uid;

    // ✅ Create real JWT token with UID (not base64 string)
    const access_token = jwt.sign({ uid }, "alexa-secret", { expiresIn: "1h" });
    const refresh_token = jwt.sign({ uid }, "alexa-secret", { expiresIn: "30d" });

    // Optional: store in Firestore for proactive events
    await firestore.collection("users").doc(uid).set({
      access_token,
      refresh_token,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });

    return res.json({
      token_type: "Bearer",
      access_token,
      refresh_token,
      expires_in: 3600
    });
  } catch (error) {
    console.error("❌ Token exchange failed:", error.message);
    return res.status(400).json({ error: "invalid_grant" });
  }
});


// === Refresh token
app.post("/refresh", async (req, res) => {
  const { refresh_token, grant_type } = req.body;
  if (grant_type !== "refresh_token") return res.status(400).json({ error: "unsupported_grant_type" });

  try {
    const decoded = jwt.verify(refresh_token, CLIENT_SECRET);
    const uid = decoded.uid;
    const access_token = jwt.sign({ uid }, CLIENT_SECRET, { expiresIn: "1h" });

    await firestore.collection("users").doc(uid).update({ access_token });
    res.json({ token_type: "Bearer", access_token, refresh_token, expires_in: 3600 });
  } catch {
    res.status(401).json({ error: "invalid_grant" });
  }
});

app.listen(PORT, () => console.log(`🚀 Alexa OAuth server running at http://localhost:${PORT}`));
