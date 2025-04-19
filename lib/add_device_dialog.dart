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
  final TextEditingController roomNameController =
      TextEditingController(); // ✅ New Room Name Controller
  String selectedDeviceId = "";
  String selectedVersionCode = "";
  List<Map<String, dynamic>> selectedDevices = [];

  bool isAdding = false;
  bool isPairing = false;
  bool isStatusConfirmed = false;

  String selectedModel = "v.1";

  @override
  void initState() {
    super.initState();
    MqttService.subscribe("discovery/+"); // ✅ Subscribe to MQTT
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

        if (data.containsKey("status") && data["status"] == "confirmed") {
          setState(() {
            isStatusConfirmed = true;
          });

          if (data.containsKey("versionCode") && data.containsKey("devices")) {
            selectedVersionCode = data["versionCode"];
            selectedDevices = List<Map<String, dynamic>>.from(data["devices"]);

            print(
              "✅ Version Code: $selectedVersionCode, Devices: $selectedDevices",
            );

            // ✅ Create devices after status confirmation
            _createDevicesBasedOnModel();

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

    if (roomNameController.text.isEmpty) {
      Get.snackbar("Error", "Please enter a Room Name.");
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
              ? "RGB Light"
              : type == "Curtain"
              ? "Curtains"
              : "Device $deviceId";

      devices.add(
        Device(
          name: defaultName,
          type: type,
          state: RxBool(false),
          iconPath: "assets/light-bulb.png",
          deviceId: deviceId,
          registrationId: registrationIdController.text,
          roomName: roomNameController.text, // ✅ Assign the room name
        ),
      );
    }

    for (Device device in devices) {
      deviceController.addDevice(device);
    }

    print(
      "✅ Created ${devices.length} devices in room: ${roomNameController.text}",
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Add Devices"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: registrationIdController,
            decoration: InputDecoration(labelText: "Registration ID"),
            readOnly: true,
          ),
          TextField(
            controller: pairingCodeController,
            decoration: InputDecoration(labelText: "Pairing Code"),
          ),
          TextField(
            controller: roomNameController,
            decoration: InputDecoration(labelText: "Room Name"), // ✅ New Field
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Get.back();
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
