import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../shared_widgets/app_logo.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isSessionReady = false;
  String _errorMessage = '';
  
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _waitForSession();
  }

  // ✅ FUNGSI KUNCI: Tunggu sampai session benar-benar siap
  Future<void> _waitForSession() async {
    print('🔵 [RESET] Menunggu session dari Supabase...');
    
    // 1. Cek apakah session sudah ada sekarang
    if (Supabase.instance.client.auth.currentSession != null) {
      print('✅ [RESET] Session sudah ada sejak awal!');
      if (mounted) setState(() => _isSessionReady = true);
      return;
    }

    // 2. Jika belum, LISTEN event dari Supabase
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;
      
      print('🔵 [RESET] Auth event: $event');

      // Saat event passwordRecovery atau signedIn terjadi, session PASTI ada
      if ((event == AuthChangeEvent.passwordRecovery || 
           event == AuthChangeEvent.signedIn) && session != null) {
        print('✅ [RESET] Session diterima dari event $event!');
        if (mounted) setState(() => _isSessionReady = true);
        _authSubscription?.cancel(); // Stop listening
      }
    });

    // 3. Timeout: Jika setelah 10 detik session belum ada, tampilkan error
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && !_isSessionReady) {
        print('⚠️ [RESET] Timeout! Session tidak muncul dalam 10 detik.');
        setState(() {
          _isSessionReady = false;
          _errorMessage = 'Link tidak valid atau sudah kedaluwarsa. Silakan minta link baru.';
        });
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Final check session
      final session = Supabase.instance.client.auth.currentSession;
      
      if (session == null) {
        throw Exception('Sesi tidak ditemukan. Silakan minta link reset password yang baru.');
      }

      print('🔵 [UPDATE] Session valid. Memanggil updateUser...');

      // Update password
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );

      print('✅ [UPDATE] Password berhasil diupdate!');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password successfully updated! Please login with your new password.'),
            backgroundColor: Colors.green,
          ),
        );

        // Logout agar user login dengan password baru
        await Supabase.instance.client.auth.signOut();
        context.go('/login');
      }
    } catch (e) {
      print('🔴 [UPDATE] Gagal: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. TAMPILAN LOADING: Tunggu session siap
    if (!_isSessionReady && _errorMessage.isEmpty) {
      return const Scaffold(
        backgroundColor: AppColors.offWhite,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.primaryGold),
              SizedBox(height: 24),
              Text(
                'Memverifikasi link Anda...',
                style: TextStyle(
                  fontFamily: 'Lato',
                  fontSize: 16,
                  color: AppColors.textGrey,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Mohon tunggu beberapa saat.',
                style: TextStyle(
                  fontFamily: 'Lato',
                  fontSize: 13,
                  color: AppColors.textGrey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 2. TAMPILAN ERROR: Jika session gagal didapat
    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        backgroundColor: AppColors.offWhite,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.darkCharcoal),
            onPressed: () => context.go('/login'),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.link_off, size: 64, color: Colors.red),
                const SizedBox(height: 24),
                const Text(
                  'Invalid or Expired Link',
                  style: TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkCharcoal,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Lato',
                    fontSize: 14,
                    color: AppColors.textGrey,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => context.go('/forgot-password'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.darkCharcoal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: const Text('Request New Link', style: TextStyle(fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ),
        ),
      );
    }

    // 3. TAMPILAN FORM: Session sudah siap!
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.darkCharcoal),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AppLogo(height: 60, showText: true),
                const SizedBox(height: 32),
                const Text(
                  'Create New Password',
                  style: TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkCharcoal,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please enter your new password below.',
                  style: TextStyle(fontFamily: 'Lato', fontSize: 14, color: AppColors.textGrey),
                ),
                const SizedBox(height: 32),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primaryGold.withOpacity(0.3)),
                  ),
                  child: TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    validator: (v) {
                      if (v!.isEmpty) return 'Password is required';
                      if (v.length < 6) return 'Must be at least 6 characters';
                      return null;
                    },
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                      prefixIcon: Icon(Icons.lock_outline, color: AppColors.primaryGold, size: 20),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleUpdatePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.darkCharcoal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text(
                          'UPDATE PASSWORD',
                          style: TextStyle(fontFamily: 'Lato', fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}