// lib/core/widgets/app_text_fields.dart
import 'package:flutter/material.dart';
import 'package:home_automation/core/widgets/theme.dart';

class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final TextInputType keyboardType;
  final IconData? icon;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: AppTextStyles.label,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.black87),
          prefixIcon:
              icon != null ? Icon(icon, color: AppColors.primary) : null,
          border: OutlineInputBorder(
            borderRadius: AppRadius.textField,
            borderSide: const BorderSide(color: Colors.black),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.textField,
            borderSide: BorderSide(color: Colors.black87),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          floatingLabelStyle: TextStyle(fontSize: 18, color: Colors.black87),
        ),
      ),
    );
  }
}
