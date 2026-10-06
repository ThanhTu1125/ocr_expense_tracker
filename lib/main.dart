import 'package:flutter/material.dart';

import 'screens/dashboard_screen.dart';
import 'screens/review_transaction_screen.dart';
import 'screens/scanner_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OCR Expense Tracker',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      initialRoute: DashboardScreen.routeName,
      routes: {
        DashboardScreen.routeName: (context) => const DashboardScreen(),
        ScannerScreen.routeName: (context) => const ScannerScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == ReviewTransactionScreen.routeName) {
          final imagePath = settings.arguments is String
              ? settings.arguments as String
              : null;
          return MaterialPageRoute(
            builder: (context) => ReviewTransactionScreen(imagePath: imagePath),
            settings: settings,
          );
        }
        return null;
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => const DashboardScreen(),
          settings: settings,
        );
      },
    );
  }
}
