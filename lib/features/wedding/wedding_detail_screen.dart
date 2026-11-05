import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/wedding_service.dart';
import '../../core/services/cart_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/review_service.dart';
import '../../core/models/wedding_model.dart';

class WeddingDetailScreen extends StatefulWidget {
  final String packageId;

  const WeddingDetailScreen({super.key, required this.packageId});

  @override
  State<WeddingDetailScreen> createState() => _WeddingDetailScreenState();
}

class _WeddingDetailScreenState extends State<WeddingDetailScreen> {
  bool _isLoading = true;
  WeddingModel? _package;

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'IDR ',
    decimalDigits: 0,
  );

  // ✅ State untuk Review Wedding
  double _averageRating = 0.0;
  int _totalReviews = 0;
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoadingReviews = true;

  @override
  void initState() {
    super.initState();
    _fetchPackage();
    _fetchReviews(); // ✅ TAMBAHKAN INI
  }

  Future<void> _fetchPackage() async {
    try {
      final allPackages = await WeddingService.getActivePackages();
      final pkg = allPackages.firstWhere(
        (p) => p.id == widget.packageId,
        orElse: () => throw Exception('Package not found'),
      );

      if (mounted) {
        setState(() {
          _package = pkg;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching wedding package detail: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ 1. Method untuk Mengambil Data Review Wedding
  Future<void> _fetchReviews() async {
    setState(() => _isLoadingReviews = true);

    // ⚠️ PENTING: Ganti 'widget.packageId' dengan nama variabel ID di file Anda!
    // (Bisa jadi widget.weddingId, widget.id, atau widget.packageId)
    final targetId = widget.packageId;

    final avgRating = await ReviewService.getAverageRating('wedding', targetId);
    final reviews = await ReviewService.getReviews('wedding', targetId);

    if (mounted) {
      setState(() {
        _averageRating = avgRating;
        _totalReviews = reviews.length;
        _reviews = reviews;
        _isLoadingReviews = false;
      });
    }
  }

  Future<void> _handleAddToCart() async {
    // ✅ 1. CEK LOGIN DULU
    if (!AuthService.isLoggedIn) {
      if (!mounted) return;

      // ✅ PENTING: Simpan path halaman ini sebelum login
      // Agar setelah login, user otomatis kembali ke sini
      AuthService.setReturnPath('/wedding/${widget.packageId}');

      // Tampilkan SnackBar dengan tombol aksi Login
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.lock_outline, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(child: Text('Please log in to submit an inquiry.')),
            ],
          ),
          backgroundColor: Colors.pink.shade800,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'LOGIN',
            textColor: Colors.white,
            // fontWeight dihapus agar aman dari error parameter
            onPressed: () async {
              // Arahkan ke halaman login
              final result = await context.push('/login');

              // Jika kembali dari login dengan sukses (result == true), retry otomatis
              if (result == true && mounted) {
                print('🔄 [WEDDING] Login berhasil, retry _handleAddToCart...');
                _handleAddToCart();
              }
            },
          ),
          duration: const Duration(seconds: 5),
        ),
      );

      return; // ⛔ STOP DI SINI. Jangan lanjut ke dialog inquiry.
    }

    // ✅ 2. JIKA SUDAH LOGIN, LANJUT KE DIALOG INQUIRY
    if (!mounted) return;

    final inquiryData = await _showInquiryDialog();
    if (inquiryData == null) {
      return; // User membatalkan dialog
    }

    // ✅ 3. PROSES ADD TO CART
    final success = await CartService.addToCart(
      itemType: 'wedding',
      itemId: _package!.id,
      itemName: _package!.packageName,
      unitPrice: _package!.price ?? 0,
      metadata: {
        'event_date': inquiryData['event_date'],
        'guests': inquiryData['guests'],
        'venue_preference': inquiryData['venue_preference'],
      },
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_package!.packageName} inquiry added to cart successfully!',
          ),
          backgroundColor: Colors.pink.shade600,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'LIHAT CART',
            textColor: Colors.white,
            onPressed: () => context.push('/cart'),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to add inquiry. Please try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<Map<String, dynamic>?> _showInquiryDialog() async {
    String selectedDate = DateFormat('yyyy-MM-dd')
        .format(DateTime.now().add(const Duration(days: 30)));
    int selectedGuests = 100;
    String selectedVenue = 'Beach';

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Wedding Inquiry Details'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Package: ${_package!.packageName}',
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
                    labelText: 'Preferred Event Date',
                    hintText: 'YYYY-MM-DD',
                    prefixIcon: Icon(Icons.calendar_today, color: Colors.pink),
                  ),
                  controller: TextEditingController(text: selectedDate),
                  onChanged: (value) => selectedDate = value,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: selectedGuests,
                  decoration: const InputDecoration(
                    labelText: 'Estimated Guest Count',
                    prefixIcon: Icon(Icons.people, color: Colors.pink),
                  ),
                  dropdownColor: Colors.white,
                  items: [50, 100, 200, 300, 500, 1000]
                      .map(
                        (num) => DropdownMenuItem(
                          value: num,
                          child: Text('$num guests'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null)
                      setDialogState(() => selectedGuests = value);
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedVenue,
                  decoration: const InputDecoration(
                    labelText: 'Preferred Venue',
                    prefixIcon: Icon(Icons.location_on, color: Colors.pink),
                  ),
                  dropdownColor: Colors.white,
                  items: ['Beach', 'Garden', 'Grand Ballroom', 'Chapel']
                      .map(
                        (venue) =>
                            DropdownMenuItem(value: venue, child: Text(venue)),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null)
                      setDialogState(() => selectedVenue = value);
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
                'event_date': selectedDate,
                'guests': selectedGuests,
                'venue_preference': selectedVenue,
              }),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink.shade600,
              ),
              child: const Text(
                'Add Inquiry to Cart',
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

    if (_package == null) {
      return Scaffold(
        backgroundColor: AppColors.offWhite,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: const Center(child: Text('Package not found')),
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
                  if (_package!.imageUrl != null &&
                      _package!.imageUrl!.isNotEmpty)
                    Image.network(
                      _package!.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: AppColors.darkCharcoal),
                    )
                  else
                    Container(
                      color: AppColors.darkCharcoal,
                      child: const Center(
                        child: Icon(
                          Icons.favorite,
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
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _package!.packageName,
                    style: const TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkCharcoal,
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_package!.price != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.pink.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.pink.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.attach_money,
                            size: 24,
                            color: Colors.pink,
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Starting From',
                                style: TextStyle(
                                  fontFamily: 'Lato',
                                  fontSize: 11,
                                  color: AppColors.textGrey,
                                ),
                              ),
                              Text(
                                _currencyFormat.format(_package!.price),
                                style: const TextStyle(
                                  fontFamily: 'Lato',
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.pink,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),

                  const Text(
                    'About This Package',
                    style: TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _package!.description ?? 'No description available.',
                    style: const TextStyle(
                      fontFamily: 'Lato',
                      fontSize: 15,
                      color: AppColors.textGrey,
                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: 24),

                  if (_package!.includes.isNotEmpty) ...[
                    const Text(
                      'Package Includes',
                      style: TextStyle(
                        fontFamily: 'Playfair Display',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._package!.includes.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.check_circle,
                              size: 18,
                              color: Colors.pink,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item,
                                style: const TextStyle(
                                  fontFamily: 'Lato',
                                  fontSize: 14,
                                  color: AppColors.darkCharcoal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // ✅ TAMPILKAN BAGIAN REVIEW DI SINI
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
            icon: const Icon(Icons.mail_outline, size: 18),
            label: Text(
              'ADD INQUIRY TO CART',
              style: const TextStyle(
                fontFamily: 'Lato',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pink.shade600,
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

  // ✅ 2. Widget UI untuk Menampilkan Review (Sama persis seperti di Property)
  Widget _buildReviewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 24),

        const Text(
          'Guest Reviews',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.darkCharcoal,
          ),
        ),
        const SizedBox(height: 16),

        if (_isLoadingReviews)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: AppColors.primaryGold),
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
                  'No reviews yet. Be the first to share your wedding experience!',
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
                          index < _averageRating.round()
                              ? Icons.star
                              : Icons.star_border,
                          color: AppColors.primaryGold,
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
                        backgroundColor: AppColors.primaryGold.withOpacity(0.2),
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'G',
                          style: const TextStyle(
                            color: AppColors.primaryGold,
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
                      style: const TextStyle(
                        fontFamily: 'Lato',
                        fontSize: 13,
                        color: AppColors.darkCharcoal,
                        height: 1.5,
                      ),
                    ),
                  ],
                  // ✅ BARU: TAMPILKAN BALASAN ADMIN JIKA ADA
                  if (review['admin_reply'] != null &&
                      review['admin_reply'].toString().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGold.withOpacity(
                          0.08,
                        ), // Background sangat muda
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.primaryGold.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.verified_user,
                                size: 16,
                                color: AppColors.primaryGold,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Management Response',
                                style: TextStyle(
                                  fontFamily: 'Lato',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.darkCharcoal,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            review['admin_reply'],
                            style: const TextStyle(
                              fontFamily: 'Lato',
                              fontSize: 13,
                              color: AppColors.darkCharcoal,
                              height: 1.5,
                            ),
                          ),
                        ],
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
