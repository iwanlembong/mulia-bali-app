import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/reservation_model.dart';
import 'auth_service.dart';
import 'email_service.dart'; // ✅ Pastikan import ini ada di bagian atas file
import 'loyalty_service.dart';
import 'notification_service.dart';

class ReservationService {
  /// ✅ 1. CEK KETERSEDIAAN KAMAR (Mencegah Overbooking)
  /// Mengembalikan jumlah kamar yang MASIH TERSEDIA
  static Future<int> checkAvailability({
    required String roomId,
    required DateTime checkIn,
    required DateTime checkOut,
    int roomCount = 1,
  }) async {
    try {
      // Format tanggal ke YYYY-MM-DD untuk Postgres
      final checkInStr = checkIn.toIso8601String().split('T')[0];
      final checkOutStr = checkOut.toIso8601String().split('T')[0];

      // Panggil RPC check_room_availability
      final response = await Supabase.instance.client.rpc(
        'check_room_availability',
        params: {
          'p_room_id': roomId,
          'p_check_in': checkInStr,
          'p_check_out': checkOutStr,
          'p_room_count': roomCount,
        },
      );

      final availableRooms = response as int;
      return availableRooms;
    } catch (e) {
      print('❌ [RES] Error checking availability: $e');
      return 0; // Asumsikan penuh jika error
    }
  }

  /// ✅ 2. BUAT RESERVASI BARU
  static Future<Reservation?> createReservation({
    required String roomId,
    required String propertyId,
    required DateTime checkIn,
    required DateTime checkOut,
    required int pricePerNight,
    int roomCount = 1,
    int adults = 2,
    int children = 0,
    String? specialRequests,
    String? promoCode,
    int discountAmount = 0,
    // ✅ TAMBAHKAN 2 PARAMETER INI DI SINI
    String? voucherId,
    int voucherDiscount = 0,
  }) async {
    final userId = AuthService.currentUserId;
    if (userId == null) {
      print('❌ [RES] User belum login');
      return null;
    }

    try {
      // 1. Hitung jumlah malam
      final nights = checkOut.difference(checkIn).inDays;

      // 2. Hitung total dasar (Base Total)
      final baseTotal = pricePerNight * roomCount * nights;

      // 3. Hitung total akhir (Final Total) setelah dikurangi SEMUA diskon
      // ✅ PERBAIKAN: Kurangi discountAmount DAN voucherDiscount
      int finalTotalAmount = baseTotal - discountAmount - voucherDiscount;
      if (finalTotalAmount < 0) finalTotalAmount = 0; // Cegah total minus

      // 4. Generate Reservation Number via RPC
      final resNumberResponse = await Supabase.instance.client.rpc(
        'generate_reservation_number',
      );
      final reservationNumber = resNumberResponse.toString();

      // 5. Insert ke tabel reservations
      final insertResponse = await Supabase.instance.client
          .from('reservations')
          .insert({
            'user_id': userId,
            'room_id': roomId,
            'property_id': propertyId,
            'reservation_number': reservationNumber,
            'room_count': roomCount,
            'check_in': checkIn.toIso8601String().split('T')[0],
            'check_out': checkOut.toIso8601String().split('T')[0],
            'adults': adults,
            'children': children,
            'price_per_night': pricePerNight,
            'special_requests': specialRequests,
            // ✅ TAMBAHKAN BARIS INI (Menghitung selisih hari antara check-in dan check-out)
            'nights': checkOut.difference(checkIn).inDays, 
            // ✅ DATA DISKON LENGKAP (Sekarang variabelnya sudah didefinisikan di atas)
            'total_amount': finalTotalAmount,
            'discount_amount': discountAmount,
            'promo_code': promoCode,
            'voucher_id': voucherId,
            'voucher_discount_amount': voucherDiscount,
          })
          .select('*, rooms(name, image_url)')
          .single();

      final reservation = Reservation.fromMap(insertResponse);

      // ✅ 6. AMBIL DATA USER & KIRIM EMAIL (Fire and forget)
      try {
        final profileResponse = await Supabase.instance.client
            .from('profiles')
            .select('full_name, email')
            .eq('id', userId)
            .maybeSingle();

        if (profileResponse != null) {
          final userName = profileResponse['full_name'] ?? 'Valued Guest';
          final userEmail = profileResponse['email'] as String?;

          if (userEmail != null && userEmail.isNotEmpty) {
            final htmlContent =
                EmailService.generateReservationConfirmationTemplate(
                  reservation,
                  userName,
                );

            EmailService.sendEmail(
              to: userEmail,
              subject:
                  'Room Reservation Received - ${reservation.reservationNumber}',
              htmlContent: htmlContent,
            );
          }
        }
      } catch (emailError) {
        print(
          '⚠️ [RES] Failed to send email, but the reservation was successful: $emailError',
        );
      }

      // ✅ 7. UPDATE COUNTER (Hanya tambah upcoming_stays, JANGAN kasih poin dulu!)
      await _updateProfileCounters(userId, isCompleted: false, nights: nights);

      return reservation;
    } catch (e) {
      print('❌ [RES] Error creating reservation: $e');
      return null;
    }
  }

  /// ✅ 3. AMBIL RIWAYAT RESERVASI USER
  static Future<List<Reservation>> getUserReservations({
    String? statusFilter,
  }) async {
    final userId = AuthService.currentUserId;
    if (userId == null) return [];

    try {
      // 1. Mulai query dasar
      var query = Supabase.instance.client
          .from('reservations')
          .select('*, rooms(name, image_url)')
          .eq('user_id', userId);

      // 2. ✅ TERAPKAN FILTER DI SINI (SEBELUM .order)
      if (statusFilter != null && statusFilter != 'all') {
        query = query.eq('status', statusFilter);
      }

      // 3. ✅ TERAPKAN ORDERING DI SINI (PALING AKHIR SEBELUM AWAIT)
      final response = await query.order('created_at', ascending: false);

      return (response as List)
          .map((item) => Reservation.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ [RES] Error retrieving reservation history: $e');
      return [];
    }
  }

  /// ✅ 4. AMBIL DETAIL RESERVASI (Untuk halaman detail)
  static Future<Reservation?> getReservationById(String reservationId) async {
    try {
      final response = await Supabase.instance.client
          .from('reservations')
          .select('*, rooms(name, image_url)')
          .eq('id', reservationId)
          .maybeSingle();

      if (response == null) {
        print('❌ [RES] No reservation found for ID: $reservationId');
        return null;
      }

      // ✅ Ambil data profil tamu berdasarkan user_id
      String? guestName;
      String? guestEmail;
      final userId = response['user_id'] as String?;

      if (userId != null) {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('full_name, email')
            .eq('id', userId)
            .maybeSingle();

        if (profile != null) {
          guestName = profile['full_name'] as String?;
          guestEmail = profile['email'] as String?;
        }
      }

      // ✅ Suntikkan data tamu ke dalam map response sebelum di-parse
      response['guest_name'] = guestName ?? 'Unknown Guest';
      response['guest_email'] = guestEmail ?? 'No Email';

      return Reservation.fromMap(response);
    } catch (e) {
      print('❌ [RES] Error retrieving reservation details: $e');
      return null;
    }
  }

  /// ✅ 5. CANCEL RESERVASI (Oleh User)
  static Future<bool> cancelReservation(String reservationId) async {
    final userId = AuthService.currentUserId;
    if (userId == null) return false;

    try {
      // 1. Validasi ownership & status (✅ TAMBAHKAN 'voucher_id' di sini)
      final currentData = await Supabase.instance.client
          .from('reservations')
          .select('user_id, status, check_in, check_out, voucher_id')
          .eq('id', reservationId)
          .maybeSingle();

      if (currentData == null || currentData['user_id'] != userId) return false;
      if (currentData['status'] != 'pending')
        return false; // Hanya bisa cancel jika pending

      final voucherId = currentData['voucher_id'] as String?;

      // 2. Update status menjadi cancelled
      await Supabase.instance.client
          .from('reservations')
          .update({'status': 'cancelled'})
          .eq('id', reservationId);

      // ✅ 3. BARU: REFUND VOUCHER (Kembalikan status ke 'active' jika ada voucher yang dipakai)
      if (voucherId != null && voucherId.isNotEmpty) {
        await Supabase.instance.client
            .from('redemptions')
            .update({'status': 'active'})
            .eq('id', voucherId)
            .eq(
              'status',
              'used',
            ); // Safety check: hanya revert jika statusnya 'used'
      }

      // 4. Kurangi upcoming_stays karena booking dibatalkan
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('upcoming_stays')
          .eq('id', userId)
          .single();

      int currentUpcoming = (profile['upcoming_stays'] as num?)?.toInt() ?? 0;
      int newUpcoming = currentUpcoming - 1;
      if (newUpcoming < 0) newUpcoming = 0;

      await Supabase.instance.client
          .from('profiles')
          .update({'upcoming_stays': newUpcoming})
          .eq('id', userId);

      return true;
    } catch (e) {
      print('❌ [RES] Error cancelling reservation: $e');
      return false;
    }
  }

  /// ✅ 6. UPDATE STATUS (Oleh Admin) + Notifikasi In-App
  static Future<bool> updateReservationStatus(
    String reservationId,
    String newStatus, {
    String? rejectionReason, // ✅ BARU: Parameter opsional
  }) async {
    try {
      // ✅ Update status DAN rejection_reason (jika ada)
      final updateData = {'status': newStatus};
      if (rejectionReason != null && rejectionReason.isNotEmpty) {
        updateData['rejection_reason'] = rejectionReason;
      }

      await Supabase.instance.client
          .from('reservations')
          .update(updateData)
          .eq('id', reservationId);

      // 2. Ambil data reservasi terbaru
      final res = await getReservationById(reservationId);

      // ✅ PERBAIKAN: Pastikan res TIDAK null DAN res.userId TIDAK null
      if (res != null && res.userId != null) {
        // ✅ BARU: LOGIKA REFUND VOUCHER SAAT ADMIN MEMBATALKAN
        if (newStatus == 'cancelled') {
          // 1. Simpan ke variabel lokal agar Dart bisa mempromosikan tipe datanya
          final voucherId = res.voucherId;

          // 2. Cek null dan isEmpty pada variabel lokal
          if (voucherId != null && voucherId.isNotEmpty) {
            await Supabase.instance.client
                .from('redemptions')
                .update({'status': 'active'})
                .eq(
                  'id',
                  voucherId,
                ) // ✅ Sekarang Dart tahu ini adalah String (bukan String?)
                .eq('status', 'used');

          }
        }

        final profileResponse = await Supabase.instance.client
            .from('profiles')
            .select('full_name, email')
            // ✅ Tambahkan tanda seru (!) di sini karena kita sudah memastikan != null di atas
            .eq('id', res.userId!)
            .maybeSingle();

        if (profileResponse != null && profileResponse['email'] != null) {
          final userName = profileResponse['full_name'] ?? 'Valued Guest';
          final userEmail = profileResponse['email'] as String;

          // ✅ BARU: KIRIM IN-APP NOTIFICATION
          // ==========================================
          String notifTitle = '';
          String notifMessage = '';

          switch (newStatus) {
            case 'confirmed':
              notifTitle = 'Reservation Confirmed! ✅';
              notifMessage =
                  'Reservation ${res.reservationNumber} has been confirmed. We look forward to your arrival!';
              break;
            case 'checked_in':
              notifTitle = 'Check-in Successful 🏨';
              notifMessage =
                  'Welcome to The Mulia Bali! Your reservation ${res.reservationNumber} has been checked in.';
              break;
            case 'cancelled':
              notifTitle = 'Reservation Cancelled ❌';
              notifMessage =
                  'Reservation ${res.reservationNumber} has been cancelled. ${rejectionReason != null ? 'Reason: $rejectionReason' : 'Please contact us for further information.'}';
              break;
            default:
              notifTitle = 'Update Reservation';
              notifMessage =
                  'Your reservation status ${res.reservationNumber} has been updated to $newStatus.';
          }

          // Eksekusi kirim notifikasi (jika bukan status default yang kosong)
          if (notifTitle.isNotEmpty) {
            await NotificationService.createNotification(
              userId: res.userId!,
              title: notifTitle,
              message: notifMessage,
              type: 'reservation',
            );
          }

          // ==========================================
          // KIRIM EMAIL (Kode Anda yang sudah ada)
          // ==========================================
          // Generate template email status update
          final htmlContent = EmailService.generateReservationStatusTemplate(
            res,
            userName,
            newStatus,
          );

          String subject =
              'Reservation Status Update - ${res.reservationNumber}';
          

          // Kirim email (Fire and forget)
          EmailService.sendEmail(
            to: userEmail,
            subject: subject,
            htmlContent: htmlContent,
          );
        }
      } else {
        print(
          '⚠️ [RES] Unable to send email: Reservation data or userId not found.',
        );
      }

      return true;
    } catch (e) {
      print('❌ [RES] Error updating reservation status: $e');
      return false;
    }
  }

  /// ✅ 7. AMBIL SEMUA RESERVASI (Untuk Admin)
  static Future<List<Reservation>> getAllReservations({
    String? statusFilter,
  }) async {
    try {
      // 1. Mulai dari tabel dan select (termasuk JOIN ke rooms)
      var query = Supabase.instance.client
          .from('reservations')
          .select('*, rooms(name, image_url)');

      // 2. Tambahkan FILTER (.eq) SEBELUM transform (.order)
      if (statusFilter != null) {
        query = query.eq('status', statusFilter);
      }

      // 3. Tambahkan TRANSFORM (.order) DI AKHIR, lalu langsung di-await
      final response = await query.order('check_in', ascending: false);

      return (response as List)
          .map((item) => Reservation.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('❌ [RES] Error retrieving all reservations: $e');
      return [];
    }
  }

  // ✅ METHOD BARU: Disebut saat status berubah menjadi 'completed'
  static Future<bool> completeReservation(String reservationId) async {
    try {
      // 1. Ambil data reservasi dulu untuk hitung poin
      final resData = await Supabase.instance.client
          .from('reservations')
          .select(
            '*, user_id, reservation_number, total_amount, check_in, check_out',
          )
          .eq('id', reservationId)
          .single();

      final userId = resData['user_id'];
      final resNumber = resData['reservation_number'] as String;
      final totalAmount = (resData['total_amount'] as num).toInt();
      final checkIn = DateTime.parse(resData['check_in']);
      final checkOut = DateTime.parse(resData['check_out']);
      final nights = checkOut.difference(checkIn).inDays;

      // 2. Update status menjadi 'completed'
      await Supabase.instance.client
          .from('reservations')
          .update({'status': 'completed'})
          .eq('id', reservationId);

      // 3. BERIKAN POIN & Update Counter (total_stays)
      await LoyaltyService.awardPoints(
        userId: userId,
        amount: totalAmount,
        sourceType: 'accommodation',
        sourceId: reservationId,
        quantity: nights, // Menghitung total malam
      );

      // 4. Kurangi upcoming_stays karena sudah selesai
      await _updateProfileCounters(userId, isCompleted: true, nights: nights);

      // ==========================================
      // ✅ BARU: KIRIM IN-APP NOTIFICATION
      // ==========================================
      await NotificationService.createNotification(
        userId: userId,
        title: 'Thank You for Staying! 🎉',
        message:
            'Reservation $resNumber has been completed. Loyalty points have been added to your account.',
        type: 'reservation',
      );

      // 5. ✅ BARU: Kirim email konfirmasi check-out
      try {
        final profileResponse = await Supabase.instance.client
            .from('profiles')
            .select('full_name, email')
            .eq('id', userId)
            .maybeSingle();

        if (profileResponse != null && profileResponse['email'] != null) {
          final userName = profileResponse['full_name'] ?? 'Valued Guest';
          final userEmail = profileResponse['email'] as String;

          final res = await getReservationById(reservationId);
          if (res != null) {
            final htmlContent = EmailService.generateReservationStatusTemplate(
              res,
              userName,
              'completed',
            );

            EmailService.sendEmail(
              to: userEmail,
              subject: 'Thank You for Your Stay - ${res.reservationNumber}',
              htmlContent: htmlContent,
            );
          }
        }
      } catch (emailError) {
        print('⚠️ Failed to send email check-out: $emailError');
      }

      return true;
    } catch (e) {
      print('❌ Error completing reservation: $e');
      return false;
    }
  }

  /// ✅ HELPER: Untuk update upcoming_stays & total_stays
  static Future<void> _updateProfileCounters(
    String userId, {
    required bool isCompleted,
    required int nights,
  }) async {
    // Ambil data profil saat ini
    final profile = await Supabase.instance.client
        .from('profiles')
        .select('upcoming_stays, total_stays')
        .eq('id', userId)
        .single();

    int currentUpcoming = (profile['upcoming_stays'] as num?)?.toInt() ?? 0;
    int currentTotal = (profile['total_stays'] as num?)?.toInt() ?? 0;

    if (isCompleted) {
      // ✅ Saat check-out: upcoming_stays - 1, total_stays + 1
      int newUpcoming = currentUpcoming - 1;
      if (newUpcoming < 0) newUpcoming = 0; // Cegah minus

      await Supabase.instance.client
          .from('profiles')
          .update({
            'upcoming_stays': newUpcoming,
            'total_stays':
                currentTotal + 1, // ✅ TAMBAHKAN INI: Hitung jumlah booking
          })
          .eq('id', userId);
    } else {
      // ✅ Saat booking baru: upcoming_stays + 1
      int newUpcoming = currentUpcoming + 1;

      await Supabase.instance.client
          .from('profiles')
          .update({'upcoming_stays': newUpcoming})
          .eq('id', userId);
    }
  }

  /// ✅ STRATEGI FETCH MANUAL: 100% Anti-Gagal & Rapi
  static Future<List<Reservation>>
  getPendingReservationsForVerification() async {
    try {
      final response = await Supabase.instance.client
          .from('reservations')
          .select('*, rooms(name)')
          .eq('status', 'pending')
          .not('payment_proof_url', 'is', null)
          // ✅ PERBAIKAN: Gunakan .filter() sebagai pengganti .is_()
          .filter('rejection_reason', 'is', null)
          .order('created_at', ascending: false);

      final List<Reservation> reservationsWithGuestNames = [];

      for (var item in response as List) {
        final map = item as Map<String, dynamic>;
        final userId = map['user_id'] as String?;
        String guestName = 'Guest';

        if (userId != null && userId.isNotEmpty) {
          try {
            final profileData = await Supabase.instance.client
                .from('profiles')
                .select('full_name')
                .eq('id', userId)
                .maybeSingle();

            if (profileData != null && profileData['full_name'] != null) {
              guestName = profileData['full_name'] as String;
            }
          } catch (e) {
            print('⚠️ Failed to retrieve the users name $userId: $e');
          }
        }

        map['guest_name'] = guestName;
        reservationsWithGuestNames.add(Reservation.fromMap(map));
      }

      return reservationsWithGuestNames;
    } catch (e) {
      print('❌ [ADMIN] Error fetching pending reservations: $e');
      return [];
    }
  }
}
