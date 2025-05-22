import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:home_automation/core/widgets/custom_text_fields.dart';
import 'package:home_automation/core/widgets/theme.dart';
import '../../core/services/auth_controller.dart';

class SignupPage extends StatelessWidget {
  final AuthController authController = Get.find();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  SignupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Center(child: Text("YANTRA", style: AppTextStyles.appBar)),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppGradients.loginBackground),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Image.asset('assets/logo.png', height: 150),
                Text('Sign Up', style: AppTextStyles.subtitle),
                AppTextField(controller: emailController, label: 'Email'),
                AppTextField(controller: passwordController, label: 'Password'),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed:
                      () => authController.register(
                        emailController.text,
                        passwordController.text,
                      ),
                  child: Text("Sign Up"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
