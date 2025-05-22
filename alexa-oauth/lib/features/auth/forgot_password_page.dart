import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/services/auth_controller.dart';

class ForgotPasswordPage extends StatelessWidget {
  final AuthController authController = Get.find();
  final TextEditingController emailController = TextEditingController();

  ForgotPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Forgot Password")),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: "Enter your email"),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed:
                  () => authController.resetPassword(emailController.text),
              child: Text("Reset Password"),
            ),
          ],
        ),
      ),
    );
  }
}
