import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:cloudinary_public/cloudinary_public.dart';

// =================================================================
// FIREBASE OPTIONS
// =================================================================
import 'firebase_options.dart';

// =================================================================
// MAIN FUNCTION & APP INITIALIZATION
// =================================================================
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  debugPrint(
    'Notification tapped in background: ${notificationResponse.payload}',
  );
}

Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Handling a background message: ${message.messageId}');

  await flutterLocalNotificationsPlugin.show(
    message.hashCode,
    message.notification?.title ?? 'Order Update',
    message.notification?.body ?? 'Tap to view',
    NotificationDetails(
      android: AndroidNotificationDetails(
        'mini_cafe_customer_channel',
        'Mini Cafe Customer Notifications',
        channelDescription: 'Notifications for order updates',
        importance: Importance.max,
        priority: Priority.high,
        color: const Color(0xFF00BCD4),
      ),
    ),
    payload: message.data['orderId'],
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  final fcmToken = await messaging.getToken();
  debugPrint('FCM Token: $fcmToken');

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: notificationTapBackground,
  );

  try {
    if (kIsWeb) {
      debugPrint(
        'Running on web - skipping Android-specific notification setup',
      );
    } else {
      if (Platform.isAndroid) {
        flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
      }
    }
  } catch (e) {
    debugPrint('Platform check failed (likely running on web): $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => DrinkProvider()),
        ChangeNotifierProvider(create: (_) => SnackProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => NotificationService()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
        ChangeNotifierProvider(create: (_) => LoyaltyProvider()),
        ChangeNotifierProvider(create: (_) => GameProvider()),
      ],
      child: Consumer<UserProvider>(
        builder: (ctx, userProvider, _) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'Mini Cafe',
            debugShowCheckedModeBanner: false,
            themeMode: userProvider.isDarkMode
                ? ThemeMode.dark
                : ThemeMode.light,
            theme: ThemeData(
              brightness: Brightness.light,
              fontFamily: 'Poppins',
              scaffoldBackgroundColor: const Color(0xFFF5F7FA),
              primarySwatch: Colors.teal,
              primaryColor: const Color(0xFF00BCD4),
              cardColor: Colors.white,
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 0,
                titleTextStyle: TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BCD4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                hintStyle: TextStyle(color: Colors.grey[600]),
              ),
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              fontFamily: 'Poppins',
              scaffoldBackgroundColor: const Color(0xFF121212),
              primaryColor: const Color(0xFF00BCD4),
              cardColor: const Color(0xFF1E1E1E),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF1E1E1E),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
            ),
            home: userProvider.isLoading
                ? const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  )
                : userProvider.isAuthenticated
                ? const MainScreen()
                : const WelcomeScreen(),
            routes: {
              '/order-status': (ctx) => const OrderStatusScreen(),
              '/profile': (ctx) => const ProfileScreen(),
              '/chat': (ctx) {
                final args =
                    ModalRoute.of(ctx)?.settings.arguments
                        as Map<String, dynamic>? ??
                    {};
                final orderId = args['orderId'] ?? '';
                final userName = args['userName'] ?? '';
                return ChatScreen(orderId: orderId, userName: userName);
              },
              '/subscriptions': (ctx) => const SubscriptionScreen(),
              '/hot-drinks': (ctx) => const HotDrinksScreen(),
              '/cold-drinks': (ctx) => const ColdDrinksScreen(),
              '/snacks': (ctx) => const SnacksScreen(),
              '/loyalty': (ctx) => const LoyaltyScreen(),
              '/games': (ctx) => const GamesScreen(),
              '/drink-photo': (ctx) {
                final args =
                    ModalRoute.of(ctx)?.settings.arguments
                        as Map<String, dynamic>? ??
                    {};
                final drinkId = args['drinkId'] ?? '';
                final orderId = args['orderId'] ?? '';
                return DrinkPhotoScreen(drinkId: drinkId, orderId: orderId);
              },
            },
          );
        },
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<Widget> _screens = [
    const HomeScreen(),
    const MenuScreen(),
    const CartScreen(),
    const OrderHistoryScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NotificationService>(context, listen: false).initialize();
      Provider.of<LoyaltyProvider>(context, listen: false).initializeLoyalty();
      Provider.of<GameProvider>(context, listen: false).initializeGameState();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<UserProvider>(context).isDarkMode;

    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: _screens[_currentIndex],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 10,
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
              _animationController.reset();
              _animationController.forward();
            });
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: const Color(0xFF00BCD4),
          unselectedItemColor: isDarkMode ? Colors.white54 : Colors.grey,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(
              icon: Icon(Icons.restaurant_menu),
              label: 'Menu',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart),
              label: 'Cart',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Orders'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

// =================================================================
// MODELS
// =================================================================
enum OrderStatus { pending, preparing, ready, completed, cancelled }

class Order {
  final String id;
  final String userName;
  final List<Map<String, dynamic>> items;
  final OrderStatus status;
  final fs.Timestamp timestamp;
  final String? estimatedTime;
  final String? tableNumber;
  final double totalAmount;
  final String? notes;
  final bool isSubscriptionOrder;
  final String? drinkPhoto;

  Order({
    required this.id,
    required this.userName,
    required this.items,
    required this.status,
    required this.timestamp,
    this.estimatedTime,
    this.tableNumber,
    required this.totalAmount,
    this.notes,
    this.isSubscriptionOrder = false,
    this.drinkPhoto,
  });

  factory Order.fromFirestore(fs.DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Order(
      id: doc.id,
      userName: data['userName'] ?? '',
      items: List<Map<String, dynamic>>.from(data['items'] ?? []),
      status: OrderStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => OrderStatus.pending,
      ),
      timestamp: data['timestamp'] ?? fs.Timestamp.now(),
      estimatedTime: data['estimatedTime'],
      tableNumber: data['tableNumber'],
      totalAmount: data['totalAmount']?.toDouble() ?? 0.0,
      notes: data['notes'],
      isSubscriptionOrder: data['isSubscriptionOrder'] ?? false,
      drinkPhoto: data['drinkPhoto'],
    );
  }
}

class Drink {
  final String id;
  final String name;
  final String category;
  final double price;
  final String imageUrl;
  final bool isPopular;
  final bool isInStock;
  final List<CustomizationOption> customizations;
  final String description;
  final int preparationTime;
  final List<String> userPhotos;

  Drink({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.imageUrl,
    this.isPopular = false,
    this.isInStock = true,
    this.customizations = const [],
    this.description = '',
    this.preparationTime = 5,
    this.userPhotos = const [],
  });
}

class Snack {
  final String id;
  final String name;
  final String category;
  final double price;
  final String imageUrl;
  final bool isPopular;
  final bool isInStock;
  final String description;
  final List<String> allergens;
  final int calories;
  final List<String> userPhotos;

  Snack({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.imageUrl,
    this.isPopular = false,
    this.isInStock = true,
    this.description = '',
    this.allergens = const [],
    this.calories = 0,
    this.userPhotos = const [],
  });
}

class CustomizationOption {
  final String id;
  final String name;
  final double price;
  final List<String> choices;

  CustomizationOption({
    required this.id,
    required this.name,
    required this.price,
    required this.choices,
  });
}

class ChatMessage {
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final bool isAdmin;

  ChatMessage({
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
    this.isAdmin = false,
  });

  factory ChatMessage.fromFirestore(Map<String, dynamic> data) {
    return ChatMessage(
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? 'Unknown',
      text: data['text'] ?? '',
      timestamp: (data['timestamp'] as fs.Timestamp).toDate(),
      isAdmin: data['isAdmin'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'timestamp': fs.Timestamp.fromDate(timestamp),
      'isAdmin': isAdmin,
    };
  }
}

class Subscription {
  final String id;
  final String userId;
  final String userName;
  final String planType;
  final double price;
  final fs.Timestamp startDate;
  final fs.Timestamp endDate;
  final bool isActive;
  final int remainingDrinks;
  final int maxDrinks;
  final List<String> includedCategories;
  final String status;

  Subscription({
    required this.id,
    required this.userId,
    required this.userName,
    required this.planType,
    required this.price,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    required this.remainingDrinks,
    required this.maxDrinks,
    required this.includedCategories,
    required this.status,
  });

  factory Subscription.fromFirestore(fs.DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Subscription(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      planType: data['planType'] ?? '',
      price: data['price']?.toDouble() ?? 0.0,
      startDate: data['startDate'] ?? fs.Timestamp.now(),
      endDate: data['endDate'] ?? fs.Timestamp.now(),
      isActive: data['isActive'] ?? false,
      remainingDrinks: data['remainingDrinks'] ?? 0,
      maxDrinks: data['maxDrinks'] ?? 0,
      includedCategories: List<String>.from(data['includedCategories'] ?? []),
      status: data['status'] ?? 'pending',
    );
  }
}

class SubscriptionPlan {
  final String id;
  final String name;
  final String description;
  final double price;
  final int durationInDays;
  final int maxDrinks;
  final List<String> includedCategories;

  SubscriptionPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.durationInDays,
    required this.maxDrinks,
    required this.includedCategories,
  });

  factory SubscriptionPlan.fromFirestore(fs.DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SubscriptionPlan(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      price: data['price']?.toDouble() ?? 0.0,
      durationInDays: data['durationInDays'] ?? 30,
      maxDrinks: data['maxDrinks'] ?? 30,
      includedCategories: List<String>.from(data['includedCategories'] ?? []),
    );
  }
}

// =================================================================
// PROVIDERS
// =================================================================
class CartProvider with ChangeNotifier {
  final List<Map<String, dynamic>> _items = [];
  String? _orderNotes;

  List<Map<String, dynamic>> get items => [..._items];
  int get itemCount => _items.length;
  String? get orderNotes => _orderNotes;

  void setOrderNotes(String notes) {
    _orderNotes = notes;
    notifyListeners();
  }

  void addItem(
    dynamic item, {
    Map<String, String>? customizations,
    bool isSubscriptionDrink = false,
  }) {
    _items.add({
      'item': item,
      'customizations': customizations ?? {},
      'quantity': 1,
      'isSubscriptionDrink': isSubscriptionDrink,
      'type': item.runtimeType.toString() == 'Drink' ? 'drink' : 'snack',
    });
    notifyListeners();
  }

  void updateQuantity(int index, int quantity) {
    if (quantity <= 0) {
      _items.removeAt(index);
    } else {
      _items[index]['quantity'] = quantity;
    }
    notifyListeners();
  }

  void removeItem(int index) {
    _items.removeAt(index);
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    _orderNotes = null;
    notifyListeners();
  }

  double get totalAmount {
    double total = 0.0;
    for (var item in _items) {
      final itemObj = item['item'];
      final quantity = item['quantity'] as int;
      final isSubscriptionDrink = item['isSubscriptionDrink'] as bool;

      if (!isSubscriptionDrink) {
        total += itemObj.price * quantity;
      }

      // Add customization costs
      for (var customization in item['customizations'].entries) {
        if (itemObj.runtimeType.toString() == 'Drink') {
          final drink = itemObj as Drink;
          final option = drink.customizations.firstWhere(
            (opt) => opt.id == customization.key,
            orElse: () =>
                CustomizationOption(id: '', name: '', price: 0.0, choices: []),
          );
          if (customization.value == "Yes") {
            total += option.price * quantity;
          }
        }
      }
    }
    return total;
  }
}

class UserProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;
  String _name = '';
  int _loyaltyPoints = 0;
  bool _isDarkMode = false;
  bool _isLoading = true;
  Subscription? _activeSubscription;

  User? get user => _user;
  String get name => _name;
  String get uid => _user?.uid ?? '';
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  int get loyaltyPoints => _loyaltyPoints;
  bool get isDarkMode => _isDarkMode;
  Subscription? get activeSubscription => _activeSubscription;
  bool get hasActiveSubscription =>
      _activeSubscription?.isActive == true &&
      _activeSubscription?.status == 'approved';

  UserProvider() {
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    _user = _auth.currentUser;
    if (_user != null) {
      await _fetchUserData();
      await _fetchActiveSubscription();
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
      await fs.FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .set({
            'name': name,
            'createdAt': fs.Timestamp.now(),
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
      final doc = await fs.FirebaseFirestore.instance
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

  Future<void> _fetchActiveSubscription() async {
    if (_user == null) return;
    try {
      final snapshot = await fs.FirebaseFirestore.instance
          .collection('subscriptions')
          .where('userId', isEqualTo: _user!.uid)
          .where('isActive', isEqualTo: true)
          .where('status', isEqualTo: 'approved')
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        _activeSubscription = Subscription.fromFirestore(snapshot.docs.first);
      } else {
        _activeSubscription = null;
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching subscription: $e");
    }
  }

  Future<void> _saveUserPreferences() async {
    if (_user == null) return;
    await fs.FirebaseFirestore.instance
        .collection('users')
        .doc(_user!.uid)
        .update({'loyaltyPoints': _loyaltyPoints, 'isDarkMode': _isDarkMode});
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
    _activeSubscription = null;
    notifyListeners();
  }

  Future<void> refreshSubscription() async {
    await _fetchActiveSubscription();
  }
}

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
      final snapshot = await fs.FirebaseFirestore.instance
          .collection('drinks')
          .get();
      _drinks = snapshot.docs.map((doc) {
        final data = doc.data();
        return Drink(
          id: doc.id,
          name: data['name'] ?? '',
          category: data['category'] ?? '',
          price: data['price']?.toDouble() ?? 0.0,
          imageUrl: data['imageUrl'] ?? '',
          isPopular: data['isPopular'] ?? false,
          isInStock: data['isInStock'] ?? true,
          customizations: [],
          description: data['description'] ?? '',
          preparationTime: data['preparationTime'] ?? 5,
          userPhotos: List<String>.from(data['userPhotos'] ?? []),
        );
      }).toList();
    } catch (error) {
      debugPrint("Failed to fetch drinks: $error");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addUserPhoto(String drinkId, String photoUrl) async {
    try {
      final drinkRef = fs.FirebaseFirestore.instance
          .collection('drinks')
          .doc(drinkId);

      // First check if the document exists
      final docSnapshot = await drinkRef.get();

      if (docSnapshot.exists) {
        // Check if userPhotos field exists
        final data = docSnapshot.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('userPhotos')) {
          // Field exists, use arrayUnion
          await drinkRef.update({
            'userPhotos': fs.FieldValue.arrayUnion([photoUrl]),
          });
        } else {
          // Field doesn't exist, create it
          await drinkRef.update({
            'userPhotos': [photoUrl],
          });
        }
      } else {
        // Document doesn't exist, create it with userPhotos
        await drinkRef.set({
          'userPhotos': [photoUrl],
        }, fs.SetOptions(merge: true));
      }

      // Update local state
      final drinkIndex = _drinks.indexWhere((drink) => drink.id == drinkId);
      if (drinkIndex != -1) {
        _drinks[drinkIndex].userPhotos.add(photoUrl);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Failed to add user photo: $e");
    }
  }
}

class SnackProvider with ChangeNotifier {
  List<Snack> _snacks = [];
  bool _isLoading = false;

  List<Snack> get snacks => [..._snacks];
  bool get isLoading => _isLoading;
  List<Snack> get popularSnacks =>
      _snacks.where((snack) => snack.isPopular).toList();

  Future<void> fetchSnacks() async {
    _isLoading = true;
    notifyListeners();
    try {
      final snapshot = await fs.FirebaseFirestore.instance
          .collection('snacks')
          .get();
      _snacks = snapshot.docs.map((doc) {
        final data = doc.data();
        return Snack(
          id: doc.id,
          name: data['name'] ?? '',
          category: data['category'] ?? '',
          price: data['price']?.toDouble() ?? 0.0,
          imageUrl: data['imageUrl'] ?? '',
          isPopular: data['isPopular'] ?? false,
          isInStock: data['isInStock'] ?? true,
          description: data['description'] ?? '',
          allergens: List<String>.from(data['allergens'] ?? []),
          calories: data['calories'] ?? 0,
          userPhotos: List<String>.from(data['userPhotos'] ?? []),
        );
      }).toList();
    } catch (error) {
      debugPrint("Failed to fetch snacks: $error");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addUserPhoto(String snackId, String photoUrl) async {
    try {
      await fs.FirebaseFirestore.instance
          .collection('snacks')
          .doc(snackId)
          .update({
            'userPhotos': fs.FieldValue.arrayUnion([photoUrl]),
          });

      final snackIndex = _snacks.indexWhere((snack) => snack.id == snackId);
      if (snackIndex != -1) {
        _snacks[snackIndex].userPhotos.add(photoUrl);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Failed to add user photo: $e");
    }
  }
}

class OrderProvider with ChangeNotifier {
  Order? _activeOrder;
  List<Order> _orderHistory = [];
  bool _isLoading = false;

  Order? get activeOrder => _activeOrder;
  List<Order> get orderHistory => [..._orderHistory];
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

  Future<void> fetchOrderHistory(String uid) async {
    _isLoading = true;
    notifyListeners();
    try {
      final snapshot = await fs.FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .get();
      _orderHistory = snapshot.docs
          .map((doc) => Order.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint("Error fetching order history: $e");
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

class ChatProvider with ChangeNotifier {
  final fs.FirebaseFirestore _firestore = fs.FirebaseFirestore.instance;
  List<ChatMessage> _messages = [];
  bool _isLoading = false;

  List<ChatMessage> get messages => [..._messages];
  bool get isLoading => _isLoading;

  Future<void> fetchMessages(String orderId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final snapshot = await _firestore
          .collection('chats')
          .doc(orderId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .get();
      _messages = snapshot.docs
          .map((doc) => ChatMessage.fromFirestore(doc.data()))
          .toList();
    } catch (e) {
      debugPrint("Error fetching messages: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Stream<List<ChatMessage>> getMessagesStream(String orderId) {
    return _firestore
        .collection('chats')
        .doc(orderId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ChatMessage.fromFirestore(doc.data()))
              .toList(),
        );
  }

  Future<void> sendMessage(
    String orderId,
    String text,
    String senderId,
    String senderName,
  ) async {
    final message = ChatMessage(
      senderId: senderId,
      senderName: senderName,
      text: text,
      timestamp: DateTime.now(),
    );
    await _firestore
        .collection('chats')
        .doc(orderId)
        .collection('messages')
        .add(message.toMap());
  }
}

class SubscriptionProvider with ChangeNotifier {
  final fs.FirebaseFirestore _firestore = fs.FirebaseFirestore.instance;
  List<SubscriptionPlan> _plans = [];
  bool _isLoading = false;

  List<SubscriptionPlan> get plans => [..._plans];
  bool get isLoading => _isLoading;

  Future<void> fetchPlans() async {
    _isLoading = true;
    notifyListeners();
    try {
      final snapshot = await _firestore.collection('subscriptionPlans').get();
      _plans = snapshot.docs
          .map((doc) => SubscriptionPlan.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint("Failed to fetch subscription plans: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> purchaseSubscription(
    String planId,
    String userId,
    String userName,
  ) async {
    try {
      final planDoc = await _firestore
          .collection('subscriptionPlans')
          .doc(planId)
          .get();
      if (!planDoc.exists) return false;

      final plan = SubscriptionPlan.fromFirestore(planDoc);

      final now = fs.Timestamp.now();
      await _firestore.collection('subscriptions').add({
        'userId': userId,
        'userName': userName,
        'planType': plan.name,
        'price': plan.price,
        'startDate': now,
        'endDate': now,
        'status': 'pending',
        'isActive': false,
        'remainingDrinks': plan.maxDrinks,
        'maxDrinks': plan.maxDrinks,
        'includedCategories': plan.includedCategories,
        'requestDate': now,
      });

      await _firestore.collection('adminNotifications').add({
        'type': 'subscription_request',
        'message': 'New subscription request from $userName',
        'timestamp': now,
        'read': false,
      });

      return true;
    } catch (e) {
      debugPrint("Failed to purchase subscription: $e");
      return false;
    }
  }

  Future<bool> useSubscriptionDrink(String userId, String drinkCategory) async {
    try {
      final snapshot = await _firestore
          .collection('subscriptions')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .where('status', isEqualTo: 'approved')
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return false;

      final subscription = Subscription.fromFirestore(snapshot.docs.first);

      if (!subscription.includedCategories.contains(drinkCategory)) {
        return false;
      }

      if (subscription.remainingDrinks <= 0) {
        return false;
      }

      await _firestore
          .collection('subscriptions')
          .doc(snapshot.docs.first.id)
          .update({'remainingDrinks': subscription.remainingDrinks - 1});

      return true;
    } catch (e) {
      debugPrint("Failed to use subscription drink: $e");
      return false;
    }
  }
}

class NotificationService with ChangeNotifier {
  final fs.FirebaseFirestore _firestore = fs.FirebaseFirestore.instance;
  StreamSubscription<fs.QuerySnapshot>? _ordersSubscription;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    await _initializeFCM();
    _listenForOrderUpdates();

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _initializeFCM() async {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Received foreground message: ${message.messageId}');

      flutterLocalNotificationsPlugin.show(
        message.hashCode,
        message.notification?.title ?? 'Order Update',
        message.notification?.body ?? 'Tap to view',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'mini_cafe_customer_channel',
            'Mini Cafe Customer Notifications',
            channelDescription: 'Notifications for order updates',
            importance: Importance.max,
            priority: Priority.high,
            color: const Color(0xFF00BCD4),
          ),
        ),
        payload: message.data['orderId'],
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Message clicked: ${message.messageId}');
      _handleNotificationClick(message.data['orderId']);
    });

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('App opened from notification: ${initialMessage.messageId}');
      _handleNotificationClick(initialMessage.data['orderId']);
    }
  }

  void _listenForOrderUpdates() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    _ordersSubscription = _firestore
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
          for (var change in snapshot.docChanges) {
            if (change.type == fs.DocumentChangeType.modified) {
              final orderData = change.doc.data() as Map<String, dynamic>;
              _showOrderUpdateNotification(change.doc.id, orderData);
            }
          }
        });
  }

  Future<void> _showOrderUpdateNotification(
    String orderId,
    Map<String, dynamic> orderData,
  ) async {
    try {
      final AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
            'mini_cafe_customer_channel',
            'Mini Cafe Customer Notifications',
            channelDescription: 'Notifications for order updates',
            importance: Importance.max,
            priority: Priority.high,
            color: const Color(0xFF00BCD4),
          );
      final NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
      );

      await flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        'Order Update',
        'Your order is now ${orderData['status']}',
        platformChannelSpecifics,
        payload: orderId,
      );
    } catch (e) {
      debugPrint("Failed to show notification: $e");
    }
  }

  void _handleNotificationClick(String? orderId) {
    if (orderId != null && navigatorKey.currentContext != null) {
      navigatorKey.currentState?.pushNamed('/order-status');
    }
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    super.dispose();
  }
}

// Loyalty Provider for Coffee Passport and Points System
class LoyaltyProvider with ChangeNotifier {
  final fs.FirebaseFirestore _firestore = fs.FirebaseFirestore.instance;
  List<String> _collectedStamps = [];
  int _totalPoints = 0;
  bool _hasFreeMonth = false;
  List<String> _orderHistory = [];
  bool _isLoading = false;

  List<String> get collectedStamps => [..._collectedStamps];
  int get totalPoints => _totalPoints;
  bool get hasFreeMonth => _hasFreeMonth;
  List<String> get orderHistory => [..._orderHistory];
  bool get isLoading => _isLoading;

  Future<void> initializeLoyalty() async {
    _isLoading = true;
    notifyListeners();

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final doc = await _firestore.collection('loyalty').doc(userId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _collectedStamps = List<String>.from(data['stamps'] ?? []);
        _totalPoints = data['points'] ?? 0;
        _hasFreeMonth = data['hasFreeMonth'] ?? false;
        _orderHistory = List<String>.from(data['orderHistory'] ?? []);
      }
    } catch (e) {
      debugPrint("Error initializing loyalty: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addStamp(String drinkId) async {
    if (_collectedStamps.contains(drinkId)) return;

    _collectedStamps.add(drinkId);
    await _saveLoyaltyData();

    // Award points for new drink
    final points = _getRandomPoints();
    _totalPoints += points;

    // Check if user reached 2000 points for free month
    if (_totalPoints >= 2000 && !_hasFreeMonth) {
      _hasFreeMonth = true;
      _totalPoints -= 2000; // Deduct points for free month
      _showFreeMonthDialog();
    }

    await _saveLoyaltyData();
    notifyListeners();
  }

  int _getRandomPoints() {
    final random = Random();
    final rand = random.nextDouble();

    if (rand < 0.2)
      return 4; // 20% chance for 4 points
    else if (rand < 0.5)
      return 7; // 30% chance for 7 points
    else
      return 10; // 50% chance for 10 points
  }

  Future<void> addOrderToHistory(String drinkId) async {
    _orderHistory.add(drinkId);
    await _saveLoyaltyData();
    notifyListeners();
  }

  Future<void> _saveLoyaltyData() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    await _firestore.collection('loyalty').doc(userId).set({
      'stamps': _collectedStamps,
      'points': _totalPoints,
      'hasFreeMonth': _hasFreeMonth,
      'orderHistory': _orderHistory,
      'updatedAt': fs.Timestamp.now(),
    });
  }

  void _showFreeMonthDialog() {
    showDialog(
      context: navigatorKey.currentContext!,
      builder: (context) => AlertDialog(
        title: const Text('Congratulations!'),
        content: const Text('You\'ve earned a free month subscription!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Claim'),
          ),
        ],
      ),
    );
  }

  // Get surprise drink recommendation based on order history
  String? getSurpriseDrink() {
    if (_orderHistory.isEmpty) return null;

    // Count frequency of each drink in order history
    final Map<String, int> frequency = {};
    for (final drinkId in _orderHistory) {
      frequency[drinkId] = (frequency[drinkId] ?? 0) + 1;
    }

    // Find the most frequently ordered drink
    String? mostFrequent;
    int maxCount = 0;

    frequency.forEach((drinkId, count) {
      if (count > maxCount) {
        maxCount = count;
        mostFrequent = drinkId;
      }
    });

    return mostFrequent;
  }
}

// Game Provider for Spin and Win, Dice Games
class GameProvider with ChangeNotifier {
  bool _canPlaySpin = true;
  bool _canPlayDice = true;
  DateTime? _lastSpinTime;
  DateTime? _lastDiceTime;
  int _lastSpinResult = 0;
  int _lastDiceResult = 0;
  bool _isLoading = false;

  bool get canPlaySpin => _canPlaySpin;
  bool get canPlayDice => _canPlayDice;
  int get lastSpinResult => _lastSpinResult;
  int get lastDiceResult => _lastDiceResult;
  bool get isLoading => _isLoading;

  // Initialize game state from Firestore
  Future<void> initializeGameState() async {
    _isLoading = true;
    notifyListeners();

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final doc = await fs.FirebaseFirestore.instance
          .collection('gameState')
          .doc(userId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final lastSpinTimestamp = data['lastSpinTime'] as fs.Timestamp?;
        final lastDiceTimestamp = data['lastDiceTime'] as fs.Timestamp?;

        if (lastSpinTimestamp != null) {
          _lastSpinTime = lastSpinTimestamp.toDate();
          _canPlaySpin = _checkCanPlayAgain(_lastSpinTime);
        }

        if (lastDiceTimestamp != null) {
          _lastDiceTime = lastDiceTimestamp.toDate();
          _canPlayDice = _checkCanPlayAgain(_lastDiceTime);
        }

        _lastSpinResult = data['lastSpinResult'] ?? 0;
        _lastDiceResult = data['lastDiceResult'] ?? 0;
      }
    } catch (e) {
      debugPrint("Error initializing game state: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Check if enough time has passed to play again
  bool _checkCanPlayAgain(DateTime? lastPlayTime) {
    if (lastPlayTime == null) return true;

    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final lastPlayDay = DateTime(
      lastPlayTime.year,
      lastPlayTime.month,
      lastPlayTime.day,
    );

    return now.isAfter(tomorrow) || now.day != lastPlayDay.day;
  }

  Future<void> playSpin() async {
    if (!_canPlaySpin || _isLoading) return;

    _isLoading = true;
    notifyListeners();

    // Simulate spin animation
    await Future.delayed(const Duration(seconds: 3));

    // Generate random result (1-8)
    final random = Random();
    _lastSpinResult = random.nextInt(8) + 1;

    // Add points to loyalty
    final loyaltyProvider = Provider.of<LoyaltyProvider>(
      navigatorKey.currentContext!,
      listen: false,
    );
    loyaltyProvider._totalPoints += _lastSpinResult;
    await loyaltyProvider._saveLoyaltyData();

    // Set cooldown (can play once per day)
    _lastSpinTime = DateTime.now();
    _canPlaySpin = false;

    // Save to Firestore
    await _saveGameState();

    // Check if a day has passed
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final timeUntilTomorrow = tomorrow.difference(now);

    Timer(timeUntilTomorrow, () {
      _canPlaySpin = true;
      notifyListeners();
    });

    _isLoading = false;
    notifyListeners();
  }

  Future<void> playDice() async {
    if (!_canPlayDice || _isLoading) return;

    _isLoading = true;
    notifyListeners();

    // Simulate dice roll animation
    await Future.delayed(const Duration(seconds: 2));

    // Generate random result (1-6)
    final random = Random();
    _lastDiceResult = random.nextInt(6) + 1;

    // Add points to loyalty
    final loyaltyProvider = Provider.of<LoyaltyProvider>(
      navigatorKey.currentContext!,
      listen: false,
    );
    loyaltyProvider._totalPoints += _lastDiceResult * 2; // Dice gives 2x points
    await loyaltyProvider._saveLoyaltyData();

    // Set cooldown (can play once per day)
    _lastDiceTime = DateTime.now();
    _canPlayDice = false;

    // Save to Firestore
    await _saveGameState();

    // Check if a day has passed
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final timeUntilTomorrow = tomorrow.difference(now);

    Timer(timeUntilTomorrow, () {
      _canPlayDice = true;
      notifyListeners();
    });

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _saveGameState() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      await fs.FirebaseFirestore.instance
          .collection('gameState')
          .doc(userId)
          .set({
            'lastSpinTime': _lastSpinTime != null
                ? fs.Timestamp.fromDate(_lastSpinTime!)
                : null,
            'lastDiceTime': _lastDiceTime != null
                ? fs.Timestamp.fromDate(_lastDiceTime!)
                : null,
            'lastSpinResult': _lastSpinResult,
            'lastDiceResult': _lastDiceResult,
            'updatedAt': fs.Timestamp.now(),
          });
    } catch (e) {
      debugPrint("Error saving game state: $e");
    }
  }
}

// =================================================================
// WIDGETS
// =================================================================
class DrinkCard extends StatelessWidget {
  final Drink drink;
  final bool isSubscriptionDrink;

  const DrinkCard({
    super.key,
    required this.drink,
    this.isSubscriptionDrink = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<UserProvider>(context).isDarkMode;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: drink.imageUrl,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: 80,
                  height: 80,
                  color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                  child: Icon(
                    Icons.local_cafe,
                    color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 80,
                  height: 80,
                  color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                  child: Icon(
                    Icons.error,
                    color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          drink.name,
                          style: GoogleFonts.poppins(
                            color: isDarkMode ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (isSubscriptionDrink)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'FREE',
                            style: GoogleFonts.poppins(
                              color: Colors.purple,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    drink.description.isNotEmpty
                        ? drink.description
                        : 'Delicious drink made with quality ingredients',
                    style: GoogleFonts.poppins(
                      color: isDarkMode ? Colors.white54 : Colors.grey[600],
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isSubscriptionDrink
                            ? 'FREE'
                            : '\$${drink.price.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                          color: isSubscriptionDrink
                              ? Colors.purple
                              : const Color(0xFF00BCD4),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: drink.isInStock
                              ? Colors.green.withOpacity(0.2)
                              : Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          drink.isInStock ? 'In Stock' : 'Out of Stock',
                          style: GoogleFonts.poppins(
                            color: drink.isInStock ? Colors.green : Colors.red,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                Icons.add_circle,
                color: const Color(0xFF00BCD4),
                size: 30,
              ),
              onPressed: drink.isInStock
                  ? () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => DrinkDetailScreen(
                            drink: drink,
                            isSubscriptionDrink: isSubscriptionDrink,
                          ),
                        ),
                      );
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class SnackCard extends StatelessWidget {
  final Snack snack;
  final bool isSubscriptionSnack;

  const SnackCard({
    super.key,
    required this.snack,
    this.isSubscriptionSnack = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<UserProvider>(context).isDarkMode;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: snack.imageUrl,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: 80,
                  height: 80,
                  color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                  child: Icon(
                    Icons.fastfood,
                    color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 80,
                  height: 80,
                  color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                  child: Icon(
                    Icons.error,
                    color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          snack.name,
                          style: GoogleFonts.poppins(
                            color: isDarkMode ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (isSubscriptionSnack)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'FREE',
                            style: GoogleFonts.poppins(
                              color: Colors.purple,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    snack.description.isNotEmpty
                        ? snack.description
                        : 'Delicious snack made with quality ingredients',
                    style: GoogleFonts.poppins(
                      color: isDarkMode ? Colors.white54 : Colors.grey[600],
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isSubscriptionSnack
                            ? 'FREE'
                            : '\$${snack.price.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                          color: isSubscriptionSnack
                              ? Colors.purple
                              : const Color(0xFF00BCD4),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: snack.isInStock
                              ? Colors.green.withOpacity(0.2)
                              : Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          snack.isInStock ? 'In Stock' : 'Out of Stock',
                          style: GoogleFonts.poppins(
                            color: snack.isInStock ? Colors.green : Colors.red,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                Icons.add_circle,
                color: const Color(0xFF00BCD4),
                size: 30,
              ),
              onPressed: snack.isInStock
                  ? () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => SnackDetailScreen(
                            snack: snack,
                            isSubscriptionSnack: isSubscriptionSnack,
                          ),
                        ),
                      );
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// =================================================================
// SCREENS
// =================================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _animations = List.generate(4, (index) {
      final start = index * 0.1;
      final end = start + 0.5;
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(start, end, curve: Curves.easeOut),
        ),
      );
    });

    _animationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DrinkProvider>(context, listen: false).fetchDrinks();
      Provider.of<SnackProvider>(context, listen: false).fetchSnacks();
      Provider.of<SubscriptionProvider>(context, listen: false).fetchPlans();
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      if (userProvider.isAuthenticated) {
        Provider.of<OrderProvider>(
          context,
          listen: false,
        ).fetchActiveOrder(userProvider.uid);
        userProvider.refreshSubscription();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userName = Provider.of<UserProvider>(context).name;
    final isDarkMode = Provider.of<UserProvider>(context).isDarkMode;
    final loyaltyProvider = Provider.of<LoyaltyProvider>(context);

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF121212)
          : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          'Mini Cafe',
          style: GoogleFonts.pacifico(
            fontSize: 28,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        actions: [
          Consumer<UserProvider>(
            builder: (ctx, userProvider, child) {
              if (userProvider.hasActiveSubscription) {
                return IconButton(
                  icon: const Icon(Icons.card_membership, color: Colors.purple),
                  onPressed: () =>
                      Navigator.of(context).pushNamed('/subscriptions'),
                );
              }
              return IconButton(
                icon: Icon(
                  Icons.card_membership,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                onPressed: () =>
                    Navigator.of(context).pushNamed('/subscriptions'),
              );
            },
          ),
          IconButton(
            icon: Icon(
              Icons.light_mode,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
            onPressed: () {
              Provider.of<UserProvider>(context, listen: false).toggleTheme();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildWelcomeBanner(userName, isDarkMode),
            _buildLoyaltyCard(isDarkMode, loyaltyProvider),
            Consumer<UserProvider>(
              builder: (ctx, userProvider, child) {
                if (userProvider.hasActiveSubscription) {
                  return _buildSubscriptionBanner(
                    userProvider.activeSubscription!,
                    isDarkMode,
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            Consumer<OrderProvider>(
              builder: (ctx, orderProvider, child) {
                if (orderProvider.activeOrder != null) {
                  return _buildActiveOrderBanner(
                    context,
                    orderProvider.activeOrder!,
                    isDarkMode,
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            _buildCategories(context, isDarkMode),
            _buildPopularItems(context, isDarkMode),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner(String userName, bool isDarkMode) {
    return FadeTransition(
      opacity: _animations[0],
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [const Color(0xFF00BCD4), const Color(0xFF00ACC1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back, $userName!',
              style: GoogleFonts.poppins(
                fontSize: 24,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'What would you like to order today?',
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoyaltyCard(bool isDarkMode, LoyaltyProvider loyaltyProvider) {
    return FadeTransition(
      opacity: _animations[1],
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.card_membership, color: Color(0xFF00BCD4), size: 24),
                const SizedBox(width: 12),
                Text(
                  'Coffee Passport',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: isDarkMode ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pushNamed('/loyalty'),
                  child: Text(
                    'View All',
                    style: GoogleFonts.poppins(
                      color: Color(0xFF00BCD4),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stamps Collected',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: isDarkMode ? Colors.white70 : Colors.grey[600],
                        ),
                      ),
                      Text(
                        '${loyaltyProvider.collectedStamps.length}',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          color: isDarkMode ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Points Balance',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: isDarkMode ? Colors.white70 : Colors.grey[600],
                        ),
                      ),
                      Text(
                        '${loyaltyProvider.totalPoints}',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          color: isDarkMode ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Free Month',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: isDarkMode ? Colors.white70 : Colors.grey[600],
                        ),
                      ),
                      Text(
                        loyaltyProvider.hasFreeMonth ? 'Available' : '2000 pts',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: loyaltyProvider.hasFreeMonth
                              ? Colors.green
                              : isDarkMode
                              ? Colors.white
                              : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: (loyaltyProvider.totalPoints % 2000) / 2000,
              backgroundColor: isDarkMode ? Colors.grey[700] : Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00BCD4)),
            ),
            const SizedBox(height: 8),
            Text(
              '${2000 - (loyaltyProvider.totalPoints % 2000)} points to next free month',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: isDarkMode ? Colors.white70 : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionBanner(Subscription subscription, bool isDarkMode) {
    return FadeTransition(
      opacity: _animations[2],
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.purple.withOpacity(isDarkMode ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.purple.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.card_membership, color: Colors.purple, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Active Subscription',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: isDarkMode ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${subscription.planType} - ${subscription.remainingDrinks} drinks left',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: isDarkMode ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pushNamed('/subscriptions'),
              child: Text(
                'Manage',
                style: GoogleFonts.poppins(
                  color: Colors.purple,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveOrderBanner(
    BuildContext context,
    Order order,
    bool isDarkMode,
  ) {
    return FadeTransition(
      opacity: _animations[2],
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(isDarkMode ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, color: Colors.orange, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Active Order',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: isDarkMode ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Status: ${order.status.name} - #${order.id.substring(0, 8).toUpperCase()}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: isDarkMode ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pushNamed('/order-status'),
              child: Text(
                'Track',
                style: GoogleFonts.poppins(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategories(BuildContext context, bool isDarkMode) {
    final categories = [
      {
        'name': 'Hot Drinks',
        'icon': Icons.coffee,
        'route': '/hot-drinks',
        'image':
            'https://res.cloudinary.com/dok8w6cmc/image/upload/v1760516941/download__7_-removebg-preview_rsvrqx.png',
      },
      {
        'name': 'Cold Drinks',
        'icon': Icons.local_drink,
        'route': '/cold-drinks',
        'image':
            'https://res.cloudinary.com/dok8w6cmc/image/upload/v1760516941/8272917_gmlx5t.png',
      },
      {
        'name': 'Snacks',
        'icon': Icons.fastfood,
        'route': '/snacks',
        'image':
            'https://res.cloudinary.com/dok8w6cmc/image/upload/v1760516941/snacks_uh6x5s.png',
      },
      {
        'name': 'Games',
        'icon': Icons.casino,
        'route': '/games',
        'image':
            'https://res.cloudinary.com/dok8w6cmc/image/upload/v1760516941/games_x9hj7w.png',
      },
    ];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Categories',
            style: GoogleFonts.poppins(
              fontSize: 20,
              color: isDarkMode ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                return Container(
                  width: 120,
                  margin: const EdgeInsets.only(right: 16),
                  child: Card(
                    color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: InkWell(
                      onTap: () {
                        if (category['route'] == '/menu') {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) => MenuScreen(
                                category: category['name']
                                    .toString()
                                    .toLowerCase(),
                              ),
                            ),
                          );
                        } else {
                          Navigator.of(
                            context,
                          ).pushNamed(category['route'] as String);
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: category['image']! as String,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                width: 60,
                                height: 60,
                                color: isDarkMode
                                    ? Colors.grey[800]
                                    : Colors.grey[200],
                                child: Icon(
                                  category['icon'] as IconData,
                                  color: isDarkMode
                                      ? Colors.grey[600]
                                      : Colors.grey[400],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            category['name'].toString(),
                            style: GoogleFonts.poppins(
                              color: isDarkMode ? Colors.white : Colors.black,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularItems(BuildContext context, bool isDarkMode) {
    return Consumer<DrinkProvider>(
      builder: (ctx, drinkProvider, child) {
        if (drinkProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final popularDrinks = drinkProvider.popularDrinks;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Popular Items',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      color: isDarkMode ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pushNamed('/menu'),
                    child: Text(
                      'See All',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF00BCD4),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (popularDrinks.isEmpty)
                Center(
                  child: Text(
                    'No popular items available',
                    style: GoogleFonts.poppins(
                      color: isDarkMode ? Colors.white54 : Colors.grey[600],
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: popularDrinks.length,
                  itemBuilder: (ctx, index) {
                    final drink = popularDrinks[index];
                    final userProvider = Provider.of<UserProvider>(context);
                    final isSubscriptionDrink =
                        userProvider.hasActiveSubscription &&
                        userProvider.activeSubscription!.includedCategories
                            .contains(drink.category);

                    return DrinkCard(
                      drink: drink,
                      isSubscriptionDrink: isSubscriptionDrink,
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final TextEditingController _notesController = TextEditingController();
  bool _isPlacingOrder = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      if (cartProvider.orderNotes != null) {
        _notesController.text = cartProvider.orderNotes!;
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    // Prevent multiple taps
    if (_isPlacingOrder) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    cartProvider.setOrderNotes(_notesController.text.trim());

    if (!userProvider.hasActiveSubscription) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need an active subscription to place orders'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (cartProvider.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your cart is empty'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    for (var item in cartProvider.items) {
      final itemObj = item['item'];
      final isSubscriptionItem = item['isSubscriptionDrink'] as bool;

      if (!isSubscriptionItem) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All items must be covered by your subscription'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final subscription = userProvider.activeSubscription!;
      if (!subscription.includedCategories.contains(itemObj.category)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${itemObj.name} is not included in your subscription plan',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    final subscription = userProvider.activeSubscription!;
    int totalItems = 0;
    for (var item in cartProvider.items) {
      totalItems += item['quantity'] as int;
    }

    if (subscription.remainingDrinks < totalItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You only have ${subscription.remainingDrinks} drinks remaining in your subscription',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (context) => AlertDialog(
        backgroundColor: userProvider.isDarkMode
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        title: Text(
          'Confirm Order',
          style: GoogleFonts.poppins(
            color: userProvider.isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to place this order?',
              style: GoogleFonts.poppins(
                color: userProvider.isDarkMode
                    ? Colors.white70
                    : Colors.grey[600],
              ),
            ),
            if (_notesController.text.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Order Notes:',
                style: GoogleFonts.poppins(
                  color: userProvider.isDarkMode ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _notesController.text.trim(),
                style: GoogleFonts.poppins(
                  color: userProvider.isDarkMode
                      ? Colors.white70
                      : Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: userProvider.isDarkMode
                    ? Colors.white54
                    : Colors.grey[600],
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Set loading state to prevent multiple submissions
    setState(() {
      _isPlacingOrder = true;
    });

    try {
      // Create a unique order ID to check for duplicates
      final orderTimestamp = fs.Timestamp.now();
      final orderRef = await fs.FirebaseFirestore.instance
          .collection('orders')
          .add({
            'userId': userProvider.uid,
            'userName': userProvider.name,
            'items': cartProvider.items.map((item) {
              final itemObj = item['item'];
              return {
                'name': itemObj.name,
                'price': itemObj.price,
                'quantity': item['quantity'],
                'customizations': item['customizations'],
                'type': item['type'],
              };
            }).toList(),
            'status': 'pending',
            'timestamp': orderTimestamp,
            'totalAmount': cartProvider.totalAmount,
            'notes': cartProvider.orderNotes,
            'isSubscriptionOrder': true,
          });

      // Update subscription drinks remaining
      await fs.FirebaseFirestore.instance
          .collection('subscriptions')
          .doc(subscription.id)
          .update({
            'remainingDrinks': subscription.remainingDrinks - totalItems,
          });

      // Clear cart and notes
      cartProvider.clearCart();
      _notesController.clear();

      // Navigate to order status screen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => OrderStatusScreen(orderId: orderRef.id),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to place order: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      // Reset loading state
      setState(() {
        _isPlacingOrder = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<UserProvider>(context).isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF121212)
          : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          'Your Cart',
          style: GoogleFonts.poppins(
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            Expanded(
              child: Consumer<CartProvider>(
                builder: (context, cartProvider, child) {
                  if (cartProvider.items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shopping_cart_outlined,
                            size: 80,
                            color: isDarkMode
                                ? Colors.white54
                                : Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Your cart is empty',
                            style: GoogleFonts.poppins(
                              color: isDarkMode
                                  ? Colors.white54
                                  : Colors.grey[600],
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () =>
                                Navigator.of(context).pushReplacementNamed('/'),
                            child: const Text('Browse Menu'),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      Card(
                        color: isDarkMode
                            ? const Color(0xFF1E1E1E)
                            : Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Order Notes',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _notesController,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  hintText:
                                      'Add special instructions for your order (e.g., "No sugar", "Extra hot", "Without mint")',
                                  hintStyle: TextStyle(
                                    color: isDarkMode
                                        ? Colors.white54
                                        : Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: isDarkMode
                                      ? const Color(0xFF2A2A2A)
                                      : Colors.grey[100],
                                  contentPadding: const EdgeInsets.all(16),
                                ),
                                style: TextStyle(
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black,
                                ),
                                onChanged: (value) {
                                  Provider.of<CartProvider>(
                                    context,
                                    listen: false,
                                  ).setOrderNotes(value.trim());
                                },
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Your notes will be sent to the kitchen staff',
                                style: GoogleFonts.poppins(
                                  color: isDarkMode
                                      ? Colors.white54
                                      : Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...cartProvider.items.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        return _buildCartItem(item, index, isDarkMode);
                      }).toList(),
                    ],
                  );
                },
              ),
            ),
            Consumer<CartProvider>(
              builder: (context, cartProvider, child) {
                if (cartProvider.items.isEmpty) {
                  return const SizedBox.shrink();
                }

                return Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      if (cartProvider.orderNotes != null &&
                          cartProvider.orderNotes!.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00BCD4).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF00BCD4).withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.note,
                                color: const Color(0xFF00BCD4),
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Notes: ${cartProvider.orderNotes}',
                                  style: GoogleFonts.poppins(
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                    fontSize: 12,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total',
                            style: GoogleFonts.poppins(
                              color: isDarkMode ? Colors.white : Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '\$${cartProvider.totalAmount.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF00BCD4),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isPlacingOrder ? null : _placeOrder,
                          child: _isPlacingOrder
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text('Placing Order...'),
                                  ],
                                )
                              : const Text('Place Order'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartItem(Map<String, dynamic> item, int index, bool isDarkMode) {
    final itemObj = item['item'];
    final quantity = item['quantity'] as int;
    final isSubscriptionItem = item['isSubscriptionDrink'] as bool;
    final itemType = item['type'] as String;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: itemObj.imageUrl,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: 60,
                  height: 60,
                  color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                  child: Icon(
                    itemType == 'drink' ? Icons.local_cafe : Icons.fastfood,
                    color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    itemObj.name,
                    style: GoogleFonts.poppins(
                      color: isDarkMode ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isSubscriptionItem
                        ? 'FREE'
                        : '\$${itemObj.price.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      color: isSubscriptionItem
                          ? Colors.purple
                          : const Color(0xFF00BCD4),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.remove,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  onPressed: () {
                    Provider.of<CartProvider>(
                      context,
                      listen: false,
                    ).updateQuantity(index, quantity - 1);
                  },
                ),
                Text(
                  '$quantity',
                  style: GoogleFonts.poppins(
                    color: isDarkMode ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.add,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  onPressed: () {
                    Provider.of<CartProvider>(
                      context,
                      listen: false,
                    ).updateQuantity(index, quantity + 1);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class OrderStatusScreen extends StatefulWidget {
  final String? orderId;

  const OrderStatusScreen({super.key, this.orderId});

  @override
  State<OrderStatusScreen> createState() => _OrderStatusScreenState();
}

class _OrderStatusScreenState extends State<OrderStatusScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  Order? _order;
  StreamSubscription<DocumentSnapshot>? _orderSubscription;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.orderId != null) {
        _setupOrderListener();
      } else {
        final orderProvider = Provider.of<OrderProvider>(
          context,
          listen: false,
        );
        _order = orderProvider.activeOrder;
      }
    });
  }

  void _setupOrderListener() {
    if (widget.orderId == null) return;

    _orderSubscription = fs.FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .snapshots()
        .listen(
          (DocumentSnapshot snapshot) {
            if (snapshot.exists) {
              setState(() {
                _order = Order.fromFirestore(snapshot);
              });
            }
          },
          onError: (error) {
            debugPrint("Error listening to order updates: $error");
          },
        );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _orderSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<UserProvider>(context).isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF121212)
          : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          'Order Status',
          style: GoogleFonts.poppins(
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: _order == null
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF00BCD4)),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${_order!.id.substring(0, 8).toUpperCase()}',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        color: isDarkMode ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildStatusTimeline(isDarkMode),
                    const SizedBox(height: 24),
                    _buildOrderItems(isDarkMode),
                    const SizedBox(height: 24),
                    _buildOrderDetails(isDarkMode),
                    const SizedBox(height: 24),
                    if (_order!.status != OrderStatus.completed &&
                        _order!.status != OrderStatus.cancelled)
                      _buildChatButton(),
                    if (_order!.status == OrderStatus.completed &&
                        _order!.drinkPhoto == null)
                      _buildPhotoButton(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatusTimeline(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Status',
            style: GoogleFonts.poppins(
              fontSize: 18,
              color: isDarkMode ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: OrderStatus.values.map((status) {
              final isActive = _order!.status.index >= status.index;
              final isCurrent = _order!.status == status;

              return Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xFF00BCD4) : Colors.grey,
                        shape: BoxShape.circle,
                        border: isCurrent
                            ? Border.all(color: Colors.white, width: 2)
                            : null,
                      ),
                      child: Icon(
                        _getStatusIcon(status),
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      status.name.capitalize(),
                      style: GoogleFonts.poppins(
                        color: isActive
                            ? (isDarkMode ? Colors.white : Colors.black)
                            : Colors.grey,
                        fontSize: 12,
                        fontWeight: isCurrent
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (isCurrent) ...[
                      const SizedBox(height: 4),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00BCD4),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF00BCD4).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Live updates enabled',
                  style: GoogleFonts.poppins(
                    color: isDarkMode ? Colors.white70 : Colors.grey[700],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItems(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Items',
            style: GoogleFonts.poppins(
              fontSize: 18,
              color: isDarkMode ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _order!.items.length,
            itemBuilder: (context, index) {
              final item = _order!.items[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${item['quantity']}x ${item['name']}',
                        style: GoogleFonts.poppins(
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    Text(
                      '\$${(item['price'] * item['quantity']).toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF00BCD4),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetails(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Details',
            style: GoogleFonts.poppins(
              fontSize: 18,
              color: isDarkMode ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order Time',
                style: GoogleFonts.poppins(
                  color: isDarkMode ? Colors.white70 : Colors.grey[600],
                ),
              ),
              Text(
                DateFormat(
                  'MMM dd, yyyy HH:mm',
                ).format(_order!.timestamp.toDate()),
                style: GoogleFonts.poppins(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_order!.estimatedTime != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Estimated Time',
                  style: GoogleFonts.poppins(
                    color: isDarkMode ? Colors.white70 : Colors.grey[600],
                  ),
                ),
                Text(
                  _order!.estimatedTime!,
                  style: GoogleFonts.poppins(
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
          if (_order!.tableNumber != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Table Number',
                  style: GoogleFonts.poppins(
                    color: isDarkMode ? Colors.white70 : Colors.grey[600],
                  ),
                ),
                Text(
                  _order!.tableNumber!,
                  style: GoogleFonts.poppins(
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
          if (_order!.notes != null && _order!.notes!.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Special Instructions',
                      style: GoogleFonts.poppins(
                        color: isDarkMode ? Colors.white70 : Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BCD4).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _order!.notes!,
                    style: GoogleFonts.poppins(
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: GoogleFonts.poppins(
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '\$${_order!.totalAmount.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF00BCD4),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChatButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => ChangeNotifierProvider(
                create: (_) => ChatProvider(),
                child: ChatScreen(
                  orderId: _order!.id,
                  userName: _order!.userName,
                ),
              ),
            ),
          );
        },
        icon: const Icon(Icons.chat),
        label: const Text('Chat with Staff'),
      ),
    );
  }

  Widget _buildPhotoButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.of(context).pushNamed(
            '/drink-photo',
            arguments: {
              'drinkId': _order!.items.first['id'],
              'orderId': _order!.id,
            },
          );
        },
        icon: const Icon(Icons.camera_alt),
        label: const Text('Take Photo with Your Drink'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00BCD4),
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Icons.access_time;
      case OrderStatus.preparing:
        return Icons.blender;
      case OrderStatus.ready:
        return Icons.fastfood;
      case OrderStatus.completed:
        return Icons.check_circle;
      case OrderStatus.cancelled:
        return Icons.cancel;
    }
  }
}

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      Provider.of<OrderProvider>(
        context,
        listen: false,
      ).fetchOrderHistory(userProvider.uid);
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<UserProvider>(context).isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF121212)
          : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          'Order History',
          style: GoogleFonts.poppins(
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Consumer<OrderProvider>(
          builder: (context, orderProvider, child) {
            if (orderProvider.isLoading) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF00BCD4)),
              );
            }

            if (orderProvider.orderHistory.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history_outlined,
                      size: 80,
                      color: isDarkMode ? Colors.white54 : Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No order history yet',
                      style: GoogleFonts.poppins(
                        color: isDarkMode ? Colors.white54 : Colors.grey[600],
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () =>
                          Navigator.of(context).pushReplacementNamed('/'),
                      child: const Text('Browse Menu'),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: orderProvider.orderHistory.length,
              itemBuilder: (context, index) {
                final order = orderProvider.orderHistory[index];
                return _buildOrderCard(order, isDarkMode);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildOrderCard(Order order, bool isDarkMode) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => OrderStatusScreen(orderId: order.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order #${order.id.substring(0, 8).toUpperCase()}',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order.status).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      order.status.name.toUpperCase(),
                      style: GoogleFonts.poppins(
                        color: _getStatusColor(order.status),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Items: ${order.items.length}',
                style: GoogleFonts.poppins(
                  color: isDarkMode ? Colors.white70 : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Total: \$${order.totalAmount.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF00BCD4),
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (order.notes != null && order.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Notes: ${order.notes!}',
                  style: GoogleFonts.poppins(
                    color: isDarkMode ? Colors.white54 : Colors.grey[500],
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: isDarkMode ? Colors.white54 : Colors.grey[500],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat(
                      'MMM dd, yyyy HH:mm',
                    ).format(order.timestamp.toDate()),
                    style: GoogleFonts.poppins(
                      color: isDarkMode ? Colors.white54 : Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.preparing:
        return Colors.blue;
      case OrderStatus.ready:
        return Colors.green;
      case OrderStatus.completed:
        return Colors.purple;
      case OrderStatus.cancelled:
        return Colors.red;
    }
  }
}

class MenuScreen extends StatefulWidget {
  final String? category;

  const MenuScreen({super.key, this.category});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  bool _showSurpriseMe = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    if (widget.category != null) {
      _selectedCategory = widget.category!;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DrinkProvider>(context, listen: false).fetchDrinks();
      Provider.of<SnackProvider>(context, listen: false).fetchSnacks();
      Provider.of<SubscriptionProvider>(context, listen: false).fetchPlans();

      // Check if we should show "Surprise Me" option
      final loyaltyProvider = Provider.of<LoyaltyProvider>(
        context,
        listen: false,
      );
      if (loyaltyProvider.orderHistory.isNotEmpty) {
        setState(() {
          _showSurpriseMe = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  List<dynamic> _filterItems(List<dynamic> items) {
    List<dynamic> filtered = items;

    if (_selectedCategory != 'All') {
      filtered = filtered
          .where((item) => item.category == _selectedCategory)
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (item) =>
                item.name.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<UserProvider>(context).isDarkMode;
    final drinkProvider = Provider.of<DrinkProvider>(context);
    final snackProvider = Provider.of<SnackProvider>(context);
    final loyaltyProvider = Provider.of<LoyaltyProvider>(context);

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF121212)
          : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          'Menu',
          style: GoogleFonts.poppins(
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Surprise Me button
            if (_showSurpriseMe)
              Container(
                margin: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: () {
                    final surpriseDrinkId = loyaltyProvider.getSurpriseDrink();
                    if (surpriseDrinkId != null) {
                      final surpriseDrink = drinkProvider.drinks
                          .where((drink) => drink.id == surpriseDrinkId)
                          .firstOrNull;

                      if (surpriseDrink != null) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) => DrinkDetailScreen(
                              drink: surpriseDrink,
                              isSurpriseMe: true,
                            ),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Surprise Me!'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search drinks and snacks...',
                      hintStyle: TextStyle(
                        color: isDarkMode ? Colors.white54 : Colors.grey[600],
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: const Color(0xFF00BCD4),
                      ),
                      filled: true,
                      fillColor: isDarkMode
                          ? const Color(0xFF2A2A2A)
                          : Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 50,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: ['All', 'hot_drinks', 'cold_drinks', 'snacks']
                          .map((category) {
                            final displayCategory = category == 'All'
                                ? 'All'
                                : category.replaceAll('_', ' ').capitalize();
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: FilterChip(
                                label: Text(displayCategory),
                                selected: _selectedCategory == category,
                                onSelected: (selected) => setState(
                                  () => _selectedCategory = selected
                                      ? category
                                      : 'All',
                                ),
                                backgroundColor: isDarkMode
                                    ? const Color(0xFF2A2A2A)
                                    : Colors.grey[100],
                                selectedColor: const Color(0xFF00BCD4),
                                checkmarkColor: Colors.white,
                                labelStyle: TextStyle(
                                  color: _selectedCategory == category
                                      ? Colors.white
                                      : (isDarkMode
                                            ? Colors.white
                                            : Colors.black),
                                ),
                              ),
                            );
                          })
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Consumer2<DrinkProvider, SnackProvider>(
                builder: (context, drinkProvider, snackProvider, child) {
                  if (drinkProvider.isLoading || snackProvider.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF00BCD4),
                      ),
                    );
                  }

                  final allItems = [
                    ...drinkProvider.drinks,
                    ...snackProvider.snacks,
                  ];
                  final filteredItems = _filterItems(allItems);

                  if (filteredItems.isEmpty) {
                    return Center(
                      child: Text(
                        'No items found.',
                        style: GoogleFonts.poppins(
                          color: isDarkMode ? Colors.white54 : Colors.grey[600],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      final userProvider = Provider.of<UserProvider>(context);

                      if (item.runtimeType.toString() == 'Drink') {
                        final drink = item as Drink;
                        final isSubscriptionDrink =
                            userProvider.hasActiveSubscription &&
                            userProvider.activeSubscription!.includedCategories
                                .contains(drink.category);

                        return DrinkCard(
                          drink: drink,
                          isSubscriptionDrink: isSubscriptionDrink,
                        );
                      } else {
                        final snack = item as Snack;
                        final isSubscriptionSnack =
                            userProvider.hasActiveSubscription &&
                            userProvider.activeSubscription!.includedCategories
                                .contains(snack.category);

                        return SnackCard(
                          snack: snack,
                          isSubscriptionSnack: isSubscriptionSnack,
                        );
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _saveNameAndContinue() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter your name!')));
      return;
    }
    try {
      await Provider.of<UserProvider>(
        context,
        listen: false,
      ).signInAnonymously(_nameController.text.trim());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to sign in: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF121212), Color(0xFF2A2A2A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Mini Cafe',
                    style: GoogleFonts.pacifico(
                      fontSize: 60,
                      color: const Color(0xFF00BCD4),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Your favorite drinks, delivered.',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 50),
                  Card(
                    elevation: 10,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    color: const Color(0xFF1E1E1E),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          Text(
                            'Welcome! Let\'s get to know you.',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _nameController,
                            style: const TextStyle(
                              color: Color.fromARGB(255, 0, 0, 0),
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Your Name',
                              labelStyle: TextStyle(
                                color: Color.fromARGB(137, 0, 0, 0),
                              ),
                              border: OutlineInputBorder(),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.white54),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Color(0xFF00BCD4),
                                ),
                              ),
                            ),
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: 20),
                          Consumer<UserProvider>(
                            builder: (ctx, userProvider, child) {
                              return userProvider.isLoading
                                  ? const CircularProgressIndicator(
                                      color: Color(0xFF00BCD4),
                                    )
                                  : SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF00BCD4,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 15,
                                          ),
                                        ),
                                        onPressed: _saveNameAndContinue,
                                        child: Text(
                                          'Start Ordering',
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final isDarkMode = userProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF121212)
          : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          'Profile',
          style: GoogleFonts.poppins(
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        iconTheme: IconThemeData(
          color: isDarkMode ? Colors.white : Colors.black,
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              CircleAvatar(
                radius: 50,
                backgroundColor: const Color(0xFF00BCD4),
                child: Text(
                  userProvider.name.isNotEmpty
                      ? userProvider.name[0].toUpperCase()
                      : 'U',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                userProvider.name,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Loyalty Points: ${userProvider.loyaltyPoints}',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: const Color(0xFF00BCD4),
                ),
              ),
              const SizedBox(height: 32),
              _buildProfileOption(
                icon: Icons.card_membership,
                title: 'Coffee Passport',
                isDarkMode: isDarkMode,
                onTap: () => Navigator.of(context).pushNamed('/loyalty'),
              ),
              _buildProfileOption(
                icon: Icons.casino,
                title: 'Games & Rewards',
                isDarkMode: isDarkMode,
                onTap: () => Navigator.of(context).pushNamed('/games'),
              ),
              _buildProfileOption(
                icon: Icons.subscriptions,
                title: 'My Subscriptions',
                isDarkMode: isDarkMode,
                onTap: () => Navigator.of(context).pushNamed('/subscriptions'),
              ),
              _buildProfileOption(
                icon: Icons.history,
                title: 'Order History',
                isDarkMode: isDarkMode,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => const OrderHistoryScreen(),
                  ),
                ),
              ),
              _buildProfileOption(
                icon: Icons.dark_mode,
                title: 'Dark Mode',
                isDarkMode: isDarkMode,
                trailing: Switch(
                  value: isDarkMode,
                  onChanged: (value) {
                    userProvider.toggleTheme();
                  },
                  activeColor: const Color(0xFF00BCD4),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await userProvider.signOut();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: Text(
                    'Sign Out',
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    required bool isDarkMode,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey[50],
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF00BCD4)),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        trailing: trailing,
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String orderId;
  final String userName;

  const ChatScreen({super.key, required this.orderId, required this.userName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textController = TextEditingController();
  late String _currentUserId;
  late String _currentUserName;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (mounted) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      _currentUserId = userProvider.uid;
      _currentUserName = userProvider.name;

      Provider.of<ChatProvider>(
        context,
        listen: false,
      ).fetchMessages(widget.orderId);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_textController.text.trim().isEmpty) return;
    Provider.of<ChatProvider>(context, listen: false).sendMessage(
      widget.orderId,
      _textController.text,
      _currentUserId,
      _currentUserName,
    );
    _textController.clear();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.minScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildMessage(ChatMessage message) {
    final isMe = message.senderId == _currentUserId;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFF00BCD4) : Colors.grey[300],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isMe
                      ? const Radius.circular(16)
                      : const Radius.circular(4),
                  bottomRight: isMe
                      ? const Radius.circular(4)
                      : const Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.senderName,
                    style: GoogleFonts.lato(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isMe ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message.text,
                    style: GoogleFonts.lato(
                      color: isMe ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('HH:mm').format(message.timestamp),
                    style: GoogleFonts.lato(
                      fontSize: 8,
                      color: isMe ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(
          'Chat with Staff',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E1E1E),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: Provider.of<ChatProvider>(
                context,
                listen: false,
              ).getMessagesStream(widget.orderId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data!;
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  itemCount: messages.length,
                  itemBuilder: (ctx, index) => _buildMessage(messages[index]),
                );
              },
            ),
          ),
          _buildMessageComposer(),
        ],
      ),
    );
  }

  Widget _buildMessageComposer() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      color: const Color(0xFF1E1E1E),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(color: Colors.white54),
                border: InputBorder.none,
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _sendMessage,
            color: const Color(0xFF00BCD4),
          ),
        ],
      ),
    );
  }
}

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SubscriptionProvider>(context, listen: false).fetchPlans();
      Provider.of<UserProvider>(context, listen: false).refreshSubscription();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(
          'Subscriptions',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFF1E1E1E),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCurrentSubscription(),
              const SizedBox(height: 32),
              _buildSubscriptionPlans(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentSubscription() {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        if (!userProvider.hasActiveSubscription) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.withOpacity(0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.orange,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'No Active Subscription',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Subscribe to one of our plans below to enjoy unlimited drinks',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          );
        }

        final subscription = userProvider.activeSubscription!;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.purple.withOpacity(0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.card_membership,
                    color: Colors.purple,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Active Subscription',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                subscription.planType,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${subscription.remainingDrinks} of ${subscription.maxDrinks} drinks remaining',
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                'Valid until: ${DateFormat('MMM dd, yyyy').format(subscription.endDate.toDate())}',
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSubscriptionPlans() {
    return Consumer<SubscriptionProvider>(
      builder: (ctx, subscriptionProvider, _) {
        if (subscriptionProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final paidPlans = subscriptionProvider.plans
            .where((plan) => plan.price > 0)
            .toList();

        if (paidPlans.isEmpty) {
          return Center(
            child: Text(
              'No subscription plans available',
              style: GoogleFonts.poppins(color: Colors.white54),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Available Plans',
              style: GoogleFonts.poppins(
                fontSize: 20,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: paidPlans.length,
              itemBuilder: (ctx, index) {
                final plan = paidPlans[index];
                return _buildPlanCard(plan);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildPlanCard(SubscriptionPlan plan) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color(0xFF1E1E1E),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  plan.name,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '\$${plan.price.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: const Color(0xFF00BCD4),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              plan.description,
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildPlanFeature(
                    icon: Icons.calendar_today,
                    text: '${plan.durationInDays} days',
                  ),
                ),
                Expanded(
                  child: _buildPlanFeature(
                    icon: Icons.local_drink,
                    text: '${plan.maxDrinks} drinks',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Included Categories:',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: plan.includedCategories
                  .map(
                    (category) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00BCD4).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        category.replaceAll('_', ' ').capitalize(),
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF00BCD4),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final userProvider = Provider.of<UserProvider>(
                    context,
                    listen: false,
                  );
                  final success =
                      await Provider.of<SubscriptionProvider>(
                        context,
                        listen: false,
                      ).purchaseSubscription(
                        plan.id,
                        userProvider.uid,
                        userProvider.name,
                      );

                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Subscription request sent for approval'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to request subscription'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: const Text('Request Subscription'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanFeature({required IconData icon, required String text}) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF00BCD4), size: 20),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70),
        ),
      ],
    );
  }
}

class HotDrinksScreen extends StatelessWidget {
  const HotDrinksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<UserProvider>(context).isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF121212)
          : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          'Hot Drinks',
          style: GoogleFonts.poppins(
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      ),
      body: Consumer<DrinkProvider>(
        builder: (context, drinkProvider, child) {
          final hotDrinks = drinkProvider.drinks
              .where((drink) => drink.category == 'hot_drinks')
              .toList();

          if (drinkProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (hotDrinks.isEmpty) {
            return Center(
              child: Text(
                'No hot drinks available',
                style: GoogleFonts.poppins(
                  color: isDarkMode ? Colors.white54 : Colors.grey[600],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: hotDrinks.length,
            itemBuilder: (context, index) {
              final drink = hotDrinks[index];
              final userProvider = Provider.of<UserProvider>(context);
              final isSubscriptionDrink =
                  userProvider.hasActiveSubscription &&
                  userProvider.activeSubscription!.includedCategories.contains(
                    drink.category,
                  );

              return DrinkCard(
                drink: drink,
                isSubscriptionDrink: isSubscriptionDrink,
              );
            },
          );
        },
      ),
    );
  }
}

class ColdDrinksScreen extends StatelessWidget {
  const ColdDrinksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<UserProvider>(context).isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF121212)
          : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          'Cold Drinks',
          style: GoogleFonts.poppins(
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      ),
      body: Consumer<DrinkProvider>(
        builder: (context, drinkProvider, child) {
          final coldDrinks = drinkProvider.drinks
              .where((drink) => drink.category == 'cold_drinks')
              .toList();

          if (drinkProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (coldDrinks.isEmpty) {
            return Center(
              child: Text(
                'No cold drinks available',
                style: GoogleFonts.poppins(
                  color: isDarkMode ? Colors.white54 : Colors.grey[600],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: coldDrinks.length,
            itemBuilder: (context, index) {
              final drink = coldDrinks[index];
              final userProvider = Provider.of<UserProvider>(context);
              final isSubscriptionDrink =
                  userProvider.hasActiveSubscription &&
                  userProvider.activeSubscription!.includedCategories.contains(
                    drink.category,
                  );

              return DrinkCard(
                drink: drink,
                isSubscriptionDrink: isSubscriptionDrink,
              );
            },
          );
        },
      ),
    );
  }
}

// New SnacksScreen
class SnacksScreen extends StatelessWidget {
  const SnacksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<UserProvider>(context).isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF121212)
          : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          'Snacks',
          style: GoogleFonts.poppins(
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      ),
      body: Consumer<SnackProvider>(
        builder: (context, snackProvider, child) {
          if (snackProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snackProvider.snacks.isEmpty) {
            return Center(
              child: Text(
                'No snacks available',
                style: GoogleFonts.poppins(
                  color: isDarkMode ? Colors.white54 : Colors.grey[600],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: snackProvider.snacks.length,
            itemBuilder: (context, index) {
              final snack = snackProvider.snacks[index];
              final userProvider = Provider.of<UserProvider>(context);
              final isSubscriptionSnack =
                  userProvider.hasActiveSubscription &&
                  userProvider.activeSubscription!.includedCategories.contains(
                    snack.category,
                  );

              return SnackCard(
                snack: snack,
                isSubscriptionSnack: isSubscriptionSnack,
              );
            },
          );
        },
      ),
    );
  }
}

// New LoyaltyScreen for Coffee Passport
class LoyaltyScreen extends StatefulWidget {
  const LoyaltyScreen({super.key});

  @override
  State<LoyaltyScreen> createState() => _LoyaltyScreenState();
}

class _LoyaltyScreenState extends State<LoyaltyScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _tabController = TabController(length: 2, vsync: this);
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<UserProvider>(context).isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF121212)
          : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          'Coffee Passport',
          style: GoogleFonts.poppins(
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00BCD4),
          labelColor: const Color(0xFF00BCD4),
          unselectedLabelColor: isDarkMode ? Colors.white54 : Colors.grey[600],
          tabs: const [
            Tab(text: 'Stamps'),
            Tab(text: 'Rewards'),
          ],
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: TabBarView(
          controller: _tabController,
          children: [_buildStampsTab(isDarkMode), _buildRewardsTab(isDarkMode)],
        ),
      ),
    );
  }

  Widget _buildStampsTab(bool isDarkMode) {
    return Consumer<LoyaltyProvider>(
      builder: (context, loyaltyProvider, child) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Stamps Collected',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          color: isDarkMode ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${loyaltyProvider.collectedStamps.length}',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          color: const Color(0xFF00BCD4),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: loyaltyProvider.collectedStamps.length / 50,
                    backgroundColor: isDarkMode
                        ? Colors.grey[700]
                        : Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF00BCD4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${50 - loyaltyProvider.collectedStamps.length} more to Brew Master',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: isDarkMode ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Collection',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        color: isDarkMode ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (loyaltyProvider.collectedStamps.isEmpty)
                      Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.loyalty,
                              size: 80,
                              color: isDarkMode
                                  ? Colors.white54
                                  : Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No stamps yet. Order drinks to collect stamps!',
                              style: GoogleFonts.poppins(
                                color: isDarkMode
                                    ? Colors.white54
                                    : Colors.grey[600],
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    else
                      Expanded(
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 5,
                                childAspectRatio: 1,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                          itemCount: 50,
                          itemBuilder: (context, index) {
                            final isCollected =
                                index < loyaltyProvider.collectedStamps.length;
                            return Container(
                              decoration: BoxDecoration(
                                color: isCollected
                                    ? const Color(0xFF00BCD4)
                                    : isDarkMode
                                    ? Colors.grey[700]
                                    : Colors.grey[300],
                                shape: BoxShape.circle,
                              ),
                              child: isCollected
                                  ? const Icon(Icons.check, color: Colors.white)
                                  : null,
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRewardsTab(bool isDarkMode) {
    return Consumer<LoyaltyProvider>(
      builder: (context, loyaltyProvider, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Points Balance',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            color: isDarkMode ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${loyaltyProvider.totalPoints}',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            color: const Color(0xFF00BCD4),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: (loyaltyProvider.totalPoints % 2000) / 2000,
                      backgroundColor: isDarkMode
                          ? Colors.grey[700]
                          : Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF00BCD4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${2000 - (loyaltyProvider.totalPoints % 2000)} points to free month',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: isDarkMode ? Colors.white70 : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (loyaltyProvider.hasFreeMonth)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.card_giftcard,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'You have a free month subscription available!',
                                style: GoogleFonts.poppins(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'How to Earn Points',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildRewardItem(
                icon: Icons.local_cafe,
                title: 'Try a New Drink',
                description: 'Collect stamps for trying new drinks',
                points: '4-10 points',
                isDarkMode: isDarkMode,
              ),
              _buildRewardItem(
                icon: Icons.casino,
                title: 'Play Games',
                description: 'Try your luck with Spin & Win or Dice',
                points: '1-8 points',
                isDarkMode: isDarkMode,
              ),
              _buildRewardItem(
                icon: Icons.repeat,
                title: 'Daily Order',
                description: 'Order something every day',
                points: '5 points',
                isDarkMode: isDarkMode,
              ),
              _buildRewardItem(
                icon: Icons.share,
                title: 'Share with Friends',
                description: 'Share your favorite drinks',
                points: '7 points',
                isDarkMode: isDarkMode,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRewardItem({
    required IconData icon,
    required String title,
    required String description,
    required String points,
    required bool isDarkMode,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF00BCD4).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF00BCD4), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: isDarkMode ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: isDarkMode ? Colors.white70 : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            points,
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: const Color(0xFF00BCD4),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// New GamesScreen for Spin and Win, Dice
class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen>
    with TickerProviderStateMixin {
  late AnimationController _spinController;
  late AnimationController _diceController;
  late Animation<double> _spinAnimation;
  late Animation<double> _diceAnimation;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _diceController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _spinAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _spinController, curve: Curves.easeOut));
    _diceAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _diceController, curve: Curves.easeOut));

    // Initialize game state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<GameProvider>(context, listen: false).initializeGameState();
    });
  }

  @override
  void dispose() {
    _spinController.dispose();
    _diceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<UserProvider>(context).isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF121212)
          : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          'Games & Rewards',
          style: GoogleFonts.poppins(
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Consumer<GameProvider>(
              builder: (context, gameProvider, child) {
                return Column(
                  children: [
                    _buildSpinToWin(gameProvider, isDarkMode),
                    const SizedBox(height: 24),
                    _buildDiceRoll(gameProvider, isDarkMode),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            Consumer<LoyaltyProvider>(
              builder: (context, loyaltyProvider, child) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Points',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          color: isDarkMode ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${loyaltyProvider.totalPoints} points',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          color: const Color(0xFF00BCD4),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: (loyaltyProvider.totalPoints % 2000) / 2000,
                        backgroundColor: isDarkMode
                            ? Colors.grey[700]
                            : Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF00BCD4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${2000 - (loyaltyProvider.totalPoints % 2000)} points to free month',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: isDarkMode ? Colors.white70 : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpinToWin(GameProvider gameProvider, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Spin & Win',
            style: GoogleFonts.poppins(
              fontSize: 20,
              color: isDarkMode ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _spinAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _spinAnimation.value * 2 * pi * 5,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BCD4),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00BCD4).withOpacity(0.5),
                        spreadRadius: 5,
                        blurRadius: 15,
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Wheel segments
                      ...List.generate(8, (index) {
                        final angle = (index * 45) * (pi / 180);
                        final isEven = index % 2 == 0;
                        return Transform.rotate(
                          angle: angle,
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              color: isEven
                                  ? Colors.white.withOpacity(0.3)
                                  : Colors.transparent,
                            ),
                          ),
                        );
                      }),
                      // Center circle
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.casino,
                          color: Color(0xFF00BCD4),
                        ),
                      ),
                      // Pointer
                      Positioned(
                        top: -10,
                        left: 90,
                        child: Container(
                          width: 20,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          if (gameProvider.lastSpinResult > 0)
            Text(
              'You won ${gameProvider.lastSpinResult} points!',
              style: GoogleFonts.poppins(
                fontSize: 18,
                color: const Color(0xFF00BCD4),
                fontWeight: FontWeight.bold,
              ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: gameProvider.canPlaySpin
                  ? () {
                      _spinController.reset();
                      _spinController.forward();
                      gameProvider.playSpin();
                    }
                  : null,
              child: Text(
                gameProvider.canPlaySpin ? 'Spin' : 'Come Back Tomorrow',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiceRoll(GameProvider gameProvider, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Roll the Dice',
            style: GoogleFonts.poppins(
              fontSize: 20,
              color: isDarkMode ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _diceAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _diceAnimation.value * 2 * pi * 3,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildDiceFace(
                      gameProvider.lastDiceResult > 0
                          ? gameProvider.lastDiceResult
                          : 1,
                      isDarkMode,
                    ),
                    _buildDiceFace(
                      gameProvider.lastDiceResult > 0
                          ? gameProvider.lastDiceResult
                          : 1,
                      isDarkMode,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          if (gameProvider.lastDiceResult > 0)
            Text(
              'You won ${gameProvider.lastDiceResult * 2} points!',
              style: GoogleFonts.poppins(
                fontSize: 18,
                color: const Color(0xFF00BCD4),
                fontWeight: FontWeight.bold,
              ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: gameProvider.canPlayDice
                  ? () {
                      _diceController.reset();
                      _diceController.forward();
                      gameProvider.playDice();
                    }
                  : null,
              child: Text(
                gameProvider.canPlayDice ? 'Roll' : 'Come Back Tomorrow',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiceFace(int value, bool isDarkMode) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: Center(
        child: Text(
          value.toString(),
          style: GoogleFonts.poppins(
            fontSize: 36,
            color: isDarkMode ? Colors.black : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// New DrinkPhotoScreen for taking photos with drinks
class DrinkPhotoScreen extends StatefulWidget {
  final String drinkId;
  final String orderId;

  const DrinkPhotoScreen({
    super.key,
    required this.drinkId,
    required this.orderId,
  });

  @override
  State<DrinkPhotoScreen> createState() => _DrinkPhotoScreenState();
}

class _DrinkPhotoScreenState extends State<DrinkPhotoScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _image;
  bool _isUploading = false;

  // Cloudinary configuration
  late CloudinaryPublic _cloudinary;

  @override
  void initState() {
    super.initState();
    // Initialize CloudinaryPublic with your credentials (replace 'unsigned_preset' with your actual upload preset)
    _cloudinary = CloudinaryPublic('dok8w6cmc', 'unsigned_preset');
  }

  Future<void> _uploadPhoto() async {
    if (_image == null) return;

    setState(() => _isUploading = true);

    try {
      // 1. Upload to Cloudinary
      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(_image!.path, folder: 'mini_cafe/drink_photos'),
      );
      final downloadUrl = response.secureUrl;
      final publicId = response.publicId;

      // Get the drink name
      final drinkProvider = Provider.of<DrinkProvider>(context, listen: false);
      final drink = drinkProvider.drinks.firstWhere(
        (d) => d.id == widget.drinkId,
        orElse: () => Drink(
          id: widget.drinkId,
          name: 'Unknown Drink',
          category: '',
          price: 0.0,
          imageUrl: '',
        ),
      );

      // 2. Create a pending photo request instead of directly updating the order
      await fs.FirebaseFirestore.instance.collection('photo_requests').add({
        'userId': FirebaseAuth.instance.currentUser?.uid,
        'userName': Provider.of<UserProvider>(context, listen: false).name,
        'drinkId': widget.drinkId,
        'drinkName': drink.name,
        'orderId': widget.orderId,
        'photoUrl': downloadUrl,
        'cloudinaryPublicId': publicId,
        'status': 'pending', // Set status to pending
        'uploadedAt': fs.Timestamp.now(),
      });

      // 3. Award points
      final loyaltyProvider = Provider.of<LoyaltyProvider>(
        context,
        listen: false,
      );
      loyaltyProvider._totalPoints += 5;
      await loyaltyProvider._saveLoyaltyData();

      setState(() => _isUploading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo submitted for review! You earned 5 points.'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _isUploading = false);
      debugPrint("Error uploading photo: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit photo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Note: Image deletion should be handled by backend
  Future<void> _deletePhoto(String publicId) async {
    try {
      // Store publicId to be deleted by backend
      await fs.FirebaseFirestore.instance.collection('delete_requests').add({
        'publicId': publicId,
        'timestamp': fs.Timestamp.now(),
        'status': 'pending',
      });
      debugPrint('Delete request created for image: $publicId');
    } catch (e) {
      debugPrint('Error requesting image deletion: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<UserProvider>(context).isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF121212)
          : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          'Photo with Your Drink',
          style: GoogleFonts.poppins(
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Capture Your Moment',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      color: isDarkMode ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Take a photo with your drink to share with the community and earn loyalty points!',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: isDarkMode ? Colors.white70 : Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_image != null)
              Container(
                height: 300,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(File(_image!.path), fit: BoxFit.cover),
                ),
              )
            else
              Container(
                height: 300,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.camera_alt,
                      size: 80,
                      color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No photo taken yet',
                      style: GoogleFonts.poppins(
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final XFile? image = await _picker.pickImage(
                        source: ImageSource.camera,
                      );
                      if (image != null) {
                        setState(() {
                          _image = image;
                        });
                      }
                    },
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take Photo'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final XFile? image = await _picker.pickImage(
                        source: ImageSource.gallery,
                      );
                      if (image != null) {
                        setState(() {
                          _image = image;
                        });
                      }
                    },
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Choose from Gallery'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_image != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _uploadPhoto,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00BCD4),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: _isUploading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Uploading to Cloudinary...',
                              style: GoogleFonts.poppins(fontSize: 14),
                            ),
                          ],
                        )
                      : const Text('Upload Photo'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// New DrinkDetailScreen with Surprise Me option
class DrinkDetailScreen extends StatefulWidget {
  final Drink drink;
  final bool isSubscriptionDrink;
  final bool isSurpriseMe;

  const DrinkDetailScreen({
    super.key,
    required this.drink,
    this.isSubscriptionDrink = false,
    this.isSurpriseMe = false,
  });

  @override
  State<DrinkDetailScreen> createState() => _DrinkDetailScreenState();
}

class _DrinkDetailScreenState extends State<DrinkDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  Map<String, String> _selectedCustomizations = {};
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _addToCart() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    if (!userProvider.hasActiveSubscription) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need an active subscription to add items to cart'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final subscription = userProvider.activeSubscription!;
    if (!subscription.includedCategories.contains(widget.drink.category)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This drink is not included in your subscription plan'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (subscription.remainingDrinks <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have no remaining drinks in your subscription'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    for (int i = 0; i < _quantity; i++) {
      Provider.of<CartProvider>(context, listen: false).addItem(
        widget.drink,
        customizations: _selectedCustomizations,
        isSubscriptionDrink: true,
      );
    }

    // Add stamp to loyalty
    final loyaltyProvider = Provider.of<LoyaltyProvider>(
      context,
      listen: false,
    );
    loyaltyProvider.addStamp(widget.drink.id);
    loyaltyProvider.addOrderToHistory(widget.drink.id);

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<UserProvider>(context).isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF121212)
          : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          widget.isSurpriseMe ? 'Your Surprise Drink!' : widget.drink.name,
          style: GoogleFonts.poppins(
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Hero(
                    tag: widget.drink.id,
                    child: CachedNetworkImage(
                      imageUrl: widget.drink.imageUrl,
                      width: double.infinity,
                      height: 250,
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (widget.isSurpriseMe)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.auto_awesome,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Surprise!',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            widget.drink.name,
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              color: isDarkMode ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (widget.isSubscriptionDrink)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.purple.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'FREE',
                              style: GoogleFonts.poppins(
                                color: Colors.purple,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        else
                          Text(
                            '\$${widget.drink.price.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              color: const Color(0xFF00BCD4),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.drink.description.isNotEmpty
                          ? widget.drink.description
                          : 'Delicious drink made with quality ingredients',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: isDarkMode ? Colors.white70 : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: isDarkMode ? Colors.white54 : Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.drink.preparationTime} min',
                          style: GoogleFonts.poppins(
                            color: isDarkMode
                                ? Colors.white54
                                : Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.category,
                          size: 16,
                          color: isDarkMode ? Colors.white54 : Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.drink.category
                              .replaceAll('_', ' ')
                              .capitalize(),
                          style: GoogleFonts.poppins(
                            color: isDarkMode
                                ? Colors.white54
                                : Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (widget.drink.userPhotos.isNotEmpty) ...[
                      Text(
                        'Community Photos',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          color: isDarkMode ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: widget.drink.userPhotos.length,
                          itemBuilder: (context, index) {
                            return Container(
                              width: 100,
                              margin: const EdgeInsets.only(right: 8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: widget.drink.userPhotos[index],
                                  fit: BoxFit.cover,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    if (widget.drink.customizations.isNotEmpty)
                      _buildCustomizations(),
                    const SizedBox(height: 24),
                    _buildQuantitySelector(),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _addToCart,
                        child: const Text('Add to Cart'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // In DrinkDetailScreen, add this method to display approved photos

  Widget _buildCustomizations() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Customizations',
          style: GoogleFonts.poppins(
            fontSize: 18,
            color: Provider.of<UserProvider>(context).isDarkMode
                ? Colors.white
                : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...widget.drink.customizations.map((option) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                option.name,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Provider.of<UserProvider>(context).isDarkMode
                      ? Colors.white
                      : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              ...option.choices.map((choice) {
                return RadioListTile<String>(
                  title: Text(
                    choice,
                    style: GoogleFonts.poppins(
                      color: Provider.of<UserProvider>(context).isDarkMode
                          ? Colors.white
                          : Colors.black,
                    ),
                  ),
                  value: choice,
                  groupValue: _selectedCustomizations[option.id],
                  onChanged: (value) {
                    setState(() {
                      _selectedCustomizations[option.id] = value!;
                    });
                  },
                  activeColor: const Color(0xFF00BCD4),
                );
              }),
              const SizedBox(height: 16),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildQuantitySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quantity',
          style: GoogleFonts.poppins(
            fontSize: 18,
            color: Provider.of<UserProvider>(context).isDarkMode
                ? Colors.white
                : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove, color: Color(0xFF00BCD4)),
              onPressed: () {
                if (_quantity > 1) {
                  setState(() {
                    _quantity--;
                  });
                }
              },
            ),
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF00BCD4).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '$_quantity',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF00BCD4),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add, color: Color(0xFF00BCD4)),
              onPressed: () {
                setState(() {
                  _quantity++;
                });
              },
            ),
          ],
        ),
      ],
    );
  }
}

// New SnackDetailScreen
class SnackDetailScreen extends StatefulWidget {
  final Snack snack;
  final bool isSubscriptionSnack;

  const SnackDetailScreen({
    super.key,
    required this.snack,
    this.isSubscriptionSnack = false,
  });

  @override
  State<SnackDetailScreen> createState() => _SnackDetailScreenState();
}

class _SnackDetailScreenState extends State<SnackDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _addToCart() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    if (!userProvider.hasActiveSubscription) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need an active subscription to add items to cart'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final subscription = userProvider.activeSubscription!;
    if (!subscription.includedCategories.contains(widget.snack.category)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This snack is not included in your subscription plan'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (subscription.remainingDrinks <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have no remaining drinks in your subscription'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    for (int i = 0; i < _quantity; i++) {
      Provider.of<CartProvider>(
        context,
        listen: false,
      ).addItem(widget.snack, isSubscriptionDrink: true);
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<UserProvider>(context).isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF121212)
          : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          widget.snack.name,
          style: GoogleFonts.poppins(
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: widget.snack.id,
                child: CachedNetworkImage(
                  imageUrl: widget.snack.imageUrl,
                  width: double.infinity,
                  height: 250,
                  fit: BoxFit.cover,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            widget.snack.name,
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              color: isDarkMode ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (widget.isSubscriptionSnack)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.purple.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'FREE',
                              style: GoogleFonts.poppins(
                                color: Colors.purple,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        else
                          Text(
                            '\$${widget.snack.price.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              color: const Color(0xFF00BCD4),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.snack.description.isNotEmpty
                          ? widget.snack.description
                          : 'Delicious snack made with quality ingredients',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: isDarkMode ? Colors.white70 : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          Icons.fastfood,
                          size: 16,
                          color: isDarkMode ? Colors.white54 : Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.snack.calories} calories',
                          style: GoogleFonts.poppins(
                            color: isDarkMode
                                ? Colors.white54
                                : Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.category,
                          size: 16,
                          color: isDarkMode ? Colors.white54 : Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.snack.category
                              .replaceAll('_', ' ')
                              .capitalize(),
                          style: GoogleFonts.poppins(
                            color: isDarkMode
                                ? Colors.white54
                                : Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (widget.snack.allergens.isNotEmpty) ...[
                      Text(
                        'Allergens',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          color: isDarkMode ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.snack.allergens.map((allergen) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              allergen,
                              style: GoogleFonts.poppins(
                                color: Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                    ],
                    if (widget.snack.userPhotos.isNotEmpty) ...[
                      Text(
                        'Community Photos',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          color: isDarkMode ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: widget.snack.userPhotos.length,
                          itemBuilder: (context, index) {
                            return Container(
                              width: 100,
                              margin: const EdgeInsets.only(right: 8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: widget.snack.userPhotos[index],
                                  fit: BoxFit.cover,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    _buildQuantitySelector(),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _addToCart,
                        child: const Text('Add to Cart'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuantitySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quantity',
          style: GoogleFonts.poppins(
            fontSize: 18,
            color: Provider.of<UserProvider>(context).isDarkMode
                ? Colors.white
                : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove, color: Color(0xFF00BCD4)),
              onPressed: () {
                if (_quantity > 1) {
                  setState(() {
                    _quantity--;
                  });
                }
              },
            ),
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF00BCD4).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '$_quantity',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF00BCD4),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add, color: Color(0xFF00BCD4)),
              onPressed: () {
                setState(() {
                  _quantity++;
                });
              },
            ),
          ],
        ),
      ],
    );
  }
}

// Extension method for string capitalization
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
