import 'package:flutter/material.dart';

import 'scanner_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  static const routeName = '/';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, ScannerScreen.routeName);
        },
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}

