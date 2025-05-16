// ✅ alexa-oauth/index.js
const express = require('express');
const bodyParser = require('body-parser');
const admin = require('firebase-admin');
const jwt = require('jsonwebtoken');
const cors = require('cors');
const path = require('path');

const serviceAccount = require('./serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: serviceAccount.project_id,
});
const firestore = admin.firestore();

const app = express();
const port = process.env.PORT || 3000;
app.use(bodyParser.urlencoded({ extended: true }));
app.use(bodyParser.json());
app.use(cors());
app.use(express.static('public'));

const CLIENT_ID = 'amzn1.application-oa2-client.alexa-client';
const CLIENT_SECRET = 'alexa-secret';
const REDIRECT_URI = 'https://alexa-oauth.onrender.com/callback';

const userTokens = {}; // temporary memory store

app.get('/login', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'login.html'));
});

app.post('/login', async (req, res) => {
  const { email, password, redirect_uri, state } = req.body;

  try {
    const userRecord = await admin.auth().getUserByEmail(email);
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

app.post('/token', async (req, res) => {
  const { client_id, client_secret, code, grant_type, refresh_token } = req.body;

  if (client_id !== CLIENT_ID || client_secret !== CLIENT_SECRET) {
    return res.status(401).json({ error: 'invalid_client' });
  }

  if (grant_type === 'authorization_code') {
    const data = userTokens[code];
    if (!data) return res.status(400).json({ error: 'invalid_grant' });

    const uid = data.uid;
    const access_token = jwt.sign({ uid }, CLIENT_SECRET, { expiresIn: '1h' });
    const newRefreshToken = jwt.sign({ uid }, CLIENT_SECRET, { expiresIn: '30d' });

    userTokens[newRefreshToken] = { access_token, uid };

    // ✅ Store token to Firestore
    await firestore.collection('users').doc(uid).set({ access_token }, { merge: true });
    console.log(`✅ Stored access_token for UID: ${uid}`);

    return res.json({
      token_type: 'Bearer',
      access_token,
      refresh_token: newRefreshToken,
      expires_in: 3600
    });
  }

  if (grant_type === 'refresh_token') {
    const data = userTokens[refresh_token];
    if (!data) return res.status(400).json({ error: 'invalid_grant' });

    const newAccessToken = jwt.sign({ uid: data.uid }, CLIENT_SECRET, { expiresIn: '1h' });
    userTokens[refresh_token].access_token = newAccessToken;

    // ✅ Refresh path: also update stored access_token
    await firestore.collection('users').doc(data.uid).set({ access_token: newAccessToken }, { merge: true });
    console.log(`🔄 Refreshed and stored new access_token for UID: ${data.uid}`);

    return res.json({
      token_type: 'Bearer',
      access_token: newAccessToken,
      refresh_token,
      expires_in: 3600
    });
  }

  return res.status(400).json({ error: 'unsupported_grant_type' });
});

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

app.listen(port, () => {
  console.log(`🚀 Alexa OAuth server running at http://localhost:${port}`);
});
