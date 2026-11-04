import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/services/auth_service.dart';
import 'home/home_screen.dart';
import 'properties/properties_screen.dart';
import 'experiences/experiences_screen.dart';
import 'profile/profile_screen.dart';

// ✅ 1. DEKLARASI GLOBAL KEY DI LUAR CLASS
// Ini memungkinkan MainShell "berbicara" langsung dengan HomeScreen
final GlobalKey<HomeScreenState> homeScreenKey = GlobalKey<HomeScreenState>();

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  int _profileRefreshKey = 0;

  void onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;

      if (index == 3) {
        _profileRefreshKey++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ 2. PASANG KEY PADA HOMESCREEN
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomeScreen(key: homeScreenKey), // <-- Key dipasang di sini
          const PropertiesScreen(),
          const ExperiencesScreen(),
          ProfileScreen(key: ValueKey('profile_$_profileRefreshKey')),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1), // Gunakan withOpacity(0.1) jika withValues error di versi Flutter lama
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.primaryGold,
          unselectedItemColor: AppColors.textGrey,
          selectedLabelStyle: const TextStyle(
            fontFamily: 'Lato',
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'Lato',
            fontSize: 12,
          ),
          onTap: (index) {
            // A. Cek Login untuk Tab Profile
            if (index == 3 && !AuthService.isLoggedIn) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Please log in to access your Mulia Privilege profile and points.',
                  ),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: AppColors.darkCharcoal,
                  duration: Duration(seconds: 2),
                ),
              );
              return; // Batalkan perpindahan tab
            }

            // ✅ B. TRIGGER REFRESH AVATAR SAAT TAB HOME DIKLIK
            if (index == 0 && AuthService.isLoggedIn) {
              // Memanggil fungsi public refreshAvatar() di HomeScreen
              homeScreenKey.currentState?.refreshAvatar();
            }

            // C. Jalankan perpindahan tab normal
            onItemTapped(index);
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.business_outlined),
              activeIcon: Icon(Icons.business),
              label: 'Properties',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.auto_awesome_outlined),
              activeIcon: Icon(Icons.auto_awesome),
              label: 'Experiences',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}