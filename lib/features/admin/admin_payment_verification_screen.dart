import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/payment_model.dart'; // ✅ BARU
import '../../core/services/payment_service.dart'; // ✅ BARU
import '../../core/models/reservation_model.dart';
import '../../core/models/order_model.dart';
import '../../core/services/email_service.dart';
import 'admin_reservation_detail_screen.dart';
import 'admin_booking_detail_screen.dart';

class AdminPaymentVerificationScreen extends StatefulWidget {
  const AdminPaymentVerificationScreen({super.key});

  @override
  State<AdminPaymentVerificationScreen> createState() =>
      _AdminPaymentVerificationScreenState();
}

class _AdminPaymentVerificationScreenState
    extends State<AdminPaymentVerificationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  // ✅ BARU: Menyimpan data pembayaran yang sudah diperkaya dengan detail Order/Reservation
  List<Map<String, dynamic>> _pendingOrderPayments = [];
  List<Map<String, dynamic>> _pendingReservationPayments = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchPendingVerifications();
    _tabController.addListener(() {
      if (mounted)
        setState(() {}); // Rebuild saat tab berubah untuk animasi yang mulus
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ✅ SOLUSI BARU: Fetch dari order_payments, lalu enrich dengan data Orders/Reservations
  Future<void> _fetchPendingVerifications() async {
    setState(() => _isLoading = true);
    try {
      // 1. Ambil semua pembayaran yang statusnya 'pending' dari tabel baru
      final payments = await PaymentService.getPendingPayments();

      // 2. Pisahkan ID Order dan Reservation untuk di-fetch detailnya
      final orderIds = payments.where((p) => p.orderId != null).map((p) => p.orderId!).toSet().toList();
      final resIds = payments.where((p) => p.reservationId != null).map((p) => p.reservationId!).toSet().toList();

      // Kumpulkan semua user_id unik
      Set<String> userIds = {};

      // 3. Fetch detail Orders terkait (HANYA ambil user_id, BUKAN user_name)
      List<Map<String, dynamic>> enrichedOrders = [];
      if (orderIds.isNotEmpty) {
        final ordersData = await Supabase.instance.client
            .from('orders')
            .select('id, order_number, total_amount, user_id') // ✅ AMAN: user_id
            .inFilter('id', orderIds);

        for (var order in ordersData) {
          if (order['user_id'] != null) userIds.add(order['user_id']);
          final payment = payments.firstWhere((p) => p.orderId == order['id']);
          enrichedOrders.add({
            'payment': payment,
            'id': order['id'],
            'title': order['order_number'],
            'user_id': order['user_id'], 
            'subtitle': 'Service Booking',
            'total_amount': order['total_amount'] as int,
          });
        }
      }

      // 4. Fetch detail Reservations terkait (HANYA ambil user_id, BUKAN guest_name)
      List<Map<String, dynamic>> enrichedReservations = [];
      if (resIds.isNotEmpty) {
        final resData = await Supabase.instance.client
            .from('reservations')
            .select('id, reservation_number, total_amount, user_id, check_in, check_out') // ✅ AMAN: user_id
            .inFilter('id', resIds);

        for (var res in resData) {
          if (res['user_id'] != null) userIds.add(res['user_id']);
          final payment = payments.firstWhere((p) => p.reservationId == res['id']);
          enrichedReservations.add({
            'payment': payment,
            'id': res['id'],
            'title': res['reservation_number'],
            'user_id': res['user_id'], 
            'subtitle': 'Accommodation',
            'total_amount': res['total_amount'] as int,
            'check_in': res['check_in'],
            'check_out': res['check_out'],
          });
        }
      }

      // 5. Ambil data nama tamu (profiles) secara batch menggunakan user_id yang terkumpul
      Map<String, String> userNames = {};
      if (userIds.isNotEmpty) {
        final profilesResponse = await Supabase.instance.client
            .from('profiles')
            .select('id, full_name')
            .inFilter('id', userIds.toList());

        for (var profile in profilesResponse) {
          userNames[profile['id']] = profile['full_name'] ?? 'Guest';
        }
      }

      // 6. Suntikkan nama tamu ke dalam data yang sudah di-enrich
      for (var order in enrichedOrders) {
        order['guest_name'] = userNames[order['user_id']] ?? 'Guest';
      }
      for (var res in enrichedReservations) {
        res['guest_name'] = userNames[res['user_id']] ?? 'Guest';
      }

      if (mounted) {
        setState(() {
          _pendingOrderPayments = enrichedOrders;
          _pendingReservationPayments = enrichedReservations;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ [ADMIN] Error fetch verifications: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load data: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ✅ LOGIKA VERIFIKASI TERPADU (Mendukung Approve & Revision)
  Future<void> _handleVerifyPayment(
    Map<String, dynamic> itemData,
    String action,
  ) async {
    final OrderPayment payment = itemData['payment'];
    final bool isOrder = payment.orderId != null;
    final String targetId = isOrder ? payment.orderId! : payment.reservationId!;
    final String tableName = isOrder ? 'orders' : 'reservations';
    final String docNumber = itemData['title'];

    String? rejectionReason;

    // --- 1. JIKA REVISION / REJECT ---
    if (action == 'revision') {
      final reasonController = TextEditingController();
      final inputConfirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(
            'Reason for Revision',
            style: TextStyle(
              color: Colors.orange,
              fontFamily: 'Playfair Display',
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Please provide a reason so the guest can re-upload the correct proof:',
                style: TextStyle(fontFamily: 'Lato', fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 3,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText:
                      'e.g., Transfer amount is incorrect, Proof is blurry',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
              ),
              child: const Text(
                'Submit Revision',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );

      if (!mounted || inputConfirmed != true) return;
      rejectionReason = reasonController.text.trim();
      if (rejectionReason.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reason cannot be empty!'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }
    // --- 2. JIKA APPROVE ---
    else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(
            'Approve Payment?',
            style: TextStyle(fontFamily: 'Playfair Display'),
          ),
          content: Text(
            'Mark payment of ${payment.formattedAmount} for $docNumber as verified?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text(
                'Yes, Approve',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
      if (!mounted || confirm != true) return;
    }

    // --- 3. EKSEKUSI UPDATE KE DATABASE ---
    try {
      // A. Update status di tabel order_payments
      await PaymentService.updatePaymentStatus(
        payment.id,
        action == 'revision' ? 'rejected' : 'verified',
        rejectionReason: rejectionReason,
      );

      // B. Jika APPROVED, cek apakah parent (Order/Reservation) sudah FULLY PAID
      if (action == 'verified') {
        final parentData = await Supabase.instance.client
            .from(tableName)
            .select('total_amount, status')
            .eq('id', targetId)
            .single();

        final totalAmount = parentData['total_amount'] as int;

        // Hitung total yang sudah verified untuk ID ini
        final verifiedPayments = await Supabase.instance.client
            .from('order_payments')
            .select('amount')
            .eq(isOrder ? 'order_id' : 'reservation_id', targetId)
            .eq('status', 'verified');

        final totalPaid = (verifiedPayments as List).fold<int>(
          0,
          (sum, item) => sum + (item['amount'] as int),
        );

        // Jika sudah lunas, update status parent menjadi 'confirmed'
        if (totalPaid >= totalAmount && parentData['status'] != 'confirmed') {
          await Supabase.instance.client
              .from(tableName)
              .update({'status': 'confirmed'})
              .eq('id', targetId);
        }
      }

      // C. Kirim Email Notifikasi
      try {
        if (isOrder) {
          // Ambil data Order lengkap untuk dikirim ke EmailService
          final orderData = await Supabase.instance.client
              .from('orders')
              .select('*, user_id') // Ambil semua data order + user_id
              .eq('id', targetId)
              .single();
          
          // Ambil profil user
          final profile = await Supabase.instance.client
              .from('profiles')
              .select('email, full_name')
              .eq('id', orderData['user_id'])
              .maybeSingle();

          final userEmail = profile?['email'] as String?;
          final userName = profile?['full_name'] as String? ?? 'Valued Guest';

          if (userEmail != null && userEmail.isNotEmpty) {
            // Buat object Order sementara dari Map agar kompatibel dengan EmailService Anda
            final orderObj = Order.fromMap(orderData);
            
            EmailService.sendEmail(
              to: userEmail,
              subject: action == 'verified' 
                  ? 'Payment Verified - ${orderObj.orderNumber}' 
                  : 'Payment Revision Required - ${orderObj.orderNumber}',
              htmlContent: EmailService.generateStatusUpdateTemplate(
                orderObj, // ✅ Sekarang kita kirim object Order yang valid
                userName,
                action == 'verified' ? 'confirmed' : 'pending',
                rejectionReason: rejectionReason,
              ),
            );
          }
        } else {
          // LOGIKA SAMA UNTUK RESERVATION (Jika Anda punya EmailService untuk Reservation)
          final resData = await Supabase.instance.client
              .from('reservations')
              .select('*, user_id')
              .eq('id', targetId)
              .single();
              
          final profile = await Supabase.instance.client
              .from('profiles')
              .select('email, full_name')
              .eq('id', resData['user_id'])
              .maybeSingle();

          final userEmail = profile?['email'] as String?;
          final userName = profile?['full_name'] as String? ?? 'Valued Guest';

          if (userEmail != null && userEmail.isNotEmpty) {
            final resObj = Reservation.fromMap(resData);
            
            EmailService.sendEmail(
              to: userEmail,
              subject: action == 'verified' 
                  ? 'Payment Verified - ${resObj.reservationNumber}' 
                  : 'Payment Revision Required - ${resObj.reservationNumber}',
              htmlContent: EmailService.generateStatusUpdateTemplate(
                resObj, // ✅ Kirim object Reservation yang valid
                userName,
                action == 'verified' ? 'confirmed' : 'pending',
                rejectionReason: rejectionReason,
              ),
            );
          }
        }
      } catch (emailError) {
        // ✅ FAIL-SAFE: Jika email gagal, jangan gagalkan seluruh proses verifikasi
        print('⚠️ [ADMIN] Email notification failed, but payment status updated: $emailError');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              rejectionReason != null
                  ? 'Revision requested.'
                  : 'Payment verified successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        _fetchPendingVerifications(); // Refresh list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showProofImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              title: const Text(
                'Payment Proof',
                style: TextStyle(fontFamily: 'Lato'),
              ),
              actions: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            SizedBox(
              height: 300,
              width: double.infinity,
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  String _formatPrice(int price) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'IDR ',
      decimalDigits: 0,
    ).format(price);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        backgroundColor: AppColors.darkCharcoal,
        foregroundColor: Colors.white,
        title: const Text(
          'Payment Verification',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryGold,
          labelColor: AppColors.primaryGold,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(
              text: 'Accommodation',
              icon: Icon(Icons.hotel_outlined, size: 18),
            ),
            Tab(text: 'Services', icon: Icon(Icons.spa_outlined, size: 18)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGold),
            )
          : TabBarView(
              controller: _tabController,
              children: [_buildReservationList(), _buildOrderList()],
            ),
    );
  }

  Widget _buildReservationList() {
    if (_pendingReservationPayments.isEmpty)
      return _buildEmptyState('Accommodation payments');
    return RefreshIndicator(
      onRefresh: _fetchPendingVerifications,
      color: AppColors.primaryGold,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pendingReservationPayments.length,
        itemBuilder: (context, index) {
          final item = _pendingReservationPayments[index];
          final payment = item['payment'] as OrderPayment;
          final checkIn = DateTime.parse(item['check_in']);
          final checkOut = DateTime.parse(item['check_out']);

          return _buildVerificationCard(
            title: item['title'],
            guestName: item['guest_name'],
            subtitle: item['subtitle'],
            date:
                '${DateFormat('dd MMM').format(checkIn)} - ${DateFormat('dd MMM').format(checkOut)}',
            amount: payment.amount, // ✅ Gunakan amount dari payment, bukan total_amount order
            proofUrl: payment.paymentProofUrl,
            onApprove: () => _handleVerifyPayment(item, 'verified'),
            onReject: () => _handleVerifyPayment(item, 'revision'),
            onTapDetail: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    AdminReservationDetailScreen(reservationId: item['id']),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderList() {
    if (_pendingOrderPayments.isEmpty)
      return _buildEmptyState('Service payments');
    return RefreshIndicator(
      onRefresh: _fetchPendingVerifications,
      color: AppColors.primaryGold,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pendingOrderPayments.length,
        itemBuilder: (context, index) {
          final item = _pendingOrderPayments[index];
          final payment = item['payment'] as OrderPayment;

          return _buildVerificationCard(
            title: item['title'],
            guestName: item['guest_name'],
            subtitle: item['subtitle'],
            date: payment.formattedDate,
            amount: payment.amount, // ✅ Gunakan amount dari payment
            proofUrl: payment.paymentProofUrl,
            onApprove: () => _handleVerifyPayment(item, 'verified'),
            onReject: () => _handleVerifyPayment(item, 'revision'),
            onTapDetail: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AdminBookingDetailScreen(orderId: item['id']),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVerificationCard({
    required String title,
    required String guestName,
    required String subtitle,
    required String date,
    required int amount,
    required String proofUrl,
    required VoidCallback onApprove,
    required VoidCallback onReject,
    required VoidCallback onTapDetail,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Lato',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.darkCharcoal,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'PENDING',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              guestName,
              style: const TextStyle(
                fontFamily: 'Playfair Display',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.darkCharcoal,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontFamily: 'Lato',
                fontSize: 13,
                color: AppColors.textGrey,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: AppColors.textGrey,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    date,
                    style: const TextStyle(
                      fontFamily: 'Lato',
                      fontSize: 12,
                      color: AppColors.textGrey,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Spacer(),
                Text(
                  'IDR ${_formatPrice(amount)}',
                  style: const TextStyle(
                    fontFamily: 'Lato',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Payment Proof:',
              style: TextStyle(
                fontFamily: 'Lato',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.darkCharcoal,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _showProofImage(proofUrl),
              child: Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primaryGold, width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Image.network(
                    proofUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: const Text(
                      'REVISION',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text(
                      'APPROVE',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onTapDetail,
              child: const Text(
                'View Full Details',
                style: TextStyle(
                  color: AppColors.primaryGold,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String type) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: Colors.green.shade300,
          ),
          const SizedBox(height: 16),
          const Text(
            'All caught up!',
            style: TextStyle(
              fontFamily: 'Playfair Display',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.darkCharcoal,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No pending $type to verify.',
            style: TextStyle(fontFamily: 'Lato', color: AppColors.textGrey),
          ),
        ],
      ),
    );
  }
}
