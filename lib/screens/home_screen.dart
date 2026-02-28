import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/drink_provider.dart';
import '../providers/user_provider.dart';
import '../providers/order_provider.dart';
import 'checkout_screen.dart';
import 'drink_list_screen.dart';
import 'order_history_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userName = Provider.of<UserProvider>(context).name;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8), // Light cream background
      appBar: AppBar(
        elevation: 0,
        title: Text(
          'Mini Cafe',
          style: GoogleFonts.pacifico(
            fontSize: 28,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: const Color(0xFF6F4E37),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF8B6F47), Color(0xFF6F4E37)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.history, color: Colors.white),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => const OrderHistoryScreen(),
                  ),
                );
              },
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Consumer<CartProvider>(
              builder: (_, cart, ch) => Badge(
                label: Text(
                  '${cart.itemCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: const Color(0xFFE5B88A),
                child: ch!,
              ),
              child: IconButton(
                icon: const Icon(Icons.shopping_cart, color: Colors.white),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (ctx) => const CheckoutScreen()),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: _HomeBody(userName: userName),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            icon: Icons.home,
            label: 'Home',
            isActive: true,
            onTap: () {},
          ),
          _buildNavItem(
            icon: Icons.local_cafe,
            label: 'Menu',
            isActive: false,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => const DrinkListScreen(
                    category: 'all',
                    title: 'All Drinks',
                  ),
                ),
              );
            },
          ),
          _buildNavItem(
            icon: Icons.shopping_cart,
            label: 'Cart',
            isActive: false,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => const CheckoutScreen()),
              );
            },
          ),
          _buildNavItem(
            icon: Icons.person,
            label: 'Profile',
            isActive: false,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isActive ? const Color(0xFF6F4E37) : Colors.grey,
            size: 28,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? const Color(0xFF6F4E37) : Colors.grey,
              fontSize: 12,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeBody extends HookWidget {
  final String userName;

  const _HomeBody({required this.userName});

  @override
  Widget build(BuildContext context) {
    useEffect(() {
      Future.microtask(
        () => Provider.of<DrinkProvider>(context, listen: false).fetchDrinks(),
      );
      return null;
    }, []);

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildWelcomeBanner(userName),
          _buildSpecialOffers(),
          _buildCategories(context),
          _buildPopularItems(context),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildWelcomeBanner(String userName) {
    return Container(
      height: 220,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.network(
              'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=1170&q=80',
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Container(
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.black.withOpacity(0.3),
                ],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, $userName!',
                  style: GoogleFonts.lato(
                    fontSize: 26,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'What would you like to drink today?',
                  style: GoogleFonts.lato(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialOffers() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Special Offers',
              style: GoogleFonts.lato(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF6F4E37),
              ),
            ),
          ),
          Container(
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: const LinearGradient(
                colors: [Color(0xFFE5B88A), Color(0xFFD4A574)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Summer Special',
                          style: GoogleFonts.lato(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Get 20% off on all cold drinks',
                          style: GoogleFonts.lato(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'SUMMER20',
                            style: GoogleFonts.lato(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF6F4E37),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Image.network(
                      'https://img.icons8.com/fluency/96/iced-coffee.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategories(BuildContext context) {
    return Consumer<DrinkProvider>(
      builder: (ctx, drinkProvider, child) {
        if (drinkProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Container(
          margin: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Categories',
                  style: GoogleFonts.lato(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF6F4E37),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _buildCategoryCard(
                      context,
                      title: 'Cold Drinks',
                      iconUrl:
                          'https://img.icons8.com/fluency/96/iced-coffee.png',
                      color: const Color(0xFF64B5F6),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const DrinkListScreen(
                            category: 'cold',
                            title: 'Cold Drinks',
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildCategoryCard(
                      context,
                      title: 'Hot Drinks',
                      iconUrl:
                          'https://img.icons8.com/?size=100&id=fZo41yg651Rr&format=png&color=000000',
                      color: const Color(0xFFFF8A65),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => const DrinkListScreen(
                            category: 'hot',
                            title: 'Hot Drinks',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryCard(
    BuildContext context, {
    required String title,
    required String iconUrl,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                color: color.withOpacity(0.2),
              ),
              child: Center(
                child: Image.network(iconUrl, width: 80, height: 80),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                title,
                style: GoogleFonts.lato(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF6F4E37),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopularItems(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Popular Items',
                  style: GoogleFonts.lato(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF6F4E37),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => const DrinkListScreen(
                          category: 'all',
                          title: 'All Drinks',
                        ),
                      ),
                    );
                  },
                  child: Text(
                    'See All',
                    style: GoogleFonts.lato(
                      fontSize: 14,
                      color: const Color(0xFF6F4E37),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 180,
            child: Consumer<DrinkProvider>(
              builder: (ctx, drinkProvider, child) {
                if (drinkProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Just showing placeholder items for now
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 3,
                  itemBuilder: (ctx, index) {
                    return _buildPopularItemCard(context, index);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularItemCard(BuildContext context, int index) {
    final List<Map<String, dynamic>> popularItems = [
      {
        'name': 'Iced Latte',
        'price': '\$4.50',
        'image': 'https://img.icons8.com/fluency/96/iced-coffee.png',
        'color': const Color(0xFF64B5F6),
      },
      {
        'name': 'Cappuccino',
        'price': '\$3.80',
        'image':
            'https://img.icons8.com/?size=100&id=fZo41yg651Rr&format=png&color=000000',
        'color': const Color(0xFFFF8A65),
      },
      {
        'name': 'Green Tea',
        'price': '\$3.20',
        'image': 'https://img.icons8.com/fluency/96/green-tea.png',
        'color': const Color(0xFF81C784),
      },
    ];

    final item = popularItems[index];

    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
              color: item['color'].withOpacity(0.2),
            ),
            child: Center(
              child: Image.network(item['image'], width: 60, height: 60),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'],
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF6F4E37),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item['price'],
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: item['color'],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
