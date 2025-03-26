import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'device.dart';
import 'device_controller.dart';
import 'mqtt_service.dart';

class AddDeviceDialog extends StatefulWidget {
  const AddDeviceDialog({super.key});

  @override
  _AddDeviceDialogState createState() => _AddDeviceDialogState();
}

class _AddDeviceDialogState extends State<AddDeviceDialog> {
  final TextEditingController registrationIdController =
      TextEditingController();
  final TextEditingController pairingCodeController = TextEditingController();
  String selectedDeviceId = "";
  String selectedVersionCode = "";
  List<Map<String, dynamic>> selectedDevices = [];

  bool isAdding = false;
  bool isPairing = false;
  bool isStatusConfirmed = false; // ✅ Track status confirmation

  String selectedModel = "v.1";

  @override
  void initState() {
    super.initState();
    MqttService.subscribe("discovery/+"); // ✅ Subscribe to discovery/+
    MqttService.setMessageHandler(_onMqttMessageReceived);
  }

  @override
  void dispose() {
    MqttService.unsubscribe("discovery/+"); // ✅ Unsubscribe from discovery/+
    super.dispose();
  }

  void _onMqttMessageReceived(String topic, String message) {
    print("📩 Received MQTT Message: Topic: $topic, Message: $message");

    try {
      Map<String, dynamic> data = jsonDecode(message);
      if (topic.startsWith("discovery/") &&
          data.containsKey("registrationId")) {
        setState(() {
          registrationIdController.text = data["registrationId"];
        });

        // ✅ Check for status confirmation
        if (data.containsKey("status") && data["status"] == "confirmed") {
          setState(() {
            isStatusConfirmed = true; // ✅ Mark status as confirmed
          });

          // ✅ Only create devices after status is confirmed
          if (data.containsKey("versionCode") && data.containsKey("devices")) {
            selectedVersionCode = data["versionCode"];

            List<Map<String, dynamic>> devices =
                List<Map<String, dynamic>>.from(data["devices"]);
            setState(() {
              selectedDevices = devices;
            });

            print(
              "✅ Version Code: $selectedVersionCode, Devices: $selectedDevices",
            );

            // ✅ Create devices after status confirmation
            _createDevicesBasedOnModel();

            // ✅ Close the dialog and show a snackbar
            Get.back(); // Close the dialog
            Get.snackbar(
              "Success",
              "Pairing successful, devices created",
              snackPosition: SnackPosition.BOTTOM,
              duration: Duration(seconds: 3),
            );
          }
        }
      }
    } catch (e) {
      print("❌ Error parsing MQTT message: $e");
    }
  }

  void _sendPairingRequest() {
    if (pairingCodeController.text.isNotEmpty &&
        registrationIdController.text.isNotEmpty) {
      setState(() {
        isPairing = true;
      });

      // ✅ Publish to discovery/registrationId (without /mobile)
      MqttService.publish(
        "discovery/${registrationIdController.text}",
        jsonEncode({"pairingCode": pairingCodeController.text}),
      );
    } else {
      Get.snackbar(
        "Error",
        "Please enter both Registration ID and Pairing Code",
      );
    }
  }

  void _createDevicesBasedOnModel() {
    final deviceController = Get.find<DeviceController>();

    if (selectedDevices.isEmpty || selectedVersionCode.isEmpty) {
      Get.snackbar(
        "Error",
        "No Device IDs or Version Code found. Please pair first.",
      );
      return;
    }

    List<Device> devices = [];

    for (var device in selectedDevices) {
      String deviceId = device["deviceId"];
      String type = device["type"];

      String defaultName =
          type == "On/Off"
              ? "Switch"
              : type == "Fan"
              ? "Ceiling Fan"
              : type == "Dimmable light"
              ? "Smart Light"
              : type == "RGB"
              ? "RGB light"
              : type == "Curtain"
              ? "curtains"
              : "Device $deviceId";

      devices.add(
        Device(
          name: defaultName,
          type: type,
          state: RxBool(false),
          pin: 'N/A',
          iconPath: "assets/light-bulb.png",
          deviceId: deviceId,
          registrationId: registrationIdController.text,
        ),
      );
    }

    for (Device device in devices) {
      deviceController.addDevice(device);
    }

    print(
      "✅ Created ${devices.length} devices for Registration ID: ${registrationIdController.text}",
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Add Devices"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButton<String>(
            value: selectedModel,
            items:
                ["v.1", "v.2", "v.3", "v.4"].map((String model) {
                  return DropdownMenuItem<String>(
                    value: model,
                    child: Text("Model $model"),
                  );
                }).toList(),
            onChanged: (newValue) {
              setState(() {
                selectedModel = newValue!;
              });
            },
          ),
          TextField(
            controller: registrationIdController,
            decoration: InputDecoration(labelText: "Registration ID"),
            readOnly: true,
          ),
          TextField(
            controller: pairingCodeController,
            decoration: InputDecoration(labelText: "Pairing Code"),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Get.back(); // ✅ Close dialog without creating devices
          },
          child: Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _sendPairingRequest,
          child:
              isPairing
                  ? CircularProgressIndicator()
                  : Text("Pair & Add Devices"),
        ),
      ],
    );
  }
}
