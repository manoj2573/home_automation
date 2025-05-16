const express = require('express');
const bodyParser = require('body-parser');
const admin = require('firebase-admin');
const jwt = require('jsonwebtoken');
const cors = require('cors');
const path = require('path');

// === Firebase Admin Init ===
const serviceAccount = require('./serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: serviceAccount.project_id,
});
const firestore = admin.firestore();

// === App Init ===
const app = express();
const port = process.env.PORT || 3000;
app.use(bodyParser.urlencoded({ extended: true }));
app.use(bodyParser.json());
app.use(cors());
app.use(express.static('public'));

// === Secrets ===
const CLIENT_ID = 'amzn1.application-oa2-client.alexa-client';
const CLIENT_SECRET = 'alexa-secret';
const REDIRECT_URI = 'https://alexa-oauth.onrender.com/callback';

// === Memory Store (for testing/demo) ===
const userTokens = {};  // { refreshToken: { access_token, uid } }

// === Login Page ===
app.get('/login', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'login.html'));
});

// === Handle Login Form ===
app.post('/login', async (req, res) => {
  const { email, password, redirect_uri, state } = req.body;

  try {
    const userRecord = await admin.auth().getUserByEmail(email);
    const customToken = await admin.auth().createCustomToken(userRecord.uid);
    const uid = userRecord.uid;

    const code = jwt.sign({ uid }, CLIENT_SECRET, { expiresIn: '10m' });
    userTokens[code] = { uid };

    const redirectUrl = `${redirect_uri}?code=${code}&state=${state}`;
    res.redirect(redirectUrl);
  } catch (err) {
    console.error("❌ Login failed:", err);
    res.status(401).send('Invalid login credentials');
  }
});

// === Exchange Code for Access Token ===
app.post('/token', async (req, res) => {
  const { client_id, client_secret, code, grant_type, refresh_token } = req.body;

  if (client_id !== CLIENT_ID || client_secret !== CLIENT_SECRET) {
    return res.status(401).json({ error: 'invalid_client' });
  }

  if (grant_type === 'authorization_code') {
    const data = userTokens[code];
    if (!data) return res.status(400).json({ error: 'invalid_grant' });

    const access_token = jwt.sign({ uid: data.uid }, CLIENT_SECRET, { expiresIn: '1h' });
    const refresh_token = jwt.sign({ uid: data.uid }, CLIENT_SECRET, { expiresIn: '30d' });

    userTokens[refresh_token] = { access_token, uid: data.uid };

    try {
      await firestore.collection('users').doc(data.uid).set({ access_token }, { merge: true });
      console.log(`✅ Access token stored in Firestore for UID: ${data.uid}`);
    } catch (err) {
      console.error("❌ Failed to write token to Firestore:", err);
    }

    return res.json({
      token_type: 'Bearer',
      access_token,
      refresh_token,
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

// === Get User Profile ===
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
