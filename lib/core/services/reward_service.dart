import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/reward_model.dart';
import 'auth_service.dart';
import 'notification_service.dart'; // ✅ Tambahkan ini agar bisa memanggil NotificationService

class RewardService {
  // 1. Ambil semua hadiah yang aktif
  static Future<List<Reward>> getActiveRewards() async {
    final response = await Supabase.instance.client
        .from('rewards')
        .select()
        .eq('is_active', true)
        .order('points_required', ascending: true);

    return (response as List)
        .map((e) => Reward.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // 2. Ambil riwayat penukaran user
  static Future<List<Redemption>> getUserRedemptions() async {
    final userId = AuthService.currentUserId;
    if (userId == null) return [];

    final response = await Supabase.instance.client
        .from('redemptions')
        .select('*, rewards(title, reward_type, reward_value, applicable_to)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((e) => Redemption.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // ✅ ADMIN: Ambil SEMUA rewards (termasuk yang non-aktif)
  static Future<List<Reward>> getAllRewardsForAdmin() async {
    final response = await Supabase.instance.client
        .from('rewards')
        .select()
        .order('points_required', ascending: true);

    return (response as List)
        .map((e) => Reward.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // ✅ ADMIN: Tambah Reward Baru (Menggunakan .toMap() dari model)
  static Future<bool> createReward(Reward reward) async {
    try {
      await Supabase.instance.client.from('rewards').insert(reward.toMap());
      return true;
    } catch (e) {
      print('❌ [ADMIN REWARD] Error creating: $e');
      return false;
    }
  }

  // ✅ ADMIN: Update Status Aktif/Non-aktif (Toggle Switch)
  static Future<bool> toggleRewardStatus(String id, bool isActive) async {
    try {
      await Supabase.instance.client
          .from('rewards')
          .update({'is_active': isActive})
          .eq('id', id);
      return true;
    } catch (e) {
      print('❌ [ADMIN REWARD] Error updating status: $e');
      return false;
    }
  }

  // 3. Proses Redeem (Kurangi Poin & Buat Voucher)
  static Future<bool> redeemReward(Reward reward) async {
    final userId = AuthService.currentUserId;
    if (userId == null) return false;

    try {
      // a. Cek poin user saat ini
      final profileRes = await Supabase.instance.client
          .from('profiles')
          .select('points')
          .eq('id', userId)
          .single();

      final currentPoints = (profileRes['points'] as num).toInt();

      if (currentPoints < reward.pointsRequired) {
        throw Exception('Insufficient points');
      }

      // b. Generate Kode Voucher Unik
      final voucherCode = 'MULIA-${Random().nextInt(9000) + 1000}';

      // c. Kurangi Poin User
      await Supabase.instance.client
          .from('profiles')
          .update({'points': currentPoints - reward.pointsRequired})
          .eq('id', userId);


      await Supabase.instance.client.from('redemptions').insert({
        'user_id': userId,
        'reward_id': reward.id, // ✅ PASTIKAN INI reward.id, BUKAN variabel lain
        'points_deducted': reward.pointsRequired,
        'voucher_code': voucherCode,
        'status': 'active',
      });

      // e. Buat notifikasi otomatis
      await NotificationService.createNotification(
        userId: userId,
        title: '🎉 New Voucher!',
        message:
            'You have successfully redeemed ${reward.pointsRequired} poin for "${reward.title}". Voucher code: $voucherCode',
        type: 'reward',
      );

      return true;
    } catch (e) {
      print('❌ [REWARD] Error redeeming: $e');
      return false;
    }
  }

  // ✅ BARU: Ambil voucher aktif user beserta detail rewardnya
  static Future<List<Redemption>> getActiveVouchers() async {
    final userId = AuthService.currentUserId;
    if (userId == null) return [];

    final response = await Supabase.instance.client
        .from('redemptions')
        .select('*, rewards(title, reward_type, reward_value, applicable_to)')
        .eq('user_id', userId)
        .eq('status', 'active')
        .order('created_at', ascending: false);

    return (response as List)
        .map((e) => Redemption.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // ✅ ADMIN: Update Reward yang sudah ada
  static Future<bool> updateReward(Reward reward) async {
    try {
      await Supabase.instance.client
          .from('rewards')
          .update(reward.toMap())
          .eq('id', reward.id);
      return true;
    } catch (e) {
      print('❌ [ADMIN REWARD] Error updating: $e');
      return false;
    }
  }

  // ✅ ADMIN: Ambil SEMUA riwayat penukaran (dengan data user & reward)
    // ✅ ADMIN: Ambil SEMUA riwayat penukaran (dengan data user & reward)
  static Future<List<Map<String, dynamic>>> getAllRedemptions({
    String? statusFilter,
  }) async {
    try {

      // 1. Mulai query dasar
      var query = Supabase.instance.client
          .from('redemptions')
          .select('''
            *,
            profiles!inner(full_name, email),
            rewards(title, reward_type, reward_value, applicable_to)
          ''');

      // 2. Terapkan filter di sini (SEBELUM .order)
      if (statusFilter != null) {
        query = query.eq('status', statusFilter);
      }

      // 3. Terapkan ordering di sini (paling akhir sebelum await)
      final response = await query.order('created_at', ascending: false);
      
      // ✅ PERBAIKAN: Kembalikan langsung tanpa 'as' cast, karena Dart sudah tahu tipenya
      return response; 
      
    } catch (e) {
      print('❌ [ADMIN] Error retrieving exchange history: $e');
      return [];
    }
  }
}
