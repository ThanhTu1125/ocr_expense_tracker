import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/transaction_controller.dart';
import 'repositories/isar_transaction_repository.dart';
import 'repositories/transaction_repository.dart';
import 'screens/dashboard_screen.dart';
import 'screens/review_transaction_screen.dart';
import 'screens/scanner_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  final TransactionRepository? repository;
  final TransactionController? controller;

  const MyApp({
    super.key,
    this.repository,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveController = controller;

    final app = MaterialApp(
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

    if (effectiveController != null) {
      return ChangeNotifierProvider<TransactionController>.value(
        value: effectiveController,
        child: app,
      );
    }

    return ChangeNotifierProvider<TransactionController>(
      create: (_) => TransactionController(
        repository: repository ?? IsarTransactionRepository(),
      ),
      child: app,
    );
  }
}
