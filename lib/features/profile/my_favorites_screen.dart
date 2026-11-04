import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/favorite_service.dart';
import '../../core/services/spa_service_service.dart';
import '../../core/services/restaurant_service.dart';

// ✅ TAMBAHKAN DUA BARIS INI:
import '../../core/widgets/shimmer_card.dart';
import '../../core/widgets/empty_state_widget.dart';

class MyFavoritesScreen extends StatefulWidget {
  const MyFavoritesScreen({super.key});

  @override
  State<MyFavoritesScreen> createState() => _MyFavoritesScreenState();
}

class _MyFavoritesScreenState extends State<MyFavoritesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _allFavorites = [];
  List<Map<String, dynamic>> _displayFavorites = [];

  final List<String> _tabs = ['All', 'Spa', 'Dining'];
  String _selectedTab = 'All';

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'IDR ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _selectedTab = _tabs[_tabController.index]);
        _filterFavorites();
      }
    });
    _fetchFavorites();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchFavorites() async {
    setState(() => _isLoading = true);

    try {
      // 1. Ambil semua favorite dari tabel favorites
      final favorites = await FavoriteService.getUserFavorites();

      if (favorites.isEmpty) {
        setState(() {
          _allFavorites = [];
          _displayFavorites = [];
          _isLoading = false;
        });
        return;
      }

      // 2. Ambil detail item dari tabel yang sesuai
      final List<Map<String, dynamic>> detailedFavorites = [];

      for (final fav in favorites) {
        final itemType = fav['item_type'] as String;
        final itemId = fav['item_id'] as String;

        try {
          if (itemType == 'spa') {
            final spaServices = await SpaServiceService.getActiveServices();
            final spa = spaServices.firstWhere(
              (s) => s.id == itemId,
              orElse: () => throw Exception('Spa not found'),
            );

            detailedFavorites.add({
              'item_type': itemType,
              'item_id': itemId,
              'name': spa.name,
              'image_url': spa.imageUrl,
              'price': spa.price,
              'description': spa.description ?? '',
              'category': spa.category ?? '',
            });
          } else if (itemType == 'dining') {
            final restaurant = await RestaurantService.getRestaurantById(
              itemId,
            );

            // ✅ TAMBAHKAN NULL CHECK
            if (restaurant == null) {
              throw Exception('Restaurant not found');
            }

            detailedFavorites.add({
              'item_type': itemType,
              'item_id': itemId,
              'name': restaurant['name'],
              'image_url': restaurant['cover_image'],
              'cuisine_type': restaurant['cuisine_type'] ?? '',
              'description': restaurant['description'] ?? '',
              'operating_hours': restaurant['operating_hours'] ?? '',
            });
          }
        } catch (e) {
          print('❌ Error fetching detail for $itemType $itemId: $e');
          // Skip item yang tidak ditemukan
        }
      }

      setState(() {
        _allFavorites = detailedFavorites;
        _displayFavorites = detailedFavorites;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error fetching favorites: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load favorites'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _filterFavorites() {
    if (_selectedTab == 'All') {
      setState(() => _displayFavorites = _allFavorites);
    } else {
      final type = _selectedTab.toLowerCase();
      setState(() {
        _displayFavorites = _allFavorites
            .where((f) => f['item_type'] == type)
            .toList();
      });
    }
  }

    Future<void> _removeFavorite(String itemType, String itemId) async {
    // 1. Optimistic UI update (Hapus dari list lokal agar UI langsung responsif)
    setState(() {
      _allFavorites.removeWhere((f) => f['item_type'] == itemType && f['item_id'] == itemId);
      _filterFavorites();
    });

    try {
      // 2. Kirim ke database
      // Kita tidak perlu menyimpan return value. 
      // Jika berhasil dihapus, toggleFavorite akan return false (tanpa error).
      // Jika GAGAL di database, toggleFavorite akan melempar error (throw).
      await FavoriteService.toggleFavorite(itemType, itemId);

      // 3. Jika kode sampai di sini, berarti BERHASIL (tidak ada error)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed from favorites'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // 4. Jika BENAR-BENAR GAGAL (misal: mati internet, error RLS)
      print('❌ [UI] Gagal menghapus favorite: $e');
      if (mounted) {
        // Kembalikan data dari database (rollback UI)
        _fetchFavorites(); 
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to remove favorite'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Logika Tombol Empty State yang Dinamis
    String? buttonText;
    VoidCallback? onButtonPressed;

    if (_selectedTab == 'All') {
      buttonText = 'Explore Experiences';
      onButtonPressed = () => context.go('/');
    } else if (_selectedTab == 'Spa') {
      buttonText = 'Browse Spa';
      onButtonPressed = () => context.go('/spa');
    } else if (_selectedTab == 'Dining') {
      // Sesuaikan dengan route dining Anda jika berbeda, atau biarkan '/'
      buttonText = 'Browse Dining'; 
      onButtonPressed = () => context.go('/'); 
    }

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        backgroundColor: AppColors.darkCharcoal,
        foregroundColor: Colors.white,
        title: const Text(
          'My Favorites',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryGold,
          labelColor: AppColors.primaryGold,
          unselectedLabelColor: Colors.white70,
          tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
        ),
      ),
      body: _isLoading
          ? ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 3, // Tampilkan 3 shimmer cards
              itemBuilder: (context, index) => const ShimmerCard(),
            )
          : _displayFavorites.isEmpty
              ? EmptyStateWidget(
                  icon: Icons.favorite_border,
                  title: _selectedTab == 'All' ? 'No Favorites Yet' : 'No $_selectedTab Favorites',
                  subtitle: _selectedTab == 'All' 
                      ? 'Start exploring our spa and dining experiences to save your favorites.' 
                      : 'You haven\'t saved any $_selectedTab favorites yet.',
                  buttonText: buttonText,
                  onButtonPressed: onButtonPressed,
                )
              : RefreshIndicator(
                  onRefresh: _fetchFavorites,
                  color: AppColors.primaryGold,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _displayFavorites.length,
                    itemBuilder: (context, index) {
                      final fav = _displayFavorites[index];
                      return _buildFavoriteCard(fav);
                    },
                  ),
                ),
    );
  }

  // Widget _buildEmptyState() {
  //   return Center(
  //     child: Padding(
  //       padding: const EdgeInsets.all(32),
  //       child: Column(
  //         mainAxisAlignment: MainAxisAlignment.center,
  //         children: [
  //           Icon(
  //             Icons.favorite_border,
  //             size: 80,
  //             color: AppColors.textGrey.withOpacity(0.3),
  //           ),
  //           const SizedBox(height: 16),
  //           const Text(
  //             'No Favorites Yet',
  //             style: TextStyle(
  //               fontFamily: 'Playfair Display',
  //               fontSize: 20,
  //               fontWeight: FontWeight.bold,
  //               color: AppColors.darkCharcoal,
  //             ),
  //           ),
  //           const SizedBox(height: 8),
  //           Text(
  //             _selectedTab == 'All'
  //                 ? 'Start exploring our spa and dining experiences to save your favorites.'
  //                 : 'No $_selectedTab favorites yet.',
  //             textAlign: TextAlign.center,
  //             style: const TextStyle(
  //               fontFamily: 'Lato',
  //               fontSize: 14,
  //               color: AppColors.textGrey,
  //               height: 1.5,
  //             ),
  //           ),
  //           if (_selectedTab == 'All') ...[
  //             const SizedBox(height: 24),
  //             ElevatedButton.icon(
  //               onPressed: () => context.go('/'),
  //               icon: const Icon(Icons.explore, size: 18),
  //               label: const Text('EXPLORE EXPERIENCES'),
  //               style: ElevatedButton.styleFrom(
  //                 backgroundColor: AppColors.primaryGold,
  //                 foregroundColor: Colors.white,
  //                 padding: const EdgeInsets.symmetric(
  //                   horizontal: 24,
  //                   vertical: 12,
  //                 ),
  //               ),
  //             ),
  //           ],
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget _buildFavoriteCard(Map<String, dynamic> fav) {
    final itemType = fav['item_type'] as String;
    final itemId = fav['item_id'] as String;
    final name = fav['name'] as String;
    final imageUrl = fav['image_url'] as String?;
    final description = fav['description'] as String;

    final isSpa = itemType == 'spa';
    final primaryColor = isSpa
        ? const Color(0xFF8B7355)
        : const Color(0xFF6B8E23);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (isSpa) {
            context.push('/spa/$itemId');
          } else {
            context.push('/restaurant/$itemId');
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Stack(
              children: [
                if (imageUrl != null && imageUrl.isNotEmpty)
                  Image.network(
                    imageUrl,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 180,
                      color: AppColors.darkCharcoal,
                      child: Icon(
                        isSpa ? Icons.spa : Icons.restaurant,
                        size: 64,
                        color: Colors.white24,
                      ),
                    ),
                  )
                else
                  Container(
                    height: 180,
                    color: AppColors.darkCharcoal,
                    child: Icon(
                      isSpa ? Icons.spa : Icons.restaurant,
                      size: 64,
                      color: Colors.white24,
                    ),
                  ),

                // Gradient overlay
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.6),
                      ],
                    ),
                  ),
                ),

                // Type Badge
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isSpa ? 'SPA' : 'DINING',
                      style: const TextStyle(
                        fontFamily: 'Lato',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),

                // Remove Button
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(
                      Icons.favorite,
                      color: Colors.red,
                      size: 28,
                    ),
                    onPressed: () => _removeFavorite(itemType, itemId),
                    tooltip: 'Remove from favorites',
                  ),
                ),
              ],
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    name,
                    style: const TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkCharcoal,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Category or Cuisine
                  if (isSpa &&
                      fav['category'] != null &&
                      (fav['category'] as String).isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        fav['category'],
                        style: TextStyle(
                          fontFamily: 'Lato',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                    ),

                  if (!isSpa &&
                      fav['cuisine_type'] != null &&
                      (fav['cuisine_type'] as String).isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        fav['cuisine_type'],
                        style: TextStyle(
                          fontFamily: 'Lato',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                    ),

                  const SizedBox(height: 8),

                  // Description
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Lato',
                      fontSize: 13,
                      color: AppColors.textGrey,
                      height: 1.4,
                    ),
                  ),

                  if (isSpa) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    // Price
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Starting from',
                          style: TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 11,
                            color: AppColors.textGrey,
                          ),
                        ),
                        Text(
                          _currencyFormat.format(fav['price']),
                          style: TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
