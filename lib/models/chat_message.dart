import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;

  ChatMessage({
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
  });

  factory ChatMessage.fromFirestore(Map<String, dynamic> data) {
    final dynamic ts = data['timestamp'];
    DateTime parsedTimestamp;
    if (ts is Timestamp) {
      parsedTimestamp = ts.toDate();
    } else if (ts is DateTime) {
      parsedTimestamp = ts;
    } else if (ts is String) {
      parsedTimestamp = DateTime.tryParse(ts) ?? DateTime.now();
    } else {
      parsedTimestamp = DateTime.now();
    }

    return ChatMessage(
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? 'Unknown',
      text: data['text'] ?? '',
      timestamp: parsedTimestamp,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
