import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/form_validators.dart'; // ✅ 1. TAMBAHKAN IMPORT INI
import '../../shared_widgets/app_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    // Validasi akan otomatis memicu pesan error dari FormValidators jika tidak sesuai
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await AuthService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      await AuthService.fetchUserRole();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login successful! Welcome back.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        final returnPath = AuthService.getAndClearReturnPath();
        final destination = returnPath ?? '/';
        
        print('🔄 [LOGIN] Mengarahkan user ke: $destination');
        await Future.delayed(const Duration(milliseconds: 800));

        if (mounted) {
          if (returnPath != null) {
            print('🔄 [LOGIN] Mengganti halaman login dengan return path: $returnPath');
            context.replace(returnPath);
          } else if (AuthService.isAdmin) {
            print('👑 [LOGIN] User is admin, redirecting to /admin/dashboard');
            context.go('/admin/dashboard');
          } else {
            print('👤 [LOGIN] User is regular, redirecting to /');
            context.go('/');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        String errorMessage = _getLoginErrorMessage(e.toString());

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  String _getLoginErrorMessage(String error) {
    if (error.contains('Invalid login credentials') || error.contains('invalid login credentials')) {
      return 'Invalid email or password. Please check your credentials and try again.';
    }
    if (error.contains('Email not confirmed') || error.contains('email not confirmed')) {
      return 'Your email has not been verified yet. Please check your inbox.';
    }
    if (error.contains('Too many requests') || error.contains('too many requests')) {
      return 'Too many login attempts. Please wait a few minutes.';
    }
    if (error.contains('User not found') || error.contains('user not found')) {
      return 'No account found with this email. Please register first.';
    }
    if (error.contains('Invalid password') || error.contains('invalid password')) {
      return 'Incorrect password. Please try again.';
    }
    return 'Login failed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),

                AppLogo(
                  height: 80,
                  showText: true,
                  onTap: () => context.go('/'),
                ),

                const SizedBox(height: 8),
                const Text(
                  '(Tap logo to browse as guest)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Lato',
                    fontSize: 11,
                    color: AppColors.textGrey,
                    fontStyle: FontStyle.italic,
                  ),
                ),

                const SizedBox(height: 48),

                const Text(
                  'Welcome Back',
                  style: TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkCharcoal,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sign in to access your Mulia Privilege account.',
                  style: TextStyle(
                    fontFamily: 'Lato',
                    fontSize: 14,
                    color: AppColors.textGrey,
                  ),
                ),

                const SizedBox(height: 32),

                // ✅ 2. EMAIL FIELD DENGAN VALIDATOR KUAT
                _buildTextField(
                  controller: _emailController,
                  label: 'Email Address',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress, // Memunculkan keyboard email di HP
                  validator: FormValidators.validateEmail, // Menggunakan regex validasi email
                ),

                const SizedBox(height: 16),

                // ✅ 3. PASSWORD FIELD DENGAN VALIDATOR REQUIRED
                _buildTextField(
                  controller: _passwordController,
                  label: 'Password',
                  icon: Icons.lock_outline,
                  isPassword: true,
                  // Untuk login, cukup cek apakah kosong. Validasi ketat (huruf besar/angka) 
                  // sebaiknya hanya di halaman Register agar user tidak frustrasi saat salah ketik.
                  validator: (value) => FormValidators.validateRequired(value, 'Password'),
                ),

                const SizedBox(height: 8),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push('/forgot-password'),
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(
                        fontFamily: 'Lato',
                        color: AppColors.primaryGold,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.darkCharcoal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'SIGN IN',
                          style: TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                ),

                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Don't have an account? ",
                      style: TextStyle(
                        fontFamily: 'Lato',
                        color: AppColors.textGrey,
                        fontSize: 14,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/register'),
                      child: const Text(
                        'Register Now',
                        style: TextStyle(
                          fontFamily: 'Lato',
                          color: AppColors.primaryGold,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType, // ✅ Ditambahkan agar bisa diatur jenis keyboardnya
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primaryGold.withOpacity(0.3)),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType, // ✅ Diterapkan di sini
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            fontFamily: 'Lato',
            fontSize: 14,
            color: AppColors.textGrey,
          ),
          prefixIcon: Icon(icon, color: AppColors.primaryGold, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}