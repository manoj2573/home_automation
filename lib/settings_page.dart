import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:home_automation/home_screen.dart';
import 'device.dart';
import 'device_controller.dart';

class SettingsPage extends StatefulWidget {
  final Device device;

  const SettingsPage({super.key, required this.device});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _nameController;
  late TextEditingController _roomController;
  String? _selectedIconPath;
  final DeviceController deviceController = Get.find();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.device.name);
    _roomController = TextEditingController(text: widget.device.roomName ?? "");
    _selectedIconPath = widget.device.iconPath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  void _saveChanges() {
    if (_nameController.text != widget.device.name) {
      deviceController.updateDeviceName(
        widget.device.deviceId,
        _nameController.text,
      );
    }

    if (_roomController.text != widget.device.roomName) {
      deviceController.updateDeviceRoom(
        widget.device.deviceId,
        _roomController.text,
      );
    }

    if (_selectedIconPath != null &&
        _selectedIconPath != widget.device.iconPath) {
      deviceController.updateDeviceIcon(
        widget.device.deviceId,
        _selectedIconPath!,
      );
    }

    Get.back();
  }

  Future<void> _showIconSelectionDialog() async {
    final selectedIcon = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Select Icon'),
            content: SingleChildScrollView(
              child: Wrap(
                spacing: 20.0,
                runSpacing: 20.0,
                children: [
                  _iconOption('assets/light-bulb.png'),
                  _iconOption('assets/air-conditioner.png'),
                  _iconOption('assets/blinds.png'),
                  _iconOption('assets/geyser.png'),
                  _iconOption('assets/fan.png'),
                  _iconOption('assets/refrigerator.png'),
                  _iconOption('assets/led-strip.png'),
                  _iconOption('assets/light.png'),
                  _iconOption('assets/power-socket.png'),
                  _iconOption('assets/rgb.png'),
                  _iconOption('assets/room.png'),
                  _iconOption('assets/washing-machine.png'),
                  _iconOption('assets/chandlier.png'),
                  _iconOption('assets/cooling-fan.png'),
                  _iconOption('assets/food.png'),

                  _iconOption('assets/table_fan.png'),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Get.back(), child: Text('Cancel')),
            ],
          ),
    );

    if (selectedIcon != null) {
      setState(() {
        _selectedIconPath = selectedIcon;
      });
    }
  }

  Widget _iconOption(String iconPath) {
    return InkWell(
      onTap: () => Navigator.pop(context, iconPath),
      child: Image.asset(iconPath, width: 40, height: 40),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Device Settings"),
        actions: [IconButton(icon: Icon(Icons.check), onPressed: _saveChanges)],
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // Device Name
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Device Name',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),

            // Room Name
            TextField(
              controller: _roomController,
              decoration: InputDecoration(
                labelText: 'Room Name',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),

            // Device Icon Selection
            GestureDetector(
              onTap: _showIconSelectionDialog,
              child: Card(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'Device Icon',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                    Image.asset(
                      _selectedIconPath ?? widget.device.iconPath,
                      width: 60,
                      height: 60,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),

            // Delete Button
            TextButton.icon(
              onPressed: () {
                _showDeleteDialog(context);
              },
              label: Text(
                "Delete device",
                style: TextStyle(fontSize: 20, color: Colors.black),
              ),
              icon: Icon(Icons.delete_forever, size: 40, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  Future<dynamic> _showDeleteDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text("Delete Alert", style: TextStyle(fontSize: 20)),
            content: Text("Are you sure you want to delete this device?"),
            actions: [
              TextButton(onPressed: () => Get.back(), child: Text("Cancel")),
              ElevatedButton(
                onPressed: () {
                  deviceController.removeDevice(widget.device);
                  Get.to(() => HomeScreen());
                },
                child: Text("Delete"),
              ),
            ],
          ),
    );
  }
}
