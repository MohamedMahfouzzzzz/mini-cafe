import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/drink.dart';
import '../providers/cart_provider.dart';

class DrinkDetailScreen extends StatelessWidget {
  final Drink drink;

  const DrinkDetailScreen({super.key, required this.drink});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          drink.name,
          style: GoogleFonts.pacifico(fontSize: 28, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF6F4E37),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: drink.id,
              child: CachedNetworkImage(
                imageUrl: drink.imageUrl,
                width: double.infinity,
                height: 300,
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    drink.name,
                    style: GoogleFonts.lato(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '\$${drink.price.toStringAsFixed(2)}',
                    style: GoogleFonts.lato(
                      fontSize: 22,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4ECDC4),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        Provider.of<CartProvider>(
                          context,
                          listen: false,
                        ).addItem(drink, customizations: {}); // empty map

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${drink.name} added to cart!'),
                          ),
                        );
                        Navigator.of(context).pop();
                      },

                      child: Text(
                        'Add to Cart',
                        style: GoogleFonts.lato(
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
