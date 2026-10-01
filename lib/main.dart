import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OCR Expense Tracker',
      home: Scaffold(
        appBar: AppBar(title: const Text('OCR Expense Tracker')),
        body: const Center(child: Text('Project initialized')),
      ),
    );
  }
}
