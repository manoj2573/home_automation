import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
  String? _selectedIconPath;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.device.name);
    _selectedIconPath = widget.device.iconPath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveChanges() {
    final deviceController = Get.find<DeviceController>();

    if (_nameController.text != widget.device.name) {
      deviceController.updateDeviceName(
        widget.device.deviceId,
        _nameController.text,
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
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Device Name',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
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
          ],
        ),
      ),
    );
  }
}
