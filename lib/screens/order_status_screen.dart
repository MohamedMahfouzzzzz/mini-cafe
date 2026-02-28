import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/order.dart';
import '../providers/order_provider.dart';
import '../providers/user_provider.dart';
import '../providers/chat_provider.dart'; // <-- ADD IMPORT
import 'chat_screen.dart'; // <-- ADD IMPORT

class OrderStatusScreen extends StatelessWidget {
  const OrderStatusScreen({super.key});

  Widget _buildStatusTile(String title, bool isActive) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isActive ? Colors.green : Colors.grey.shade300,
        child: Icon(
          isActive ? Icons.check : Icons.hourglass_empty,
          color: Colors.white,
        ),
      ),
      title: Text(
        title,
        style: GoogleFonts.lato(
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Order Status',
          style: GoogleFonts.pacifico(fontSize: 28, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF6F4E37),
        automaticallyImplyLeading: false,
      ),
      body: Consumer2<OrderProvider, UserProvider>(
        builder: (ctx, orderProvider, userProvider, child) {
          if (orderProvider.activeOrder == null) {
            return const Center(child: Text('No active order.'));
          }

          return StreamBuilder<Order?>(
            stream: orderProvider.orderStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data == null) {
                return const Center(child: Text('Order not found.'));
              }

              final order = snapshot.data!;

              // Award points when the order is completed for the first time
              if (order.status == OrderStatus.completed) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  userProvider.addLoyaltyPoints(10);
                });
              }

              return Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #${order.id.substring(0, 8).toUpperCase()}',
                          style: GoogleFonts.lato(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildStatusTile(
                          'Order Placed',
                          order.status.index >= OrderStatus.pending.index,
                        ),
                        _buildStatusTile(
                          'Preparing',
                          order.status.index >= OrderStatus.preparing.index,
                        ),
                        _buildStatusTile(
                          'Ready for Pickup',
                          order.status.index >= OrderStatus.ready.index,
                        ),
                        _buildStatusTile(
                          'Completed',
                          order.status.index >= OrderStatus.completed.index,
                        ),
                        const Spacer(),
                        if (order.estimatedTime != null)
                          Center(
                            child: Text(
                              'Estimated Time: ${order.estimatedTime}',
                              style: GoogleFonts.lato(
                                fontSize: 16,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        const SizedBox(height: 80), // Add space for the FAB
                      ],
                    ),
                  ),
                  // --- CHAT FLOATING ACTION BUTTON ---
                  if (order.status != OrderStatus.completed)
                    Positioned(
                      bottom: 20,
                      right: 20,
                      child: FloatingActionButton.extended(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) => ChangeNotifierProvider(
                                create: (_) => ChatProvider(),
                                child: ChatScreen(
                                  orderId: order.id,
                                  userName: "Admin",
                                ), // Chatting with "Admin"
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chat),
                        label: const Text('Chat with us'),
                        backgroundColor: const Color(0xFF6F4E37),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
