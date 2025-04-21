import 'package:flutter/material.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import 'add_device_dialog.dart';

class WiFiAndAddDeviceFlowDialog extends StatefulWidget {
  const WiFiAndAddDeviceFlowDialog({super.key});

  @override
  State<WiFiAndAddDeviceFlowDialog> createState() =>
      _WiFiAndAddDeviceFlowDialogState();
}

class _WiFiAndAddDeviceFlowDialogState
    extends State<WiFiAndAddDeviceFlowDialog> {
  final ssidController = TextEditingController();
  final passwordController = TextEditingController();
  bool isConnectedToESP = false;
  bool isSending = false;
  String? ssid;
  String? ip;
  String? responseMessage;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _requestPermissions();
    await _connectToESP32Hotspot();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.location,
      Permission.locationWhenInUse,
      Permission.locationAlways,
    ].request();
  }

  Future<void> _connectToESP32Hotspot() async {
    try {
      bool connected = await WiFiForIoTPlugin.connect(
        "ESP32_Config",
        security: NetworkSecurity.WPA,
        password: "12345678",
        joinOnce: true,
        withInternet: false,
      );

      if (connected) {
        await WiFiForIoTPlugin.forceWifiUsage(true);
        ssid = await WiFiForIoTPlugin.getSSID();
        ip = await WiFiForIoTPlugin.getIP();

        setState(() => isConnectedToESP = true);
      }
    } catch (e) {
      print("⚠️ Error: $e");
    }
  }

  Future<void> _sendWiFiCredentials() async {
    setState(() => isSending = true);

    try {
      final response = await http.post(
        Uri.parse("http://192.168.4.1/connect"),
        body: {
          'ssid': ssidController.text,
          'password': passwordController.text,
        },
      );

      setState(() => responseMessage = response.body);

      if (response.statusCode == 200 &&
          response.body.toLowerCase().contains("received")) {
        if (!mounted) return;

        // Close current dialog first
        Navigator.of(context).pop();

        // Wait until the dialog closes completely
        await Future.delayed(Duration(milliseconds: 300));

        // Show AddDeviceDialog on next frame
        Get.dialog(const AddDeviceDialog());
      } else {
        Get.snackbar("Error", "ESP32 Response: ${response.body}");
      }
    } catch (e) {
      Get.snackbar("Error", "Failed to send credentials: $e");
    } finally {
      if (mounted) {
        setState(() => isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Connect Device to Wi-Fi"),
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
                  const SizedBox(height: 20),
                  isSending
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                        onPressed: _sendWiFiCredentials,
                        child: Text("Send Credentials"),
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
