import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/order_model.dart';
import '../models/cart_model.dart';
import 'auth_service.dart';
import 'cart_service.dart';
import 'loyalty_service.dart';
import 'notification_service.dart'; // ✅ Tambahkan ini

class OrderService {
  /// ✅ METHOD UTAMA: Buat order baru dari cart yang aktif
  static Future<Order?> createOrderFromCart({
    String? notes,
    String? promoCode,
    int discountAmount = 0,
    String? voucherId, // ✅ BARU
    int voucherDiscount = 0, // ✅ BARU
  }) async {
    final userId = AuthService.currentUserId;
    if (userId == null) {
      print('❌ [ORDER] User belum login');
      return null;
    }

    try {
      print('🔍 [ORDER] === MEMULAI PROSES CHECKOUT ===');

      final cart = await CartService.getOrCreateActiveCart();
      if (cart == null || cart.items.isEmpty) {
        print('❌ [ORDER] Cart kosong atau tidak ditemukan');
        return null;
      }

      print('🛒 [ORDER] Cart ditemukan dengan ${cart.items.length} items');

      try {
        final orderNumberResponse = await Supabase.instance.client.rpc(
          'generate_order_number',
        );
        final orderNumber = orderNumberResponse.toString();

        if (orderNumber.isEmpty) {
          print('⚠️ [ORDER] RPC kosong, menggunakan fallback...');
          final fallbackNumber = 'MB-${DateTime.now().millisecondsSinceEpoch}';
          return await _createOrderWithNumber(
            fallbackNumber,
            cart,
            userId,
            notes,
            promoCode,
            discountAmount,
            voucherId, // ✅ BARU
            voucherDiscount, // ✅ BARU
          );
        }

        print('✅ [ORDER] Order number generated: $orderNumber');
        return await _createOrderWithNumber(
          orderNumber,
          cart,
          userId,
          notes,
          promoCode,
          discountAmount,
          voucherId, // ✅ BARU
          voucherDiscount, // ✅ BARU
        );
      } catch (rpcError) {
        print('⚠️ [ORDER] Error RPC: $rpcError. Menggunakan fallback...');
        final fallbackNumber = 'MB-${DateTime.now().millisecondsSinceEpoch}';
        return await _createOrderWithNumber(
          fallbackNumber,
          cart,
          userId,
          notes,
          promoCode,
          discountAmount,
          voucherId, // ✅ BARU
          voucherDiscount, // ✅ BARU
        );
      }
    } catch (e) {
      print('❌ [ORDER] Error creating order: $e');
      return null;
    }
  }

  /// ✅ HELPER: Buat order dengan order number yang sudah di-generate
  static Future<Order?> _createOrderWithNumber(
    String orderNumber,
    Cart cart,
    String userId,
    String? notes,
    String? promoCode,
    int discountAmount,
    String? voucherId, // ✅ BARU
    int voucherDiscount, // ✅ BARU
  ) async {
    try {
      // ✅ PERBAIKAN: Kurangi diskon promo DAN diskon voucher
      int finalTotalAmount =
          cart.totalAmount - discountAmount - voucherDiscount;
      if (finalTotalAmount < 0) finalTotalAmount = 0; // Cegah minus

      print(
        '🔍 [DEBUG CHECKOUT] Cart: ${cart.totalAmount}, Promo: $discountAmount, Voucher: $voucherDiscount, Final: $finalTotalAmount',
      );

      // ✅ 1. Insert order baru (tambahkan payment_method & payment_proof_url sebagai null)
      final orderResponse = await Supabase.instance.client
          .from('orders')
          .insert({
            'user_id': userId,
            'order_number': orderNumber,
            'status': 'pending',
            'total_amount': finalTotalAmount,
            'notes': notes,
            'promo_code': promoCode,
            'discount_amount': discountAmount,
            'voucher_id': voucherId, // ✅ Simpan ID voucher di order (opsional, untuk tracking)
            'voucher_discount_amount':
                voucherDiscount, // ✅ Nominal diskon dari voucher
            'payment_method': null, // ✅ BARU: Persiapan untuk payment screen
            'payment_proof_url': null, // ✅ BARU: Persiapan untuk payment screen
          })
          .select()
          .single();

      final orderId = orderResponse['id'] as String;

      // ✅ 2. Pindahkan semua cart_items ke order_items
      final orderItemsData = cart.items
          .map(
            (item) => {
              'order_id': orderId,
              'item_type': item.itemType,
              'item_id': item.itemId,
              'item_name': item.itemName,
              'quantity': item.quantity,
              'unit_price': item.unitPrice,
              'total_price': item.totalPrice,
              'metadata': item.metadata,
            },
          )
          .toList();

      await Supabase.instance.client.from('order_items').insert(orderItemsData);

      // ✅ 3. Update status cart menjadi 'checked_out'
      await Supabase.instance.client
          .from('carts')
          .update({'status': 'checked_out'})
          .eq('id', cart.id);
      CartService.itemCountNotifier.value = 0;

      // ✅ BARU: Tandai voucher sebagai 'used' di database jika ada
      if (voucherId != null) {
        await Supabase.instance.client
            .from('redemptions')
            .update({'status': 'used'})
            .eq('id', voucherId);
        print('✅ [ORDER] Voucher $voucherId marked as used.');
      }

      // ✅ 4. Ambil data user untuk keperluan Email Service
      String? userName;
      String? userEmail;
      try {
        final profileResponse = await Supabase.instance.client
            .from('profiles')
            .select('full_name, email')
            .eq('id', userId)
            .maybeSingle();

        if (profileResponse != null) {
          userName = profileResponse['full_name'] as String?;
          userEmail = profileResponse['email'] as String?;
        }
      } catch (e) {
        print('⚠️ [ORDER] Gagal mengambil profil user: $e');
      }

      // ✅ 5. Return Order object yang LENGKAP
      return Order(
        id: orderResponse['id'] as String,
        userId: userId,
        orderNumber: orderNumber,
        status: 'pending',
        totalAmount: finalTotalAmount,

        // ✅ PERBAIKAN: Tambahkan 2 baris ini agar UI langsung tahu ada diskon
        discountAmount: discountAmount,
        promoCode: promoCode,

        orderDate: DateTime.parse(orderResponse['order_date'] as String),
        notes: notes,
        createdAt: DateTime.parse(orderResponse['created_at'] as String),
        updatedAt: DateTime.parse(orderResponse['updated_at'] as String),
        items: [], // Items akan di-load saat detail dibuka
        userName: userName ?? 'Valued Guest',
        userEmail: userEmail ?? 'No Email',
        paymentMethod: null, // ✅ BARU
        paymentProofUrl: null, // ✅ BARU
      );
    } catch (e) {
      // ✅ MEKANISME AUTO-RETRY UNTUK ERROR DUPLIKAT (23505)
      final errorString = e.toString();
      if (errorString.contains('23505') ||
          errorString.contains('duplicate key')) {
        print(
          '⚠️ [ORDER] Nomor order duplikat. Mencoba lagi dengan fallback...',
        );
        final fallbackNumber = 'MB-${DateTime.now().millisecondsSinceEpoch}';
        return await _createOrderWithNumber(
          fallbackNumber,
          cart,
          userId,
          notes,
          promoCode,
          discountAmount,
          voucherId, // ✅ BARU
          voucherDiscount, // ✅ BARU
        );
      }

      print('❌ [ORDER] Error di _createOrderWithNumber: $e');
      return null;
    }
  }

  /// ✅ Ambil semua order milik user (List View - Ringan & Aman dari RLS)
  static Future<List<Order>> getUserOrders() async {
    final userId = AuthService.currentUserId;
    if (userId == null) return [];

    try {
      // ✅ PENTING: Ganti 'order_items' dengan nama tabel anak Anda di Supabase jika berbeda (misal: 'items')
      final response = await Supabase.instance.client
          .from('orders')
          .select(
            'id, user_id, order_number, status, total_amount, discount_amount, voucher_discount_amount, promo_code, order_date, created_at, updated_at, order_items(*)',
          )
          .eq('user_id', userId)
          .order('order_date', ascending: false);

      return (response as List).map((item) {
        final map = item as Map<String, dynamic>;
        
        // ✅ 1. Parse items terlebih dahulu menggunakan fromMap (sesuai model Anda)
        final List<OrderItem> parsedItems = (map['order_items'] as List?)
            ?.map((e) => OrderItem.fromMap(e as Map<String, dynamic>))
            .toList() ?? [];

        // ✅ 2. Masukkan parsedItems ke dalam Order.fromMap
        return Order.fromMap(map, items: parsedItems);
        
      }).toList();
    } catch (e) {
      print('❌ [ORDER] Error fetching user orders: $e');
      return [];
    }
  }

  /// ✅ Ambil detail 1 order beserta semua items-nya (Detail View - Lengkap)
  static Future<Order?> getOrderById(String orderId) async {
    try {
      print('🔍 [ORDER] Fetching order detail: $orderId');

      // ✅ 1. Ambil data order
      final orderResponse = await Supabase.instance.client
          .from('orders')
          .select()
          .eq('id', orderId)
          .maybeSingle();

      if (orderResponse == null) {
        print('❌ [ORDER] Order not found');
        return null;
      }

      print('✅ [ORDER] Order found: ${orderResponse['order_number']}');

      // ✅ DEBUG: Print semua kolom yang di-return dari database
      print('🔍 [DEBUG] Raw data from database:');
      print('   discount_amount: ${orderResponse['discount_amount']}');
      print(
        '   voucher_discount_amount: ${orderResponse['voucher_discount_amount']}',
      );
      print('   promo_code: ${orderResponse['promo_code']}');
      print('   total_amount: ${orderResponse['total_amount']}');

      // ✅ 2. Ambil data user secara terpisah (RLS Safe)
      final userId = orderResponse['user_id'] as String;
      String? userName;
      String? userEmail;

      try {
        final profileResponse = await Supabase.instance.client
            .from('profiles')
            .select('full_name, email')
            .eq('id', userId)
            .maybeSingle();

        if (profileResponse != null) {
          userName = profileResponse['full_name'] as String?;
          userEmail = profileResponse['email'] as String?;
        }
      } catch (e) {
        print('⚠️ [ORDER] Error fetching profile: $e');
      }

      // ✅ 3. Ambil items order
      final itemsResponse = await Supabase.instance.client
          .from('order_items')
          .select()
          .eq('order_id', orderId)
          .order('created_at', ascending: true);

      final items = (itemsResponse as List)
          .map((item) => OrderItem.fromMap(item as Map<String, dynamic>))
          .toList();

      // ✅ 4. Parse discount_amount dan promo_code dengan aman
      final discountAmount =
          (orderResponse['discount_amount'] as num?)?.toInt() ?? 0;
      final promoCode = orderResponse['promo_code'] as String?;

      print('✅ [DEBUG] Parsed values:');
      print('   discountAmount: $discountAmount');
      print('   promoCode: $promoCode');

      // ✅ 5. Bangun Order object LENGKAP
      return Order(
        id: orderResponse['id'] as String,
        userId: userId,
        orderNumber: orderResponse['order_number'] as String,
        status: orderResponse['status'] as String? ?? 'pending',
        totalAmount: orderResponse['total_amount'] as int? ?? 0,
        orderDate: DateTime.parse(orderResponse['order_date'] as String),
        notes: orderResponse['notes'] as String?,
        createdAt: DateTime.parse(orderResponse['created_at'] as String),
        updatedAt: DateTime.parse(orderResponse['updated_at'] as String),
        items: items,
        userName: userName ?? 'Unknown User',
        userEmail: userEmail ?? 'No Email',
        discountAmount: discountAmount, // ✅ PASTIKAN INI DI-PARSE
        promoCode: promoCode, // ✅ PASTIKAN INI DI-PARSE
        voucherId: orderResponse['voucher_id'] as String?, // ✅ TAMBAHKAN
        voucherDiscountAmount:
            (orderResponse['voucher_discount_amount'] as num?)?.toInt() ??
            0, // ✅ TAMBAHKAN
        paymentMethod: orderResponse['payment_method'] as String?,
        paymentProofUrl: orderResponse['payment_proof_url'] as String?,
        rejectionReason:
            orderResponse['rejection_reason'] as String?, // ✅ TAMBAHKAN INI
      );
    } catch (e) {
      print('❌ [ORDER] Error fetching order detail: $e');
      return null;
    }
  }

  /// ✅ Hitung jumlah order user (untuk badge di Profile)
  static Future<int> getUserOrderCount() async {
    final userId = AuthService.currentUserId;
    if (userId == null) return 0;

    try {
      final response = await Supabase.instance.client
          .from('orders')
          .select('id')
          .eq('user_id', userId);
      return (response as List).length;
    } catch (e) {
      print('❌ [ORDER] Error counting orders: $e');
      return 0;
    }
  }

  /// ✅ Update status order (untuk admin) + REFUND VOUCHER jika dibatalkan
  static Future<bool> updateOrderStatus(
    String orderId,
    String newStatus,
  ) async {
    try {
      // 1. Ambil data order terlebih dahulu untuk mengecek apakah ada voucher yang dipakai
      final orderData = await Supabase.instance.client
          .from('orders')
          .select('voucher_id, user_id') // Ambil voucher_id (dan user_id untuk keperluan notifikasi di masa depan)
          .eq('id', orderId)
          .maybeSingle();

      if (orderData == null) {
        print('❌ [ORDER] Order tidak ditemukan untuk ID: $orderId');
        return false;
      }

      // 2. Update status order
      await Supabase.instance.client
          .from('orders')
          .update({'status': newStatus})
          .eq('id', orderId);

      // 3. ✅ BARU: LOGIKA REFUND VOUCHER SAAT ADMIN MEMBATALKAN
      if (newStatus == 'cancelled') {
        // Gunakan variabel lokal untuk menghindari error null-safety promotion di Dart
        final voucherId = orderData['voucher_id'] as String?;

        if (voucherId != null && voucherId.isNotEmpty) {
          await Supabase.instance.client
              .from('redemptions')
              .update({'status': 'active'})
              .eq('id', voucherId)
              .eq(
                'status',
                'used',
              ); // Safety check: hanya revert jika statusnya benar-benar 'used'

          print(
            '✅ [ADMIN-ORDER] Voucher $voucherId berhasil di-refund ke status active.',
          );
        }
      }

      return true;
    } catch (e) {
      print('❌ [ORDER] Error updating status: $e');
      return false;
    }
  }

  /// ✅ Ambil semua orders (untuk Admin List View)
  static Future<List<Order>> getAllOrders({String? statusFilter}) async {
    try {
      var query = Supabase.instance.client.from('orders').select('*');
      if (statusFilter != null) {
        query = query.eq('status', statusFilter);
      }

      final response = await query.order('order_date', ascending: false);
      final ordersList = response as List;

      return ordersList.map((item) {
        final map = item as Map<String, dynamic>;
        return Order(
          id: map['id'],
          userId: map['user_id'],
          orderNumber: map['order_number'],
          status: map['status'] ?? 'pending',
          totalAmount: map['total_amount'] ?? 0,
          discountAmount:
              (map['discount_amount'] as num?)?.toInt() ?? 0, // ✅ AMBIL DISKON
          voucherDiscountAmount:
              (map['voucher_discount_amount'] as num?)?.toInt() ??
              0, // ✅ AMBIL VOUCHER
          promoCode: map['promo_code'] as String?, // ✅ AMBIL PROMO CODE
          orderDate: DateTime.parse(map['order_date']),
          createdAt: DateTime.parse(map['created_at']),
          updatedAt: DateTime.parse(map['updated_at']),
          items: [],
          userName: 'Guest User',
          userEmail: 'No Email',
          paymentMethod: map['payment_method'] as String?, // ✅ BARU
          paymentProofUrl: map['payment_proof_url'] as String?, // ✅ BARU
        );
      }).toList();
    } catch (e) {
      print('❌ [ORDER] Error fetching all orders: $e');
      return [];
    }
  }

  /// ✅ User membatalkan order sendiri (Hanya jika status 'pending')
  static Future<bool> cancelOrder(String orderId) async {
    final userId = AuthService.currentUserId;
    if (userId == null) return false;

    try {
      // ✅ TAMBAHKAN 'voucher_id' di sini
      final currentData = await Supabase.instance.client
          .from('orders')
          .select('user_id, status, voucher_id')
          .eq('id', orderId)
          .maybeSingle();

      if (currentData == null || currentData['user_id'] != userId) return false;
      if (currentData['status'] != 'pending') return false;

      final voucherId = currentData['voucher_id'] as String?;

      await Supabase.instance.client
          .from('orders')
          .update({'status': 'cancelled'})
          .eq('id', orderId);

      // ✅ REFUND VOUCHER
      if (voucherId != null && voucherId.isNotEmpty) {
        await Supabase.instance.client
            .from('redemptions')
            .update({'status': 'active'})
            .eq('id', voucherId)
            .eq('status', 'used');
      }

      return true;
    } catch (e) {
      print('❌ [ORDER] Error cancelling order: $e');
      return false;
    }
  }

  /// ✅ METHOD: Menandai Order/Booking Service sebagai Completed
  static Future<bool> completeOrder(String orderId) async {
    try {
      // 1. Ambil data order
      final orderData = await Supabase.instance.client
          .from('orders')
          .select('user_id, total_amount, order_number')
          .eq('id', orderId)
          .single();

      // 2. Deklarasikan variabel dengan NULL-SAFE (Menggunakan ?.toString() ?? '')
      final userId = orderData['user_id']?.toString() ?? '';
      final totalAmount = (orderData['total_amount'] as num?)?.toInt() ?? 0;

      // ✅ PERBAIKAN: Jika order_number null, gunakan teks 'Booking Anda'
      final orderNumber =
          orderData['order_number']?.toString() ?? 'Booking Anda';

      if (userId.isEmpty) {
        print('❌ [Order] User ID kosong, tidak bisa melanjutkan.');
        return false;
      }

      // 3. Update status menjadi completed
      await Supabase.instance.client
          .from('orders')
          .update({'status': 'completed'})
          .eq('id', orderId);

      // 4. Berikan Loyalty Points
      await LoyaltyService.awardPoints(
        userId: userId,
        amount: totalAmount,
        sourceType: 'service',
        sourceId: orderId,
        quantity: 1,
      );

      // 5. Update Counter total_services (+1 per booking)
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('total_services')
          .eq('id', userId)
          .single();

      int currentServices = (profile['total_services'] as num?)?.toInt() ?? 0;
      await Supabase.instance.client
          .from('profiles')
          .update({'total_services': currentServices + 1})
          .eq('id', userId);

      // 6. ✅ Kirim Notifikasi ke User
      await NotificationService.createNotification(
        userId: userId,
        title: 'Booking Selesai! 🎉',
        message:
            'Terima kasih telah menikmati layanan The Mulia Bali. Poin loyalitas untuk order $orderNumber telah ditambahkan ke akun Anda.',
        type: 'booking',
      );

      print(
        '✅ [Order] Berhasil menyelesaikan order $orderId. Status, Poin, Counter, & Notifikasi diupdate.',
      );
      return true;
    } catch (e) {
      print('❌ [Order] Error completing order: $e');
      return false;
    }
  }
}
