import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'device.dart';
import 'device_controller.dart';

class SettingsPage extends StatelessWidget {
  final Device device;

  const SettingsPage({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    final DeviceController deviceController = Get.find();

    return Scaffold(
      appBar: AppBar(title: Text("Device Settings")),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Icon for ${device.name}',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 20),
            Wrap(
              spacing: 8.0,
              children: [
                _iconButton(deviceController, device, 'assets/light-bulb.png'),
                _iconButton(
                  deviceController,
                  device,
                  'assets/air-conditioner.png',
                ),
                _iconButton(deviceController, device, 'assets/blinds.png'),
                _iconButton(deviceController, device, 'assets/geyser.png'),
                _iconButton(deviceController, device, 'assets/fan.png'),
                _iconButton(
                  deviceController,
                  device,
                  'assets/refrigerator.png',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Function to Select an Icon
  Widget _iconButton(
    DeviceController deviceController,
    Device device,
    String iconPath,
  ) {
    return ElevatedButton(
      child: Image.asset(iconPath, height: 40, width: 40),
      onPressed: () {
        deviceController.updateDeviceIcon(device.name, iconPath);
        Get.back();
      },
    );
  }
}
