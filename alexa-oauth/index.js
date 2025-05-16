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

const FIREBASE_API_KEY = 'AIzaSyDW5glX6e8GMXtlAlyZnoDB6KfWDqw08X0'; // Replace with your Firebase Web API Key

// === App Config ===
const app = express();
const port = process.env.PORT || 3000;
app.use(cors());
app.use(bodyParser.urlencoded({ extended: true }));
app.use(bodyParser.json());
app.use(express.static('public'));

// === Constants ===
const CLIENT_ID = 'amzn1.application-oa2-client.alexa-client';
const CLIENT_SECRET = 'alexa-secret';

// === In-Memory Store
const userTokens = {}; // { refreshToken: { access_token, uid } }

// === Step 1: Alexa hits this to start OAuth flow
app.get('/authorize', (req, res) => {
  const { redirect_uri, state, client_id } = req.query;

  if (!redirect_uri || !state || !client_id) {
    return res.status(400).send("Missing required query parameters.");
  }

  // Save everything for POST to use
  const loginUrl = `/login?redirect_uri=${encodeURIComponent(redirect_uri)}&state=${encodeURIComponent(state)}&client_id=${encodeURIComponent(client_id)}`;
  res.redirect(loginUrl);
});
// === Step 2: Serve Login Form
app.get('/login', (req, res) => {
  const { redirect_uri, state, client_id } = req.query;
  
  if (!redirect_uri || !state || !client_id) {
    return res.status(400).send("Missing required query parameters.");
  }
  
  // Serve the login form with the parameters
  res.sendFile(path.join(__dirname, 'login.html'));
});

// === Step 2: Show Login Form
app.post('/login', async (req, res) => {
  const { email, password, redirect_uri, state, client_id } = req.body;

  if (!redirect_uri || !state || !client_id) {
    return res.status(400).send("Invalid request");
  }

  try {
    const result = await axios.post(
      `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${FIREBASE_API_KEY}`,
      { email, password, returnSecureToken: true }
    );

    const uid = result.data.localId;
    const code = jwt.sign({ uid }, CLIENT_SECRET, { expiresIn: '10m' });

    // ✅ IMPORTANT: Alexa will use this `code` to call /token
    const redirectUrl = `${redirect_uri}?code=${code}&state=${state}`;
    console.log("✅ Redirecting to:", redirectUrl);
    res.redirect(redirectUrl);
  } catch (err) {
    console.error("❌ Login error:", err.response?.data || err.message);
    res.status(401).send("Invalid login credentials");
  }
});


// === Step 4: Alexa exchanges code for token
app.post('/token', async (req, res) => {
  const { client_id, client_secret, code, grant_type, refresh_token } = req.body;

  console.log("🔐 /token request received:", req.body);

  if (client_id !== CLIENT_ID || client_secret !== CLIENT_SECRET) {
    return res.status(401).json({ error: 'invalid_client' });
  }

  try {
    if (grant_type === 'authorization_code') {
      // Verify the JWT code first
      let decoded;
      try {
        decoded = jwt.verify(code, CLIENT_SECRET);
      } catch (err) {
        return res.status(400).json({ error: 'invalid_grant', message: 'Invalid authorization code' });
      }

      const uid = decoded.uid;
      const access_token = jwt.sign({ uid }, CLIENT_SECRET, { expiresIn: '1h' });
      const new_refresh_token = jwt.sign({ uid }, CLIENT_SECRET, { expiresIn: '30d' });

      // Store tokens in memory
      userTokens[new_refresh_token] = { access_token, uid };

      // Store access token in Firestore with error handling
      try {
        await firestore.collection('users').doc(uid).set({ 
          access_token,
          refresh_token: new_refresh_token,
          updatedAt: admin.firestore.FieldValue.serverTimestamp() 
        }, { merge: true });
        
        console.log("✅ Token stored in Firestore for UID:", uid);
      } catch (firestoreError) {
        console.error("❌ Firestore error:", firestoreError);
        // Don't fail the request, just log the error
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
      if (!data) return res.status(400).json({ error: 'invalid_grant' });

      const newAccessToken = jwt.sign({ uid: data.uid }, CLIENT_SECRET, { expiresIn: '1h' });
      userTokens[refresh_token].access_token = newAccessToken;

      // Update Firestore with new access token
      try {
        await firestore.collection('users').doc(data.uid).update({
          access_token: newAccessToken,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
      } catch (firestoreError) {
        console.error("❌ Firestore update error:", firestoreError);
      }

      return res.json({
        token_type: 'Bearer',
        access_token: newAccessToken,
        refresh_token,
        expires_in: 3600
      });
    }

    return res.status(400).json({ error: 'unsupported_grant_type' });
  } catch (err) {
    console.error("❌ /token endpoint error:", err);
    return res.status(500).json({ error: 'server_error', message: err.message });
  }
});
// === Step 5: Success Page (optional)
app.get('/callback', (req, res) => {
  res.send(`
    <h2>✅ Alexa Account Linked</h2>
    <p>You may now return to your Alexa app.</p>
  `);
});

// === Step 6: Profile API (optional)
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

// === Start Server
app.listen(port, () => {
  console.log(`🚀 Alexa OAuth server running at http://localhost:${port}`);
});
