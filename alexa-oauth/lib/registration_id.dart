import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:home_automation/core/services/mqtt_service.dart';
import 'package:home_automation/core/widgets/theme.dart';
import 'package:home_automation/features/wifi/wifi_status_dialog.dart';
import 'core/services/device_controller.dart';

class ConfigurationPage extends StatelessWidget {
  const ConfigurationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final DeviceController deviceController = Get.find();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Center(child: const Text('DEVICE LIST')),
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppGradients.loginBackground),
        child: Obx(() {
          if (deviceController.devices.isEmpty) {
            return const Center(child: Text('No devices found'));
          }

          // Extract unique registrationIds
          final registrationIds =
              deviceController.devices
                  .map((device) => device.registrationId)
                  .toSet() // Remove duplicates
                  .toList();

          return SafeArea(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: registrationIds.length,
              itemBuilder: (context, index) {
                final registrationId = registrationIds[index];
                return InkWell(
                  onTap: () {
                    final DeviceController deviceController = Get.find();

                    String topic = "$registrationId/device";
                    String payload = jsonEncode({
                      "registrationId": registrationId,
                      "command": "wifiStatus", // 🔥 Ask for Wi-Fi status
                    });

                    if (MqttService.isConnected) {
                      MqttService.publish(topic, payload);
                      print(
                        "📤 Published Wi-Fi status request to $topic: $payload",
                      );
                    }

                    // Open Wi-Fi Status Dialog
                    showDialog(
                      context: context,
                      builder:
                          (context) =>
                              WifiStatusDialog(registrationId: registrationId),
                    );
                  },

                  child: Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    color: AppColors.tileBackground,
                    child: ListTile(
                      title: Text(registrationId, style: AppTextStyles.label),
                    ),
                  ),
                );
              },
            ),
          );
        }),
      ),
    );
  }
}
