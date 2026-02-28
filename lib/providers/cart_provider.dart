import 'package:flutter/material.dart';
import '../models/drink.dart';

class CartProvider with ChangeNotifier {
  final List<Drink> _items = [];

  List<Drink> get items => [..._items];
  int get itemCount => _items.length;

  void addItem(Drink drink, {required Map customizations}) {
    _items.add(drink);
    notifyListeners();
  }

  void removeItem(Drink drink) {
    _items.removeWhere((item) => item.id == drink.id);
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }

  double get totalAmount => 0.0;
}
