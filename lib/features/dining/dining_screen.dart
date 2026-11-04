import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../shared_widgets/login_prompt_dialog.dart';
import 'reservation_screen.dart';

// Model Data Restoran
class Restaurant {
  final String name;
  final String cuisine;
  final String description;
  final String imageUrl;

  Restaurant({
    required this.name,
    required this.cuisine,
    required this.description,
    required this.imageUrl,
  });
}

final List<Restaurant> muliaRestaurants = [
  Restaurant(
    name: 'Table8',
    cuisine: 'Award-Winning Chinese',
    description: 'Experience the pinnacle of Chinese culinary artistry with panoramic ocean views.',
    imageUrl: 'https://images.unsplash.com/photo-1552566626-52f8b828add9?auto=format&fit=crop&w=800&q=80',
  ),
  Restaurant(
    name: 'Soleil',
    cuisine: 'Mediterranean',
    description: 'A vibrant all-day dining venue offering the finest Mediterranean flavors and ocean breezes.',
    imageUrl: 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=800&q=80',
  ),
  Restaurant(
    name: 'The Cafe',
    cuisine: 'International Buffet',
    description: 'A lavish spread of international and local Indonesian delicacies in an elegant setting.',
    imageUrl: 'https://images.unsplash.com/photo-1559339352-11d035aa65de?auto=format&fit=crop&w=800&q=80',
  ),
  Restaurant(
    name: 'Sky Bar',
    cuisine: 'Cocktails & Light Bites',
    description: 'Elevate your evening with handcrafted cocktails and breathtaking sunset views.',
    imageUrl: 'https://images.unsplash.com/photo-1514362545857-3bc16c4c7d1b?auto=format&fit=crop&w=800&q=80',
  ),
];

class DiningScreen extends StatelessWidget {
  const DiningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: CustomScrollView(
        slivers: [
          // Header Dining
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Mulia Dining',
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    'https://images.unsplash.com/photo-1550966871-3ed3cdb5ed0c?auto=format&fit=crop&w=1200&q=80',
                    fit: BoxFit.cover,
                  ),
                  // Gradient Overlay yang dibungkus Container
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // List Restoran
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final restaurant = muliaRestaurants[index];
                return _buildRestaurantCard(context, restaurant)
                    .animate()
                    .fadeIn(delay: (100 * index).ms)
                    .slideY(begin: 0.2, end: 0);
              }, childCount: muliaRestaurants.length),
            ),
          ),
        ],
      ),
    );
  }

  // TAMBAHKAN 'BuildContext context' di sini 👇
  Widget _buildRestaurantCard(BuildContext context, Restaurant restaurant) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Image.network(
              restaurant.imageUrl,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  restaurant.cuisine.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.primaryGold,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  restaurant.name,
                  style: const TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkCharcoal,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  restaurant.description,
                  style: const TextStyle(
                    fontFamily: 'Lato',
                    fontSize: 14,
                    color: AppColors.textGrey,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // Sekarang 'context' sudah dikenali! ✅
                    if (!AuthService.isLoggedIn) {
                      // Kirim "misi" ke dialog: Buka ReservationScreen dengan nama restoran ini setelah login
                      showLoginPromptDialog(context);
                    } else {
                      // Jika sudah login, langsung buka form
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReservationScreen(
                            restaurantName: restaurant.name,
                          ),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.darkCharcoal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    'Reserve a Table',
                    style: TextStyle(fontWeight: FontWeight.bold),
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
