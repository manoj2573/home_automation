import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';
import 'login_page.dart';
import 'device_controller.dart';

class AuthController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Rx<User?> firebaseUser = Rx<User?>(null);

  @override
  void onInit() {
    super.onInit();
    firebaseUser.bindStream(_auth.authStateChanges());
    ever(firebaseUser, _setInitialScreen);
  }

  // ✅ Redirect user based on authentication state
  void _setInitialScreen(User? user) {
    if (user != null) {
      Get.offAll(() => HomeScreen());
    } else {
      Get.offAll(() => LoginPage());
    }
  }

  // ✅ Register User and Create Firestore Document
  void register(String email, String password) async {
    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      String uid = userCredential.user!.uid;

      // ✅ Create user document in Firestore
      await _firestore.collection('users').doc(uid).set({"email": email});

      Get.offAll(() => HomeScreen());
    } catch (e) {
      Get.snackbar("Error", e.toString());
    }
  }

  // ✅ Login User and Load Devices
  void login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      Get.find<DeviceController>().loadDevices(); // ✅ Load correct devices
      Get.offAll(() => HomeScreen());
    } catch (e) {
      Get.snackbar("Login Failed", e.toString());
    }
  }

  // ✅ Logout User and Clear Devices
  void logout() async {
    await _auth.signOut();
    Get.find<DeviceController>().devices.clear(); // ✅ Clear devices on logout
    Get.offAll(() => LoginPage());
  }

  // ✅ Reset Password
  void resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      Get.snackbar("Success", "Password reset email sent!");
    } catch (e) {
      Get.snackbar("Error", e.toString());
    }
  }
}
