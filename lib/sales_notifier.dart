import 'package:flutter/material.dart';
import 'db_helper.dart';

class SalesNotifier extends ValueNotifier<double> {
  SalesNotifier() : super(0);

  Future<void> refresh() async {
    final db = await DBHelper().database;
    final result = await db.rawQuery('SELECT SUM(total_amount) as total FROM invoices');
    value = (result.first['total'] as num?)?.toDouble() ?? 0.0;
    notifyListeners();
  }
}
