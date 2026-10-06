import 'package:flutter/material.dart';

class ReviewTransactionScreen extends StatelessWidget {
  const ReviewTransactionScreen({
    super.key,
    this.imagePath,
  });

  static const routeName = '/review';

  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Transaction'),
      ),
      body: imagePath != null ? Center(child: Text(imagePath!)) : null,
    );
  }
}

