import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'mqtt_service.dart'; // ✅ Import MQTT service
import 'auth_controller.dart';
import 'device_controller.dart';
import 'login_page.dart';
import 'home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  Get.put(AuthController());
  Get.put(DeviceController());

  await MqttService.connect(); // ✅ Ensure MQTT connects before UI loads

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      home:
          Get.find<AuthController>().firebaseUser.value != null
              ? HomeScreen()
              : LoginPage(),
    );
  }
}
