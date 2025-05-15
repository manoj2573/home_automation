// === index.js (Main Express App) ===
const express = require('express');
const bodyParser = require('body-parser');
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const app = express();

admin.initializeApp({
  credential: admin.credential.cert(require('./serviceAccountKey.json'))
});

app.use(bodyParser.urlencoded({ extended: true }));
app.use(bodyParser.json());
app.use(express.static('public'));

const authCodes = new Map();
const accessTokens = new Map();

app.get('/login', (req, res) => {
  const { redirect_uri, state, client_id } = req.query;
  const htmlPath = path.join(__dirname, 'public', 'login.html');
  let html = fs.readFileSync(htmlPath, 'utf8');
  html = html.replace('{{redirect_uri}}', redirect_uri)
             .replace('{{state}}', state)
             .replace('{{client_id}}', client_id);
  res.send(html);
});

app.post('/login', async (req, res) => {
  const { email, password, redirect_uri, state } = req.body;
  try {
    const user = await admin.auth().getUserByEmail(email);
    const customToken = await admin.auth().createCustomToken(user.uid);
    const code = crypto.randomBytes(20).toString('hex');
    authCodes.set(code, { uid: user.uid });
    res.redirect(`${redirect_uri}?code=${code}&state=${state}`);
  } catch (err) {
    res.status(401).send('Authentication failed.');
  }
});

app.post('/token', (req, res) => {
  const { grant_type, code, client_id, client_secret, refresh_token } = req.body;

  if (grant_type === 'authorization_code') {
    const data = authCodes.get(code);
    if (!data) return res.status(400).send('Invalid code');

    const access_token = jwt.sign({ uid: data.uid }, 'access_secret', { expiresIn: '1h' });
    const refresh_token = jwt.sign({ uid: data.uid }, 'refresh_secret', { expiresIn: '7d' });

    accessTokens.set(access_token, data.uid);
    return res.json({
      token_type: 'Bearer',
      access_token,
      refresh_token,
      expires_in: 3600
    });
  }

  if (grant_type === 'refresh_token') {
    try {
      const decoded = jwt.verify(refresh_token, 'refresh_secret');
      const newAccessToken = jwt.sign({ uid: decoded.uid }, 'access_secret', { expiresIn: '1h' });
      return res.json({
        token_type: 'Bearer',
        access_token: newAccessToken,
        expires_in: 3600
      });
    } catch (err) {
      return res.status(400).send('Invalid refresh token');
    }
  }

  res.status(400).send('Unsupported grant_type');
});

app.get('/validate', (req, res) => {
  const authHeader = req.headers.authorization;
  if (!authHeader) return res.sendStatus(401);
  const token = authHeader.split(' ')[1];
  try {
    const decoded = jwt.verify(token, 'access_secret');
    res.json({ uid: decoded.uid });
  } catch {
    res.sendStatus(403);
  }
});

app.listen(3000, () => console.log('OAuth Server running on port 3000'));
