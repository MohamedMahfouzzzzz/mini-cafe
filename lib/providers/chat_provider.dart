import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/chat_message.dart';

class ChatProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<ChatMessage> _messages = [];
  bool _isLoading = false;

  List<ChatMessage> get messages => _messages;
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
