import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/services/auth_service.dart';
import 'home/home_screen.dart';
import 'properties/properties_screen.dart';
import 'experiences/experiences_screen.dart';
import 'profile/profile_screen.dart';

// ✅ 1. DEKLARASI GLOBAL KEY DI LUAR CLASS
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

  // ✅ 2. EKSTRAK LOGIKA NAVIGASI AGAR BISA DIPAKAI OLEH BOTTOM NAV & NAVIGATION RAIL
  void _handleNavigation(int index) {
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

    // B. TRIGGER REFRESH AVATAR SAAT TAB HOME DIKLIK
    if (index == 0 && AuthService.isLoggedIn) {
      homeScreenKey.currentState?.refreshAvatar();
    }

    // C. Jalankan perpindahan tab normal
    onItemTapped(index);
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 3. LAYOUTBUILDER UNTUK ADAPTIVE NAVIGATION
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 600;

        // --- DESKTOP & TABLET: Navigation Rail (Sisi Kiri) ---
        if (isDesktop) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _handleNavigation,
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: Colors.white,
                  selectedIconTheme: const IconThemeData(color: AppColors.primaryGold),
                  selectedLabelTextStyle: const TextStyle(
                    fontFamily: 'Lato',
                    color: AppColors.primaryGold,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  unselectedIconTheme: const IconThemeData(color: AppColors.textGrey),
                  unselectedLabelTextStyle: const TextStyle(
                    fontFamily: 'Lato',
                    color: AppColors.textGrey,
                    fontSize: 12,
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: Text('Home'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.business_outlined),
                      selectedIcon: Icon(Icons.business),
                      label: Text('Properties'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.auto_awesome_outlined),
                      selectedIcon: Icon(Icons.auto_awesome),
                      label: Text('Experiences'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(Icons.person),
                      label: Text('Profile'),
                    ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                // ✅ Konten Utama (IndexedStack tetap sama)
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: [
                      HomeScreen(key: homeScreenKey),
                      const PropertiesScreen(),
                      const ExperiencesScreen(),
                      ProfileScreen(key: ValueKey('profile_$_profileRefreshKey')),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // --- MOBILE: Bottom Navigation (Bawah) - TIDAK BERUBAH (PWA Safe) ---
        return Scaffold(
          body: IndexedStack(
            index: _selectedIndex,
            children: [
              HomeScreen(key: homeScreenKey),
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
                  color: Colors.black.withOpacity(0.1), // ✅ Diperbaiki dari withValues
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
              onTap: _handleNavigation, // ✅ Menggunakan method yang sama
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
      },
    );
  }
}