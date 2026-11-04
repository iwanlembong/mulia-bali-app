import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../constants/app_colors.dart';
import '../models/special_offer_model.dart';

class OfferDetailDialog {
  static void show(BuildContext context, SpecialOfferModel offer) {
    final dateFormat = DateFormat('dd MMM yyyy');

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: EdgeInsets.zero,
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Gambar Promo
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: Image.network(
                    offer.imageUrl,
                    height: 180,
                    width: MediaQuery.of(context).size.width,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 180,
                      width: MediaQuery.of(context).size.width,
                      color: AppColors.offWhite,
                      child: const Icon(
                        Icons.image_not_supported,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 2. Judul & Badge Diskon
                      Text(
                        offer.title,
                        style: const TextStyle(
                          fontFamily: 'Playfair Display',
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkCharcoal,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (offer.discountPercentage != null &&
                          offer.discountPercentage! > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${offer.discountPercentage}% OFF',
                            style: const TextStyle(
                              fontFamily: 'Lato',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),

                      // 3. Deskripsi
                      if (offer.description != null &&
                          offer.description!.isNotEmpty)
                        Text(
                          offer.description!,
                          style: const TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 14,
                            color: AppColors.textGrey,
                            height: 1.5,
                          ),
                        ),
                      const SizedBox(height: 16),

                      // 4. Kode Promo & Tombol Copy
                      if (offer.promoCode != null &&
                          offer.promoCode!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGold.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primaryGold.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Your Promo Code',
                                style: TextStyle(
                                  fontFamily: 'Lato',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textGrey,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      offer.promoCode!,
                                      style: const TextStyle(
                                        fontFamily: 'Lato',
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.darkCharcoal,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () async {
                                      await Clipboard.setData(
                                        ClipboardData(text: offer.promoCode!),
                                      );
                                      if (dialogContext.mounted) {
                                        ScaffoldMessenger.of(
                                          dialogContext,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Promo code copied!'),
                                            backgroundColor: Colors.green,
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.darkCharcoal,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.copy,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),

                      // 5. Periode Berlaku
                      if (offer.validFrom != null && offer.validUntil != null)
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: AppColors.primaryGold,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Valid: ${dateFormat.format(offer.validFrom!)} - ${dateFormat.format(offer.validUntil!)}',
                                style: const TextStyle(
                                  fontFamily: 'Lato',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.darkCharcoal,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Close',
                style: TextStyle(fontFamily: 'Lato', color: AppColors.textGrey),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _handleBookOffer(dialogContext, offer);
              },
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text(
                'BROWSE & BOOK',
                style: TextStyle(
                  fontFamily: 'Lato',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkCharcoal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Helper routing (dipindahkan ke sini agar rapi)
  static void _handleBookOffer(BuildContext context, SpecialOfferModel offer) {
    if (offer.promoCode != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Promo code "${offer.promoCode}" is ready to use at checkout!',
          ),
          backgroundColor: AppColors.primaryGold,
          duration: const Duration(seconds: 3),
        ),
      );
    }

    switch (offer.serviceType) {
      case 'accommodation':
        if (offer.propertyId != null) {
          context.push('/property/${offer.propertyId}');
        } else {
          context.push('/properties');
        }
        break;
      case 'spa':
        context.push('/spa'); // Sesuaikan dengan route services/spa Anda
        break;
      case 'dining':
        context.push('/dining'); // Sesuaikan dengan route services/spa Anda
        break;
      case 'wedding':
        context.push('/wedding'); // Sesuaikan dengan route services/spa Anda
        break;
      default:
        context.push('/properties');
        break;
    }
  }
}
