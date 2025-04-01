// scenes_page.dart
import 'package:flutter/material.dart';

class ScenesPage extends StatelessWidget {
  const ScenesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scenes'),
        backgroundColor: const Color.fromARGB(255, 240, 200, 126),
      ),
      body: const Center(child: Text('Scenes Page - Coming Soon!')),
    );
  }
}
