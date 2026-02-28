import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import 'welcome_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Profile',
          style: GoogleFonts.pacifico(fontSize: 28, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF6F4E37),
      ),
      body: Center(
        child: Consumer<UserProvider>(
          builder: (ctx, userProvider, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Welcome, ${userProvider.name}',
                  style: GoogleFonts.lato(fontSize: 24),
                ),
                const SizedBox(height: 20),
                Text(
                  'Loyalty Points: ${userProvider.loyaltyPoints}',
                  style: GoogleFonts.lato(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),
                SwitchListTile(
                  title: const Text('Dark Mode'),
                  value: userProvider.isDarkMode,
                  onChanged: (value) {
                    userProvider.toggleTheme();
                  },
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () async {
                    await userProvider.signOut();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (ctx) => const WelcomeScreen(),
                        ),
                        (Route<dynamic> route) => false,
                      );
                    }
                  },
                  child: const Text(
                    'Sign Out',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
