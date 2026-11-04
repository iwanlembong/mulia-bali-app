import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/spa_service_service.dart';
import '../../core/services/cart_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/favorite_service.dart'; // ✅ Pastikan ini ada
import '../../core/models/spa_service_model.dart';
import '../../core/services/review_service.dart';
import '../../core/widgets/review_modal.dart';

class SpaDetailScreen extends StatefulWidget {
  final String serviceId;

  const SpaDetailScreen({super.key, required this.serviceId});

  @override
  State<SpaDetailScreen> createState() => _SpaDetailScreenState();
}

class _SpaDetailScreenState extends State<SpaDetailScreen> {
  bool _isLoading = true;
  SpaServiceModel? _service;

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'IDR ',
    decimalDigits: 0,
  );

  // ✅ State untuk Favorite
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
    _checkFavoriteStatus();
    _fetchService();
    _fetchReviews(); // ✅ Tambahkan ini
  }

  Future<void> _fetchReviews() async {
    setState(() => _isLoadingReviews = true);
    
    final avgRating = await ReviewService.getAverageRating('spa', widget.serviceId);
    final reviews = await ReviewService.getReviews('spa', widget.serviceId);

    if (mounted) {
      setState(() {
        _averageRating = avgRating;
        _totalReviews = reviews.length;
        _reviews = reviews;
        _isLoadingReviews = false;
      });
    }
  }

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
        itemType: 'spa',
        itemId: widget.serviceId,
        onReviewSubmitted: _fetchReviews, // Refresh list setelah submit
      ),
    );
  }


  Future<void> _fetchService() async {
    try {
      final allServices = await SpaServiceService.getActiveServices();
      final service = allServices.firstWhere(
        (s) => s.id == widget.serviceId,
        orElse: () => throw Exception('Service not found'),
      );

      if (mounted) {
        setState(() {
          _service = service;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching service detail: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkFavoriteStatus() async {
    final isFav = await FavoriteService.isFavorite('spa', widget.serviceId);
    if (mounted) {
      setState(() {
        _isFavorite = isFav;
        _isCheckingFavorite = false;
      });
    }
  }

  // ✅ BARU: Method untuk Toggle Favorite dengan Optimistic UI Update
  Future<void> _toggleFavorite() async {
    // 1. Simpan state lama untuk rollback jika gagal
    final previousState = _isFavorite;
    
    // 2. Update UI segera (Optimistic Update)
    setState(() => _isFavorite = !_isFavorite);

    try {
      // 3. Kirim ke database
      final newStatus = await FavoriteService.toggleFavorite('spa', widget.serviceId);
      // Ganti 'spa' dengan 'dining' jika di dining_detail_screen.dart
      // Ganti widget.serviceId dengan widget.restaurantId jika di dining

      // 4. Jika status di database TIDAK sesuai dengan UI, sinkronkan
      if (mounted && newStatus != _isFavorite) {
        print('⚠️ [UI] Status mismatch. Database: $newStatus | UI: $_isFavorite');
        setState(() => _isFavorite = newStatus);
      }

      // 5. Tampilkan pesan sukses
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isFavorite ? 'Added to favorites ❤️' : 'Removed from favorites'),
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

  Future<void> _handleAddToCart() async {
    if (!AuthService.isLoggedIn) {
      if (!mounted) return;

      AuthService.setReturnPath('/spa/${widget.serviceId}');

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
                print('🔄 [SPA] Login berhasil, retry _handleAddToCart...');
                _handleAddToCart();
              }
            },
          ),
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    if (!mounted) return;

    final selectedBooking = await _showBookingDialog();
    if (selectedBooking == null) return;

    final success = await CartService.addToCart(
      itemType: 'spa',
      itemId: _service!.id,
      itemName: _service!.name,
      unitPrice: _service!.price,
      metadata: {
        'date': selectedBooking['date'],
        'time': selectedBooking['time'],
        'duration': _service!.durationMinutes,
      },
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_service!.name} added to cart successfully!'),
          backgroundColor: const Color(0xFF8B7355),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'VIEW CART', // ✅ Diterjemahkan ke Inggris
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

  Future<Map<String, String>?> _showBookingDialog() async {
    String selectedDate = DateFormat('yyyy-MM-dd')
        .format(DateTime.now().add(const Duration(days: 1)));
    String selectedTime = '10:00';

    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Select Date & Time'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Preferred Date',
                  hintText: 'YYYY-MM-DD',
                  prefixIcon: Icon(
                    Icons.calendar_today,
                    color: Color(0xFF8B7355),
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
                  prefixIcon: Icon(Icons.access_time, color: Color(0xFF8B7355)),
                ),
                dropdownColor: Colors.white,
                items:
                    [
                          '09:00',
                          '10:00',
                          '11:00',
                          '13:00',
                          '14:00',
                          '15:00',
                          '16:00',
                          '17:00',
                          '18:00',
                          '19:00',
                        ]
                        .map(
                          (time) =>
                              DropdownMenuItem(value: time, child: Text(time)),
                        )
                        .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selectedTime = value);
                  }
                },
              ),
            ],
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
              }),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B7355),
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

    if (_service == null) {
      return Scaffold(
        backgroundColor: AppColors.offWhite,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: const Center(child: Text('Service not found')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (_service!.imageUrl != null &&
                      _service!.imageUrl!.isNotEmpty)
                    Image.network(
                      _service!.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: AppColors.darkCharcoal),
                    )
                  else
                    Container(
                      color: AppColors.darkCharcoal,
                      child: const Center(
                        child: Icon(Icons.spa, size: 64, color: Colors.white24),
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

            // ✅ PERBAIKAN UTAMA DI SINI: Actions untuk Favorite
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

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_service!.category != null &&
                      _service!.category!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B7355).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _service!.category!,
                        style: const TextStyle(
                          fontFamily: 'Lato',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8B7355),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  Text(
                    _service!.name,
                    style: const TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkCharcoal,
                    ),
                  ),

                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF8B7355).withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Duration',
                                style: TextStyle(
                                  fontFamily: 'Lato',
                                  fontSize: 11,
                                  color: AppColors.textGrey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.access_time,
                                    size: 18,
                                    color: Color(0xFF8B7355),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${_service!.durationMinutes ?? 0} minutes',
                                    style: const TextStyle(
                                      fontFamily: 'Lato',
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: AppColors.textGrey.withOpacity(0.2),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Price',
                                style: TextStyle(
                                  fontFamily: 'Lato',
                                  fontSize: 11,
                                  color: AppColors.textGrey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _currencyFormat.format(_service!.price),
                                style: const TextStyle(
                                  fontFamily: 'Lato',
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF8B7355),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),

                  const Text(
                    'About This Treatment',
                    style: TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _service!.description ?? 'No description available.',
                    style: const TextStyle(
                      fontFamily: 'Lato',
                      fontSize: 15,
                      color: AppColors.textGrey,
                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'What to Expect',
                    style: TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildBenefitItem('Relaxing ambiance with aromatic oils'),
                  _buildBenefitItem('Professional and certified therapists'),
                  _buildBenefitItem('Complimentary herbal tea after treatment'),
                  _buildBenefitItem(
                    'Private treatment room with shower facilities',
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

      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton.icon(
            onPressed: _handleAddToCart,
            icon: const Icon(Icons.shopping_bag, size: 18),
            label: Text(
              'ADD TO CART - ${_currencyFormat.format(_service!.price)}',
              style: const TextStyle(
                fontFamily: 'Lato',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B7355),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF8B7355).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.check, size: 16, color: Color(0xFF8B7355)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Lato',
                fontSize: 14,
                color: AppColors.darkCharcoal,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Widget untuk menampilkan bagian Review
  Widget _buildReviewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 24),
        
        // Header: Judul + Tombol Write Review
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
              style: TextButton.styleFrom(foregroundColor: AppColors.primaryGold),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Loading State
        if (_isLoadingReviews)
          const Center(child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(color: AppColors.primaryGold),
          ))
        
        // Empty State
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
                Icon(Icons.rate_review_outlined, size: 40, color: AppColors.textGrey),
                SizedBox(height: 12),
                Text(
                  'No reviews yet. Be the first to share your experience!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Lato', color: AppColors.textGrey),
                ),
              ],
            ),
          )
        
        // List Reviews
        else ...[
          // Rating Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryGold.withOpacity(0.1),
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
                          index < _averageRating.round() ? Icons.star : Icons.star_border,
                          color: AppColors.primaryGold,
                          size: 16,
                        );
                      }),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Based on $_totalReviews reviews',
                      style: const TextStyle(fontFamily: 'Lato', fontSize: 12, color: AppColors.textGrey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Review List
          ..._reviews.map((review) {
            // ✅ PERBAIKAN: Baca langsung dari field 'user_name' yang sudah kita gabungkan
            final userName = review['user_name'] ?? 'Valued Guest';
            
            final comment = review['comment'] ?? '';
            final rating = review['rating'] as int;
            final date = DateTime.parse(review['created_at']);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.primaryGold.withOpacity(0.2),
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'G',
                          style: const TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: const TextStyle(fontFamily: 'Lato', fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              DateFormat('dd MMM yyyy').format(date),
                              style: const TextStyle(fontFamily: 'Lato', fontSize: 11, color: AppColors.textGrey),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: List.generate(5, (index) {
                          return Icon(
                            index < rating ? Icons.star : Icons.star_border,
                            color: AppColors.primaryGold,
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
                      style: const TextStyle(fontFamily: 'Lato', fontSize: 13, color: AppColors.darkCharcoal, height: 1.5),
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
