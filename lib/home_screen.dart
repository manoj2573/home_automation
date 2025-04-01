import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'device.dart';
import 'device_controller.dart';
import 'auth_controller.dart';
import 'add_device_dialog.dart';
import 'device_control_page.dart';
import 'scenes_page.dart';

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

    deviceController.loadDevices(); // ✅ Load devices on startup

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "SMART HOME",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color.fromARGB(255, 240, 200, 126),
      ),
      drawer: Drawer(
        width: 270,
        backgroundColor: const Color.fromARGB(255, 240, 200, 126),

        child: ListView(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                border: Border.all(width: 1),
                color: const Color.fromARGB(255, 240, 200, 126),
              ),
              child: Column(
                children: [
                  Center(
                    child: Text(
                      "YANTRA",
                      style: TextStyle(
                        fontSize: 40,
                        color: const Color.fromARGB(255, 36, 34, 32),
                      ),
                    ),
                  ),
                  Text('data'),
                ],
              ),
            ),

            ListTile(
              title: TextButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AddDeviceDialog(),
                  );
                },
                label: Text("Add Device", style: TextStyle(fontSize: 20)),
                icon: Icon(Icons.add, size: 30),
              ),
            ),
            SizedBox(height: 400),
            Divider(
              thickness: 2,
              color: Colors.black,
              indent: 20,
              endIndent: 20,
            ),
            ListTile(
              title: TextButton.icon(
                onPressed: () {
                  _showLogOutDialog(
                    context,
                    authController,
                  ); // ✅ Navigate to log
                },
                label: Text("LogOut", style: TextStyle(fontSize: 20)),
                icon: Icon(Icons.logout, size: 30, color: Colors.redAccent),
              ),
            ),
          ],
        ),
      ),

      body: Obx(() {
        if (deviceController.devices.isEmpty) {
          return Center(child: Text("No devices found"));
        }

        // ✅ Group devices by `roomName`
        Map<String, List<Device>> groupedDevices = {};
        for (var device in deviceController.devices) {
          groupedDevices.putIfAbsent(device.roomName, () => []).add(device);
        }

        return ListView(
          padding: EdgeInsets.all(8),
          children:
              groupedDevices.entries.map((entry) {
                String roomName = entry.key;
                List<Device> devices = entry.value;

                // ✅ Check if all devices in the room are ON
                bool isRoomOn = devices.every((device) => device.state.value);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ Room Name Header with Switch
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            roomName, // ✅ Display Room Name
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Switch(
                            activeTrackColor: Colors.green.shade200,
                            value: isRoomOn,
                            onChanged: (value) {
                              _toggleRoomDevices(
                                deviceController,
                                devices,
                                value,
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // ✅ Device Grid for this Room
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
                            child: Center(
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

  Future<dynamic> _showLogOutDialog(
    BuildContext context,
    AuthController authController,
  ) {
    return showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text("Logout Alert", style: TextStyle(fontSize: 20)),
            content: Text("Are you sure you want to logout this device?"),
            actions: [
              TextButton(onPressed: () => Get.back(), child: Text("Cancel")),
              ElevatedButton(
                onPressed: () {
                  authController.logout();
                  Get.offAllNamed('/login'); // ✅ Navigate to login screen
                },
                child: Text("Logout"),
              ),
            ],
          ),
    );
  }

  // ✅ Function to Toggle All Devices in a Room
  void _toggleRoomDevices(
    DeviceController deviceController,
    List<Device> devices,
    bool turnOn,
  ) {
    for (var device in devices) {
      if (device.state.value != turnOn) {
        deviceController.toggleDeviceState(device); // ✅ Use existing function
      }
    }
  }
}
