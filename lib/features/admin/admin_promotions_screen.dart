import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';

class AdminPromotionsScreen extends StatefulWidget {
  const AdminPromotionsScreen({super.key});

  @override
  State<AdminPromotionsScreen> createState() => _AdminPromotionsScreenState();
}

class _AdminPromotionsScreenState extends State<AdminPromotionsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _promotions = [];
  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _fetchPromotions();
  }

  Future<void> _fetchPromotions() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('promotions')
          .select('*')
          // ✅ PERBAIKAN KRITIS: Ganti 'created_at' dengan 'code' agar urutan TIDAK BERUBAH
          .order('code', ascending: true); 
      
      if (mounted) {
        setState(() {
          _promotions = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error fetching promotions: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load data: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ✅ FIX 1: Toggle langsung menggunakan nilai 'val' dari switch
  Future<void> _toggleActive(String id, bool newVal) async {
    try {
      await Supabase.instance.client
          .from('promotions')
          .update({'is_active': newVal})
          .eq('id', id);

      await _fetchPromotions();
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ✅ FIX 2: Menggunakan AlertDialog (Lebih ringan, anti-crash emulator)
  // ✅ DIPERBAIKI: Menggunakan ChoiceChip & StatefulBuilder (Anti-Crash Emulator)
  Future<void> _showPromoDialog({Map<String, dynamic>? existingPromo}) async {
    final isEditing = existingPromo != null;
    final codeController = TextEditingController(
      text: isEditing ? existingPromo['code'] : '',
    );
    final valueController = TextEditingController(
      text: isEditing ? existingPromo['discount_value'].toString() : '',
    );
    final minPurchaseController = TextEditingController(
      text: isEditing ? existingPromo['min_purchase'].toString() : '0',
    );

    // State lokal untuk dialog
    String selectedType = isEditing
        ? existingPromo['discount_type']
        : 'percentage';

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        // ✅ WAJIB: StatefulBuilder agar UI dialog bisa diupdate
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            isEditing ? 'Edit Promo Code' : 'Add New Promo Code',
            style: const TextStyle(
              fontFamily: 'Playfair Display',
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(
                    labelText: 'Promo Code (e.g., SPA20)',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  enabled: !isEditing,
                ),
                const SizedBox(height: 16),

                // ✅ PENGGANTI DROPDOWN: Menggunakan ChoiceChip (Jauh lebih ringan & aman)
                const Text(
                  'Discount Type:',
                  style: TextStyle(
                    fontFamily: 'Lato',
                    fontSize: 12,
                    color: AppColors.textGrey,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text(
                          'Percentage (%)',
                          style: TextStyle(fontSize: 12),
                        ),
                        selected: selectedType == 'percentage',
                        onSelected: (val) =>
                            setDialogState(() => selectedType = 'percentage'),
                        selectedColor: AppColors.primaryGold,
                        labelStyle: TextStyle(
                          color: selectedType == 'percentage'
                              ? Colors.white
                              : AppColors.darkCharcoal,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text(
                          'Amount (IDR)',
                          style: TextStyle(fontSize: 12),
                        ),
                        selected: selectedType == 'fixed',
                        onSelected: (val) =>
                            setDialogState(() => selectedType = 'fixed'),
                        selectedColor: AppColors.primaryGold,
                        labelStyle: TextStyle(
                          color: selectedType == 'fixed'
                              ? Colors.white
                              : AppColors.darkCharcoal,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                TextField(
                  controller: valueController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Discount Value',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: minPurchaseController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Minimum Purchase (IDR)',
                    border: OutlineInputBorder(),
                    helperText: '0 = No minimum',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Cancelled',
                style: TextStyle(color: AppColors.textGrey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (codeController.text.isEmpty ||
                    valueController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Discount code and value must be filled in!'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                final parsedValue = double.tryParse(valueController.text) ?? 0;
                final parsedMin =
                    double.tryParse(minPurchaseController.text) ?? 0;

                try {
                  final payload = {
                    'code': codeController.text.toUpperCase(),
                    'discount_type': selectedType,
                    'discount_value': parsedValue,
                    'min_purchase': parsedMin,
                    'is_active': true,
                  };

                  if (isEditing) {
                    await Supabase.instance.client
                        .from('promotions')
                        .update(payload)
                        .eq('id', existingPromo['id']);
                  } else {
                    await Supabase.instance.client
                        .from('promotions')
                        .insert(payload);
                  }

                  if (mounted) {
                    Navigator.pop(dialogContext);
                    _fetchPromotions();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isEditing
                              ? 'Promo successfully updated!'
                              : 'Promo successfully added!',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to save: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGold,
              ),
              child: Text(
                isEditing ? 'UPDATE' : 'SAVE',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        backgroundColor: AppColors.darkCharcoal,
        foregroundColor: Colors.white,
        title: const Text(
          'Manage Promotions',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGold),
            )
          : _promotions.isEmpty
          ? const Center(
              child: Text(
                'No promo data available yet.',
                style: TextStyle(fontFamily: 'Lato', color: AppColors.textGrey),
              ),
            )
          : ListView(
              // ✅ GANTI ListView.builder menjadi ListView biasa
              padding: const EdgeInsets.all(16),
              children: _promotions.map((promo) {
                // ✅ Gunakan .map() untuk membangun widget secara eksplisit
                final isPercentage = promo['discount_type'] == 'percentage';
                final discountText = isPercentage
                    ? '${promo['discount_value']}%'
                    : _currencyFormat.format(promo['discount_value']);

                // Pastikan ID adalah String untuk Key
                final promoId = promo['id'].toString();

                return Card(
                  key: ValueKey(promoId), // ✅ Key unik untuk setiap Card
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGold.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.local_offer,
                            color: AppColors.primaryGold,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                promo['code'],
                                style: const TextStyle(
                                  fontFamily: 'Lato',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Discount: $discountText',
                                style: const TextStyle(
                                  fontFamily: 'Lato',
                                  color: AppColors.darkCharcoal,
                                ),
                              ),
                              Text(
                                'Min: ${_currencyFormat.format(promo['min_purchase'] ?? 0)}',
                                style: const TextStyle(
                                  fontFamily: 'Lato',
                                  fontSize: 12,
                                  color: AppColors.textGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.edit,
                            color: AppColors.primaryGold,
                            size: 20,
                          ),
                          onPressed: () =>
                              _showPromoDialog(existingPromo: promo),
                        ),
                        // ✅ Switch dengan Key yang sangat spesifik
                        Switch(
                          key: ValueKey('switch_$promoId'),
                          value: promo['is_active'] == true,
                          onChanged: (val) => _toggleActive(promoId, val),
                          activeColor: AppColors.primaryGold,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(), // ✅ Konversi hasil map menjadi List
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPromoDialog(),
        backgroundColor: AppColors.darkCharcoal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'Add Promo',
          style: TextStyle(fontFamily: 'Lato', fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
