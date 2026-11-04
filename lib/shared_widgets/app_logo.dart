import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class AppLogo extends StatelessWidget {
  final double height;
  final bool showText;
  final VoidCallback? onTap; // <-- TAMBAHKAN PARAMETER INI

  const AppLogo({
    super.key,
    this.height = 60, // Default tinggi untuk halaman Login
    this.showText = true,
    this.onTap, // <-- TAMBAHKAN DI SINI
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // PERUBAHAN DI SINI: Gunakan Image.asset
            Image.asset(
              'assets/images/mulia_logo.png', // Path ke file Anda
              height: height,
              fit: BoxFit.contain,
              // CATATAN: Jika logo PNG Anda sudah berwarna (misal emas/hitam), hapus baris 'color' di bawah ini.
              // Biarkan baris 'color' ini HANYA jika file PNG Anda berwarna putih polos/hitam polos dan Anda ingin memberinya warna emas via kode.
              // color: AppColors.primaryGold, 
              errorBuilder: (context, error, stackTrace) {
                // Fallback jika file tidak ditemukan
                return Text(
                  'THE MULIA',
                  style: TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: height * 0.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGold,
                    letterSpacing: 2.0,
                  ),
                );
              },
            ),
            if (showText) ...[
              const SizedBox(height: 8),
              const Text(
                'MULIA HOTELS & RESORTS',
                style: TextStyle(
                  fontFamily: 'Lato',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textGrey,
                  letterSpacing: 3.0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}