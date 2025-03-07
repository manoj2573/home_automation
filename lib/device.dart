import 'package:get/get.dart';

class Device {
  String name;
  String type;
  RxBool state;
  String pin;
  String? pin2;
  String iconPath;
  RxDouble? sliderValue;
  String color; // ✅ Ensure this exists in the class

  Device({
    required this.name,
    required this.type,
    required this.state,
    required this.pin,
    this.pin2,
    required this.iconPath,
    this.sliderValue,
    this.color = "#FFFFFF", // ✅ Default color is white
  });
}
