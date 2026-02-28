import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/chat_message.dart';
import '../providers/chat_provider.dart';
import '../providers/user_provider.dart'; // For customer app

class ChatScreen extends StatefulWidget {
  final String orderId;
  final String userName; // Customer's name

  const ChatScreen({super.key, required this.orderId, required this.userName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textController = TextEditingController();
  late String _currentUserId;
  late String _currentUserName;

  @override
  void initState() {
    super.initState();
    // Get user details
    if (mounted) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      _currentUserId = userProvider.uid;
      _currentUserName = userProvider.name;
    }
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
                color: isMe ? const Color(0xFF6F4E37) : Colors.grey[300],
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
      appBar: AppBar(
        title: Text(
          'Chat with ${widget.userName}',
          style: GoogleFonts.pacifico(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF6F4E37),
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
                  reverse: true, // To start from the bottom
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
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: const InputDecoration.collapsed(
                hintText: 'Type a message...',
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          IconButton(icon: const Icon(Icons.send), onPressed: _sendMessage),
        ],
      ),
    );
  }
}
