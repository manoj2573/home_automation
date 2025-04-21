import 'package:flutter/material.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'device.dart';
import 'device_controller.dart';

class WiFiProvisionAndDeviceSetupDialog extends StatefulWidget {
  const WiFiProvisionAndDeviceSetupDialog({super.key});

  @override
  State<WiFiProvisionAndDeviceSetupDialog> createState() =>
      _WiFiProvisionAndDeviceSetupDialogState();
}

class _WiFiProvisionAndDeviceSetupDialogState
    extends State<WiFiProvisionAndDeviceSetupDialog> {
  final ssidController = TextEditingController();
  final passwordController = TextEditingController();
  final roomController = TextEditingController();

  bool isConnectedToESP = false;
  bool isSending = false;
  String? responseMessage;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await [
      Permission.location,
      Permission.locationWhenInUse,
      Permission.locationAlways,
    ].request();

    bool connected = await WiFiForIoTPlugin.connect(
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

  Future<void> _sendCredentialsAndFetchDevices() async {
    setState(() => isSending = true);

    try {
      final connectResp = await http.post(
        Uri.parse("http://192.168.4.1/connect"),
        body: {
          'ssid': ssidController.text,
          'password': passwordController.text,
        },
      );

      if (connectResp.statusCode == 200 &&
          connectResp.body.toLowerCase().contains("received")) {
        await Future.delayed(Duration(seconds: 5));

        final deviceResp = await http.get(
          Uri.parse("http://192.168.4.1/device-info"),
        );

        if (deviceResp.statusCode == 200) {
          final data = jsonDecode(deviceResp.body);
          _createDevicesFromJson(data);
          Get.back(); // Close dialog
          Get.snackbar(
            "Success",
            "Devices added successfully",
            snackPosition: SnackPosition.BOTTOM,
          );
        } else {
          Get.snackbar("Error", "Failed to fetch device info");
        }
      } else {
        Get.snackbar("Error", "ESP32 rejected credentials");
      }
    } catch (e) {
      Get.snackbar("Error", "Exception: $e");
    } finally {
      setState(() => isSending = false);
    }
  }

  void _createDevicesFromJson(Map<String, dynamic> json) {
    final deviceController = Get.find<DeviceController>();
    final String roomName = roomController.text.trim();

    if (!json.containsKey("devices")) return;

    for (var d in json["devices"]) {
      final device = Device(
        name:
            d["type"] == "Fan"
                ? "Ceiling Fan"
                : d["type"] == "Dimmable light"
                ? "Smart Light"
                : "Device ${d["deviceId"]}",
        type: d["type"],
        state: RxBool(false),
        iconPath: "assets/light-bulb.png",
        deviceId: d["deviceId"],
        registrationId: json["registrationId"],
        roomName: roomName,
      );
      deviceController.addDevice(device);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Provision Device"),
      content:
          isConnectedToESP
              ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: ssidController,
                    decoration: InputDecoration(labelText: "Wi-Fi SSID"),
                  ),
                  TextField(
                    controller: passwordController,
                    decoration: InputDecoration(labelText: "Wi-Fi Password"),
                    obscureText: true,
                  ),
                  TextField(
                    controller: roomController,
                    decoration: InputDecoration(labelText: "Room Name"),
                  ),
                  SizedBox(height: 20),
                  isSending
                      ? CircularProgressIndicator()
                      : ElevatedButton(
                        onPressed: _sendCredentialsAndFetchDevices,
                        child: Text("Send & Add Devices"),
                      ),
                ],
              )
              : const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
      actions: [TextButton(onPressed: () => Get.back(), child: Text("Cancel"))],
    );
  }
}
