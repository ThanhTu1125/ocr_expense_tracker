import 'package:isar_community/isar.dart';

part 'transaction.g.dart';

enum TransactionCategory {
  food,
  study,
  travel,
  gear,
  entertainment,
}

@collection
class TransactionModel {
  Id id = Isar.autoIncrement;

  double amount = 0.0;

  String merchantName = '';

  DateTime date = DateTime.fromMillisecondsSinceEpoch(0);

  @enumerated
  TransactionCategory category = TransactionCategory.food;

  String imagePath = '';

  TransactionModel({
    this.id = Isar.autoIncrement,
    this.amount = 0.0,
    this.merchantName = '',
    required this.date,
    this.category = TransactionCategory.food,
    this.imagePath = '',
  });
}
