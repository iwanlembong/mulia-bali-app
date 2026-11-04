import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/reservation_model.dart';
import '../../core/models/order_model.dart';
import '../../core/services/email_service.dart';
// ⚠️ PASTIKAN PATH INI SESUAI DENGAN STRUKTUR FOLDER ANDA
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

  // ✅ BARU: Dua list terpisah untuk Accommodation dan Services
  List<Reservation> _pendingReservations = [];
  List<Order> _pendingOrders = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchPendingVerifications();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ✅ SOLUSI BULLETPROOF: Fetch & Merge (Menghindari Error JOIN PGRST200)
  Future<void> _fetchPendingVerifications() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch Reservations (Hanya yang pending DAN belum ada alasan revisi)
      final resResponse = await Supabase.instance.client
          .from('reservations')
          .select()
          .eq('status', 'pending')
          .isFilter('rejection_reason', null) // ✅ GANTI MENJADI .isFilter()
          .not('payment_proof_url', 'is', null)
          .order('created_at', ascending: false);

      // 2. Fetch Orders (Hanya yang pending DAN belum ada alasan revisi)
      final orderResponse = await Supabase.instance.client
          .from('orders')
          .select()
          .eq('status', 'pending')
          .isFilter('rejection_reason', null) // ✅ GANTI MENJADI .isFilter()
          .not('payment_proof_url', 'is', null)
          .order('order_date', ascending: false);

      // 2. Kumpulkan semua user_id yang unik dari kedua tabel
      Set<String> userIds = {};
      for (var res in resResponse) {
        if (res['user_id'] != null) userIds.add(res['user_id']);
      }
      for (var order in orderResponse) {
        if (order['user_id'] != null) userIds.add(order['user_id']);
      }

      // 3. Ambil data nama tamu (profiles) secara batch
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

      // 4. Gabungkan (Merge) nama tamu ke dalam data Reservations & Orders
      if (mounted) {
        setState(() {
          _pendingReservations = (resResponse as List).map((e) {
            final map = e as Map<String, dynamic>;
            // ✅ Suntikkan nama tamu ke dalam map sebelum di-parse ke Model
            map['guest_name'] = userNames[map['user_id']] ?? 'Guest';
            return Reservation.fromMap(map);
          }).toList();

          _pendingOrders = (orderResponse as List).map((e) {
            final map = e as Map<String, dynamic>;
            // ✅ Suntikkan nama tamu ke dalam map sebelum di-parse ke Model
            map['user_name'] = userNames[map['user_id']] ?? 'Guest';
            return Order.fromMap(map);
          }).toList();

          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ [ADMIN] Error fetch verifications: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- LOGIKA VERIFIKASI RESERVATION (ACCOMMODATION) DENGAN REASON ---
  Future<void> _handleVerifyReservation(
    Reservation res,
    String newStatus,
  ) async {
    String? rejectionReason;

    // ✅ 1. Jika Admin menekan REVISE (Status tetap 'pending') atau CANCEL
    if (newStatus == 'pending' || newStatus == 'cancelled') {
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

      if (!mounted) return;
      if (inputConfirmed != true) return;

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
    // ✅ 2. Jika Admin menekan APPROVE (Status: confirmed)
    else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(
            'Approve Payment?',
            style: TextStyle(fontFamily: 'Playfair Display'),
          ),
          content: Text('Mark ${res.reservationNumber} as confirmed?'),
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

      if (!mounted) return;
      if (confirm != true) return;
    }

    // ✅ 3. Eksekusi Update ke Database
    try {
      Map<String, dynamic> updateData = {'status': newStatus};

      if (rejectionReason != null) {
        updateData['rejection_reason'] = rejectionReason;
      }

      await Supabase.instance.client
          .from('reservations')
          .update(updateData)
          .eq('id', res.id);

      // ✅ 4. Kirim Email Notifikasi ke User
      final resData = await Supabase.instance.client
          .from('reservations')
          .select('user_id, reservation_number')
          .eq('id', res.id)
          .single();

      final profile = await Supabase.instance.client
          .from('profiles')
          .select('email, full_name')
          .eq('id', resData['user_id'])
          .maybeSingle();

      final userEmail = profile?['email'] as String?;
      final userName = profile?['full_name'] as String? ?? 'Valued Guest';

      if (userEmail != null && userEmail.isNotEmpty) {
        EmailService.sendEmail(
          to: userEmail,
          subject: newStatus == 'confirmed'
              ? 'Reservation Confirmed - ${res.reservationNumber}'
              : 'Reservation Payment Revision - ${res.reservationNumber}',
          
          // ✅ PERBAIKAN: Tambahkan 'rejectionReason:' di depan variabelnya
          htmlContent: EmailService.generateStatusUpdateTemplate(
            res,
            userName,
            newStatus,
            rejectionReason: rejectionReason, // ✅ Sekarang Dart tahu ini adalah named parameter
          ),
        ).then((sent) {
          if (sent) {
            print('✅ [ADMIN] Reservation verification email sent to $userEmail');
          }
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              rejectionReason != null
                  ? 'Revision requested. Reason saved.'
                  : 'Reservation approved successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        _fetchPendingVerifications(); // Refresh data
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- LOGIKA VERIFIKASI ORDER (SERVICES) DENGAN REASON ---
  // --- LOGIKA VERIFIKASI ORDER (SERVICES) DENGAN REASON ---
  Future<void> _handleVerifyOrder(Order order, String newStatus) async {
    String? rejectionReason;

    // ✅ 1. Jika Admin menekan REVISE (Status: pending) atau CANCEL (Status: cancelled)
    // PASTIKAN KONDISI INI MENANGKAP 'pending'
    if (newStatus == 'pending' || newStatus == 'cancelled') {
      final reasonController = TextEditingController();

      final inputConfirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(
            'Reason for Revision', // ✅ JUDUL SAMA PERSIS DENGAN ACCOMMODATION
            style: TextStyle(
              color: Colors.orange, // ✅ WARNA ORANGE (Bukan Merah)
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
                  hintText: 'e.g., Transfer amount is incorrect, Proof is blurry',
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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700),
              child: const Text(
                'Submit Revision',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );

      if (!mounted) return;
      if (inputConfirmed != true) return;

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
    // ✅ 2. Jika Admin menekan APPROVE (Status: confirmed)
    else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(
            'Approve Payment?',
            style: TextStyle(fontFamily: 'Playfair Display'),
          ),
          content: Text('Mark ${order.orderNumber} as confirmed?'),
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

      if (!mounted) return;
      if (confirm != true) return;
    }

    // ✅ 3. Eksekusi Update ke Database
    try {
      Map<String, dynamic> updateData = {'status': newStatus};

      if (rejectionReason != null) {
        updateData['rejection_reason'] = rejectionReason;
      }

      await Supabase.instance.client
          .from('orders')
          .update(updateData)
          .eq('id', order.id);

      // ✅ 4. Kirim Email Notifikasi
      final orderData = await Supabase.instance.client
          .from('orders')
          .select('user_id, order_number')
          .eq('id', order.id)
          .single();

      final profile = await Supabase.instance.client
          .from('profiles')
          .select('email, full_name')
          .eq('id', orderData['user_id'])
          .maybeSingle();

      final userEmail = profile?['email'] as String?;
      final userName = profile?['full_name'] as String? ?? 'Valued Guest';

      if (userEmail != null && userEmail.isNotEmpty) {
        EmailService.sendEmail(
          to: userEmail,
          subject: newStatus == 'confirmed'
              ? 'Booking Confirmed - ${order.orderNumber}'
              : 'Booking Payment Revision - ${order.orderNumber}',
          htmlContent: EmailService.generateStatusUpdateTemplate(
            order,
            userName,
            newStatus,
            rejectionReason: rejectionReason, // ✅ Named parameter
          ),
        ).then((sent) {
          if (sent) {
            print('✅ [ADMIN] Booking verification email sent to $userEmail');
          }
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              rejectionReason != null
                  ? 'Revision requested. Reason saved.'
                  : 'Order approved successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        _fetchPendingVerifications(); // Refresh data
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
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
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

  // ✅ WIDGET LIST ACCOMMODATION
  Widget _buildReservationList() {
    if (_pendingReservations.isEmpty) {
      return _buildEmptyState('Accommodation bookings');
    }
    return RefreshIndicator(
      onRefresh: _fetchPendingVerifications,
      color: AppColors.primaryGold,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pendingReservations.length,
        itemBuilder: (context, index) {
          final res = _pendingReservations[index];
          return _buildVerificationCard(
            title: res.reservationNumber,
            guestName: res.guestName ?? 'Guest',
            subtitle: res.roomName ?? 'Room',
            date:
                '${DateFormat('dd MMM').format(res.checkIn)} - ${DateFormat('dd MMM').format(res.checkOut)}',
            amount: res.totalAmount,
            proofUrl: res.paymentProofUrl,
            onApprove: () => _handleVerifyReservation(res, 'confirmed'),
            onReject: () => _handleVerifyReservation(
              res,
              'pending',
            ), // Atau 'cancelled' sesuai logika Anda
            onTapDetail: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    AdminReservationDetailScreen(reservationId: res.id),
              ),
            ),
          );
        },
      ),
    );
  }

  // ✅ WIDGET LIST SERVICES (BOOKINGS)
  Widget _buildOrderList() {
    if (_pendingOrders.isEmpty) {
      return _buildEmptyState('Service bookings');
    }
    return RefreshIndicator(
      onRefresh: _fetchPendingVerifications,
      color: AppColors.primaryGold,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pendingOrders.length,
        itemBuilder: (context, index) {
          final order = _pendingOrders[index];

          // ✅ AMBIL NAMA ITEM PERTAMA JIKA ADA, JIKA TIDAK PAKAI FALLBACK
          final firstItem = order.items.isNotEmpty 
              ? order.items.first.itemName 
              : 'Service Booking';

          return _buildVerificationCard(
            title: order.orderNumber,
            guestName: order.userName ?? 'Guest',
            subtitle: firstItem,
            date: DateFormat('dd MMM yyyy').format(order.orderDate),
            amount: order.totalAmount,
            proofUrl: order.paymentProofUrl,
            onApprove: () => _handleVerifyOrder(order, 'confirmed'),
            onReject: () => _handleVerifyOrder(order, 'pending'),
            onTapDetail: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AdminBookingDetailScreen(orderId: order.id),
              ),
            ),
          );
        },
      ),
    );
  }

  // ✅ WIDGET KARTU VERIFIKASI REUSABLE (Agar kode tidak duplikat)
  Widget _buildVerificationCard({
    required String title,
    required String guestName,
    required String subtitle,
    required String date,
    required int amount,
    required String? proofUrl,
    required VoidCallback onApprove,
    required VoidCallback onReject,
    required VoidCallback onTapDetail,
  }) {
    final hasProof = proofUrl != null && proofUrl.isNotEmpty;

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
            if (hasProof)
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
              )
            else
              Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text(
                    'No proof uploaded',
                    style: TextStyle(color: Colors.grey),
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
                    onPressed: hasProof ? onApprove : null,
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
          Text(
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
