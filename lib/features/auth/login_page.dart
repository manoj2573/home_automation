import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:home_automation/core/widgets/custom_text_fields.dart';
import '../../core/services/auth_controller.dart';
import 'signup_page.dart';
import 'forgot_password_page.dart';
import '../../core/widgets/theme.dart';

class LoginPage extends StatelessWidget {
  final AuthController authController = Get.find();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  LoginPage({super.key});

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
                Text('Log In', style: AppTextStyles.subtitle),
                AppTextField(label: 'Email', controller: emailController),
                AppTextField(controller: passwordController, label: 'Password'),
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

                ElevatedButton.icon(
                  onPressed: () => authController.signInWithGoogle(),
                  icon: Icon(Icons.login, color: Colors.white),
                  label: Text("Sign in with Google"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                  ),
                ),
                TextButton(
                  onPressed: () => Get.to(() => ForgotPasswordPage()),
                  child: Text("Forgot Password?"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
