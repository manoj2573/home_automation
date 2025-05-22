import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import 'dart:convert';

import 'features/device/device.dart';
import 'core/services/device_controller.dart';

class WiFiProvisionDialog extends StatefulWidget {
  const WiFiProvisionDialog({super.key});

  @override
  State<WiFiProvisionDialog> createState() => _WiFiProvisionDialogState();
}

class _WiFiProvisionDialogState extends State<WiFiProvisionDialog> {
  final ssidController = TextEditingController();
  final passwordController = TextEditingController();
  final roomController = TextEditingController();
  bool isConnectedToESP = false;
  bool isSending = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await [
      Permission.location,
      Permission.locationWhenInUse,
      Permission.locationAlways,
    ].request();

    final connected = await WiFiForIoTPlugin.connect(
      "ESP32_Config",
      security: NetworkSecurity.WPA,
      password: "12345678",
      joinOnce: true,
      withInternet: false,
    );

    if (connected) {
      await WiFiForIoTPlugin.forceWifiUsage(true);
      setState(() => isConnectedToESP = true);
    }
  }

  Future<void> _provisionDevice() async {
    setState(() => isSending = true);

    try {
      final deviceResp = await http.get(
        Uri.parse("http://192.168.4.1/device-info"),
      );

      if (deviceResp.statusCode != 200) {
        Get.snackbar("Error", "Failed to get device info");
        return;
      }

      final deviceData = jsonDecode(deviceResp.body);

      // Send Wi-Fi credentials
      final wifiResp = await http.post(
        Uri.parse("http://192.168.4.1/connect"),
        body: {
          'ssid': ssidController.text,
          'password': passwordController.text,
        },
      );

      if (wifiResp.statusCode == 200 &&
          wifiResp.body.toLowerCase().contains("received")) {
        _createDevices(deviceData);
        if (wifiResp.statusCode == 200 &&
            wifiResp.body.toLowerCase().contains("received")) {
          _createDevices(deviceData);
          await WiFiForIoTPlugin.disconnect(); // ✅ Disconnect from ESP32 hotspot
          Get.back(); // Close the dialog
          Get.snackbar("Success", "Devices added successfully");
        }

        Get.back(); // Close the dialog
        Get.snackbar("Success", "Devices added successfully");
      } else {
        Get.snackbar("Error", "ESP32 rejected Wi-Fi credentials");
      }
    } catch (e) {
      Get.snackbar("Error", "Failed: $e");
    } finally {
      setState(() => isSending = false);
    }
  }

  void _createDevices(Map<String, dynamic> json) {
    final deviceController = Get.find<DeviceController>();
    final roomName = roomController.text.trim();

    if (!json.containsKey("devices")) return;

    for (var d in json["devices"]) {
      final device = Device(
        name: d["type"],
        type: d["type"],
        state: RxBool(false),
        iconPath: "assets/light-bulb.png",
        deviceId: d["deviceId"],
        registrationId: json["registrationId"] ?? "NA",
        roomName: roomName,
      );
      deviceController.addDevice(device);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Wi-Fi Provisioning"),
      content:
          isConnectedToESP
              ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: ssidController,
                    decoration: const InputDecoration(labelText: "Wi-Fi SSID"),
                  ),
                  TextField(
                    controller: passwordController,
                    decoration: const InputDecoration(
                      labelText: "Wi-Fi Password",
                    ),
                    obscureText: false,
                  ),
                  TextField(
                    controller: roomController,
                    decoration: const InputDecoration(labelText: "Room Name"),
                  ),
                  const SizedBox(height: 20),
                  isSending
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                        onPressed: _provisionDevice,
                        child: const Text("Provision & Add"),
                      ),
                ],
              )
              : const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text("Cancel")),
      ],
    );
  }
}
