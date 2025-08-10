import 'package:flutter/foundation.dart';
import 'db_helper.dart';

class PurchaseNotifier extends ValueNotifier<double> {
  PurchaseNotifier() : super(0.0) {
    _loadTotal();
  }

  Future<void> _loadTotal() async {
    final total = await DBHelper().getTotalPurchases();
    value = total;
  }

  Future<void> refresh() async {
    await _loadTotal();
  }
}
