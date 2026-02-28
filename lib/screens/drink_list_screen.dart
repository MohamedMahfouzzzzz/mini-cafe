import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/drink_provider.dart';
import '../widgets/drink_card.dart';
import 'drink_detail_screen.dart';

class DrinkListScreen extends StatelessWidget {
  final String category;
  final String title;

  const DrinkListScreen({
    super.key,
    required this.category,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final allDrinks = Provider.of<DrinkProvider>(context).drinks;
    final categoryDrinks = (category == 'all')
        ? allDrinks
        : allDrinks.where((drink) => drink.category == category).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: GoogleFonts.pacifico(fontSize: 28, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF6F4E37),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: categoryDrinks.isEmpty
          ? const Center(child: Text('No drinks in this category yet.'))
          : ListView.builder(
              itemCount: categoryDrinks.length,
              itemBuilder: (ctx, index) {
                final drink = categoryDrinks[index];
                return GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => DrinkDetailScreen(drink: drink),
                    ),
                  ),
                  child: DrinkCard(drink: drink),
                );
              },
            ),
    );
  }
}
