import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:home_automation/core/widgets/custom_text_fields.dart';
import 'package:home_automation/core/widgets/theme.dart';
import 'package:home_automation/home_screen.dart';
import 'device.dart';
import '../../core/services/device_controller.dart';

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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text("Device Settings", style: AppTextStyles.title),
        actions: [IconButton(icon: Icon(Icons.check), onPressed: _saveChanges)],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppGradients.loginBackground),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // Device Name
                AppTextField(controller: _nameController, label: 'Device Name'),
                SizedBox(height: 12),

                // Room Name
                AppTextField(controller: _roomController, label: 'Room Name'),
                SizedBox(height: 20),

                // Device Icon Selection
                GestureDetector(
                  onTap: _showIconSelectionDialog,
                  child: Card(
                    color: AppColors.cardBackground,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'DEVICE  ICON',
                            style: AppTextStyles.drawerList,
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
                SizedBox(height: MediaQuery.of(context).size.height * 0.05),

                // Delete Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 50),
                  child: OutlinedButton(
                    onPressed: () {
                      _showDeleteDialog(context);
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.delete_forever,
                          size: 40,
                          color: AppColors.delete,
                        ),
                        Text('REMOVE DEVICE', style: AppTextStyles.label),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
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
