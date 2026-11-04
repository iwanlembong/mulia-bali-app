import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  // Ambil instance client Supabase
  static final SupabaseClient _client = Supabase.instance.client;

  // Cek apakah user sedang login
  static bool get isLoggedIn => _client.auth.currentSession != null;

  // Ambil data user yang sedang login
  static User? get currentUser => _client.auth.currentUser;

  // ✅ TAMBAHKAN BARIS INI: Untuk mendapatkan ID user yang sedang login
  static String? get currentUserId => currentUser?.id;

  static String get userName {
    final user = currentUser;
    if (user != null) {
      // Coba ambil dari metadata, atau fallback ke email
      return user.userMetadata?['full_name'] ??
          user.email?.split('@')[0] ??
          'Guest';
    }
    return 'Guest User';
  }

  static String get userEmail => currentUser?.email ?? 'guest@themulia.com';
  static String get userMembership =>
      'GOLD MEMBER'; // Bisa diambil dari tabel profiles nanti
  /// Cache role untuk menghindari query berulang
  static String? _cachedRole;

  // ✅ 1. TAMBAHKAN METHOD INI: Dipanggil saat app dimulai
  static Future<void> initialize() async {
    if (isLoggedIn) {
      await fetchUserRole();
    }
  }

  /// Cek apakah user saat ini adalah admin
  static bool get isAdmin {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;

    // Cek dari cache role yang kita simpan
    return _cachedRole == 'admin';
  }

  // ✅ TAMBAHKAN: Variabel untuk menyimpan path sebelum login
  static String? _returnPath;

  // ✅ TAMBAHKAN: Method untuk menyimpan return path
  static void setReturnPath(String path) {
    _returnPath = path;
    print('💾 [AUTH] Return path disimpan: $path');
  }

  // ✅ TAMBAHKAN: Method untuk mengambil dan menghapus return path
  static String? getAndClearReturnPath() {
    final path = _returnPath;
    _returnPath = null; // Hapus setelah diambil (one-time use)
    return path;
  }

  /// Fetch role user dari database
  static Future<String?> fetchUserRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _cachedRole = null;
      return null;
    }

    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      _cachedRole = response?['role'] as String?;
      return _cachedRole;
    } catch (e) {
      print('Error fetching user role: $e');
      return null;
    }
  }

  static void clearCachedRole() {
    _cachedRole = null;
  }

  // Fungsi Login Nyata
  static Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    // ✅ Jika login berhasil, langsung fetch role-nya
    if (response.user != null) {
      await fetchUserRole();
    }

    return response;
  }

  // Fungsi Register Nyata
  static Future<AuthResponse> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
      }, // Ini akan memicu trigger di database untuk membuat profil
    );
  }

  // Fungsi Logout
  static Future<void> logout() async {
    await _client.auth.signOut();
  }

  // 1. Kirim link reset password ke email
  static Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(
      email,
      // PENTING: Ini adalah URL yang akan dibuka user setelah klik link di email
      redirectTo: 'https://mulia-bali-demo.web.app/reset-password',
    );
  }

  // 2. Update password baru
  static Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }
}
