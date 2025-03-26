import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'device.dart';
import 'device_controller.dart';
import 'auth_controller.dart';
import 'add_device_dialog.dart';
import 'device_control_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final DeviceController deviceController = Get.find();
    final AuthController authController = Get.find();

    deviceController.loadDevices(); // ✅ Ensure devices are loaded

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
        if (deviceController.devices.isEmpty) {
          return Center(child: Text("No devices found"));
        }

        // ✅ Group devices by registrationId
        Map<String, List<Device>> groupedDevices = {};
        for (var device in deviceController.devices) {
          groupedDevices
              .putIfAbsent(device.registrationId, () => [])
              .add(device);
        }

        return ListView(
          padding: EdgeInsets.all(8),
          children:
              groupedDevices.entries.map((entry) {
                String registrationId = entry.key;
                List<Device> devices = entry.value;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ Registration ID Header
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        "Registration ID: $registrationId",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    // ✅ Device Grid for this Registration ID
                    GridView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1,
                      ),
                      itemCount: devices.length,
                      itemBuilder: (context, index) {
                        final device = devices[index];

                        return GestureDetector(
                          onTap: () {
                            deviceController.toggleDeviceState(device);
                          },
                          onLongPress: () async {
                            await Get.to(
                              () => DeviceControlPage(device: device),
                            );
                            deviceController.loadDevices(); // Refresh on return
                          },
                          child: Card(
                            color:
                                device.state.value
                                    ? Colors.green.shade200
                                    : Colors.white,
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
                                    icon: Icon(
                                      Icons.delete_outline,
                                      color: Colors.black,
                                    ),
                                    onPressed: () {
                                      deviceController.removeDevice(device);
                                    },
                                  ),
                                ),
                                Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Image.asset(
                                        device.iconPath,
                                        width: 40,
                                        height: 40,
                                      ),
                                      SizedBox(height: 10),
                                      Text(
                                        device.name,
                                        textAlign: TextAlign.center,
                                      ),
                                      Text(device.state.value ? 'On' : 'Off'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              }).toList(),
        );
      }),
    );
  }
}
