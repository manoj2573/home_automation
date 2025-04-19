import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'device.dart';
import 'device_controller.dart';
import 'mqtt_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ScenesPage extends StatefulWidget {
  const ScenesPage({super.key});

  @override
  State<ScenesPage> createState() => _ScenesPageState();
}

class _ScenesPageState extends State<ScenesPage> {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final DeviceController deviceController = Get.find();

  List<Map<String, dynamic>> scenes = [];

  @override
  void initState() {
    super.initState();
    _loadScenes();
  }

  void _loadScenes() {
    print("📡 Listening for scenes...");
    String? uid = auth.currentUser?.uid;
    if (uid == null) return;

    firestore
        .collection("users")
        .doc(uid)
        .collection("scenes")
        .snapshots()
        .listen((snapshot) {
          setState(() {
            scenes =
                snapshot.docs.map((doc) {
                  final data = doc.data();
                  return {
                    "id": doc.id,
                    "sceneName": data["sceneName"] ?? "Unnamed Scene",
                    "devices":
                        (data["devices"] is List)
                            ? List<Map<String, dynamic>>.from(data["devices"])
                            : [],
                    "active": false,
                  };
                }).toList();
          });

          print("✅ Loaded ${scenes.length} scenes from Firestore");
        });
  }

  void _toggleScene(Map<String, dynamic> scene, bool activate) async {
    List<Map<String, dynamic>> devices = List<Map<String, dynamic>>.from(
      scene["devices"],
    );

    for (var deviceData in devices) {
      Device? device = deviceController.devices.firstWhereOrNull(
        (d) => d.deviceId == deviceData["deviceId"],
      );
      if (device != null) {
        // Update device state
        device.state.value = deviceData["state"] ?? false;
        device.sliderValue?.value = deviceData["sliderValue"]?.toDouble() ?? 0;
        device.color = deviceData["color"] ?? device.color;

        deviceController.devices.refresh();

        Map<String, dynamic> payload = {
          "deviceId": device.deviceId,
          "state": device.state.value,
          "sliderValue": device.sliderValue?.value ?? 0,
          "color": device.color,
          "registrationId": device.registrationId,
          "roomName": device.roomName,
        };

        if (MqttService.isConnected) {
          MqttService.publish("${device.deviceId}/device", jsonEncode(payload));
        }

        // Update Firestore
        String? uid = auth.currentUser?.uid;
        if (uid != null) {
          await firestore
              .collection("users")
              .doc(uid)
              .collection("devices")
              .doc(device.deviceId)
              .update({
                "state": device.state.value,
                "sliderValue": device.sliderValue?.value ?? 0,
                "color": device.color,
              });
        }
      }
    }

    setState(() {
      scene["active"] = activate;
    });
  }

  void _showAddSceneDialog() {
    TextEditingController sceneNameController = TextEditingController();
    Map<String, Map<String, dynamic>> selectedDevices = {};

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Create Scene"),
            content: StatefulBuilder(
              builder: (context, setState) {
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      TextField(
                        controller: sceneNameController,
                        decoration: const InputDecoration(
                          labelText: "Scene Name",
                        ),
                      ),
                      const SizedBox(height: 10),
                      Column(
                        children:
                            deviceController.devices.map((device) {
                              bool isSelected = selectedDevices.containsKey(
                                device.deviceId,
                              );
                              return Column(
                                children: [
                                  CheckboxListTile(
                                    title: Text(device.name),
                                    value: isSelected,
                                    onChanged: (value) {
                                      setState(() {
                                        if (value == true) {
                                          selectedDevices[device.deviceId] = {
                                            "deviceId": device.deviceId,
                                            "type": device.type,
                                            "state": device.state.value,
                                            "sliderValue":
                                                device.sliderValue?.value ??
                                                0.0,
                                            "color": device.color,
                                          };
                                        } else {
                                          selectedDevices.remove(
                                            device.deviceId,
                                          );
                                        }
                                      });
                                    },
                                  ),
                                  if (isSelected)
                                    _buildDeviceControls(
                                      device,
                                      selectedDevices[device.deviceId]!,
                                      setState,
                                    ),
                                ],
                              );
                            }).toList(),
                      ),
                    ],
                  ),
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () {
                  _saveScene(
                    sceneNameController.text.trim(),
                    selectedDevices.values.toList(),
                  );
                  Navigator.pop(context);
                },
                child: const Text("Save"),
              ),
            ],
          ),
    );
  }

  void _showEditSceneDialog(Map<String, dynamic> scene) {
    TextEditingController sceneNameController = TextEditingController(
      text: scene["sceneName"],
    );
    Map<String, Map<String, dynamic>> selectedDevices = {
      for (var d in scene["devices"])
        d["deviceId"]: Map<String, dynamic>.from(d),
    };

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Edit Scene"),
            content: StatefulBuilder(
              builder: (context, setState) {
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      TextField(
                        controller: sceneNameController,
                        decoration: const InputDecoration(
                          labelText: "Scene Name",
                        ),
                      ),
                      const SizedBox(height: 10),
                      Column(
                        children:
                            deviceController.devices.map((device) {
                              bool isSelected = selectedDevices.containsKey(
                                device.deviceId,
                              );
                              return Column(
                                children: [
                                  CheckboxListTile(
                                    title: Text(device.name),
                                    value: isSelected,
                                    onChanged: (value) {
                                      setState(() {
                                        if (value == true) {
                                          selectedDevices[device.deviceId] = {
                                            "deviceId": device.deviceId,
                                            "type": device.type,
                                            "state": device.state.value,
                                            "sliderValue":
                                                device.sliderValue?.value ??
                                                0.0,
                                            "color": device.color,
                                          };
                                        } else {
                                          selectedDevices.remove(
                                            device.deviceId,
                                          );
                                        }
                                      });
                                    },
                                  ),
                                  if (isSelected)
                                    _buildDeviceControls(
                                      device,
                                      selectedDevices[device.deviceId]!,
                                      setState,
                                    ),
                                ],
                              );
                            }).toList(),
                      ),
                    ],
                  ),
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () {
                  _updateScene(
                    scene["id"],
                    sceneNameController.text.trim(),
                    selectedDevices.values.toList(),
                  );
                  Navigator.pop(context);
                },
                child: const Text("Update"),
              ),
            ],
          ),
    );
  }

  void _updateScene(
    String sceneId,
    String sceneName,
    List<Map<String, dynamic>> devices,
  ) async {
    if (sceneName.isEmpty || devices.isEmpty) {
      Get.snackbar("Error", "Please enter a scene name and select devices");
      return;
    }

    String? uid = auth.currentUser?.uid;
    if (uid == null) return;

    await firestore
        .collection("users")
        .doc(uid)
        .collection("scenes")
        .doc(sceneId)
        .update({"sceneName": sceneName, "devices": devices});

    _loadScenes();
    Get.snackbar("Success", "Scene updated");
  }

  Widget _buildDeviceControls(
    Device device,
    Map<String, dynamic> data,
    void Function(void Function()) setState,
  ) {
    return Column(
      children: [
        Row(
          children: [
            const Text("Action: "),
            Switch(
              value: data["state"],
              onChanged: (val) => setState(() => data["state"] = val),
            ),
          ],
        ),
        if (["Fan", "Curtain", "Dimmable light"].contains(device.type))
          Slider(
            value: data["sliderValue"],
            onChanged: (val) => setState(() => data["sliderValue"] = val),
            min: 0,
            max: 100,
            divisions: 100,
            label: (data["sliderValue"]).toInt().toString(),
          ),
        if (device.type == "RGB")
          TextField(
            decoration: const InputDecoration(labelText: "RGB Hex (#FFFFFF)"),
            controller: TextEditingController(text: data["color"]),
            onChanged: (val) => data["color"] = val,
          ),
        const Divider(),
      ],
    );
  }

  void _saveScene(String sceneName, List<Map<String, dynamic>> devices) async {
    if (sceneName.isEmpty || devices.isEmpty) {
      Get.snackbar("Error", "Please enter a scene name and select devices");
      return;
    }

    String? uid = auth.currentUser?.uid;
    if (uid == null) return;

    await firestore.collection("users").doc(uid).collection("scenes").add({
      "sceneName": sceneName,
      "devices": devices,
    });
    _loadScenes();
    Get.snackbar("Success", "Scene created");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Scenes"),
        backgroundColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSceneDialog,
        child: const Icon(Icons.add),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFE29E), Color.fromARGB(255, 222, 114, 5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child:
            scenes.isEmpty
                ? const Center(child: Text("No scenes found"))
                : ListView.builder(
                  itemCount: scenes.length,
                  itemBuilder: (context, index) {
                    final scene = scenes[index];
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: InkWell(
                        onTap: () {
                          _toggleScene(scene, !scene["active"]);
                        },
                        child: ListTile(
                          tileColor: Colors.amber[100],
                          title: Text(scene["sceneName"]),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showEditSceneDialog(scene),
                          ),
                        ),
                      ),
                    );
                  },
                ),
      ),
    );
  }
}
