import 'package:get/get.dart';

class Device {
  String deviceId;
  String name;
  String type;
  RxBool state;
  String pin;
  String? pin2;
  String iconPath;
  RxDouble? sliderValue;
  String color;
  String registrationId; // ✅ Added Registration ID

  Device({
    required this.deviceId,
    required this.name,
    required this.type,
    required this.state,
    required this.pin,
    this.pin2,
    required this.iconPath,
    this.sliderValue,
    this.color = "#FFFFFF",
    required this.registrationId, // ✅ Make it required
  });
}
