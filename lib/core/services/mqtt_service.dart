import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

class MqttService {
  static late MqttServerClient client;
  static bool isConnected = false;
  static Function(String, String)? messageHandler; // Callback for messages
  static Future<String> getUniqueClientId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final id = androidInfo.id;
      return 'home_automation_$id';
    } catch (e) {
      print("⚠️ Failed to get unique ID: $e");
      return 'home_automation_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  // ✅ Connect to MQTT
  static Future<void> connect() async {
    final clientId = await getUniqueClientId();
    client = MqttServerClient.withPort(
      'anqg66n1fr3hi-ats.iot.eu-north-1.amazonaws.com', // Your AWS IoT endpoint
      clientId,
      8883,
    );

    client.keepAlivePeriod = 30;
    client.logging(on: true);
    client.autoReconnect = true; // (optional if your library supports it)

    final connMessage =
        MqttConnectMessage()
          ..withClientIdentifier(
            'home_automation_app_${DateTime.now().millisecondsSinceEpoch}',
          ).startClean();
    client.connectionMessage = connMessage;

    try {
      final context = await getSecurityContext();
      client.secure = true;
      client.securityContext = context;

      await client.connect();
      isConnected = true;
      print('✅ Connected to MQTT broker');

      client.updates!.listen((
        List<MqttReceivedMessage<MqttMessage>>? messages,
      ) {
        if (messages != null && messages.isNotEmpty) {
          final recMessage = messages.first.payload as MqttPublishMessage;
          final payload = utf8.decode(recMessage.payload.message);
          final topic = messages.first.topic;

          print("📩 MQTT Received Message: Topic: $topic, Message: $payload");

          if (messageHandler != null) {
            messageHandler!(topic, payload);
          } else {
            print("⚠️ No MQTT message handler set.");
          }
        }
      });
    } catch (e) {
      print('❌ Error connecting to MQTT broker: $e');
      isConnected = false;
    }

    client.onDisconnected = () {
      print('❌ Disconnected from MQTT broker');
      isConnected = false;

      // ✅ Retry MQTT connection
      Future.delayed(Duration(seconds: 5), () {
        print("🔄 Retrying MQTT connection...");
        connect();
      });
    };
  }

  static void publish(String deviceTopic, String message) {
    if (!isConnected) {
      print("⚠️ MQTT not connected. Cannot publish to $deviceTopic");
      return;
    }
    String topic = deviceTopic;
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);
    client.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
    print("📤 Published to $topic: $message");
  }

  static void subscribe(String deviceTopic) {
    if (!isConnected) {
      print("⚠️ MQTT not connected. Cannot subscribe to $deviceTopic");
      return;
    }
    String topic = deviceTopic;
    client.subscribe(topic, MqttQos.atMostOnce);
    print("✅ Subscribed to: $topic");
  }

  // ✅ Unsubscribe from a topic
  static void unsubscribe(String topic) {
    if (!isConnected) {
      print("⚠️ MQTT not connected. Cannot unsubscribe from $topic.");
      return;
    }
    client.unsubscribe(topic);
    print("🚫 Unsubscribed from: $topic");
  }

  // ✅ Set message handler for incoming MQTT messages
  static void setMessageHandler(Function(String, String) handler) {
    messageHandler = handler;
    print("✅ MQTT Message Handler Set");
  }

  static Future<SecurityContext> getSecurityContext() async {
    SecurityContext context = SecurityContext.defaultContext;

    final rootCA = await rootBundle.load('assets/secrets/root-CA.crt');
    context.setTrustedCertificatesBytes(rootCA.buffer.asUint8List());

    final clientCert = await rootBundle.load('assets/secrets/pem.crt');
    final privateKey = await rootBundle.load('assets/secrets/private.pem.key');

    context.useCertificateChainBytes(clientCert.buffer.asUint8List());
    context.usePrivateKeyBytes(privateKey.buffer.asUint8List());

    return context;
  }
}
