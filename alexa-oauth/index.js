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

const FIREBASE_API_KEY = 'AIzaSyDW5glX6e8GMXtlAlyZnoDB6KfWDqw08X0'; // ⛳ Replace with your Firebase Web API Key

// === Server Config ===
const app = express();
const port = process.env.PORT || 3000;
app.use(cors());
app.use(bodyParser.urlencoded({ extended: true }));
app.use(bodyParser.json());
app.use(express.static('public'));

// === Constants ===
const CLIENT_ID = 'amzn1.application-oa2-client.alexa-client';
const CLIENT_SECRET = 'alexa-secret';

// === In-Memory Store for Tokens (ephemeral)
const userTokens = {}; // { refreshToken: { access_token, uid } }

// === Step 1: Alexa hits this to start OAuth flow
app.get('/authorize', (req, res) => {
  const { redirect_uri, state, client_id } = req.query;
  const loginUrl = `/login?redirect_uri=${encodeURIComponent(redirect_uri)}&state=${encodeURIComponent(state)}&client_id=${encodeURIComponent(client_id)}`;
  res.redirect(loginUrl);
});

// === Step 2: Show Login Page
app.get('/login', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'login.html'));
});

// === Step 3: Handle Login Form
app.post('/login', async (req, res) => {
  const { email, password, redirect_uri, state } = req.body;

  try {
    // Firebase Auth REST API sign-in
    const result = await axios.post(
      `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${FIREBASE_API_KEY}`,
      {
        email,
        password,
        returnSecureToken: true,
      }
    );

    const uid = result.data.localId;
    const code = jwt.sign({ uid }, CLIENT_SECRET, { expiresIn: '10m' });
    userTokens[code] = { uid };

    console.log("✅ Login success for:", email, "UID:", uid);
    const redirectUrl = `${redirect_uri}?code=${code}&state=${state}`;
    res.redirect(redirectUrl);

  } catch (error) {
    console.error("❌ Login failed:", error.response?.data || error.message);
    res.status(401).send('Invalid login credentials');
  }
});

// === Step 4: Token Exchange (Authorization Code → Access Token)
app.post('/token', async (req, res) => {
  const { client_id, client_secret, code, grant_type, refresh_token } = req.body;

  console.log("🔐 Token request:", req.body);

  if (client_id !== CLIENT_ID || client_secret !== CLIENT_SECRET) {
    return res.status(401).json({ error: 'invalid_client' });
  }

  if (grant_type === 'authorization_code') {
    const data = userTokens[code];
    if (!data) return res.status(400).json({ error: 'invalid_grant' });

    const access_token = jwt.sign({ uid: data.uid }, CLIENT_SECRET, { expiresIn: '1h' });
    const new_refresh_token = jwt.sign({ uid: data.uid }, CLIENT_SECRET, { expiresIn: '30d' });

    userTokens[new_refresh_token] = { access_token, uid: data.uid };

    // ✅ Save access_token to Firestore
    await firestore.collection('users').doc(data.uid).set({
      access_token
    }, { merge: true });

    console.log("✅ Token saved to Firestore for UID:", data.uid);

    return res.json({
      token_type: 'Bearer',
      access_token,
      refresh_token: new_refresh_token,
      expires_in: 3600
    });
  }

  if (grant_type === 'refresh_token') {
    const data = userTokens[refresh_token];
    if (!data) return res.status(400).json({ error: 'invalid_grant' });

    const newAccessToken = jwt.sign({ uid: data.uid }, CLIENT_SECRET, { expiresIn: '1h' });
    userTokens[refresh_token].access_token = newAccessToken;

    return res.json({
      token_type: 'Bearer',
      access_token: newAccessToken,
      refresh_token,
      expires_in: 3600
    });
  }

  return res.status(400).json({ error: 'unsupported_grant_type' });
});

// === Step 5: User Profile API (optional for testing)
app.get('/profile', (req, res) => {
  const auth = req.headers.authorization || '';
  const token = auth.replace('Bearer ', '');

  try {
    const decoded = jwt.verify(token, CLIENT_SECRET);
    res.json({ user_id: decoded.uid });
  } catch (err) {
    return res.status(401).json({ error: 'invalid_token' });
  }
});

// === Start Server ===
app.listen(port, () => {
  console.log(`🚀 Alexa OAuth server running at http://localhost:${port}`);
});
