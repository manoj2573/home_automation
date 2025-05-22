import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:home_automation/core/widgets/theme.dart';
import 'package:home_automation/features/schedule/schedule_dialog.dart';
import '../../core/services/device_controller.dart';
import '../../core/services/mqtt_service.dart';
import 'device.dart';
import 'settings_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DeviceControlPage extends StatefulWidget {
  final Device device;

  const DeviceControlPage({super.key, required this.device});

  @override
  State<DeviceControlPage> createState() => _DeviceControlPageState();
}

class _DeviceControlPageState extends State<DeviceControlPage> {
  double _currentValue = 0;
  Color _currentColor = Colors.white;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;
  final bool _isDragging = false;

  Future? _loadFuture;
  bool _isDataLoaded = false;
  String? scheduleMessage;

  DateTime? selectedDateTime;
  String selectedAction = "On";

  @override
  void initState() {
    super.initState();
    _listenToDeviceUpdates();
    _subscribeToMqtt();
  }

  void _subscribeToMqtt() {
    String topic = "${widget.device.deviceId}/mobile"; // ✅ Correct topic

    if (MqttService.isConnected) {
      MqttService.subscribe(topic);
      print("✅ Subscribed to MQTT topic: $topic in DeviceControlPage");
    } else {
      print("⚠️ MQTT Not Connected - Retrying subscription...");
      Future.delayed(Duration(seconds: 3), _subscribeToMqtt);
    }

    MqttService.setMessageHandler(_onMqttMessageReceived);
  }

  void _listenToDeviceUpdates() {
    String? uid = auth.currentUser?.uid;

    firestore
        .collection("users")
        .doc(uid)
        .collection("devices")
        .doc(widget.device.deviceId)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists && snapshot.data() != null) {
            final data = snapshot.data() as Map<String, dynamic>;

            setState(() {
              widget.device.state.value = data["state"];
              _currentValue = data["sliderValue"]?.toDouble() ?? 0;
              _currentColor = _hexToColor(data["color"] ?? "#FFFFFF");
              _isDataLoaded = true;
            });
          }
        });
  }

  void _onMqttMessageReceived(String topic, String message) {
    print("📩 Received MQTT Message: Topic: $topic, Message: $message");

    try {
      Map<String, dynamic> data = jsonDecode(message);

      if (!data.containsKey("deviceId") || !data.containsKey("state")) {
        print("⚠️ Invalid message format. Ignoring...");
        return;
      }

      String deviceId = data["deviceId"];
      bool newState = data["state"];
      double? newSliderValue =
          data.containsKey("sliderValue")
              ? data["sliderValue"]?.toDouble()
              : null;
      String? newColor = data["color"];

      // ✅ Find the device in the device list
      DeviceController deviceController = Get.find();
      int index = deviceController.devices.indexWhere(
        (d) => d.deviceId == deviceId,
      );

      if (index == -1) {
        print("⚠️ Device not found: $deviceId. Skipping update.");
        return;
      }

      Device device = deviceController.devices[index];

      // ✅ Update the UI with new state, slider value, and color
      device.state.value = newState;
      if (newSliderValue != null && device.sliderValue != null) {
        device.sliderValue!.value = newSliderValue;
      }
      if (newColor != null) {
        device.color = newColor;
      }

      deviceController.devices.refresh();

      print(
        "🔄 UI Updated for ${device.name}: State = $newState, Slider = $newSliderValue, Color = $newColor",
      );

      // ✅ Update Firestore
      String? uid = FirebaseAuth.instance.currentUser?.uid;
      Map<String, dynamic> updateData = {"state": newState};
      if (newSliderValue != null) updateData["sliderValue"] = newSliderValue;
      if (newColor != null) updateData["color"] = newColor;

      FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .collection("devices")
          .doc(deviceId)
          .update(updateData)
          .then((_) => print("✅ Firestore Updated for $deviceId"))
          .catchError((error) => print("❌ Firestore Update Failed: $error"));
      _updateFirestore;
    } catch (e) {
      print("❌ Error decoding MQTT message: $e");
    }
  }

  void _updateFirestore(Map<String, dynamic> data) async {
    String? uid = auth.currentUser?.uid;

    try {
      await firestore
          .collection("users")
          .doc(uid)
          .collection("devices")
          .doc(widget.device.deviceId)
          .update({
            "state": data["state"],
            "sliderValue": data["sliderValue"]?.toDouble() ?? _currentValue,
            "color": data["color"] ?? _colorToHex(_currentColor),
          });

      print("✅ Firestore Updated for ${widget.device.name}");
    } catch (e) {
      print("❌ Error updating Firestore: $e");
    }
  }

  void _saveSelectedColor(Color color) async {
    setState(() {
      _currentColor = color; // ✅ Update UI
    });

    String? uid = FirebaseAuth.instance.currentUser?.uid;

    String hexColor = _colorToHex(color); // ✅ Convert color to HEX format

    // ✅ Update Firestore
    await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("devices")
        .doc(widget.device.deviceId)
        .update({"color": hexColor});

    // ✅ Publish MQTT message
    _publishMQTTMessage();
  }

  void _publishMQTTMessage() {
    String topic = "${widget.device.deviceId}/device";
    Map<String, dynamic> payload = {
      'deviceId': widget.device.deviceId,
      'deviceName': widget.device.name,
      'deviceType': widget.device.type,
      'state': widget.device.state.value,

      'sliderValue': _currentValue,
      'color': _colorToHex(_currentColor),
      'registrationId': widget.device.registrationId,
    };

    if (MqttService.isConnected) {
      print("📤 Publishing to $topic: $payload");
      MqttService.publish(topic, jsonEncode(payload));

      setState(() {
        _isDataLoaded = false;
      });

      print("🔄 Waiting for response from ${widget.device.deviceId}/mobile...");
    } else {
      print("⚠️ MQTT Not Connected - Retrying...");
      Future.delayed(Duration(seconds: 3), _publishMQTTMessage);
    }
  }

  void _onSliderChanged(double value) {
    setState(() {
      _currentValue = value;

      if (value == 0) {
        widget.device.state.value = false;
      } else {
        widget.device.state.value = true;
      }

      // ✅ ALSO UPDATE device.sliderValue!
      widget.device.sliderValue?.value = value;
    });

    int intSliderValue = _currentValue.toInt();

    Map<String, dynamic> payload = {
      "deviceId": widget.device.deviceId,
      "deviceName": widget.device.name,
      "deviceType": widget.device.type,
      "state": widget.device.state.value,
      "sliderValue": intSliderValue,
      "color": _colorToHex(_currentColor),
      "registrationId": widget.device.registrationId,
    };

    if (MqttService.isConnected) {
      MqttService.publish(
        "${widget.device.deviceId}/device",
        jsonEncode(payload),
      );
      print("📡 Published to ${widget.device.deviceId}/device: $payload");
    } else {
      print("❌ MQTT is not connected. Cannot send message.");
    }

    String? uid = auth.currentUser?.uid;
    FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("devices")
        .doc(widget.device.deviceId)
        .update({
          "state": widget.device.state.value,
          "sliderValue": _currentValue,
        });
  }

  String _colorToHex(Color color) {
    return "#${color.value.toRadixString(16).substring(2).toUpperCase()}";
  }

  Color _hexToColor(String hex) {
    return Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);
  }

  @override
  Widget build(BuildContext context) {
    final DeviceController deviceController = Get.find();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          '${widget.device.name} Controls',
          style: AppTextStyles.title,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        height: MediaQuery.of(context).size.height * 1,
        decoration: BoxDecoration(gradient: AppGradients.loginBackground),
        child: SafeArea(
          child: FutureBuilder(
            future: _loadFuture,
            builder: (context, snapshot) {
              return _buildDeviceControlUI(deviceController);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceControlUI(DeviceController deviceController) {
    return Padding(
      padding: AppPadding.page,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '${widget.device.name} is ${widget.device.state.value ? 'On' : 'Off'}',
              style: AppTextStyles.subtitle,
            ),
            if (widget.device.type == "On/Off")
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () {
                      // ✅ Toggle device state & send MQTT message
                      deviceController.toggleDeviceState(widget.device);
                    },
                    child: Card(
                      color:
                          widget.device.state.value
                              ? AppColors.success
                              : AppColors.cardBackground,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.card,
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 30,
                              horizontal: 20,
                            ),
                            child: Image.asset(
                              widget.device.iconPath,
                              width: 220,
                              height: 220,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 70),
                ],
              ),

            if (widget.device.type == 'Dimmable light' ||
                widget.device.type == 'Fan' ||
                widget.device.type == 'Curtain') ...[
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () {
                      // ✅ Toggle device state & send MQTT message
                      deviceController.toggleDeviceState(widget.device);
                    },
                    child: Card(
                      color:
                          widget.device.state.value
                              ? AppColors.success
                              : AppColors.cardBackground,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.card,
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 30,
                              horizontal: 20,
                            ),
                            child: Image.asset(
                              widget.device.iconPath,
                              width: 220,
                              height: 220,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    widget.device.type == 'Fan'
                        ? 'Adjust Speed'
                        : widget.device.type == 'Curtain'
                        ? 'Adjust Position'
                        : 'Adjust Brightness',
                  ),
                  Slider(
                    value: _currentValue,
                    min: 0,
                    max: 90,
                    divisions: 90,
                    label: "${_currentValue.toInt()}",
                    onChanged: _onSliderChanged, // ✅ Pass function directly
                  ),
                ],
              ),
            ],

            if (widget.device.type == 'RGB') ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Text('Pick Color', style: AppTextStyles.label),
                  Switch(
                    activeTrackColor: AppColors.success,
                    value: widget.device.state.value,
                    onChanged: (value) {
                      final deviceController = Get.find<DeviceController>();
                      deviceController.toggleDeviceState(
                        widget.device,
                      ); // ✅ Call Firestore update
                      _publishMQTTMessage();
                    },
                  ),
                ],
              ),
              SizedBox(height: 10),
              ColorPicker(
                paletteType: PaletteType.hueWheel,
                colorPickerWidth: 220,
                pickerColor: _currentColor,
                onColorChanged: (color) {
                  _saveSelectedColor(color); // ✅ Save color when changed
                },
              ),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                InkWell(
                  onTap: () {
                    Get.to(() => SettingsPage(device: widget.device));
                  },

                  child: Card(
                    margin: EdgeInsets.all(10),
                    elevation: 4,
                    color: AppColors.cardBackground,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
                    child: Column(
                      children: [
                        Icon(
                          Icons.settings,
                          size: 80,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    Get.to(() => ScheduleDialogPage(device: widget.device));
                  },

                  child: Card(
                    margin: EdgeInsets.all(10),
                    elevation: 4,
                    color: AppColors.cardBackground,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
                    child: Column(
                      children: [
                        Icon(
                          Icons.calendar_month,
                          size: 80,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
