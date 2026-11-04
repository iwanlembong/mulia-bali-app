import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/special_offer_service.dart';
import '../../core/models/special_offer_model.dart';
import '../../core/widgets/offer_detail_dialog.dart';

class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key});

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  bool _isLoading = true;
  List<SpecialOfferModel> _offers = [];
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _fetchOffers();
  }

  Future<void> _fetchOffers() async {
    setState(() => _isLoading = true);
    try {
      final data = await SpecialOfferService.getActiveOffers();
      if (mounted) {
        setState(() {
          _offers = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching offers: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        backgroundColor: AppColors.darkCharcoal,
        foregroundColor: Colors.white,
        title: const Text(
          'Special Offers',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchOffers,
        color: AppColors.primaryGold,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primaryGold),
              )
            : _offers.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.local_offer_outlined,
                      size: 64,
                      color: AppColors.textGrey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No special offers available at the moment.',
                      style: TextStyle(
                        fontFamily: 'Lato',
                        fontSize: 16,
                        color: AppColors.textGrey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _fetchOffers,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGold,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _offers.length,
                itemBuilder: (context, index) {
                  final offer = _offers[index];
                  return _buildOfferCard(offer);
                },
              ),
      ),
    );
  }

 
  // ✅ Widget Kartu Offer yang Lebih Detail (Karena ruang vertikal lebih luas)
  Widget _buildOfferCard(SpecialOfferModel offer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Gambar dengan Badge Diskon
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: Image.network(
                  offer.imageUrl,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 200,
                    color: AppColors.offWhite,
                    child: const Center(
                      child: Icon(
                        Icons.image_not_supported,
                        size: 48,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ),
                ),
              ),
              if (offer.discountPercentage != null &&
                  offer.discountPercentage! > 0)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      '${offer.discountPercentage}% OFF',
                      style: const TextStyle(
                        fontFamily: 'Lato',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // 2. Informasi Detail
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                if (offer.description != null && offer.description!.isNotEmpty)
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
                const Divider(color: AppColors.primaryGold, thickness: 1),
                const SizedBox(height: 12),

                // 3. Periode Berlaku
                if (offer.validFrom != null && offer.validUntil != null)
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGold.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.calendar_today,
                          size: 20,
                          color: AppColors.primaryGold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Valid Period',
                              style: TextStyle(
                                fontFamily: 'Lato',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textGrey,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_dateFormat.format(offer.validFrom!)} - ${_dateFormat.format(offer.validUntil!)}',
                              style: const TextStyle(
                                fontFamily: 'Lato',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.darkCharcoal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 16),

                // ✅ 4. Tombol View Details & Book
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => OfferDetailDialog.show(context, offer), // ✅ Buka dialog detail
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text(
                      'VIEW DETAILS & BOOK',
                      style: TextStyle(
                        fontFamily: 'Lato',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.darkCharcoal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
