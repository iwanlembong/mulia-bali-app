import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/restaurant_service.dart';
import '../../core/services/cart_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/favorite_service.dart'; // ✅ 1. TAMBAHKAN IMPORT INI
import '../../core/services/review_service.dart'; // ✅ TAMBAHKAN INI
import '../../core/widgets/review_modal.dart'; // ✅ TAMBAHKAN INI

class DiningDetailScreen extends StatefulWidget {
  final String restaurantId;

  const DiningDetailScreen({super.key, required this.restaurantId});

  @override
  State<DiningDetailScreen> createState() => _DiningDetailScreenState();
}

class _DiningDetailScreenState extends State<DiningDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _restaurant;
  List<Map<String, dynamic>> _menuItems = [];

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'IDR ',
    decimalDigits: 0,
  );

  // ✅ 2. STATE UNTUK FAVORITE
  bool _isFavorite = false;
  bool _isCheckingFavorite = true;

  // ✅ State untuk Review
  double _averageRating = 0.0;
  int _totalReviews = 0;
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoadingReviews = true;

  @override
  void initState() {
    super.initState();
    _checkFavoriteStatus(); // ✅ Cek status favorite saat halaman dibuka
    _fetchData();
    _fetchReviews(); // ✅ TAMBAHKAN INI
  }

  Future<void> _checkFavoriteStatus() async {
    final isFav = await FavoriteService.isFavorite(
      'dining',
      widget.restaurantId,
    );
    if (mounted) {
      setState(() {
        _isFavorite = isFav;
        _isCheckingFavorite = false;
      });
    }
  }

  // ✅ 3. METHOD TOGGLE FAVORITE (Optimistic UI Update)
  // ✅ DIPERBAIKI: Toggle Favorite tanpa Delay
  Future<void> _toggleFavorite() async {
    // 1. Simpan state lama untuk rollback jika gagal
    final previousState = _isFavorite;

    // 2. Update UI segera (Optimistic Update)
    setState(() => _isFavorite = !_isFavorite);

    try {
      // 3. Kirim ke database
      final newStatus = await FavoriteService.toggleFavorite(
        'dining',
        widget.restaurantId,
      );
      // Ganti 'spa' dengan 'dining' jika di dining_detail_screen.dart
      // Ganti widget.serviceId dengan widget.restaurantId jika di dining

      // 4. Jika status di database TIDAK sesuai dengan UI, sinkronkan
      if (mounted && newStatus != _isFavorite) {
        print(
          '⚠️ [UI] Status mismatch. Database: $newStatus | UI: $_isFavorite',
        );
        setState(() => _isFavorite = newStatus);
      }

      // 5. Tampilkan pesan sukses
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isFavorite ? 'Added to favorites ❤️' : 'Removed from favorites',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // 6. Jika error, kembalikan ke state sebelumnya
      print('❌ [UI] Toggle failed: $e');
      if (mounted) {
        setState(() => _isFavorite = previousState);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update favorite'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final restaurant = await RestaurantService.getRestaurantById(
        widget.restaurantId,
      );
      final menuItems = await RestaurantService.getMenuItemsByRestaurantId(
        widget.restaurantId,
      );

      if (mounted) {
        setState(() {
          _restaurant = restaurant;
          _menuItems = menuItems;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching restaurant data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ 1. Fetch Reviews
  Future<void> _fetchReviews() async {
    setState(() => _isLoadingReviews = true);

    final avgRating = await ReviewService.getAverageRating(
      'dining',
      widget.restaurantId,
    );
    final reviews = await ReviewService.getReviews(
      'dining',
      widget.restaurantId,
    );

    if (mounted) {
      setState(() {
        _averageRating = avgRating;
        _totalReviews = reviews.length;
        _reviews = reviews;
        _isLoadingReviews = false;
      });
    }
  }

  // ✅ 2. Show Review Modal
  void _showWriteReviewModal() {
    if (!AuthService.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to write a review')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ReviewModal(
        itemType: 'dining', // ✅ Perhatikan: 'dining' bukan 'spa'
        itemId:
            widget.restaurantId, // ✅ Perhatikan: restaurantId bukan serviceId
        onReviewSubmitted: _fetchReviews,
      ),
    );
  }

  Future<void> _handleAddToCart(Map<String, dynamic> menuItem) async {
    if (!AuthService.isLoggedIn) {
      if (!mounted) return;

      AuthService.setReturnPath('/restaurant/${widget.restaurantId}');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.lock_outline, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(child: Text('Please log in to add items to your cart.')),
            ],
          ),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'LOGIN',
            textColor: Colors.white,
            onPressed: () async {
              final result = await context.push('/login');
              if (result == true && mounted) {
                print('🔄 [DINING] Login berhasil, retry _handleAddToCart...');
                _handleAddToCart(menuItem);
              }
            },
          ),
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    if (!mounted) return;

    final bookingData = await _showBookingDialog(menuItem['name']);
    if (bookingData == null) return;

    final price = menuItem['price'] is int
        ? menuItem['price'] as int
        : int.tryParse(menuItem['price'].toString()) ?? 0;

    final success = await CartService.addToCart(
      itemType: 'dining',
      itemId: menuItem['id'] as String,
      itemName: menuItem['name'] as String,
      unitPrice: price,
      metadata: {
        'date': bookingData['date'],
        'time': bookingData['time'],
        'guests': bookingData['guests'],
        'restaurant_name': _restaurant!['name'],
        'cuisine_type': _restaurant!['cuisine_type'] ?? '',
      },
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${menuItem['name']} added to cart successfully!'),
          backgroundColor: const Color(0xFF6B8E23),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'VIEW CART', // ✅ 4. DITERJEMAHKAN KE INGGRIS
            textColor: Colors.white,
            onPressed: () => context.push('/cart'),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to add to cart. Please try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<Map<String, dynamic>?> _showBookingDialog(String itemName) async {
    String selectedDate = DateFormat('yyyy-MM-dd')
        .format(DateTime.now().add(const Duration(days: 1)));
    String selectedTime = '19:00';
    int selectedGuests = 2;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Reserve a Table'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Booking for: $itemName',
                  style: const TextStyle(
                    fontFamily: 'Lato',
                    fontSize: 13,
                    color: AppColors.textGrey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Preferred Date',
                    hintText: 'YYYY-MM-DD',
                    prefixIcon: Icon(
                      Icons.calendar_today,
                      color: Color(0xFF6B8E23),
                    ),
                  ),
                  controller: TextEditingController(text: selectedDate),
                  onChanged: (value) => selectedDate = value,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedTime,
                  decoration: const InputDecoration(
                    labelText: 'Preferred Time',
                    prefixIcon: Icon(
                      Icons.access_time,
                      color: Color(0xFF6B8E23),
                    ),
                  ),
                  dropdownColor: Colors.white,
                  items:
                      [
                            '11:00',
                            '12:00',
                            '13:00',
                            '14:00',
                            '18:00',
                            '19:00',
                            '20:00',
                            '21:00',
                            '22:00',
                          ]
                          .map(
                            (time) => DropdownMenuItem(
                              value: time,
                              child: Text(time),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value != null)
                      setDialogState(() => selectedTime = value);
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: selectedGuests,
                  decoration: const InputDecoration(
                    labelText: 'Number of Guests',
                    prefixIcon: Icon(Icons.people, color: Color(0xFF6B8E23)),
                  ),
                  dropdownColor: Colors.white,
                  items: List.generate(10, (index) => index + 1)
                      .map(
                        (num) => DropdownMenuItem(
                          value: num,
                          child: Text('$num ${num == 1 ? "guest" : "guests"}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null)
                      setDialogState(() => selectedGuests = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, {
                'date': selectedDate,
                'time': selectedTime,
                'guests': selectedGuests,
              }),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B8E23),
              ),
              child: const Text(
                'Add to Cart',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, List<Map<String, dynamic>>> _groupMenuByCategory() {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final item in _menuItems) {
      final category = (item['category'] as String?) ?? 'Other';
      if (!grouped.containsKey(category)) grouped[category] = [];
      grouped[category]!.add(item);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.offWhite,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryGold),
        ),
      );
    }

    if (_restaurant == null) {
      return Scaffold(
        backgroundColor: AppColors.offWhite,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: const Center(child: Text('Restaurant not found')),
      );
    }

    final groupedMenu = _groupMenuByCategory();

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: CustomScrollView(
        slivers: [
          // 1. HERO IMAGE
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (_restaurant!['cover_image'] != null &&
                      _restaurant!['cover_image'].toString().isNotEmpty)
                    Image.network(
                      _restaurant!['cover_image'],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: AppColors.darkCharcoal),
                    )
                  else
                    Container(
                      color: AppColors.darkCharcoal,
                      child: const Center(
                        child: Icon(
                          Icons.restaurant,
                          size: 64,
                          color: Colors.white24,
                        ),
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.pop(),
            ),

            // ✅ 5. PERBAIKAN UTAMA: Actions untuk Favorite Restoran
            actions: [
              if (_isCheckingFavorite)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                )
              else
                IconButton(
                  icon: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: _isFavorite
                        ? Colors.red
                        : Colors.white, // ❤️ Merah jika favorite
                  ),
                  onPressed: _toggleFavorite,
                ),
            ],
          ),

          // 2. CONTENT
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_restaurant!['cuisine_type'] != null &&
                      _restaurant!['cuisine_type'].toString().isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6B8E23).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _restaurant!['cuisine_type'],
                        style: const TextStyle(
                          fontFamily: 'Lato',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6B8E23),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  Text(
                    _restaurant!['name'],
                    style: const TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkCharcoal,
                    ),
                  ),

                  const SizedBox(height: 12),

                  if (_restaurant!['operating_hours'] != null &&
                      _restaurant!['operating_hours'].toString().isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6B8E23).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 18,
                            color: Color(0xFF6B8E23),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Open: ${_restaurant!['operating_hours']}',
                            style: const TextStyle(
                              fontFamily: 'Lato',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B8E23),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),

                  if (_restaurant!['description'] != null &&
                      _restaurant!['description'].toString().isNotEmpty) ...[
                    const Text(
                      'About',
                      style: TextStyle(
                        fontFamily: 'Playfair Display',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkCharcoal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _restaurant!['description'],
                      style: const TextStyle(
                        fontFamily: 'Lato',
                        fontSize: 14,
                        color: AppColors.textGrey,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  const Divider(color: Color(0xFF6B8E23), thickness: 1),
                  const SizedBox(height: 24),

                  const Text(
                    'Our Menu',
                    style: TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkCharcoal,
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (groupedMenu.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'Menu is currently being updated.',
                          style: TextStyle(
                            fontFamily: 'Lato',
                            color: AppColors.textGrey,
                          ),
                        ),
                      ),
                    )
                  else
                    ...groupedMenu.entries.map(
                      (entry) => _buildCategorySection(entry.key, entry.value),
                    ),

                  const SizedBox(height: 24),

                  // ✅ TAMBAHKAN BAGIAN REVIEW DI SINI
                  _buildReviewsSection(),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(
    String category,
    List<Map<String, dynamic>> items,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.darkCharcoal,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            category.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Lato',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ...items.map((item) => _buildMenuItemCard(item)).toList(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildMenuItemCard(Map<String, dynamic> item) {
    final price = item['price'] is int
        ? item['price'] as int
        : int.tryParse(item['price'].toString()) ?? 0;
    final hasImage =
        item['image_url'] != null && item['image_url'].toString().isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  item['image_url'],
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 80,
                    height: 80,
                    color: AppColors.offWhite,
                    child: const Icon(
                      Icons.restaurant_menu,
                      color: AppColors.textGrey,
                    ),
                  ),
                ),
              ),
            if (hasImage) const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['name'],
                    style: const TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkCharcoal,
                    ),
                  ),
                  if (item['description'] != null &&
                      item['description'].toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item['description'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Lato',
                        fontSize: 12,
                        color: AppColors.textGrey,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        _currencyFormat.format(price),
                        style: const TextStyle(
                          fontFamily: 'Lato',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6B8E23),
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _handleAddToCart(item),
                        icon: const Icon(
                          Icons.add_shopping_cart,
                          size: 16,
                          color: Color(0xFF6B8E23),
                        ),
                        label: const Text(
                          'Add',
                          style: TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6B8E23),
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ 3. Build Reviews Section UI (Sama persis dengan Spa, hanya disesuaikan)
  Widget _buildReviewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 24),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Guest Reviews',
              style: TextStyle(
                fontFamily: 'Playfair Display',
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton.icon(
              onPressed: _showWriteReviewModal,
              icon: const Icon(Icons.rate_review, size: 18),
              label: const Text('Write a Review'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6B8E23),
              ), // Warna hijau dining
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_isLoadingReviews)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: Color(0xFF6B8E23)),
            ),
          )
        else if (_reviews.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.rate_review_outlined,
                  size: 40,
                  color: AppColors.textGrey,
                ),
                SizedBox(height: 12),
                Text(
                  'No reviews yet. Be the first to share your dining experience!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Lato',
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
          )
        else ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF6B8E23).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(
                  _averageRating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkCharcoal,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: List.generate(5, (index) {
                        return Icon(
                          index < _averageRating.round()
                              ? Icons.star
                              : Icons.star_border,
                          color: const Color(0xFF6B8E23),
                          size: 16,
                        );
                      }),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Based on $_totalReviews reviews',
                      style: const TextStyle(
                        fontFamily: 'Lato',
                        fontSize: 12,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          ..._reviews.map((review) {
            final userName = review['user_name'] ?? 'Valued Guest'; // ✅ Menggunakan user_name yang sudah digabungkan di service
            final comment = review['comment'] ?? '';
            final rating = review['rating'] as int;
            final date = DateTime.parse(review['created_at']);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 5,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFF6B8E23)
                            .withOpacity(0.2),
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'G',
                          style: const TextStyle(
                            color: Color(0xFF6B8E23),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: const TextStyle(
                                fontFamily: 'Lato',
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              DateFormat('dd MMM yyyy').format(date),
                              style: const TextStyle(
                                fontFamily: 'Lato',
                                fontSize: 11,
                                color: AppColors.textGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: List.generate(5, (index) {
                          return Icon(
                            index < rating ? Icons.star : Icons.star_border,
                            color: const Color(0xFF6B8E23),
                            size: 14,
                          );
                        }),
                      ),
                    ],
                  ),
                  if (comment.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Text(
                      comment,
                      style: const TextStyle(
                        fontFamily: 'Lato',
                        fontSize: 13,
                        color: AppColors.darkCharcoal,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ],
      ],
    );
  }
}
