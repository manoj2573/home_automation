import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../../features/device/device.dart';
import 'mqtt_service.dart';
import 'dart:async'; // ✅ Add this import

class DeviceController extends GetxController {
  var devices = <Device>[].obs;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;
  final bool _isDisposed = false;

  @override
  void onInit() {
    super.onInit();
    print("🔄 DeviceController Initialized");
    loadDevices();
    Future.delayed(Duration(seconds: 3), () {
      requestWifiStatus();
    });
  }

  void _onMqttMessageReceived(String topic, String message) {
    print("📩 Received MQTT Message: Topic: $topic, Message: $message");

    try {
      Map<String, dynamic> data = jsonDecode(message);

      // ✅ Extract registrationId from payload
      String? registrationId = data["registrationId"];

      // ✅ Handle device-specific state update
      String deviceId = data["deviceId"] ?? topic.split('/')[0];

      int index = devices.indexWhere(
        (device) =>
            device.deviceId == deviceId &&
            device.registrationId == registrationId,
      );

      if (index != -1) {
        devices[index].state.value = data["state"];
        devices[index].sliderValue?.value =
            (data["sliderValue"]?.toDouble()) ?? 0;
        devices[index].color = data["color"] ?? devices[index].color;

        _updateFirestore(devices[index]);
        print("🔄 Updated UI and Firestore for ${devices[index].name}");
      }
    } catch (e) {
      print("❌ Error decoding MQTT message: $e");
    }
  }

  void _updateFirestore(Device device) async {
    String? uid = auth.currentUser?.uid;

    try {
      await firestore
          .collection("users")
          .doc(uid)
          .collection("devices")
          .doc(device.deviceId)
          .set({
            "deviceId": device.deviceId,
            "name": device.name,
            "type": device.type,
            "state": device.state.value,
            "sliderValue": device.sliderValue?.value ?? 0,
            "color": device.color,
            "registrationId": device.registrationId,
            "roomName": device.roomName,
          }, SetOptions(merge: true));

      print(
        "✅ Firestore Updated: ${device.name} (Device ID: ${device.deviceId})",
      );
    } catch (e) {
      print("❌ Error updating Firestore: $e");
    }
  }

  // ✅ Load Devices for the Logged-in User
  void loadDevices() async {
    String? uid = auth.currentUser?.uid;

    firestore
        .collection("users")
        .doc(uid)
        .collection("devices")
        .snapshots()
        .listen((snapshot) {
          devices.value =
              snapshot.docs.map((doc) {
                final data = doc.data();
                final device = Device(
                  deviceId: data["deviceId"],
                  name: data["name"],
                  type: data["type"],
                  state: RxBool(data["state"]),
                  iconPath: data["iconPath"],
                  sliderValue: RxDouble(data["sliderValue"]?.toDouble() ?? 0),
                  color: data["color"] ?? "#FFFFFF",
                  registrationId: data["registrationId"],
                  roomName: data["roomName"] ?? "Unknown Room",
                );

                // ✅ Subscribe to device topic if MQTT is connected
                if (MqttService.isConnected) {
                  MqttService.subscribe("${device.deviceId}/mobile");
                  MqttService.subscribe("${device.registrationId}/mobile");
                  print("✅ Subscribed to ${device.deviceId}/mobile (on load)");
                }

                return device;
              }).toList();

          devices.refresh();
        });

    MqttService.setMessageHandler(_onMqttMessageReceived);
  }

  // ✅ Add Device for the Logged-in User
  Future<void> addDevice(Device device) async {
    String? uid = auth.currentUser?.uid;

    await firestore
        .collection("users")
        .doc(uid)
        .collection("devices")
        .doc(device.deviceId)
        .set({
          "deviceId": device.deviceId,
          "name": device.name,
          "type": device.type,
          "state": device.state.value,

          "iconPath": device.iconPath,
          "sliderValue": device.sliderValue?.value ?? 0,
          "color": device.color,
          "registrationId": device.registrationId,
          "roomName": device.roomName,
        });

    devices.add(device);
    devices.refresh();

    if (MqttService.isConnected) {
      MqttService.subscribe("${device.deviceId}/mobile");
      print("✅ Subscribed to ${device.deviceId}/mobile");
    } else {
      print("⚠️ MQTT not connected. Subscription will be retried.");
    }
  }

  // ✅ Toggle Device State and Update Firestore
  void toggleDeviceState(Device device) async {
    devices.refresh();

    String? uid = auth.currentUser?.uid;

    await firestore
        .collection("users")
        .doc(uid)
        .collection("devices")
        .doc(device.deviceId)
        .update({"state": device.state.value});

    double currentSliderValue = device.sliderValue?.value ?? 0.0;
    int intSliderValue = currentSliderValue.toInt();
    // ✅ Send MQTT message
    Map<String, dynamic> payload = {
      "deviceId": device.deviceId,
      "deviceName": device.name,
      "deviceType": device.type,
      "state": !device.state.value,

      "sliderValue": intSliderValue,
      'color': device.color,
      "registrationId": device.registrationId,
      "roomName": device.roomName,
    };

    if (MqttService.isConnected) {
      MqttService.publish("${device.deviceId}/device", jsonEncode(payload));
    } else {
      print("❌ MQTT is not connected. Cannot send message.");
    }
  }

  // ✅ Update Device Icon for the Logged-in User
  void updateDeviceIcon(String deviceId, String newIconPath) async {
    String? uid = auth.currentUser?.uid;

    int index = devices.indexWhere((d) => d.deviceId == deviceId);
    if (index != -1) {
      devices[index].iconPath = newIconPath;
      devices.refresh();

      await firestore
          .collection("users")
          .doc(uid)
          .collection("devices")
          .doc(deviceId)
          .update({"iconPath": newIconPath});
    }
  }

  void updateDeviceName(String deviceId, String newDeviceName) async {
    String? uid = auth.currentUser?.uid;

    int index = devices.indexWhere((d) => d.deviceId == deviceId);
    if (index != -1) {
      devices[index].name = newDeviceName;
      devices.refresh();

      await firestore
          .collection("users")
          .doc(uid)
          .collection("devices")
          .doc(deviceId)
          .update({"name": newDeviceName});
    }
  }

  // ✅ Delete Device for the Logged-in User
  void removeDevice(Device device) async {
    String? uid = auth.currentUser?.uid;

    await firestore
        .collection("users")
        .doc(uid)
        .collection("devices")
        .doc(device.deviceId)
        .delete();
    devices.remove(device);
  }

  void updateDeviceRoom(String deviceId, String newRoom) async {
    String? uid = auth.currentUser?.uid;
    int index = devices.indexWhere((d) => d.deviceId == deviceId);
    if (index != -1) {
      devices[index].roomName = newRoom;
      devices.refresh();

      await firestore
          .collection("users")
          .doc(uid)
          .collection("devices")
          .doc(deviceId)
          .update({'roomName': newRoom})
          .then((_) {
            print("Device moved to new room: $newRoom");
          })
          .catchError((error) {
            print("Failed to update room: $error");
          });
    }
  }

  void requestWifiStatus() {
    final registrationIds = devices.map((d) => d.registrationId).toSet();

    for (final regId in registrationIds) {
      final topic = "$regId/device";
      final payload = jsonEncode({"command": "wifiStatus"});

      if (MqttService.isConnected) {
        MqttService.publish(topic, payload);
        print("🔄 Requested Wi-Fi status on $topic");
      } else {
        print("❌ MQTT not connected. Cannot send Wi-Fi status request.");
      }
    }
  }
}
