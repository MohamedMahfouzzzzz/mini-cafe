import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:flutter/material.dart';
import '../models/order.dart';

class OrderProvider with ChangeNotifier {
  Order? _activeOrder;
  bool _isLoading = false;

  Order? get activeOrder => _activeOrder;
  bool get isLoading => _isLoading;

  void setActiveOrder(Order order) {
    _activeOrder = order;
    notifyListeners();
  }

  void clearActiveOrder() {
    _activeOrder = null;
    notifyListeners();
  }

  Future<void> fetchActiveOrder(String uid) async {
    _isLoading = true;
    notifyListeners();
    try {
      final snapshot = await fs.FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: uid)
          .where('status', whereIn: ['pending', 'preparing', 'ready'])
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        _activeOrder = Order.fromFirestore(snapshot.docs.first);
      } else {
        _activeOrder = null;
      }
    } catch (e) {
      debugPrint("Error fetching active order: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Stream<Order?> get orderStream {
    if (_activeOrder == null) return Stream.value(null);
    return fs.FirebaseFirestore.instance
        .collection('orders')
        .doc(_activeOrder!.id)
        .snapshots()
        .map((snapshot) => Order.fromFirestore(snapshot));
  }
}
