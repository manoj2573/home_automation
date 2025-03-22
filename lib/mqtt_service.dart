import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'dart:io';

class MqttService {
  static late MqttServerClient client;
  static bool isConnected = false;
  static Function(String, String)? messageHandler; // Callback for messages

  // ✅ Connect to MQTT
  static Future<void> connect() async {
    client = MqttServerClient.withPort(
      'anqg66n1fr3hi-ats.iot.eu-north-1.amazonaws.com', // Your AWS IoT endpoint
      'home_automation_app',
      8883,
    );

    client.keepAlivePeriod = 30;
    client.logging(on: true);

    final connMessage =
        MqttConnectMessage()
            .withClientIdentifier('home_automation_app')
            .startClean();
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

  // ✅ Subscribe to a topic
  static void subscribe(String topic) {
    if (!isConnected) {
      print("⚠️ MQTT not connected. Cannot subscribe to $topic.");
      return;
    }
    client.subscribe(topic, MqttQos.atMostOnce);
    print("✅ Subscribed to: $topic");
  }

  // ✅ Publish a message to a topic
  static void publish(String topic, String message) {
    if (!isConnected) {
      print("⚠️ MQTT not connected. Cannot publish to $topic.");
      return;
    }

    final builder = MqttClientPayloadBuilder();
    builder.addString(message);

    client.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
    print("📤 Published to $topic: $message");
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
  }

  static Future<SecurityContext> getSecurityContext() async {
    SecurityContext context = SecurityContext.defaultContext;

    final rootCA = await rootBundle.load('assets/root-CA.crt');
    context.setTrustedCertificatesBytes(rootCA.buffer.asUint8List());

    final clientCert = await rootBundle.load('assets/pem.crt');
    final privateKey = await rootBundle.load('assets/private.pem.key');

    context.useCertificateChainBytes(clientCert.buffer.asUint8List());
    context.usePrivateKeyBytes(privateKey.buffer.asUint8List());

    return context;
  }
}
