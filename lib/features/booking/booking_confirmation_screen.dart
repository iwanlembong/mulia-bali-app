import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/order_model.dart';

class BookingConfirmationScreen extends StatelessWidget {
  final Order order;

  const BookingConfirmationScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'IDR ',
      decimalDigits: 0,
    );

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.darkCharcoal),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // ✅ Success Icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  size: 80,
                  color: Colors.green.shade600,
                ),
              ),

              const SizedBox(height: 24),

              // ✅ Success Message
              const Text(
                'Booking Confirmed!',
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkCharcoal,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Thank you for your reservation.',
                style: TextStyle(
                  fontFamily: 'Lato',
                  fontSize: 16,
                  color: AppColors.textGrey,
                ),
              ),

              const SizedBox(height: 32),

              // ✅ Order Details Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Order Number
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Order Number',
                          style: TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 13,
                            color: AppColors.textGrey,
                          ),
                        ),
                        Text(
                          order.orderNumber,
                          style: const TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryGold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Order Date
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Booking Date',
                          style: TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 13,
                            color: AppColors.textGrey,
                          ),
                        ),
                        Text(
                          order.formattedDate,
                          style: const TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkCharcoal,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Status',
                          style: TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 13,
                            color: AppColors.textGrey,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            order.statusLabel,
                            style: TextStyle(
                              fontFamily: 'Lato',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Total Amount
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Amount',
                          style: TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 13,
                            color: AppColors.textGrey,
                          ),
                        ),
                        Text(
                          currencyFormat.format(order.totalAmount),
                          style: const TextStyle(
                            fontFamily: 'Playfair Display',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkCharcoal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ✅ Info Message
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primaryGold.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: AppColors.primaryGold,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'A confirmation email will be sent to your registered email address. You can view your booking details in the "My Bookings" section.',
                        style: TextStyle(
                          fontFamily: 'Lato',
                          fontSize: 13,
                          color: AppColors.darkCharcoal,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ✅ Action Buttons
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // ✅ PERBAIKAN: Arahkan ke halaman My Bookings
                    context.go('/my-bookings');
                  },
                  icon: const Icon(Icons.list_alt, size: 18),
                  label: const Text(
                    'VIEW MY BOOKINGS',
                    style: TextStyle(
                      fontFamily: 'Lato',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.darkCharcoal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.home, size: 18),
                  label: const Text(
                    'BACK TO HOME',
                    style: TextStyle(
                      fontFamily: 'Lato',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.darkCharcoal,
                    side: const BorderSide(color: AppColors.darkCharcoal),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
