import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'auth_controller.dart';
import 'signup_page.dart';
import 'forgot_password_page.dart';

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
        title: Center(
          child: Text(
            "YANTRA",
            style: TextStyle(
              letterSpacing: 3,
              fontSize: 25,
              fontWeight: FontWeight.w600,
              color: Colors.blueGrey[900],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFE29E), Color.fromARGB(255, 222, 114, 5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Image.asset('assets/logo.png', height: 150),
                Text('Log In', style: TextStyle(fontSize: 20)),
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
