import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:home_automation/login_page.dart';
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

    deviceController.loadDevices(); // ✅ Load devices on startup

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          "SMART HOME",
          style: TextStyle(
            fontWeight: FontWeight.w400,
            color: Colors.blueGrey[900],
            letterSpacing: 2.5,
          ),
        ),
        backgroundColor: Colors.transparent,
      ),
      drawer: Drawer(
        width: MediaQuery.of(context).size.width * 0.65,
        backgroundColor: const Color.fromARGB(255, 240, 200, 126),

        child: ListView(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 240, 200, 126),
              ),
              child: Column(
                children: [
                  Image.asset('assets/logo.png', height: 80),
                  Center(
                    child: Text(
                      "YANTRA",
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.blueGrey[900],
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  Text(
                    'Home Automation',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blueGrey[900],
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),

            ListTile(
              title: TextButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => WiFiProvisionDialog(),
                  );
                },
                label: Text(
                  "Add wifi Device",
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    fontSize: 18,
                    color: Colors.blueGrey[900],
                  ),
                ),
                icon: Icon(Icons.add, size: 30, color: Colors.blueGrey[900]),
              ),
            ),

            SizedBox(height: 380),
            Divider(
              thickness: 1,
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
                label: Text(
                  "LogOut",
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    fontSize: 20,
                    color: Colors.blueGrey[900],
                  ),
                ),
                icon: Icon(Icons.logout, size: 25, color: Colors.redAccent),
              ),
            ),
          ],
        ),
      ),

      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFE29E), Color.fromARGB(255, 222, 114, 5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Obx(() {
          if (deviceController.devices.isEmpty) {
            return Center(child: Text("No devices found"));
          }

          // ✅ Group devices by `roomName`
          Map<String, List<Device>> groupedDevices = {};
          for (var device in deviceController.devices) {
            groupedDevices.putIfAbsent(device.roomName, () => []).add(device);
          }

          return SafeArea(
            child: ListView(
              padding: EdgeInsets.fromLTRB(8, 8, 8, 16),
              children:
                  groupedDevices.entries.map((entry) {
                    String roomName = entry.key;
                    List<Device> devices = entry.value;

                    // ✅ Check if all devices in the room are ON
                    bool isRoomOn = devices.every(
                      (device) => device.state.value,
                    );

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ✅ Room Name Header with Switch
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 12),
                                  child: Text(
                                    roomName, // ✅ Display Room Name
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.blueGrey[900],
                                    ),
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

                          GridView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
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
                                  deviceController
                                      .loadDevices(); // Refresh on return
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
                          SizedBox(height: 20),
                          Divider(
                            color: Colors.blueGrey[400],
                            indent: 2,
                            endIndent: 2,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
            ),
          );
        }),
      ),
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

                  Get.to(() => LoginPage()); // ✅ Navigate to login screen
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
