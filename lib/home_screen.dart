import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'add_device_dialog.dart';
import 'device_control_page.dart';
import 'device_controller.dart';
import 'auth_controller.dart';
import 'mqtt_service.dart';
import 'device.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ✅ Import FirebaseAuth
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ Import Firestore

class HomeScreen extends StatelessWidget {
  void _listenToDeviceUpdates() {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("devices")
        .snapshots()
        .listen((snapshot) {
          final DeviceController deviceController = Get.find();
          deviceController.devices.value =
              snapshot.docs.map((doc) {
                final data = doc.data();
                return Device(
                  name: data["name"],
                  type: data["type"],
                  state: RxBool(data["state"]),
                  pin: data["pin"],
                  pin2: data["pin2"],
                  iconPath: data["iconPath"],
                  sliderValue: RxDouble(data["sliderValue"]?.toDouble() ?? 0),
                  color: data["color"] ?? "#FFFFFF",
                );
              }).toList();
        });
  }

  @override
  Widget build(BuildContext context) {
    _listenToDeviceUpdates(); // ✅ Start listening to Firestore changes

    final DeviceController deviceController = Get.find();
    final AuthController authController = Get.find();

    return Scaffold(
      appBar: AppBar(
        title: Text("Home Automation"),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
              authController.logout();
              Get.offAllNamed('/login'); // ✅ Navigate to login screen
            },
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () {
          showDialog(context: context, builder: (context) => AddDeviceDialog());
        },
      ),

      body: Obx(() {
        return GridView.builder(
          padding: EdgeInsets.all(8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: deviceController.devices.length,
          itemBuilder: (context, index) {
            final device = deviceController.devices[index];

            return GestureDetector(
              onTap: () {
                // ✅ Toggle device state & send MQTT message
                deviceController.toggleDeviceState(device);
              },
              onLongPress: () {
                Get.to(() => DeviceControlPage(device: device));
              },
              child: Card(
                color:
                    device.state.value ? Colors.green.shade200 : Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  children: [
                    // ✅ Delete Button in Top Right Corner (Aligned Properly)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton(
                        icon: Icon(Icons.delete_outline, color: Colors.black),
                        onPressed: () {
                          deviceController.removeDevice(device);
                        },
                      ),
                    ),

                    // ✅ Device Details (Image, Name, State)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(device.iconPath, width: 40, height: 40),
                          SizedBox(height: 10),
                          Text(device.name, textAlign: TextAlign.center),
                          Text(device.state.value ? 'On' : 'Off'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
