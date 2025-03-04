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

  Future? _loadFuture;
  bool _isDataLoaded = false;
  String? scheduleMessage;

  DateTime? selectedDateTime;
  String selectedAction = "On"; // ✅ Default to "On"

  @override
  @override
  void initState() {
    super.initState();
    _listenToDeviceUpdates(); // ✅ Start listening to Firestore changes
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
              _isDataLoaded = true; // ✅ Ensures UI updates
            });
          }
        });
  }

  void _saveSliderValue(double value) async {
    String? uid = auth.currentUser?.uid;
    if (uid == null) return;

    await firestore
        .collection("users")
        .doc(uid)
        .collection("devices")
        .doc(widget.device.name)
        .update({"sliderValue": value});

    _publishMQTTMessage();
  }

  void _saveSelectedColor(Color color) async {
    String? uid = auth.currentUser?.uid;
    if (uid == null) return;

    String hexColor = _colorToHex(color);
    await firestore
        .collection("users")
        .doc(uid)
        .collection("devices")
        .doc(widget.device.name)
        .update({"color": hexColor});

    _publishMQTTMessage();
  }

  void _publishMQTTMessage() {
    Map<String, dynamic> payload = {
      'deviceName': widget.device.name,
      'deviceType': widget.device.type,
      'state': widget.device.state.value,
      'pin1No': widget.device.pin,
      'pin2No': widget.device.pin2 ?? '',
      'brightness': _currentValue,
      'color': _colorToHex(_currentColor),
    };

    if (MqttService.isConnected) {
      MqttService.publishMessage(payload);
      print("📡 MQTT Message Sent: $payload"); // ✅ Debugging log
    } else {
      print("⚠️ MQTT Not Connected - Retrying...");
      Future.delayed(Duration(seconds: 3), _publishMQTTMessage); // ✅ Retry
    }
  }

  // ✅ Pick Date & Time
  Future<void> _pickDateTime() async {
    DateTime now = DateTime.now();

    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(Duration(days: 365)),
    );

    if (pickedDate == null) return;

    TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (pickedTime == null) return;

    setState(() {
      selectedDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  // ✅ Save Schedule in Firestore & Show Confirmation
  Future<void> _saveSchedule() async {
    if (selectedDateTime == null) {
      setState(() {
        scheduleMessage = "⚠️ Please select a date and time.";
      });
      return;
    }

    String? uid = auth.currentUser?.uid;
    if (uid == null) {
      setState(() {
        scheduleMessage = "⚠️ User not logged in.";
      });
      return;
    }

    try {
      await firestore
          .collection("users")
          .doc(uid)
          .collection("devices")
          .doc(widget.device.name)
          .collection("schedules")
          .doc(
            selectedDateTime!.millisecondsSinceEpoch.toString(),
          ) // ✅ Unique ID
          .set({
            "dateTime": selectedDateTime!.toIso8601String(),
            "action": selectedAction,
          });

      setState(() {
        scheduleMessage =
            "✅ Schedule Set: ${DateFormat("yyyy-MM-dd HH:mm").format(selectedDateTime!)} - $selectedAction";
      });

      print("🔥 Schedule successfully added to Firestore!");
    } catch (e) {
      print("❌ Error adding schedule: $e");
      setState(() {
        scheduleMessage = "❌ Error saving schedule.";
      });
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
          if (!_isDataLoaded) {
            return Center(
              child: Text("Loading device data..."),
            ); // ✅ Shows fallback text
          }

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
                      deviceController.toggleDeviceState(widget.device);
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
                onChanged: (value) {
                  setState(() {
                    _currentValue = value;
                  });

                  _saveSliderValue(value);
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

                  _saveSelectedColor(color);
                },
              ),
            ],

            SizedBox(height: 20),
            Text(
              "📅 Schedule Device",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),

            ElevatedButton(
              onPressed: _pickDateTime,
              child: Text(
                selectedDateTime == null
                    ? "Select Date & Time"
                    : DateFormat("yyyy-MM-dd HH:mm").format(selectedDateTime!),
              ),
            ),

            DropdownButton<String>(
              value: selectedAction,
              items:
                  ["On", "Off"].map((String action) {
                    return DropdownMenuItem<String>(
                      value: action,
                      child: Text(action),
                    );
                  }).toList(),
              onChanged: (newValue) {
                setState(() {
                  selectedAction = newValue!;
                });
              },
            ),

            ElevatedButton(
              onPressed: _saveSchedule,
              child: Text("Save Schedule"),
            ),

            if (scheduleMessage != null)
              Text(scheduleMessage!, style: TextStyle(color: Colors.green)),
          ],
        ),
      ),
    );
  }
}
