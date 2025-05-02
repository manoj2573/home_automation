import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:home_automation/splash/splash_screen.dart';
import 'core/services/mqtt_service.dart'; // ✅ Import MQTT service
import 'core/services/auth_controller.dart';
import 'core/services/device_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Register GetX Controllers
  Get.put(AuthController());
  Get.put(DeviceController());

  try {
    await MqttService.connect(); // ✅ With catch protection
  } catch (e, stack) {
    print('❌ MQTT Connect Error: $e');
    print(stack);
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(home: SplashScreen());
  }
}
