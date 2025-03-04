import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'dart:io';
import 'package:get/get.dart';
import 'device_controller.dart';

class MqttService {
  static late MqttServerClient client;
  static const String topic = 'home/devices';
  static bool isConnected = false;

  // ✅ Connect to MQTT
  static Future<void> connect() async {
    client = MqttServerClient.withPort(
      'anqg66n1fr3hi-ats.iot.eu-north-1.amazonaws.com', // Replace with your AWS IoT endpoint
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

    client.onSubscribed = (String topic) {
      print('✅ Subscribed to topic: $topic');
    };

    client.subscribe(topic, MqttQos.atMostOnce);
  }

  // ✅ Publish only if MQTT is connected
  static void publishMessage(Map<String, dynamic> message) {
    if (!isConnected) {
      print('❌ MQTT not connected. Skipping publish.');
      return;
    }

    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode(message));

    client.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
    print('✅ Message published: $message');
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
