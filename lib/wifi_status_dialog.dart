import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'mqtt_service.dart';
import 'update_wifi_dialog.dart'; // already exists

class WifiStatusDialog extends StatefulWidget {
  final String registrationId;

  const WifiStatusDialog({super.key, required this.registrationId});

  @override
  State<WifiStatusDialog> createState() => _WifiStatusDialogState();
}

class _WifiStatusDialogState extends State<WifiStatusDialog> {
  String wifiName = "Unknown";
  int wifiStrength = 0; // %

  @override
  void initState() {
    super.initState();
    _subscribeToMqtt();
  }

  void _subscribeToMqtt() {
    if (MqttService.isConnected) {
      MqttService.subscribe("${widget.registrationId}/mobile");
      MqttService.setMessageHandler(_onMqttMessageReceived);
    }
  }

  void _onMqttMessageReceived(String topic, String message) {
    if (topic == "${widget.registrationId}/mobile") {
      try {
        final data = jsonDecode(message);
        if (data.containsKey("wifiName") && data.containsKey("wifiStrength")) {
          setState(() {
            wifiName = data["wifiName"];
            wifiStrength = data["wifiStrength"];
          });
        }
      } catch (e) {
        print("❌ Failed to decode Wi-Fi Status: $e");
      }
    }
  }

  void _sendConfigRequest() {
    if (MqttService.isConnected) {
      final payload = jsonEncode({
        "registrationId": widget.registrationId,
        "command": "configWifi", // 🔥 ask ESP to enter config mode
      });

      MqttService.publish("${widget.registrationId}/device", payload);
      print("📤 Sent config request to ${widget.registrationId}/device");

      // Open update wifi page
      Get.back(); // Close current dialog
      showDialog(context: context, builder: (context) => UpdateWifiDialog());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Wi-Fi Status"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Wi-Fi Name: $wifiName"),
          const SizedBox(height: 10),
          Text("Wi-Fi Strength: $wifiStrength%"),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _sendConfigRequest,
            child: const Text("Config Wi-Fi"),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text("Close")),
      ],
    );
  }
}
