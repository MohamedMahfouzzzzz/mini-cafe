import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/drink.dart';
import '../providers/cart_provider.dart';

class DrinkCard extends StatelessWidget {
  final Drink drink;

  const DrinkCard({super.key, required this.drink});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CachedNetworkImage(
              imageUrl: drink.imageUrl,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              placeholder: (context, url) => const CircularProgressIndicator(),
              errorWidget: (context, url, error) => const Icon(Icons.error),
            ),
          ),
          title: Text(
            drink.name,
            style: GoogleFonts.lato(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            '\$${drink.price.toStringAsFixed(2)}',
            style: GoogleFonts.lato(color: Colors.grey[600]),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.add_circle, size: 30),
            color: drink.isInStock ? const Color(0xFF4ECDC4) : Colors.grey,
            onPressed: drink.isInStock
                ? () {
                    Provider.of<CartProvider>(
                      context,
                      listen: false,
                    ).addItem(drink, customizations: {}); // empty map

                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${drink.name} added to cart!'),
                        duration: const Duration(seconds: 2),
                        action: SnackBarAction(
                          label: 'UNDO',
                          onPressed: () => Provider.of<CartProvider>(
                            context,
                            listen: false,
                          ).removeItem(drink),
                        ),
                      ),
                    );
                  }
                : null, // Disable button if out of stock
          ),
        ),
      ),
    );
  }
}
