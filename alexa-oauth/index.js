const express = require('express');
const bodyParser = require('body-parser');
const admin = require('firebase-admin');
const jwt = require('jsonwebtoken');
const cors = require('cors');
const path = require('path');
const axios = require('axios');

// === Firebase Init ===
const serviceAccount = require('./serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: serviceAccount.project_id,
});
const firestore = admin.firestore();
console.log("✅ Firebase Admin initialized");

const FIREBASE_API_KEY = 'AIzaSyDW5glX6e8GMXtlAlyZnoDB6KfWDqw08X0';
const CLIENT_ID = 'amzn1.application-oa2-client.alexa-client';
const CLIENT_SECRET = 'alexa-secret';

const app = express();
const port = process.env.PORT || 3000;
app.use(cors());
app.use(bodyParser.urlencoded({ extended: true }));
app.use(bodyParser.json());
app.use(express.static('public'));

const userTokens = {}; // in-memory fallback

// === Step 1: Alexa -> /authorize
app.get('/authorize', (req, res) => {
  const { redirect_uri, state, client_id } = req.query;

  if (!redirect_uri || !state || !client_id) {
    console.error("❌ Missing parameters in /authorize");
    return res.status(400).send("Missing query parameters.");
  }

  const loginUrl = `/login?redirect_uri=${encodeURIComponent(redirect_uri)}&state=${encodeURIComponent(state)}&client_id=${encodeURIComponent(client_id)}`;
  console.log("📍 Redirecting to login page:", loginUrl);
  res.redirect(loginUrl);
});

// === Step 2: Serve Login Page
app.get('/login', (req, res) => {
  res.setHeader('Cache-Control', 'no-store');
  res.sendFile(path.join(__dirname, 'login.html'));
});

// === Step 3: Handle Login Form POST
app.post('/login', async (req, res) => {
  const { email, password, redirect_uri, state, client_id } = req.body;

  if (!email || !password || !redirect_uri || !state || !client_id) {
    console.error("❌ Invalid login form submission");
    return res.status(400).send("Invalid login form.");
  }

  try {
    console.log(`🔐 Login attempt from: ${email}`);
    const result = await axios.post(
      `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${FIREBASE_API_KEY}`,
      { email, password, returnSecureToken: true }
    );

    const uid = result.data.localId;
    console.log(`✅ Firebase login success: ${email} | UID: ${uid}`);

    const code = jwt.sign({ uid }, CLIENT_SECRET, { expiresIn: '10m' });
    const redirectUrl = `${redirect_uri}?code=${code}&state=${state}`;
    console.log("🔁 Redirecting back to Alexa:", redirectUrl);

    res.redirect(redirectUrl);
  } catch (err) {
    console.error("❌ Login failed:", err.response?.data || err.message);
    res.status(401).send("Invalid login credentials. Please go back and try again.");
  }
});

// === Step 4: Alexa calls /token
app.post('/token', async (req, res) => {
  const { client_id, client_secret, code, grant_type, refresh_token } = req.body;
  console.log("📥 /token request:", req.body);

  if (client_id !== CLIENT_ID || client_secret !== CLIENT_SECRET) {
    console.error("❌ Invalid Alexa credentials");
    return res.status(401).json({ error: 'invalid_client' });
  }

  try {
    if (grant_type === 'authorization_code') {
      const decoded = jwt.verify(code, CLIENT_SECRET);
      const uid = decoded.uid;
      console.log("✅ Auth code verified, UID:", uid);

      const access_token = jwt.sign({ uid }, CLIENT_SECRET, { expiresIn: '1h' });
      const new_refresh_token = jwt.sign({ uid }, CLIENT_SECRET, { expiresIn: '30d' });

      userTokens[new_refresh_token] = { access_token, uid };

      try {
        const userSnap = await firestore.collection('users').doc(uid).get();
        const email = userSnap.exists ? userSnap.data().email : 'unknown';

        await firestore.collection('users').doc(uid).set({
          email,
          access_token,
          refresh_token: new_refresh_token,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });

        console.log(`✅ Tokens saved for UID: ${uid} (${email})`);
      } catch (firestoreError) {
        console.error("❌ Firestore write error:", firestoreError);
      }

      return res.json({
        token_type: 'Bearer',
        access_token,
        refresh_token: new_refresh_token,
        expires_in: 3600
      });
    }

    if (grant_type === 'refresh_token') {
      const data = userTokens[refresh_token];
      if (!data) {
        console.error("❌ Refresh token not found");
        return res.status(400).json({ error: 'invalid_grant' });
      }

      const newAccessToken = jwt.sign({ uid: data.uid }, CLIENT_SECRET, { expiresIn: '1h' });
      userTokens[refresh_token].access_token = newAccessToken;

      await firestore.collection('users').doc(data.uid).update({
        access_token: newAccessToken,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      console.log("🔁 Refreshed access token for UID:", data.uid);

      return res.json({
        token_type: 'Bearer',
        access_token: newAccessToken,
        refresh_token,
        expires_in: 3600
      });
    }

    return res.status(400).json({ error: 'unsupported_grant_type' });
  } catch (err) {
    console.error("❌ /token handler error:", err);
    return res.status(500).json({ error: 'server_error', message: err.message });
  }
});

// === Optional Callback Message
app.get('/callback', (req, res) => {
  res.send(`<h2>✅ Alexa Account Linked</h2><p>You may now return to the Alexa app.</p>`);
});

// === Profile API (optional)
app.get('/profile', (req, res) => {
  const token = (req.headers.authorization || '').replace('Bearer ', '');
  try {
    const decoded = jwt.verify(token, CLIENT_SECRET);
    res.json({ user_id: decoded.uid });
  } catch (err) {
    console.error("❌ Invalid profile token:", err.message);
    return res.status(401).json({ error: 'invalid_token' });
  }
});

app.listen(port, () => {
  console.log(`🚀 Alexa OAuth server running at http://localhost:${port}`);
});
