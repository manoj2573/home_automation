const express = require('express');
const bodyParser = require('body-parser');
const admin = require('firebase-admin');
const cors = require('cors');
const path = require('path');
const axios = require('axios');
const jwt = require('jsonwebtoken');

const CLIENT_SECRET = 'alexa-secret';
const FIREBASE_API_KEY = 'AIzaSyDW5glX6e8GMXtlAlyZnoDB6KfWDqw08X0';

const serviceAccount = require('./serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: serviceAccount.project_id,
});
const firestore = admin.firestore();

const app = express();
app.use(cors());
app.use(bodyParser.urlencoded({ extended: true }));
app.use(bodyParser.json());
app.use(express.static('public'));
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

app.get('/authorize', (req, res) => {
  const { redirect_uri, state, client_id } = req.query;
  res.render('login', { redirect_uri, state, client_id });
});

app.post('/login', async (req, res) => {
  const { email, password, redirect_uri, state, client_id } = req.body;
  try {
    const result = await axios.post(
      `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${FIREBASE_API_KEY}`,
      { email, password, returnSecureToken: true }
    );

    const uid = result.data.localId;
    console.log(`✅ Login success: ${email} → UID: ${uid}`);

    const code = jwt.sign({ uid }, CLIENT_SECRET, { expiresIn: '10m' });
    return res.redirect(`${redirect_uri}?code=${code}&state=${state}`);
  } catch (err) {
    console.error("❌ Login failed:", err.response?.data?.error || err.message);
    return res.status(401).send("<h3>Invalid email or password</h3><a href='/authorize'>Back</a>");
  }
});

app.post('/token', async (req, res) => {
  const { code, grant_type } = req.body;
  if (grant_type !== 'authorization_code') {
    return res.status(400).json({ error: 'unsupported_grant_type' });
  }

  try {
    const decoded = jwt.verify(code, CLIENT_SECRET);
    const uid = decoded.uid;
    const access_token = jwt.sign({ uid }, CLIENT_SECRET, { expiresIn: '1h' });
    const refresh_token = jwt.sign({ uid }, CLIENT_SECRET, { expiresIn: '30d' });

    await firestore.collection('users').doc(uid).set(
      { access_token, refresh_token },
      { merge: true }
    );

    console.log("🔑 Token issued for UID:", uid);

    return res.json({
      token_type: 'Bearer',
      access_token,
      refresh_token,
      expires_in: 3600
    });
  } catch (err) {
    console.error("❌ Invalid auth code:", err.message);
    return res.status(400).json({ error: 'invalid_grant' });
  }
});

app.listen(3000, () => {
  console.log("🚀 Alexa OAuth server running at http://localhost:3000");
});
