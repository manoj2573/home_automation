import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'device.dart';
import 'mqtt_service.dart';
import 'dart:async'; // ✅ Add this import

class DeviceController extends GetxController {
  var devices = <Device>[].obs;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;
  bool _isDisposed = false;

  @override
  void onInit() {
    super.onInit();
    print("🔄 DeviceController Initialized");
    loadDevices();
  }

  void _onMqttMessageReceived(String topic, String message) {
    print("📩 Received MQTT Message: Topic: $topic, Message: $message");

    try {
      Map<String, dynamic> data = jsonDecode(message);
      String deviceId = topic.split('/')[0]; // ✅ Extract deviceId
      String? registrationId = data["registrationId"];

      if (!data.containsKey("deviceId") || data["deviceId"] != deviceId) {
        print("⚠️ MQTT Message Ignored: No matching deviceId found");
        return;
      }

      // ✅ Find the correct device using deviceId
      int index = devices.indexWhere(
        (device) =>
            device.registrationId == registrationId &&
            device.deviceId == deviceId,
      );

      if (index != -1) {
        devices[index].state.value = data["state"];
        devices[index].sliderValue?.value =
            data["sliderValue"]?.toDouble() ??
            devices[index].sliderValue?.value ??
            0;
        devices[index].color = data["color"] ?? devices[index].color;

        devices.refresh();
        print("🔄 Home UI Updated for ${devices[index].name}");

        // ✅ Update Firestore
        _updateFirestore(devices[index]);
      } else {
        print("⚠️ No matching device found for deviceId: $deviceId");
      }
    } catch (e) {
      print("❌ Error decoding MQTT message: $e");
    }
  }

  void _updateFirestore(Device device) async {
    String? uid = auth.currentUser?.uid;
    if (uid == null) return;

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
    if (uid == null) return;

    firestore
        .collection("users")
        .doc(uid)
        .collection("devices")
        .snapshots()
        .listen((snapshot) {
          devices.value =
              snapshot.docs.map((doc) {
                final data = doc.data();
                return Device(
                  deviceId: data["deviceId"],
                  name: data["name"],
                  type: data["type"],
                  state: RxBool(data["state"]),
                  pin: data["pin"],
                  iconPath: data["iconPath"],
                  sliderValue: RxDouble(data["sliderValue"]?.toDouble() ?? 0),
                  color: data["color"] ?? "#FFFFFF",
                  registrationId: data["registrationId"],
                );
              }).toList();

          devices.refresh();
        });

    MqttService.setMessageHandler(_onMqttMessageReceived);
  }

  // ✅ Add Device for the Logged-in User
  Future<void> addDevice(Device device) async {
    String? uid = auth.currentUser?.uid;
    if (uid == null) return;

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
          "pin": device.pin,
          "pin2": device.pin2 ?? "",
          "iconPath": device.iconPath,
          "sliderValue": device.sliderValue?.value ?? 0,
          "color": device.color,
          "registrationId": device.registrationId,
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
    device.state.value = !device.state.value;
    devices.refresh();

    String? uid = auth.currentUser?.uid;
    if (uid == null) return;

    await firestore
        .collection("users")
        .doc(uid)
        .collection("devices")
        .doc(device.deviceId)
        .update({"state": device.state.value});

    // ✅ Send MQTT message
    Map<String, dynamic> payload = {
      "deviceId": device.deviceId,
      "deviceName": device.name,
      "deviceType": device.type,
      "state": device.state.value,
      "pin": device.pin,
      "pin2": device.pin2,
      "sliderValue": device.sliderValue?.value ?? 0.0,
      'color': device.color,
      "registrationId": device.registrationId,
    };

    if (MqttService.isConnected) {
      MqttService.publish("${device.deviceId}/device", jsonEncode(payload));
      MqttService.subscribe("${device.deviceId}/mobile"); // ✅ Correct topic
      print("📡 Subscribed to ${device.deviceId}/mobile");
    } else {
      print("❌ MQTT is not connected. Cannot send message.");
    }
  }

  // ✅ Update Device Icon for the Logged-in User
  void updateDeviceIcon(String deviceId, String newIconPath) async {
    String? uid = auth.currentUser?.uid;
    if (uid == null) return;

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
    if (uid == null) return;

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
    if (uid == null) return;

    await firestore
        .collection("users")
        .doc(uid)
        .collection("devices")
        .doc(device.deviceId)
        .delete();
    devices.remove(device);
  }
}
