import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/user_provider.dart';
import '../providers/order_provider.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _promoController = TextEditingController();
  Map<String, dynamic>? _appliedPromo;
  bool _isVerifyingPromo = false;

  Future<void> _verifyPromo() async {
    if (_promoController.text.trim().isEmpty) return;

    setState(() => _isVerifyingPromo = true);
    final code = _promoController.text.trim();

    try {
      final snapshot = await fs.FirebaseFirestore.instance
          .collection('promotions')
          .where('code', isEqualTo: code.toUpperCase())
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        setState(() {
          _appliedPromo = snapshot.docs.first.data();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Promo code applied!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() => _appliedPromo = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid promo code.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error verifying code.')));
    } finally {
      setState(() => _isVerifyingPromo = false);
    }
  }

  double _calculateSubtotal() {
    // NOTE: This assumes your CartProvider calculates the price correctly.
    // If items have customizations, the provider needs to account for that.
    return Provider.of<CartProvider>(context, listen: false).totalAmount;
  }

  double _calculateDiscount(double subtotal) {
    if (_appliedPromo == null) return 0.0;
    final value = _appliedPromo!['value'];
    if (_appliedPromo!['type'] == 'percentage') {
      return subtotal * (value / 100);
    } else {
      return value;
    }
  }

  Future<void> _placeOrder(BuildContext context) async {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final user = Provider.of<UserProvider>(context, listen: false);

    if (cart.items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Your cart is empty!')));
      return;
    }

    final subtotal = _calculateSubtotal();
    final discount = _calculateDiscount(subtotal);
    final total = subtotal - discount;

    try {
      await fs.FirebaseFirestore.instance.collection('orders').add({
        'userId': user.uid,
        'userName': user.name,
        'items': cart.items
            .map((drink) => {'name': drink.name, 'price': drink.price})
            .toList(),
        'subtotal': subtotal,
        'discount': discount,
        'totalAmount': total,
        'promoCode': _appliedPromo?['code'],
        'status': 'pending',
        'timestamp': fs.Timestamp.now(),
      });

      cart.clearCart();
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/order-status',
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to place order: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final subtotal = _calculateSubtotal();
    final discount = _calculateDiscount(subtotal);
    final total = subtotal - discount;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Checkout',
          style: GoogleFonts.pacifico(fontSize: 28, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF6F4E37),
      ),
      body: Column(
        children: [
          Expanded(
            child: cart.items.isEmpty
                ? Center(
                    child: Text(
                      'Your cart is empty.',
                      style: GoogleFonts.lato(fontSize: 20),
                    ),
                  )
                : ListView.builder(
                    itemCount: cart.items.length,
                    itemBuilder: (ctx, i) {
                      final drink = cart.items[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 4,
                        ),
                        child: ListTile(
                          title: Text(drink.name),
                          subtitle: Text('\$${drink.price.toStringAsFixed(2)}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => Provider.of<CartProvider>(
                              context,
                              listen: false,
                            ).removeItem(drink),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // --- PROMO CODE SECTION ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _promoController,
                    decoration: InputDecoration(
                      labelText: 'Promo Code',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: _isVerifyingPromo
                          ? SizedBox(
                              // removed 'const'
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              icon: const Icon(Icons.local_offer),
                              onPressed: _verifyPromo,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // --- CHECKOUT SUMMARY ---
          Card(
            margin: const EdgeInsets.all(15),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSummaryRow('Subtotal', subtotal),
                  if (_appliedPromo != null)
                    _buildSummaryRow('Discount', -discount, isDiscount: true),
                  const Divider(),
                  _buildSummaryRow('Total', total, isTotal: true),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4ECDC4),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    onPressed: () => _placeOrder(context),
                    child: Text(
                      'Place Order',
                      style: GoogleFonts.lato(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
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

  Widget _buildSummaryRow(
    String label,
    double amount, {
    bool isDiscount = false,
    bool isTotal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.lato(
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: Colors.white,
            ),
          ),
          Text(
            isDiscount
                ? '-\$${amount.toStringAsFixed(2)}'
                : '\$${amount.toStringAsFixed(2)}',
            style: GoogleFonts.lato(
              fontSize: isTotal ? 18 : 16,
              fontWeight: FontWeight.bold,
              color: isDiscount
                  ? Colors.redAccent
                  : (isTotal ? const Color(0xFF4ECDC4) : Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
