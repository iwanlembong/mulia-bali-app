import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/wedding_service.dart';
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

  // ✅ Variabel untuk Form Wedding
  DateTime? _selectedEventDate;
  final TextEditingController _guestCountController = TextEditingController();
  bool _isBookingLoading = false;

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
    _fetchReviews();
  }

  @override
  void dispose() {
    _guestCountController.dispose();
    super.dispose();
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

  Future<void> _fetchReviews() async {
    setState(() => _isLoadingReviews = true);
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

  // ✅ 1. Widget UI untuk Menampilkan Review
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
                Icon(Icons.rate_review_outlined, size: 40, color: AppColors.textGrey),
                SizedBox(height: 12),
                Text(
                  'No reviews yet. Be the first to share your wedding experience!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Lato', color: AppColors.textGrey),
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
                          index < _averageRating.round() ? Icons.star : Icons.star_border,
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
                            Text(userName, style: const TextStyle(fontFamily: 'Lato', fontSize: 14, fontWeight: FontWeight.bold)),
                            Text(DateFormat('dd MMM yyyy').format(date), style: const TextStyle(fontFamily: 'Lato', fontSize: 11, color: AppColors.textGrey)),
                          ],
                        ),
                      ),
                      Row(
                        children: List.generate(5, (index) {
                          return Icon(index < rating ? Icons.star : Icons.star_border, color: AppColors.primaryGold, size: 14);
                        }),
                      ),
                    ],
                  ),
                  if (comment.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Text(comment, style: const TextStyle(fontFamily: 'Lato', fontSize: 13, color: AppColors.darkCharcoal, height: 1.5)),
                  ],
                  if (review['admin_reply'] != null && review['admin_reply'].toString().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGold.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primaryGold.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.verified_user, size: 16, color: AppColors.primaryGold),
                              SizedBox(width: 6),
                              Text('Management Response', style: TextStyle(fontFamily: 'Lato', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.darkCharcoal)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(review['admin_reply'], style: const TextStyle(fontFamily: 'Lato', fontSize: 13, color: AppColors.darkCharcoal, height: 1.5)),
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

  // ✅ 2. Modal Form Wedding (Pengganti Cart Dialog)
  void _showWeddingBookingModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              top: 24, left: 24, right: 24,
            ),
            decoration: const BoxDecoration(
              color: AppColors.offWhite,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text('Wedding Inquiry Details', style: TextStyle(fontFamily: 'Playfair Display', fontSize: 22, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Please provide your event details so we can check availability.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Lato', fontSize: 13, color: AppColors.textGrey),
                  ),
                ),
                const SizedBox(height: 32),
                const Text('Event Date', style: TextStyle(fontFamily: 'Lato', fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                      builder: (context, child) {
                        return Theme(
                          data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primaryGold)),
                          child: child!,
                        );
                      },
                    );
                    if (pickedDate != null) {
                      setModalState(() => _selectedEventDate = pickedDate);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primaryGold.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedEventDate != null ? DateFormat('dd MMMM yyyy').format(_selectedEventDate!) : 'Select Event Date',
                          style: TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 14,
                            color: _selectedEventDate != null ? AppColors.darkCharcoal : AppColors.textGrey,
                          ),
                        ),
                        const Icon(Icons.calendar_today, color: AppColors.primaryGold, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Estimated Guest Count', style: TextStyle(fontFamily: 'Lato', fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primaryGold.withOpacity(0.3)),
                  ),
                  child: TextField(
                    controller: _guestCountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'e.g. 200',
                      border: InputBorder.none,
                      icon: Icon(Icons.people_outline, color: AppColors.primaryGold, size: 18),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isBookingLoading
                        ? null
                        : () {
                            if (_selectedEventDate == null || _guestCountController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please fill in all details'), backgroundColor: Colors.orange),
                              );
                              return;
                            }
                            _processWeddingBooking();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.darkCharcoal,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isBookingLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('CHECK AVAILABILITY & BOOK', style: TextStyle(fontFamily: 'Lato', fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  // ✅ 3. Proses Simpan Langsung ke Order (Bypass Cart)
  Future<void> _processWeddingBooking() async {
    if (_package == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Package data not loaded. Please try again.'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    if (_selectedEventDate == null || _guestCountController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill in all required fields'), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    setState(() => _isBookingLoading = true);

    try {
      final userId = AuthService.currentUserId;
      if (userId == null) {
        if (mounted) {
          Navigator.pop(context);
          AuthService.setReturnPath('/wedding/${widget.packageId}');
          context.push('/login');
        }
        return;
      }

      final guestCount = int.tryParse(_guestCountController.text.trim()) ?? 100;
      final eventDateStr = _selectedEventDate!.toIso8601String().split('T').first;
      final packagePrice = _package!.price ?? 0;
      final uniqueOrderNumber = 'ORD-${DateTime.now().millisecondsSinceEpoch}';

      // Langkah 1: Insert ke tabel orders
      final orderResponse = await Supabase.instance.client
          .from('orders')
          .insert({
            'order_number': uniqueOrderNumber,
            'user_id': userId,
            'status': 'pending',
            'wedding_status': 'Pending Inquiry',
            'event_date': eventDateStr,
            'guest_count': guestCount,
            'total_amount': packagePrice,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('id, order_number')
          .single();

      final newOrderId = orderResponse['id'] as String;

      // Langkah 2: Insert ke tabel order_items
      await Supabase.instance.client.from('order_items').insert({
        'order_id': newOrderId,
        'item_type': 'wedding',
        'item_id': widget.packageId,
        'item_name': _package!.packageName,
        'quantity': 1,
        'unit_price': packagePrice,
        'total_price': packagePrice,
        'metadata': {
          'event_date': eventDateStr,
          'guests': guestCount,
          'venue_preference': 'To be discussed',
        },
      });

      if (mounted) {
        final displayDate = DateFormat('dd MMMM yyyy').format(_selectedEventDate!);
        final displayGuests = guestCount.toString();

        Navigator.pop(context); // Tutup modal
        setState(() => _isBookingLoading = false);
        
        // Reset form
        _guestCountController.clear();
        setState(() => _selectedEventDate = null);

        // Tampilkan dialog sukses
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 12),
                Text('Inquiry Submitted!', style: TextStyle(fontFamily: 'Playfair Display')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Thank you for your interest in our wedding services. Our wedding consultant will contact you within 24 hours.',
                  style: TextStyle(fontFamily: 'Lato', fontSize: 13),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Your Inquiry Details:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 8),
                      Text('📅 Event Date: $displayDate', style: const TextStyle(fontSize: 12)),
                      Text('👥 Estimated Guests: $displayGuests', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  context.go('/');
                },
                child: const Text('Back to Home', style: TextStyle(color: AppColors.darkCharcoal)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  context.go('/my-bookings');
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGold),
                child: const Text('View My Inquiry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('❌ [WEDDING] Error booking: $e');
      if (mounted) {
        Navigator.pop(context);
        setState(() => _isBookingLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit inquiry: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.offWhite,
        body: Center(child: CircularProgressIndicator(color: AppColors.primaryGold)),
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
                  if (_package!.imageUrl != null && _package!.imageUrl!.isNotEmpty)
                    Image.network(
                      _package!.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: AppColors.darkCharcoal),
                    )
                  else
                    Container(
                      color: AppColors.darkCharcoal,
                      child: const Center(child: Icon(Icons.favorite, size: 64, color: Colors.white24)),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
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
                    style: const TextStyle(fontFamily: 'Playfair Display', fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.darkCharcoal),
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
                          const Icon(Icons.attach_money, size: 24, color: Colors.pink),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Starting From', style: TextStyle(fontFamily: 'Lato', fontSize: 11, color: AppColors.textGrey)),
                              Text(
                                _currencyFormat.format(_package!.price),
                                style: const TextStyle(fontFamily: 'Lato', fontSize: 20, fontWeight: FontWeight.bold, color: Colors.pink),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),
                  const Text('About This Package', style: TextStyle(fontFamily: 'Playfair Display', fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(
                    _package!.description ?? 'No description available.',
                    style: const TextStyle(fontFamily: 'Lato', fontSize: 15, color: AppColors.textGrey, height: 1.6),
                  ),
                  const SizedBox(height: 24),
                  if (_package!.includes.isNotEmpty) ...[
                    const Text('Package Includes', style: TextStyle(fontFamily: 'Playfair Display', fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ..._package!.includes.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle, size: 18, color: Colors.pink),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(item, style: const TextStyle(fontFamily: 'Lato', fontSize: 14, color: AppColors.darkCharcoal)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  _buildReviewsSection(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      
      // ✅ TOMBOL BAWAH YANG SUDAH DIBERSIHKAN DARI KATA "CART"
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
            onPressed: _showWeddingBookingModal,
            icon: const Icon(Icons.calendar_month, size: 18), // Ikon Kalender
            label: const Text(
              'CHECK AVAILABILITY & INQUIRE', // Teks yang sudah diperbaiki
              style: TextStyle(
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ),
    );
  }
}