import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'device.dart';
import 'device_controller.dart';

class AddDeviceDialog extends StatefulWidget {
  @override
  _AddDeviceDialogState createState() => _AddDeviceDialogState();
}

class _AddDeviceDialogState extends State<AddDeviceDialog> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController pinController = TextEditingController();
  final TextEditingController pin2Controller = TextEditingController();
  String selectedType = "On/Off"; // Default device type
  bool isAdding = false; // ✅ Prevent multiple taps

  @override
  Widget build(BuildContext context) {
    final DeviceController deviceController = Get.find();

    return AlertDialog(
      title: Text("Add New Device"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: InputDecoration(labelText: "Device Name"),
          ),

          // ✅ Device Type Dropdown
          DropdownButton<String>(
            value: selectedType,
            items:
                ["On/Off", "Dimmable light", "Fan", "RGB", "Curtain"].map((
                  String type,
                ) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
            onChanged: (newValue) {
              setState(() {
                selectedType = newValue!;
              });
            },
          ),

          // ✅ GPIO Pin 1 Input (Always Visible)
          TextField(
            controller: pinController,
            decoration: InputDecoration(labelText: "GPIO Pin Number 1"),
            keyboardType: TextInputType.number,
          ),

          // ✅ GPIO Pin 2 Input (Only for Fan & Curtain)
          if (selectedType == "Fan" || selectedType == "Curtain")
            TextField(
              controller: pin2Controller,
              decoration: InputDecoration(labelText: "GPIO Pin Number 2"),
              keyboardType: TextInputType.number,
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: isAdding ? null : () => Get.back(),
          child: Text("Cancel"),
        ),

        ElevatedButton(
          onPressed:
              isAdding
                  ? null
                  : () async {
                    if (nameController.text.isNotEmpty &&
                        pinController.text.isNotEmpty) {
                      setState(() {
                        isAdding = true; // ✅ Prevent multiple taps
                      });

                      // ✅ Check if device already exists to prevent duplicates
                      final deviceExists = deviceController.devices.any(
                        (device) => device.name == nameController.text.trim(),
                      );

                      if (deviceExists) {
                        Get.snackbar(
                          "Error",
                          "Device with this name already exists!",
                        );
                        setState(() {
                          isAdding = false;
                        });
                        return;
                      }

                      final newDevice = Device(
                        name: nameController.text.trim(),
                        type: selectedType,
                        state: RxBool(false),
                        pin: pinController.text.trim(),
                        pin2:
                            (selectedType == "Fan" || selectedType == "Curtain")
                                ? pin2Controller.text.trim()
                                : null,
                        iconPath: 'assets/light-bulb.png',
                      );

                      await deviceController.addDevice(
                        newDevice,
                      ); // ✅ Wait for addition

                      setState(() {
                        isAdding = false;
                      });

                      Get.back(); // ✅ Close the dialog only after adding device
                    } else {
                      Get.snackbar("Error", "Please enter all required fields");
                    }
                  },
          child: isAdding ? CircularProgressIndicator() : Text("Add"),
        ),
      ],
    );
  }
}
