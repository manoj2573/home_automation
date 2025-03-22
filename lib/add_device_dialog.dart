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
  bool isAdding = false;
  bool isPairing = false;

  String selectedModel = "v.1"; // ✅ Default Model Code

  @override
  void initState() {
    super.initState();
    MqttService.subscribe("discovery/+");
    MqttService.setMessageHandler(_onMqttMessageReceived);
  }

  @override
  void dispose() {
    MqttService.unsubscribe("discovery/+");
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
        print("✅ Registration ID received: ${data["registrationId"]}");
      }

      // ✅ Handle pairing confirmation
      if (topic == "discovery/${registrationIdController.text}") {
        if (data.containsKey("status") && data["status"] == "confirmed") {
          print("✅ Device paired successfully!");
          Get.snackbar("Success", "Device paired successfully");
          _createDevicesBasedOnModel();
        } else {
          print("❌ Pairing failed.");
          Get.snackbar("Error", "Pairing failed");
          setState(() {
            isPairing = false;
          });
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
    String registrationId = registrationIdController.text.trim();

    if (registrationId.isEmpty) {
      Get.snackbar("Error", "No Registration ID found. Please pair first.");
      return;
    }

    List<Device> devices = [];

    // ✅ Device configurations based on model selection
    Map<String, List<Device>> modelDevices = {
      "v.1": [
        Device(
          name: "Switch 1",
          type: "On/Off",
          state: RxBool(false),
          pin: "1",
          iconPath: "assets/light-bulb.png",
          registrationId: registrationId,
        ),
        Device(
          name: "Switch 2",
          type: "On/Off",
          state: RxBool(false),
          pin: "2",
          iconPath: "assets/light-bulb.png",
          registrationId: registrationId,
        ),
        Device(
          name: "Switch 3",
          type: "On/Off",
          state: RxBool(false),
          pin: "3",
          iconPath: "assets/light-bulb.png",
          registrationId: registrationId,
        ),
        Device(
          name: "Fan",
          type: "Fan",
          state: RxBool(false),
          pin: "4",
          iconPath: "assets/fan.png",
          registrationId: registrationId,
        ),
        Device(
          name: "Dimmable Light",
          type: "Dimmable light",
          state: RxBool(false),
          pin: "5",
          iconPath: "assets/light-bulb.png",
          registrationId: registrationId,
        ),
      ],
      "v.2": [
        Device(
          name: "Switch 1",
          type: "On/Off",
          state: RxBool(false),
          pin: "1",
          iconPath: "assets/light-bulb.png",
          registrationId: registrationId,
        ),
        Device(
          name: "Switch 2",
          type: "On/Off",
          state: RxBool(false),
          pin: "2",
          iconPath: "assets/light-bulb.png",
          registrationId: registrationId,
        ),
        Device(
          name: "Fan 1",
          type: "Fan",
          state: RxBool(false),
          pin: "3",
          iconPath: "assets/fan.png",
          registrationId: registrationId,
        ),
        Device(
          name: "Fan 2",
          type: "Fan",
          state: RxBool(false),
          pin: "4",
          iconPath: "assets/fan.png",
          registrationId: registrationId,
        ),
        Device(
          name: "RGB Light",
          type: "RGB",
          state: RxBool(false),
          pin: "5",
          iconPath: "assets/light-bulb.png",
          registrationId: registrationId,
        ),
      ],
      "v.3": [
        Device(
          name: "Switch",
          type: "On/Off",
          state: RxBool(false),
          pin: "1",
          iconPath: "assets/light-bulb.png",
          registrationId: registrationId,
        ),
        Device(
          name: "Curtain",
          type: "Curtain",
          state: RxBool(false),
          pin: "2",
          iconPath: "assets/light-bulb.png",
          registrationId: registrationId,
        ),
        Device(
          name: "RGB Light",
          type: "RGB",
          state: RxBool(false),
          pin: "3",
          iconPath: "assets/light-bulb.png",
          registrationId: registrationId,
        ),
        Device(
          name: "Fan",
          type: "Fan",
          state: RxBool(false),
          pin: "4",
          iconPath: "assets/fan.png",
          registrationId: registrationId,
        ),
      ],
      "v.4": [
        Device(
          name: "Switch 1",
          type: "On/Off",
          state: RxBool(false),
          pin: "1",
          iconPath: "assets/light-bulb.png",
          registrationId: registrationId,
        ),
        Device(
          name: "Switch 2",
          type: "On/Off",
          state: RxBool(false),
          pin: "2",
          iconPath: "assets/light-bulb.png",
          registrationId: registrationId,
        ),
        Device(
          name: "Switch 3",
          type: "On/Off",
          state: RxBool(false),
          pin: "3",
          iconPath: "assets/light-bulb.png",
          registrationId: registrationId,
        ),
        Device(
          name: "Switch 4",
          type: "On/Off",
          state: RxBool(false),
          pin: "4",
          iconPath: "assets/light-bulb.png",
          registrationId: registrationId,
        ),
        Device(
          name: "Fan",
          type: "Fan",
          state: RxBool(false),
          pin: "5",
          iconPath: "assets/fan.png",
          registrationId: registrationId,
        ),
      ],
    };

    devices = modelDevices[selectedModel] ?? [];

    for (Device device in devices) {
      deviceController.addDevice(device);
    }

    print("✅ Created ${devices.length} devices for model: $selectedModel");
    Get.snackbar("Success", "Devices added successfully!");
    Get.back();
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
        TextButton(onPressed: () => Get.back(), child: Text("Cancel")),
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
