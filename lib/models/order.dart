import 'package:cloud_firestore/cloud_firestore.dart' as fs;

enum OrderStatus { pending, preparing, ready, completed, cancelled }

class Order {
  final String id;
  final String userName;
  final List<Map<String, dynamic>> items;
  final OrderStatus status;
  final fs.Timestamp timestamp;
  final String? estimatedTime;

  Order({
    required this.id,
    required this.userName,
    required this.items,
    required this.status,
    required this.timestamp,
    this.estimatedTime,
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
    );
  }
}
