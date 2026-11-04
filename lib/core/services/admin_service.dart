import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

/// Service khusus untuk operasi admin
class AdminService {
  /// Cek apakah user yang login adalah admin
  static Future<bool> verifyAdminAccess() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;

    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      final role = response?['role'] as String?;
      return role == 'admin';
    } catch (e) {
      print('Error verifying admin access: $e');
      return false;
    }
  }

  /// Logout admin
  static Future<void> logout() async {
    await Supabase.instance.client.auth.signOut();
    AuthService.clearCachedRole(); // Akan kita tambahkan di step 3
  }
}