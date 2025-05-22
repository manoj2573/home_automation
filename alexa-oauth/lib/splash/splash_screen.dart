import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:home_automation/dashboard/dashboard.dart';
import 'package:home_automation/features/auth/login_page.dart';
import 'package:shimmer/shimmer.dart';
import '../core/services/auth_controller.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // Simulate a short loading time and let AuthController handle navigation
    Future.delayed(const Duration(seconds: 2), () {
      final authController = Get.find<AuthController>();
      final user = authController.firebaseUser.value;

      if (user != null) {
        Get.offAll(() => const MyDashboard());
      } else {
        Get.offAll(() => LoginPage());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.white,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFE29E), Color(0xFFDE7205)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset('assets/logo.png', width: 160, height: 160),
              Positioned.fill(
                child: Shimmer.fromColors(
                  baseColor: Colors.transparent,
                  highlightColor: Colors.white.withOpacity(0.5),
                  period: const Duration(seconds: 2),
                  child: Container(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
