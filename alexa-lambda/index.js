const admin = require('firebase-admin');
const awsIot = require('aws-iot-device-sdk');

// === Initialize Firebase ===
admin.initializeApp({
  credential: admin.credential.cert(require('./serviceAccountKey.json')),
});
const firestore = admin.firestore();

// === Initialize MQTT Client for AWS IoT Core ===
const mqttClient = awsIot.device({
  keyPath: './private.pem.key',
  certPath: './certificate.pem.crt',
  caPath: './rootCA.crt',
  clientId: 'alexa-skill',
  host: 'anqg66n1fr3hi-ats.iot.eu-north-1.amazonaws.com', // e.g. xyz-ats.iot.region.amazonaws.com
});

mqttClient.on('connect', () => {
  console.log('✅ Connected to AWS IoT Core');
});

// === Helper: Publish to MQTT ===
function sendToDevice(deviceId, payload) {
  const topic = `${deviceId}/device`;
  mqttClient.publish(topic, JSON.stringify(payload));
  console.log(`📤 Published to ${topic}:`, payload);
}

// === Lambda Handler ===
exports.handler = async (event) => {
  const directive = event.directive;
  const { namespace, name } = directive.header;

  if (namespace === 'Alexa.Discovery' && name === 'Discover') {
    const token = directive.payload.scope.token;
    const uid = extractUidFromToken(token);

    const snapshot = await firestore.collection('users').doc(uid).collection('devices').get();

    const endpoints = snapshot.docs.map(doc => {
      const d = doc.data();
      return {
        endpointId: d.deviceId,
        manufacturerName: 'ESP32Home',
        friendlyName: d.name,
        description: `Smart ${d.type}`,
        displayCategories: getAlexaCategory(d.type),
        cookie: {
          registrationId: d.registrationId,
        },
        capabilities: [
          {
            type: 'AlexaInterface',
            interface: 'Alexa.PowerController',
            version: '3',
            properties: {
              supported: [{ name: 'powerState' }],
              retrievable: false,
            },
          },
        ],
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
        payload: {
          endpoints,
        },
      },
    };
  }

  // === Handle TurnOn/TurnOff ===
  if (namespace === 'Alexa.PowerController') {
    const endpointId = directive.endpoint.endpointId;
    const correlationToken = directive.header.correlationToken;
    const powerState = name === 'TurnOn' ? 'ON' : 'OFF';
    const state = name === 'TurnOn';

    const snapshot = await firestore.collectionGroup('devices')
      .where('deviceId', '==', endpointId)
      .get();

    if (snapshot.empty) throw new Error('Device not found');

    const device = snapshot.docs[0].data();

    const payload = {
      deviceId: device.deviceId,
      registrationId: device.registrationId,
      state: state,
    };

    sendToDevice(device.deviceId, payload);

    await firestore.doc(snapshot.docs[0].ref.path).update({ state });

    return {
      context: {
        properties: [{
          namespace: 'Alexa.PowerController',
          name: 'powerState',
          value: powerState,
          timeOfSample: new Date().toISOString(),
          uncertaintyInMilliseconds: 500,
        }],
      },
      event: {
        header: {
          namespace: 'Alexa',
          name: 'Response',
          payloadVersion: '3',
          messageId: directive.header.messageId,
          correlationToken: correlationToken,
        },
        endpoint: {
          endpointId: endpointId,
        },
        payload: {},
      },
    };
  }

  throw new Error('Unsupported directive');
};

// === Helper Functions ===

function extractUidFromToken(token) {
  // For development, assume token is uid
  return token;
}

function getAlexaCategory(type) {
  switch (type) {
    case 'Fan': return ['FAN'];
    case 'Dimmable light': return ['LIGHT'];
    case 'RGB': return ['LIGHT'];
    default: return ['SWITCH'];
  }
}
