// lib/core/theme/theme.dart
import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color.fromARGB(255, 216, 129, 41);
  static const secondary = Color(0xFFFFE29E);
  static const success = Color.fromARGB(255, 165, 214, 167);
  static const error = Color(0xFFFF8A80);
  static const cardBackground = Colors.white;
  static const accentOrange = Color(0xFFD88129);
  static const background = Color(0xFFF6F6F6);
  static const drawerBackgroundColor = Color.fromARGB(255, 240, 200, 126);
  static const devider = Color.fromARGB(255, 120, 144, 156);
  static const delete = Color.fromARGB(255, 247, 92, 97);
  static const black = Colors.black;
  static const tileBackground = Color.fromARGB(255, 255, 236, 179);
}

class AppTextStyles {
  static const title = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w400,
    color: Colors.black,
    letterSpacing: 1,
  );

  static const subtitle = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w400,
    color: Colors.black87,
  );

  static const appBar = TextStyle(
    letterSpacing: 2.5,
    fontSize: 25,
    fontWeight: FontWeight.w400,
    color: Color.fromARGB(255, 38, 50, 56),
  );
  static const drawerTitle = TextStyle(
    fontSize: 20,
    color: Color.fromARGB(255, 38, 50, 56),
    letterSpacing: 2,
  );
  static const drawerSubTitle = TextStyle(
    fontSize: 12,
    color: Color.fromARGB(255, 38, 50, 56),
    letterSpacing: 2,
  );
  static const drawerList = TextStyle(
    fontWeight: FontWeight.w400,
    fontSize: 18,
    color: Color.fromARGB(255, 38, 50, 56),
  );
  static const label = TextStyle(fontSize: 15, color: Colors.black);
}

class AppRadius {
  static const card = BorderRadius.all(Radius.circular(16));
  static const button = BorderRadius.all(Radius.circular(12));
  static const textField = BorderRadius.all(Radius.circular(10));
}

class AppPadding {
  static const page = EdgeInsets.all(16);
  static const small = EdgeInsets.all(8);
  static const medium = EdgeInsets.all(12);
  static const large = EdgeInsets.all(20);
}

class AppGradients {
  static const loginBackground = LinearGradient(
    colors: [AppColors.secondary, AppColors.primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
