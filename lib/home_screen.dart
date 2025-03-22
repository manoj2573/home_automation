import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'add_device_dialog.dart';
import 'device_control_page.dart';
import 'device_controller.dart';
import 'auth_controller.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final DeviceController deviceController = Get.find();
    final AuthController authController = Get.find();

    deviceController.loadDevices(); // ✅ Load & Listen for MQTT updates

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
