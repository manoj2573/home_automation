const admin = require('firebase-admin');
const awsIot = require('aws-iot-device-sdk');
const colorConvert = require('color-convert');
const https = require('https');
const jwt = require('jsonwebtoken');

// === Firebase Init ===
if (!admin.apps.length) {
  const serviceAccount = require('./serviceAccountKey.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: serviceAccount.project_id,
  });
}
const firestore = admin.firestore();
console.log("🧾 Firebase initialized with project:", admin.app().options.projectId);

const CLIENT_SECRET = 'alexa-secret';

// === MQTT Init ===
const mqttClient = awsIot.device({
  keyPath: './private.pem.key',
  certPath: './certificate.pem.crt',
  caPath: './rootCA.crt',
  clientId: 'alexa-skill',
  host: 'anqg66n1fr3hi-ats.iot.eu-west-1.amazonaws.com',
});

mqttClient.on('connect', () => {
  console.log('✅ Connected to AWS IoT Core');
  const topic = '+/mobile';
  mqttClient.subscribe(topic, (err, granted) => {
    if (err) {
      console.error(`❌ Failed to subscribe to topic: ${topic}`, err);
    } else {
      console.log(`📡 Subscribed to topic: ${granted[0].topic} with QoS ${granted[0].qos}`);
    }
  });
});

function sendToDevice(deviceId, payload) {
  mqttClient.publish(`${deviceId}/device`, JSON.stringify(payload));
  console.log(`📤 Published to ${deviceId}/device:`, payload);
}

function postToAlexaGateway(event, token) {
  const options = {
    hostname: 'api.eu.amazonalexa.com',
    path: '/v3/events',
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    }
  };

  const req = https.request(options, (res) => {
    console.log(`📡 Alexa Event Gateway response: ${res.statusCode}`);
    res.on('data', d => process.stdout.write(d));
  });

  req.on('error', (e) => {
    console.error(`❌ Error posting to Alexa Event Gateway: ${e}`);
  });

  req.write(JSON.stringify(event));
  req.end();
}

mqttClient.on('message', async (topic, message) => {
  const payload = JSON.parse(message.toString());
  const endpointId = topic.split('/')[0];
  const reports = [];

  if ('state' in payload) {
    reports.push({
      namespace: 'Alexa.PowerController',
      name: 'powerState',
      value: payload.state ? 'ON' : 'OFF'
    });
  }
  if ('sliderValue' in payload && payload.deviceType !== 'RGB') {
    reports.push({
      namespace: 'Alexa.BrightnessController',
      name: 'brightness',
      value: Math.round((payload.sliderValue / 90) * 100)
    });
  }
  if ('color' in payload && payload.deviceType === 'RGB') {
    const hsv = colorConvert.hex.hsv(payload.color.replace('#', ''));
    reports.push({
      namespace: 'Alexa.ColorController',
      name: 'color',
      value: {
        hue: hsv[0],
        saturation: hsv[1] / 100,
        brightness: hsv[2] / 100
      }
    });
  }

  for (const report of reports) {
    const changeEvent = {
      context: {
        properties: [{
          namespace: report.namespace,
          name: report.name,
          value: report.value,
          timeOfSample: new Date().toISOString(),
          uncertaintyInMilliseconds: 500,
        }]
      },
      event: {
        header: {
          namespace: 'Alexa',
          name: 'ChangeReport',
          payloadVersion: '3',
          messageId: Math.random().toString(),
        },
        endpoint: { endpointId },
        payload: {
          change: {
            cause: { type: 'PHYSICAL_INTERACTION' },
            properties: [{
              namespace: report.namespace,
              name: report.name,
              value: report.value,
              timeOfSample: new Date().toISOString(),
              uncertaintyInMilliseconds: 500,
            }]
          }
        }
      }
    };

    console.log("📤 Alexa ChangeReport:", JSON.stringify(changeEvent, null, 2));

    const userSnap = await firestore.collectionGroup('devices')
      .where('deviceId', '==', endpointId)
      .limit(1)
      .get();

    if (userSnap.empty) {
      console.warn(`⚠️ No matching user/device found for endpointId: ${endpointId}`);
      return;
    }

    const userDoc = userSnap.docs[0];
    const userId = userDoc.ref.path.split('/')[1];
    const userData = await firestore.collection('users').doc(userId).get();
    const token = userData.data()?.access_token;

    if (!token) {
      console.warn(`⚠️ No access token for user: ${userId}`);
      return;
    }

    postToAlexaGateway(changeEvent, token);
  }
});

exports.handler = async (event) => {
  console.log("📡 Alexa event:", JSON.stringify(event, null, 2));
  const directive = event.directive;
  const { namespace, name } = directive.header;
  const endpointId = directive.endpoint?.endpointId;
  const correlationToken = directive.header.correlationToken;

  let token, uid;
  try {
    if (directive.payload?.scope?.token) {
      token = directive.payload.scope.token;
    } else if (directive.endpoint?.scope?.token) {
      token = directive.endpoint.scope.token;
    } else {
      throw new Error("Token not found");
    }
  
    if (token.split('.').length === 3) {
      // JWT
      const decoded = jwt.verify(token, CLIENT_SECRET);
      uid = decoded.uid;
      console.log("✅ UID from JWT:", uid);
    } else {
      // Base64 fallback (email:timestamp)
      const base64 = Buffer.from(token, 'base64').toString();
      const email = base64.split(':')[0];
      console.log("📧 Extracted email:", email);
  
      const userQuery = await firestore.collection("users").where("email", "==", email).limit(1).get();
      if (userQuery.empty) {
        throw new Error("No user found for email");
      }
      uid = userQuery.docs[0].id;
      console.log("✅ UID fetched from Firestore by email:", uid);
    }
  
  } catch (err) {
    console.error("❌ Failed to extract UID:", err.message);
    throw new Error("Unauthorized: Invalid token");
  }  
  
  if (namespace === 'Alexa.Discovery' && name === 'Discover') {
    console.log("🔍 Running device discovery for UID:", uid);
    const snapshot = await firestore.collection('users').doc(uid).collection('devices').get();
    if (snapshot.empty) {
      console.warn("⚠️ No devices found in Firestore for UID:", uid);
    }
    const endpoints = snapshot.docs.map(doc => {
      const d = doc.data();
      console.log(`📦 Found device: ${d.deviceId} (${d.type})`);
      const capabilities = [
        {
          type: 'AlexaInterface',
          interface: 'Alexa.PowerController',
          version: '3',
          properties: { supported: [{ name: 'powerState' }], retrievable: true,proactivelyReported: true },
        },
        {
          type: 'AlexaInterface',
          interface: 'Alexa.EndpointHealth',
          version: '3',
          properties: { supported: [{ name: 'connectivity' }], retrievable: true },
        },
        { type: 'AlexaInterface', interface: 'Alexa', version: '3' },
      ];
      if (d.type === 'Fan' || d.type === 'Dimmable light') {
        capabilities.push({
          type: 'AlexaInterface',
          interface: 'Alexa.BrightnessController',
          version: '3',
          properties: { supported: [{ name: 'brightness' }], retrievable: true,
          proactivelyReported: true },
        });
      }
      if (d.type === 'RGB') {
        capabilities.push({
          type: 'AlexaInterface',
          interface: 'Alexa.ColorController',
          version: '3',
          properties: { supported: [{ name: 'color' }], retrievable: true,
          proactivelyReported: true },
        });
      }
      return {
        endpointId: d.deviceId,
        manufacturerName: 'YANTRA',
        friendlyName: d.name,
        description: `Smart ${d.type}`,
        displayCategories: getAlexaCategory(d.type),
        cookie: { registrationId: d.registrationId },
        capabilities
      };
    });
    return {
      event: {
        header: {
          namespace: 'Alexa.Discovery',
          name: 'Discover.Response',
          messageId: directive.header.messageId,
          payloadVersion: '3',
        },
        payload: { endpoints },
      },
    };
  }

  if (namespace === 'Alexa' && name === 'ReportState') {
    const doc = await firestore.doc(`users/${uid}/devices/${endpointId}`).get();
    if (!doc.exists) throw new Error("Device not found");
    const d = doc.data();
  
    const properties = [];
  
    if (d.state !== undefined) {
      properties.push({
        namespace: 'Alexa.PowerController',
        name: 'powerState',
        value: d.state ? 'ON' : 'OFF',
        timeOfSample: new Date().toISOString(),
        uncertaintyInMilliseconds: 500
      });
    }
  
    if (d.sliderValue !== undefined && d.type !== 'RGB') {
      properties.push({
        namespace: 'Alexa.BrightnessController',
        name: 'brightness',
        value: Math.round((d.sliderValue / 90) * 100),
        timeOfSample: new Date().toISOString(),
        uncertaintyInMilliseconds: 500
      });
    }
  
    if (d.color && d.type === 'RGB') {
      const hsv = colorConvert.hex.hsv(d.color.replace('#', ''));
      properties.push({
        namespace: 'Alexa.ColorController',
        name: 'color',
        value: {
          hue: hsv[0],
          saturation: hsv[1] / 100,
          brightness: hsv[2] / 100
        },
        timeOfSample: new Date().toISOString(),
        uncertaintyInMilliseconds: 500
      });
    }
  
    return {
      context: { properties },
      event: {
        header: {
          namespace: 'Alexa',
          name: 'StateReport',
          messageId: directive.header.messageId,
          correlationToken,
          payloadVersion: '3'
        },
        endpoint: { endpointId },
        payload: {}
      }
    };
  }
  

  if (namespace === 'Alexa.PowerController') {
    const doc = await firestore.doc(`users/${uid}/devices/${endpointId}`).get();
    if (!doc.exists) throw new Error("Device not found");
    const d = doc.data();
    const payload = {
      deviceId: d.deviceId,
      registrationId: d.registrationId,
      deviceType: d.type,
      state: name === 'TurnOn'
    };
    sendToDevice(d.deviceId, payload);
    await doc.ref.update({ state: payload.state });
    return buildAlexaResponse(endpointId, correlationToken, 'Alexa.PowerController', 'powerState', name === 'TurnOn' ? 'ON' : 'OFF');
    console.log("⚡ Sending power payload:", payload);
  }

  if (namespace === 'Alexa.BrightnessController') {
    let alexaValue = directive.payload.brightness;
    let deviceValue = Math.round((alexaValue / 100) * 90);
    const doc = await firestore.doc(`users/${uid}/devices/${endpointId}`).get();
    if (!doc.exists) throw new Error("Device not found");
    const d = doc.data();
    const payload = {
      deviceId: d.deviceId,
      registrationId: d.registrationId,
      deviceType: d.type,
      state: true,
      sliderValue: deviceValue
    };
    sendToDevice(d.deviceId, payload);
    await doc.ref.update({ sliderValue: deviceValue, state: true });
    return buildAlexaResponse(endpointId, correlationToken, 'Alexa.BrightnessController', 'brightness', alexaValue);
    console.log("⚡ Sending brightness payload:", payload);
  }

  if (namespace === 'Alexa.ColorController') {
    const h = directive.payload.color.hue;
    const s = directive.payload.color.saturation;
    const b = directive.payload.color.brightness;
    const hex = `#${colorConvert.hsv.hex([h, s * 100, b * 100])}`;
    const doc = await firestore.doc(`users/${uid}/devices/${endpointId}`).get();
    if (!doc.exists) throw new Error("Device not found");
    const d = doc.data();
    const payload = {
      deviceId: d.deviceId,
      registrationId: d.registrationId,
      deviceType: d.type,
      state: true,
      color: hex
    };
    sendToDevice(d.deviceId, payload);
    await doc.ref.update({ color: hex, state: true });
    return buildAlexaResponse(endpointId, correlationToken, 'Alexa.ColorController', 'color', directive.payload.color);
    console.log("⚡ Sending color payload:", payload);
  }

  throw new Error('Unsupported directive');
};

function buildAlexaResponse(endpointId, token, namespace, name, value) {
  return {
    context: {
      properties: [{
        namespace,
        name,
        value,
        timeOfSample: new Date().toISOString(),
        uncertaintyInMilliseconds: 500,
      }],
    },
    event: {
      header: {
        namespace: 'Alexa',
        name: 'Response',
        payloadVersion: '3',
        messageId: Math.random().toString(),
        correlationToken: token,
      },
      endpoint: { endpointId },
      payload: {},
    },
  };
}

function getAlexaCategory(type) {
  switch (type) {
    case 'Fan':
    case 'Dimmable light':
    case 'RGB': return ['LIGHT'];
    default: return ['SWITCH'];
  }
}
