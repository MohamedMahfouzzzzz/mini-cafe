import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/order.dart';
import '../providers/user_provider.dart';

class OrderHistoryScreen extends StatelessWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = Provider.of<UserProvider>(context).uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Orders',
          style: GoogleFonts.pacifico(fontSize: 28, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF6F4E37),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<fs.QuerySnapshot>(
        stream: fs.FirebaseFirestore.instance
            .collection('orders')
            .where('userId', isEqualTo: uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'No past orders.',
                style: GoogleFonts.lato(fontSize: 18),
              ),
            );
          }

          final orders = snapshot.data!.docs
              .map((doc) => Order.fromFirestore(doc))
              .toList();

          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (ctx, i) {
              final order = orders[i];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                child: ListTile(
                  title: Text(
                    'Order #${order.id.substring(0, 8).toUpperCase()}',
                    style: GoogleFonts.lato(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${order.timestamp.toDate()} - ${order.items.length} items',
                  ),
                  trailing: Chip(
                    label: Text(order.status.name.toUpperCase()),
                    backgroundColor: _getStatusColor(order.status),
                    labelStyle: const TextStyle(color: Colors.white),
                  ),
                ),
              );
            },
          );
        },
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
        return Colors.purple;
      case OrderStatus.completed:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
    }
  }
}
