import 'package:get/get.dart';

class Device {
  String deviceId;
  String name;
  String type;
  RxBool state;
  String iconPath;
  RxDouble? sliderValue;
  String color;
  String registrationId; // ✅ Added Registration ID
  String roomName;

  Device({
    required this.deviceId,
    required this.name,
    required this.type,
    required this.state,
    required this.iconPath,
    this.sliderValue,
    this.color = "#FFFFFF",
    required this.registrationId, // ✅ Make it required
    required this.roomName,
  });
}
