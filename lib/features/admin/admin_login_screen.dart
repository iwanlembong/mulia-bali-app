import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../shared_widgets/app_logo.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Login user
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // 2. Fetch role
      await AuthService.fetchUserRole();

      // 3. Cek apakah admin
      if (!AuthService.isAdmin) {
        // Bukan admin, logout dan tampilkan error
        await Supabase.instance.client.auth.signOut();
        setState(() {
          _errorMessage = 'Access denied. This account does not have admin privileges.';
        });
        return;
      }

      // 4. Admin verified, redirect ke dashboard
      if (mounted) {
        context.go('/admin/dashboard');
      }
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred: $e';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.darkCharcoal),
          onPressed: () => context.go('/login'),
        ),
        title: const Text(
          'Admin Access',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            color: AppColors.darkCharcoal,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
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
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primaryGold.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.admin_panel_settings, color: AppColors.primaryGold, size: 32),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Restricted Area\nAuthorized personnel only',
                          style: TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 13,
                            color: AppColors.darkCharcoal,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Admin Sign In',
                  style: TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkCharcoal,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter your admin credentials to access the management dashboard.',
                  style: TextStyle(fontFamily: 'Lato', fontSize: 14, color: AppColors.textGrey),
                ),
                const SizedBox(height: 32),
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(fontFamily: 'Lato', fontSize: 13, color: Colors.red),
                    ),
                  ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primaryGold.withOpacity(0.3)),
                  ),
                  child: TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v!.isEmpty ? 'Email is required' : null,
                    decoration: const InputDecoration(
                      labelText: 'Admin Email',
                      prefixIcon: Icon(Icons.email_outlined, color: AppColors.primaryGold, size: 20),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primaryGold.withOpacity(0.3)),
                  ),
                  child: TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    validator: (v) => v!.isEmpty ? 'Password is required' : null,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline, color: AppColors.primaryGold, size: 20),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.darkCharcoal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text(
                          'ACCESS DASHBOARD',
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