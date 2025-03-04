import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'auth_controller.dart';
import 'signup_page.dart';
import 'forgot_password_page.dart';

class LoginPage extends StatelessWidget {
  final AuthController authController = Get.find();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Login")),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: "Email"),
            ),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(labelText: "Password"),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed:
                  () => authController.login(
                    emailController.text,
                    passwordController.text,
                  ),
              child: Text("Login"),
            ),
            TextButton(
              onPressed: () => Get.to(() => SignupPage()),
              child: Text("Don't have an account? Sign up"),
            ),
            TextButton(
              onPressed: () => Get.to(() => ForgotPasswordPage()),
              child: Text("Forgot Password?"),
            ),
          ],
        ),
      ),
    );
  }
}
