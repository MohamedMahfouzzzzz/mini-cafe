import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/drink.dart';

class DrinkProvider with ChangeNotifier {
  List<Drink> _drinks = [];
  bool _isLoading = false;

  List<Drink> get drinks => [..._drinks];
  bool get isLoading => _isLoading;
  List<Drink> get popularDrinks =>
      _drinks.where((drink) => drink.isPopular).toList();

  Future<void> fetchDrinks() async {
    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('drinks')
          .get();
      _drinks = snapshot.docs
          .map(
            (doc) => Drink(
              id: doc.id,
              name: doc['name'],
              category: doc['category'],
              price: doc['price'].toDouble(),
              imageUrl: doc['imageUrl'],
              isPopular: doc['isPopular'] ?? false,
              isInStock: doc['isInStock'] ?? true, // Parse the new field
            ),
          )
          .toList();
    } catch (error) {
      debugPrint("Failed to fetch drinks: $error");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
