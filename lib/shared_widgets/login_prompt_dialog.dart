import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart'; // ✅ PENTING: Import GoRouter

import '../core/constants/app_colors.dart';

// ✅ HAPUS parameter onLoginSuccess, kita tidak membutuhkannya lagi
void showLoginPromptDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.lock_outline, color: AppColors.primaryGold, size: 28),
          SizedBox(width: 12),
          Text(
            'Member Exclusive',
            style: TextStyle(
              fontFamily: 'Playfair Display',
              fontWeight: FontWeight.bold,
              color: AppColors.darkCharcoal,
            ),
          ),
        ],
      ),
      content: const Text(
        'To book a room or reserve a table, please sign in to your Mulia Privilege account to enjoy exclusive member benefits.',
        style: TextStyle(
          fontFamily: 'Lato', 
          fontSize: 14, 
          color: AppColors.textGrey, 
          height: 1.5
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Maybe Later', style: TextStyle(color: AppColors.textGrey)),
        ),
        ElevatedButton(
          onPressed: () {
            // ✅ LANGKAH 1: Tutup dialog terlebih dahulu
            Navigator.pop(context); 
            
            // ✅ LANGKAH 2: Arahkan ke halaman login menggunakan GoRouter
            // Ini menjaga tumpukan navigasi (navigation stack) tetap rapi dan konsisten
            context.push('/login'); 
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGold,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Sign In', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}