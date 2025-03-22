import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
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
    listenForScheduledActions();
  }

  void _onMqttMessageReceived(String topic, String message) {
    print("📩 Received MQTT Message: Topic: $topic, Message: $message");

    try {
      Map<String, dynamic> data = jsonDecode(message);
      String registrationId = topic.split('/')[0]; // Extract registrationId
      String? deviceName = data["deviceName"]; // Extract deviceName

      if (deviceName == null) {
        print("⚠️ MQTT Message Missing 'deviceName' - Ignoring");
        return;
      }

      // ✅ Find the correct device by BOTH `registrationId` and `deviceName`
      int index = devices.indexWhere(
        (device) =>
            device.registrationId == registrationId &&
            device.name == deviceName,
      );

      if (index != -1) {
        devices[index].state.value = data["state"];
        devices[index].sliderValue?.value =
            data["sliderValue"]?.toDouble() ??
            devices[index].sliderValue?.value ??
            0;
        devices[index].color = data["color"] ?? devices[index].color;

        devices.refresh(); // ✅ Refresh Home UI
        print("🔄 Home UI Updated for ${devices[index].name}");

        // ✅ Now update Firestore with the new state
        _updateFirestore(devices[index]);
      } else {
        print(
          "⚠️ No matching device found for registrationId: $registrationId & deviceName: $deviceName",
        );
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
          .doc(device.name)
          .set({
            "name": device.name,
            "type": device.type,
            "state": device.state.value,
            "sliderValue": device.sliderValue?.value ?? 0,
            "color": device.color,
            "registrationId": device.registrationId,
          }, SetOptions(merge: true)); // ✅ Merge with existing data

      print("✅ Firestore Updated: ${device.name} state saved.");
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
                Device device = Device(
                  name: data["name"],
                  type: data["type"],
                  state: RxBool(data["state"]),
                  pin: data["pin"],
                  pin2: data["pin2"],
                  iconPath: data["iconPath"],
                  sliderValue: RxDouble(data["sliderValue"]?.toDouble() ?? 0),
                  color: data["color"] ?? "#FFFFFF",
                  registrationId: data["registrationId"],
                );

                // ✅ Subscribe to MQTT updates for this device
                MqttService.subscribe("${device.registrationId}/mobile");

                return device;
              }).toList();

          devices.refresh();
        });

    // ✅ Set MQTT message handler after devices are loaded
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
        .doc(device.name)
        .set({
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
        .doc(device.name)
        .update({"state": device.state.value});

    // ✅ Send MQTT message
    Map<String, dynamic> payload = {
      "deviceName": device.name,
      "deviceType": device.type,
      "state": device.state.value,
      "pin": device.pin,
      "pin2": device.pin2,
      "registartionId": device.registrationId,
    };

    if (MqttService.isConnected) {
      MqttService.publish(
        "${device.registrationId}/device",
        jsonEncode(payload),
      );
    } else {
      print("❌ MQTT is not connected. Cannot send message.");
    }
  }

  // ✅ Update Device Icon for the Logged-in User
  void updateDeviceIcon(String deviceName, String newIconPath) async {
    String? uid = auth.currentUser?.uid;
    if (uid == null) return;

    int index = devices.indexWhere((d) => d.name == deviceName);
    if (index != -1) {
      devices[index].iconPath = newIconPath;
      devices.refresh();

      await firestore
          .collection("users")
          .doc(uid)
          .collection("devices")
          .doc(deviceName)
          .update({"iconPath": newIconPath});
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
        .doc(device.name)
        .delete();
    devices.remove(device);
  }

  void listenForScheduledActions() {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      print("⚠️ No user logged in. Skipping schedule checks.");
      return;
    }

    print("🕒 Starting schedule listener...");

    Timer.periodic(Duration(minutes: 1), (timer) async {
      print("🔄 Checking schedules...");

      for (var device in devices) {
        CollectionReference schedulesRef = FirebaseFirestore.instance
            .collection("users")
            .doc(uid)
            .collection("devices")
            .doc(device.name)
            .collection("schedules");

        QuerySnapshot schedulesSnapshot = await schedulesRef.get();

        if (schedulesSnapshot.docs.isEmpty) {
          print("⚠️ No schedules found for ${device.name}");
        }

        for (QueryDocumentSnapshot doc in schedulesSnapshot.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          DateTime scheduledTime = DateTime.parse(data["dateTime"]);
          String action = data["action"];

          print(
            "📅 Found schedule for ${device.name} → $action at $scheduledTime",
          );

          if (DateTime.now().isAfter(scheduledTime)) {
            print("⏰ Executing scheduled action: $action for ${device.name}");

            // ✅ Determine the new state (On/Off)
            bool newState = (action == "On");

            // ✅ Publish MQTT Message
            Map<String, dynamic> payload = {
              "deviceName": device.name,
              "deviceType": device.type,
              "state": newState,
              "pin1No": device.pin,
              "pin2No": device.pin2 ?? '',
              "registartionId": device.registrationId,
            };

            if (MqttService.isConnected) {
              MqttService.publish(
                "${device.registrationId}/mobile",
                jsonEncode(payload),
              );
              print("📡 MQTT Message Sent: $payload");
            } else {
              print("⚠️ MQTT Not Connected - Retrying...");
              Future.delayed(Duration(seconds: 3), () {
                if (MqttService.isConnected) {
                  MqttService.publish(
                    "${device.registrationId}/mobile",
                    jsonEncode(payload),
                  );
                  print("📡 Retried MQTT Message Sent: $payload");
                } else {
                  print("❌ Still Not Connected");
                }
              });
            }

            // ✅ Remove schedule after execution
            await doc.reference.delete();
            print("🗑️ Schedule removed after execution");
          }
        }
      }
    });
  }
}
