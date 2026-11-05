import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthService {
  // Ambil instance client Supabase
  static final SupabaseClient _client = Supabase.instance.client;

  // ✅ 1. SINGLE SOURCE OF TRUTH untuk status admin
  static bool _isAdmin = false;
  static bool get isAdmin => _isAdmin;

  // Cek apakah user sedang login
  static bool get isLoggedIn {
    try {
      return _client.auth.currentSession != null;
    } catch (e) {
      return false; // Jika error, anggap belum login
    }
  }

  // Ambil data user yang sedang login
  static User? get currentUser => _client.auth.currentUser;

  // ✅ Dapatkan ID user yang sedang login
  static String? get currentUserId => currentUser?.id;

  static String get userName {
    final user = currentUser;
    if (user != null) {
      return user.userMetadata?['full_name'] ??
          user.email?.split('@')[0] ??
          'Guest';
    }
    return 'Guest User';
  }

  static String get userEmail => currentUser?.email ?? 'guest@themulia.com';
  static String get userMembership => 'GOLD MEMBER';

  // ✅ Variabel untuk menyimpan path sebelum login
  static String? _returnPath;

  static void setReturnPath(String path) {
    _returnPath = path;
    print('💾 [AUTH] Return path disimpan: $path');
  }

  static String? getAndClearReturnPath() {
    final path = _returnPath;
    _returnPath = null;
    return path;
  }

  // ✅ 2. METHOD INI DIPANGGIL SAAT APP DIMULAI (di main.dart)
  static Future<void> initialize() async {
    try {
      final user = _client.auth.currentUser;
      if (user != null) {
        await fetchUserRole();
      } else {
        _isAdmin = false;
      }
    } catch (e) {
      print('⚠️ [AUTH] Error during auth init: $e');
    }

    // ✅ Panggil Firebase dengan aman (terpisah dari auth)
    // try {
    //   await setupFirebaseMessaging();
    // } catch (e) {
    //   print('⚠️ [FCM] Setup skipped due to error: $e');
    // }
  }

  // ✅ 3. FETCH ROLE DARI DATABASE
  static Future<void> fetchUserRole() async {
    final user = _client.auth.currentUser;
    if (user != null) {
      try {
        final response = await _client
            .from('profiles')
            .select('role')
            .eq('id', user.id)
            .maybeSingle();

        _isAdmin = response != null && response['role'] == 'admin';
        print('🔍 [AUTH] User role fetched: ${_isAdmin ? "ADMIN" : "USER"}');
      } catch (e) {
        print('❌ [AUTH] Error fetching user role: $e');
        _isAdmin = false;
      }
    } else {
      _isAdmin = false;
    }
  }

  // ✅ METHOD BARU: Minta izin dan ambil FCM Token (Versi Aman)
  static Future<void> setupFirebaseMessaging() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // 1. Minta izin notifikasi
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      print('✅ [FCM] Authorization status: ${settings.authorizationStatus}');

      // 2. Ambil Token unik perangkat
      String? token = await messaging.getToken();
      if (token != null) {
        print('🔑 [FCM] DEVICE TOKEN: $token');
      } else {
        print('⚠️ [FCM] Token is null');
      }
    } catch (e) {
      // ✅ Tangkap semua error agar tidak crash aplikasi
      print('⚠️ [FCM] Setup failed (non-fatal): $e');
    }
  }

  // ✅ 4. METHOD TAMBAHAN: Agar kode Anda yang lain tidak error
  static void clearCachedRole() {
    _isAdmin = false;
    print('🧹 [AUTH] Role cache cleared.');
  }

  // ✅ 5. FUNGSI LOGIN
  static Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.user != null) {
      await fetchUserRole();
    }

    return response;
  }

  // ✅ 6. FUNGSI REGISTER
  static Future<AuthResponse> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );
  }

  // ✅ 7. FUNGSI LOGOUT (Reset status admin saat logout!)
  static Future<void> logout() async {
    await _client.auth.signOut();
    _isAdmin = false;
    _returnPath = null;
    print('🚪 [AUTH] User logged out. Admin status reset.');
  }

  // ✅ 8. RESET PASSWORD
  static Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: 'https://mulia-bali-demo.web.app/reset-password',
    );
  }

  // ✅ 9. UPDATE PASSWORD
  static Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }
}
