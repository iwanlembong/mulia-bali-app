import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/payment_model.dart';
import 'auth_service.dart'; // Untuk mengambil ID user yang sedang login

class PaymentService {
  // ✅ 1. UPLOAD PEMBAYARAN BARU (User Action)
  static Future<bool> uploadPayment({
    String? orderId,
    String? reservationId,
    required int amount,
    required String paymentType, // 'DP', 'Full Payment', 'Installment'
    required String proofUrl,    // URL gambar dari Storage (Firebase/Supabase)
  }) async {
    try {
      final userId = AuthService.currentUserId;
      if (userId == null) throw Exception('User not logged in');

      // Validasi: Harus ada orderId ATAU reservationId
      if (orderId == null && reservationId == null) {
        throw Exception('Payment must be linked to an Order or Reservation');
      }

      await Supabase.instance.client.from('order_payments').insert({
        'order_id': orderId,
        'reservation_id': reservationId,
        'amount': amount,
        'payment_type': paymentType,
        'payment_proof_url': proofUrl,
        'payment_date': DateTime.now().toIso8601String().split('T').first,
        'status': 'pending', // Selalu mulai dengan pending
        'created_at': DateTime.now().toIso8601String(),
      });

      print('✅ [PAYMENT] Berhasil upload bukti pembayaran: $paymentType - IDR $amount');
      return true;
    } catch (e) {
      print('❌ [PAYMENT] Gagal upload pembayaran: $e');
      return false;
    }
  }

  // ✅ 2. AMBIL RIWAYAT PEMBAYARAN BERDASARKAN ORDER ID (User & Admin)
  static Future<List<OrderPayment>> getPaymentsByOrderId(String orderId) async {
    try {
      final response = await Supabase.instance.client
          .from('order_payments')
          .select('*')
          .eq('order_id', orderId)
          .order('created_at', ascending: false);

      return (response as List).map((e) => OrderPayment.fromMap(e)).toList();
    } catch (e) {
      print('❌ [PAYMENT] Gagal mengambil pembayaran untuk Order $orderId: $e');
      return [];
    }
  }

  // ✅ 3. AMBIL RIWAYAT PEMBAYARAN BERDASARKAN RESERVATION ID (User & Admin)
  static Future<List<OrderPayment>> getPaymentsByReservationId(String reservationId) async {
    try {
      final response = await Supabase.instance.client
          .from('order_payments')
          .select('*')
          .eq('reservation_id', reservationId)
          .order('created_at', ascending: false);

      return (response as List).map((e) => OrderPayment.fromMap(e)).toList();
    } catch (e) {
      print('❌ [PAYMENT] Gagal mengambil pembayaran untuk Reservation $reservationId: $e');
      return [];
    }
  }

  // ✅ 4. AMBIL SEMUA PEMBAYARAN PENDING (Khusus Admin Dashboard)
  static Future<List<OrderPayment>> getPendingPayments() async {
    try {
      // Kita limit 50 agar dashboard tidak berat
      final response = await Supabase.instance.client
          .from('order_payments')
          .select('*')
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .limit(50);

      return (response as List).map((e) => OrderPayment.fromMap(e)).toList();
    } catch (e) {
      print('❌ [PAYMENT] Gagal mengambil pending payments: $e');
      return [];
    }
  }

  // ✅ 5. UPDATE STATUS PEMBAYARAN (Khusus Admin: Approve/Reject)
  static Future<bool> updatePaymentStatus(
    String paymentId, 
    String newStatus, {
    String? rejectionReason,
  }) async {
    try {
      final adminId = AuthService.currentUserId;
      final updateData = {
        'status': newStatus,
        'verified_by': adminId,
        'verified_at': DateTime.now().toIso8601String(),
      };

      if (rejectionReason != null) {
        updateData['rejection_reason'] = rejectionReason;
      }

      await Supabase.instance.client
          .from('order_payments')
          .update(updateData)
          .eq('id', paymentId);

      print('✅ [PAYMENT] Status pembayaran $paymentId diubah menjadi $newStatus');
      return true;
    } catch (e) {
      print('❌ [PAYMENT] Gagal update status pembayaran: $e');
      return false;
    }
  }
}