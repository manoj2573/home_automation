import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';

class UpdateWifiDialog extends StatefulWidget {
  const UpdateWifiDialog({super.key});

  @override
  State<UpdateWifiDialog> createState() => _UpdateWifiDialogState();
}

class _UpdateWifiDialogState extends State<UpdateWifiDialog> {
  final ssidController = TextEditingController();
  final passwordController = TextEditingController();
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

  Future<void> _updateWifiCredentials() async {
    setState(() => isSending = true);

    try {
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
        await WiFiForIoTPlugin.disconnect();
        Get.back(); // Close the dialog
        Get.snackbar("Success", "Wi-Fi credentials updated successfully");
      } else {
        Get.snackbar("Error", "ESP32 rejected Wi-Fi credentials");
      }
    } catch (e) {
      Get.snackbar("Error", "Failed to update credentials: $e");
    } finally {
      setState(() => isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Update Wi-Fi Credentials"),
      content:
          isConnectedToESP
              ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: ssidController,
                    decoration: const InputDecoration(
                      labelText: "New Wi-Fi SSID",
                    ),
                  ),
                  TextField(
                    controller: passwordController,
                    decoration: const InputDecoration(
                      labelText: "New Wi-Fi Password",
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 20),
                  isSending
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                        onPressed: _updateWifiCredentials,
                        child: const Text("Update Credentials"),
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
