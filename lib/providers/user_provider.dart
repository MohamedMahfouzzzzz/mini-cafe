import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;
  String _name = '';
  bool _isLoading = true;
  int _loyaltyPoints = 0;
  bool _isDarkMode = false;

  User? get user => _user;
  String get name => _name;
  String get uid => _user?.uid ?? '';
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  int get loyaltyPoints => _loyaltyPoints;
  bool get isDarkMode => _isDarkMode;

  UserProvider() {
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    _user = _auth.currentUser;
    if (_user != null) {
      await _fetchUserData();
    } else {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInAnonymously(String name) async {
    try {
      _isLoading = true;
      notifyListeners();

      final userCredential = await _auth.signInAnonymously();
      _user = userCredential.user;
      _name = name;

      await FirebaseFirestore.instance.collection('users').doc(_user!.uid).set({
        'name': name,
        'createdAt': Timestamp.now(),
        'loyaltyPoints': 0,
        'isDarkMode': false,
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userName', name);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint("Error signing in: $e");
      rethrow;
    }
  }

  Future<void> _fetchUserData() async {
    if (_user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .get();
      if (doc.exists) {
        _name = doc.get('name');
        _loyaltyPoints = doc.get('loyaltyPoints') ?? 0;
        _isDarkMode = doc.get('isDarkMode') ?? false;
      }
    } catch (e) {
      debugPrint("Error fetching user data: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveUserPreferences() async {
    if (_user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(_user!.uid).update(
      {'loyaltyPoints': _loyaltyPoints, 'isDarkMode': _isDarkMode},
    );
  }

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    _saveUserPreferences();
    notifyListeners();
  }

  void addLoyaltyPoints(int points) {
    _loyaltyPoints += points;
    _saveUserPreferences();
    notifyListeners();
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _user = null;
    _name = '';
    _loyaltyPoints = 0;
    _isDarkMode = false;
    notifyListeners();
  }
}
