import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:home_automation/core/widgets/theme.dart';
import '../../core/services/mqtt_service.dart';
import '../device/device.dart';

class ScheduleDialogPage extends StatefulWidget {
  final Device device;
  const ScheduleDialogPage({super.key, required this.device});

  @override
  State<ScheduleDialogPage> createState() => _ScheduleDialogPageState();
}

class _ScheduleDialogPageState extends State<ScheduleDialogPage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> schedules = [];
  TimeOfDay? selectedOnTime;
  TimeOfDay? selectedOffTime;
  List<bool> selectedDays = List.filled(7, false);
  String? editingScheduleId;
  TextEditingController scheduleNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  void _loadSchedules() {
    String? uid = auth.currentUser?.uid;

    firestore
        .collection("users")
        .doc(uid)
        .collection("devices")
        .doc(widget.device.deviceId)
        .collection("schedules")
        .snapshots()
        .listen((snapshot) {
          setState(() {
            schedules =
                snapshot.docs.map((doc) {
                  var data = doc.data();
                  data["id"] = doc.id; // Store document ID for editing
                  return data;
                }).toList();
          });
        });
  }

  Future<void> _pickTime(BuildContext context, bool isOnTime) async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        if (isOnTime) {
          selectedOnTime = picked;
        } else {
          selectedOffTime = picked;
        }
      });
    }
  }

  void _showScheduleDialog([Map<String, dynamic>? existingSchedule]) {
    setState(() {
      if (existingSchedule != null) {
        editingScheduleId = existingSchedule["id"];
        scheduleNameController.text = existingSchedule["scheduleName"] ?? "";
        selectedDays = List.generate(
          7,
          (index) => existingSchedule["days"].contains(index),
        );
        selectedOnTime =
            existingSchedule["onTime"] != null
                ? TimeOfDay(
                  hour: int.parse(existingSchedule["onTime"].split(":")[0]),
                  minute: int.parse(existingSchedule["onTime"].split(":")[1]),
                )
                : null;
        selectedOffTime =
            existingSchedule["offTime"] != null
                ? TimeOfDay(
                  hour: int.parse(existingSchedule["offTime"].split(":")[0]),
                  minute: int.parse(existingSchedule["offTime"].split(":")[1]),
                )
                : null;
      } else {
        editingScheduleId = null;
        scheduleNameController.clear();
        selectedDays = List.filled(7, false);
        selectedOnTime = null;
        selectedOffTime = null;
      }
    });

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            existingSchedule != null ? "Edit Schedule" : "Add Schedule",
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: scheduleNameController,
                  decoration: InputDecoration(labelText: "Schedule Name"),
                ),
                Wrap(
                  children: List.generate(7, (index) {
                    return StatefulBuilder(
                      builder: (context, setStateCheckbox) {
                        return CheckboxListTile(
                          title: Text(
                            [
                              "Mon",
                              "Tue",
                              "Wed",
                              "Thu",
                              "Fri",
                              "Sat",
                              "Sun",
                            ][index],
                          ),
                          value: selectedDays[index],
                          onChanged: (bool? value) {
                            setStateCheckbox(() {
                              selectedDays[index] = value ?? false;
                            });
                          },
                        );
                      },
                    );
                  }),
                ),
                GestureDetector(
                  onTap: () => _pickTime(context, true),
                  child: Card(
                    color: Colors.green.shade200,
                    child: ListTile(
                      title: Text("ON Time"),
                      subtitle: Text(
                        selectedOnTime != null
                            ? selectedOnTime!.format(context)
                            : "Select Time",
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _pickTime(context, false),
                  child: Card(
                    color: Colors.red.shade200,
                    child: ListTile(
                      title: Text("OFF Time"),
                      subtitle: Text(
                        selectedOffTime != null
                            ? selectedOffTime!.format(context)
                            : "Select Time",
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                _saveSchedule();
                Navigator.pop(context);
              },
              child: Text("Save"),
            ),
          ],
        );
      },
    );
  }

  void _saveSchedule() {
    String? uid = auth.currentUser?.uid;

    List<int> selectedDaysList = [];
    for (int i = 0; i < selectedDays.length; i++) {
      if (selectedDays[i]) selectedDaysList.add(i);
    }

    if (selectedDaysList.isEmpty ||
        (selectedOnTime == null && selectedOffTime == null)) {
      Get.snackbar("Error", "Select at least one day and one action time.");
      return;
    }

    Map<String, dynamic> scheduleData = {
      "deviceId": widget.device.deviceId,
      "scheduleId": scheduleNameController.text,
      "days": selectedDaysList,
      "onTime":
          selectedOnTime != null
              ? "${selectedOnTime!.hour}:${selectedOnTime!.minute}"
              : null,
      "offTime":
          selectedOffTime != null
              ? "${selectedOffTime!.hour}:${selectedOffTime!.minute}"
              : null,
    };

    if (editingScheduleId != null) {
      firestore
          .collection("users")
          .doc(uid)
          .collection("devices")
          .doc(widget.device.deviceId)
          .collection("schedules")
          .doc(editingScheduleId)
          .update(scheduleData);
    } else {
      firestore
          .collection("users")
          .doc(uid)
          .collection("devices")
          .doc(widget.device.deviceId)
          .collection("schedules")
          .add(scheduleData);
    }

    _publishMQTTSchedule(scheduleData);
  }

  void _publishMQTTSchedule(Map<String, dynamic> schedule) {
    if (MqttService.isConnected) {
      String topic = "${widget.device.deviceId}/device";
      String message = jsonEncode(schedule);

      print("📡 Publishing MQTT Message to $topic: $message");
      MqttService.publish(topic, message);
    } else {
      print("❌ MQTT Not Connected - Cannot Send Message");
      Future.delayed(
        Duration(seconds: 3),
        () => _publishMQTTSchedule(schedule),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          '${widget.device.name} Schedules',
          style: AppTextStyles.title,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 14),
            child: IconButton(
              iconSize: 35,
              onPressed: () => _showScheduleDialog(),
              icon: Icon(Icons.add, color: AppColors.black),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppGradients.loginBackground),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: schedules.length,
                  itemBuilder: (context, index) {
                    final schedule = schedules[index];
                    return Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: Card(
                        child: ListTile(
                          tileColor: AppColors.tileBackground,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          title: Text(
                            schedule['scheduleId'] ?? "Unnamed Schedule",
                          ),

                          subtitle: Text(
                            "On: ${schedule["onTime"] ?? "-"} Off: ${schedule["offTime"] ?? "-"}",
                          ),
                          onTap: () => _showScheduleDialog(schedule),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
