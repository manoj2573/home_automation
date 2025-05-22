const express = require('express');
const bodyParser = require('body-parser');
const admin = require('firebase-admin');
const jwt = require('jsonwebtoken');
const path = require('path');
const axios = require('axios');
const cors = require('cors');

const app = express();
const port = process.env.PORT || 3000;

// === Firebase Admin Init ===
const serviceAccount = require('./serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});
const firestore = admin.firestore();
console.log("✅ Firebase Admin initialized");

const CLIENT_ID = 'amzn1.application-oa2-client.alexa-client';
const CLIENT_SECRET = 'alexa-secret';
const FIREBASE_API_KEY = 'AIzaSyDW5glX6e8GMXtlAlyZnoDB6KfWDqw08X0'; // 🔁 Replace this

app.use(cors());
app.use(bodyParser.urlencoded({ extended: true }));
app.use(bodyParser.json());
app.use(express.static('public'));
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

// === Step 1: Alexa initiates account link
app.get('/authorize', (req, res) => {
  const { client_id, redirect_uri, state } = req.query;
  res.render('login', { client_id, redirect_uri, state, error: null });
});

// === Step 2: Handle login form submission
app.post('/login', async (req, res) => {
  const { email, password, client_id, redirect_uri, state } = req.body;

  if (!email || !password || !redirect_uri || !state) {
    return res.render('login', {
      client_id,
      redirect_uri,
      state,
      error: 'All fields are required.',
    });
  }

  try {
    const result = await axios.post(
      `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${FIREBASE_API_KEY}`,
      { email, password, returnSecureToken: true }
    );

    const uid = result.data.localId;
    const code = jwt.sign({ uid }, CLIENT_SECRET, { expiresIn: '10m' });

    console.log(`✅ Login success. UID: ${uid}, Email: ${email}`);
    const redirectUrl = `${redirect_uri}?code=${code}&state=${state}`;
    res.redirect(redirectUrl);
  } catch (err) {
    console.error("❌ Firebase login failed:", err.response?.data || err.message);
    res.render('login', {
      client_id,
      redirect_uri,
      state,
      error: 'Invalid email or password.',
    });
  }
});

// === Step 3: Token exchange
app.post('/token', async (req, res) => {
  const { code, client_id, client_secret, grant_type } = req.body;

  if (client_id !== CLIENT_ID || client_secret !== CLIENT_SECRET) {
    return res.status(401).json({ error: 'invalid_client' });
  }

  try {
    const decoded = jwt.verify(code, CLIENT_SECRET);
    const uid = decoded.uid;

    const access_token = jwt.sign({ uid }, CLIENT_SECRET, { expiresIn: '1h' });
    const refresh_token = jwt.sign({ uid }, CLIENT_SECRET, { expiresIn: '30d' });

    await firestore.collection('users').doc(uid).set({
      access_token,
      refresh_token,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    console.log("🎫 Token exchange successful for UID:", uid);
    return res.json({
      token_type: 'Bearer',
      access_token,
      refresh_token,
      expires_in: 3600,
    });
  } catch (err) {
    console.error("❌ Token verification failed:", err.message);
    return res.status(400).json({ error: 'invalid_grant' });
  }
});

// === Step 4: Profile endpoint (optional for Alexa)
app.get('/profile', (req, res) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  try {
    const decoded = jwt.verify(token, CLIENT_SECRET);
    res.json({ user_id: decoded.uid });
  } catch (err) {
    res.status(401).json({ error: 'invalid_token' });
  }
});

app.listen(port, () => {
  console.log(`🚀 Alexa OAuth server running at http://localhost:${port}`);
});
