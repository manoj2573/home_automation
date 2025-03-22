import 'dart:convert'; // ✅ Import for jsonEncode & jsonDecode
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'device_controller.dart';
import 'mqtt_service.dart';
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
  bool _isDragging = false;

  Future? _loadFuture;
  bool _isDataLoaded = false;
  String? scheduleMessage;

  DateTime? selectedDateTime;
  String selectedAction = "On"; // ✅ Default to "On"

  @override
  void initState() {
    super.initState();
    _listenToDeviceUpdates(); // ✅ Start Firestore listener
    _subscribeToMqtt(); // ✅ Start MQTT listener
  }

  void _listenToDeviceUpdates() {
    String? uid = auth.currentUser?.uid;
    if (uid == null) return;

    firestore
        .collection("users")
        .doc(uid)
        .collection("devices")
        .doc(widget.device.name)
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

  // ✅ Subscribe to MQTT topic when page opens
  void _subscribeToMqtt() {
    String topic = "${widget.device.registrationId}/mobile";

    if (MqttService.isConnected) {
      MqttService.subscribe(topic);
      print("✅ Subscribed to MQTT topic: $topic in DeviceControlPage");
    } else {
      print("⚠️ MQTT Not Connected - Retrying subscription...");
      Future.delayed(Duration(seconds: 3), _subscribeToMqtt);
    }

    MqttService.setMessageHandler(_onMqttMessageReceived);
  }

  // ✅ Handle MQTT messages from registrationId/mobile
  void _onMqttMessageReceived(String topic, String message) {
    print(
      "📩 Received MQTT Message in DeviceControlPage: Topic: $topic, Message: $message",
    );

    try {
      Map<String, dynamic> data = jsonDecode(message);
      String registrationId = topic.split('/')[0]; // Extract registrationId
      String? deviceName = data["deviceName"]; // Extract deviceName

      if (deviceName == null || deviceName != widget.device.name) {
        print("⚠️ MQTT Message Ignored: No 'deviceName' or mismatch");
        return;
      }

      // ✅ Extract brightness value (same for all devices)
      double? sliderValue = data["sliderValue"]?.toDouble();

      setState(() {
        widget.device.state.value = data["state"];

        // ✅ Only update `_currentValue` if the user is NOT dragging the slider
        if (!_isDragging && sliderValue != null) {
          _currentValue = sliderValue;
        }

        _currentColor = _hexToColor(
          data["color"] ?? _colorToHex(_currentColor),
        );
      });

      print(
        "🔄 UI Updated in DeviceControlPage: ${widget.device.name}, Brightness: $_currentValue",
      );
    } catch (e) {
      print("❌ Error decoding MQTT message in DeviceControlPage: $e");
    }
  }

  void _saveSliderValue(double value) async {
    String? uid = auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await firestore
          .collection("users")
          .doc(uid)
          .collection("devices")
          .doc(widget.device.name)
          .update({
            "sliderValue": value, // ✅ Save slider value
          });

      print("✅ Firestore Updated: ${widget.device.name} sliderValue = $value");

      _publishMQTTMessage();
    } catch (e) {
      print("❌ Error updating Firestore sliderValue: $e");
    }
  }

  void _publishMQTTMessage() {
    String topic = "${widget.device.registrationId}/device";
    Map<String, dynamic> payload = {
      'deviceName': widget.device.name,
      'deviceType': widget.device.type,
      'state': widget.device.state.value,
      'pin1No': widget.device.pin,
      'pin2No': widget.device.pin2 ?? '',
      'sliderValue': _currentValue, // Ensure this is consistent
      'color': _colorToHex(_currentColor),
    };

    if (MqttService.isConnected) {
      print("📤 Publishing to $topic: $payload");
      MqttService.publish(topic, jsonEncode(payload));

      // ✅ Temporarily disable UI updates until response is received
      setState(() {
        _isDataLoaded = false; // Disable UI updates
      });

      print(
        "🔄 Waiting for response from ${widget.device.registrationId}/mobile...",
      );
    } else {
      print("⚠️ MQTT Not Connected - Retrying...");
      Future.delayed(Duration(seconds: 3), _publishMQTTMessage);
    }
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
      appBar: AppBar(
        title: Text('${widget.device.name} Controls'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Get.to(() => SettingsPage(device: widget.device));
            },
          ),
        ],
      ),
      body: FutureBuilder(
        future: _loadFuture,
        builder: (context, snapshot) {
          return _buildDeviceControlUI(deviceController);
        },
      ),
    );
  }

  Widget _buildDeviceControlUI(DeviceController deviceController) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${widget.device.name} is ${widget.device.state.value ? 'On' : 'Off'}',
                ),
                Spacer(),
                Obx(
                  () => Switch(
                    value: widget.device.state.value,
                    onChanged: (value) {
                      final deviceController = Get.find<DeviceController>();
                      deviceController.toggleDeviceState(
                        widget.device,
                      ); // ✅ Call Firestore update
                      _publishMQTTMessage();
                    },
                  ),
                ),
              ],
            ),

            // ✅ Sliders for Fan, Curtain, and Dimmable Light
            if (widget.device.type == 'Dimmable light' ||
                widget.device.type == 'Fan' ||
                widget.device.type == 'Curtain') ...[
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
                max: 100,
                divisions: 100,
                label: "sliderValue: ${_currentValue.toInt()}",
                onChangeStart: (value) {
                  _isDragging = true; // ✅ Mark as dragging
                },
                onChanged: (value) {
                  setState(() {
                    _currentValue = value;
                  });
                },
                onChangeEnd: (value) {
                  _isDragging = false; // ✅ Mark as not dragging
                  _saveSliderValue(
                    value,
                  ); // ✅ Save value only after user stops dragging
                },
              ),
            ],

            // ✅ RGB Color Picker
            if (widget.device.type == 'RGB') ...[
              Text('Pick Color'),
              SizedBox(height: 10),
              ColorPicker(
                pickerColor: _currentColor,
                onColorChanged: (color) {
                  setState(() {
                    _currentColor = color;
                  });
                  _publishMQTTMessage();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
