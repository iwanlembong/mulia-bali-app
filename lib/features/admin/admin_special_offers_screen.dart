import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';

class AdminSpecialOffersScreen extends StatefulWidget {
  const AdminSpecialOffersScreen({super.key});

  @override
  State<AdminSpecialOffersScreen> createState() =>
      _AdminSpecialOffersScreenState();
}

class _AdminSpecialOffersScreenState extends State<AdminSpecialOffersScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _offers = [];

  final DateFormat _displayDateFormat = DateFormat('dd MMM yyyy');
  final DateFormat _dbDateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _fetchOffers();
  }

  Future<void> _fetchOffers() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('special_offers')
          .select()
          .order('sort_order', ascending: true);

      if (mounted) {
        setState(() {
          _offers = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching offers: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteOffer(String id, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Offer?'),
        content: Text('Are you sure you want to delete "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client
            .from('special_offers')
            .delete()
            .eq('id', id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Offer deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _fetchOffers();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showOfferDialog({Map<String, dynamic>? offer}) async {
    final Map<String, dynamic> existing = offer ?? <String, dynamic>{};
    final bool isEdit = existing.isNotEmpty;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final titleController = TextEditingController(
      text: existing['title'] ?? '',
    );
    final descController = TextEditingController(
      text: existing['description'] ?? '',
    );
    final discountController = TextEditingController(
      text: existing['discount_percentage']?.toString() ?? '',
    );
    final imageController = TextEditingController(
      text: existing['image_url'] ?? '',
    );
    final sortController = TextEditingController(
      text: existing['sort_order']?.toString() ?? '0',
    );

    bool isActive = existing['is_active'] ?? true;
    DateTime? validFrom = existing['valid_from'] != null
        ? DateTime.parse(existing['valid_from'])
        : null;
    DateTime? validUntil = existing['valid_until'] != null
        ? DateTime.parse(existing['valid_until'])
        : null;

    // ✅ BARU: State untuk Promo Code dan Service Type
    String? selectedPromoCode = existing['promo_code'];
    String selectedServiceType = existing['service_type'] ?? 'general';

    // ✅ BARU: Fetch active promotions untuk dropdown
    List<Map<String, dynamic>> activePromos = [];
    try {
      final response = await Supabase.instance.client
          .from('promotions')
          .select('code, discount_type, discount_value')
          .eq('is_active', true)
          .order('code', ascending: true);
      activePromos = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('⚠️ Error fetching promos for dropdown: $e');
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            isEdit ? 'Edit Special Offer' : 'Add New Special Offer',
            style: const TextStyle(
              fontFamily: 'Playfair Display',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Offer Title * (e.g., Early Bird Promo)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                // ✅ BARU: Dropdown Service Type
                DropdownButtonFormField<String>(
                  value: selectedServiceType,
                  decoration: const InputDecoration(
                    labelText: 'Applicable For',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'general',
                      child: Text('General (All Services)'),
                    ),
                    DropdownMenuItem(
                      value: 'accommodation',
                      child: Text('Accommodation (Rooms)'),
                    ),
                    DropdownMenuItem(value: 'spa', child: Text('Spa Services')),
                    DropdownMenuItem(value: 'dining', child: Text('Dining')),
                    DropdownMenuItem(
                      value: 'wedding',
                      child: Text('Wedding Packages'),
                    ),
                  ],
                  onChanged: (val) =>
                      setDialogState(() => selectedServiceType = val!),
                ),
                const SizedBox(height: 12),

                // ✅ BARU: Dropdown Promo Code (Terhubung ke tabel promotions)
                DropdownButtonFormField<String>(
                  value: selectedPromoCode,
                  decoration: const InputDecoration(
                    labelText: 'Linked Promo Code (Optional)', 
                    border: OutlineInputBorder(), 
                  ),
                  items: [
                    const DropdownMenuItem<String>(value: null, child: Text('None (Manual Entry Only)')),
                    ...activePromos.map((promo) {
                      final type = promo['discount_type'] == 'percentage' ? '%' : ' IDR';
                      return DropdownMenuItem<String>(
                        value: promo['code'],
                        child: Text('${promo['code']} (Disc: ${promo['discount_value']}$type)'),
                      );
                    }).toList(),
                  ],
                  onChanged: (val) {
                    setDialogState(() {
                      selectedPromoCode = val;
                      
                      // ✅ LOGIKA AUTO-FILL: Isi discountController berdasarkan promo yang dipilih
                      if (val == null) {
                        discountController.clear(); // Kosongkan jika memilih "None"
                      } else {
                        // Cari data promo yang dipilih dari list activePromos
                        final selectedPromo = activePromos.firstWhere((p) => p['code'] == val);
                        // Isi text field dengan nilai diskonnya
                        discountController.text = selectedPromo['discount_value'].toString();
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: discountController,
                  readOnly: true, // ✅ Buat hanya baca agar admin tahu ini auto-filled
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Display Discount Badge (%)',
                    suffixText: '%',
                    helperText: 'Auto populated based on the selected Promo Code',
                    filled: true,
                    fillColor: Colors.grey.shade100, // Beri warna latar sedikit berbeda
                  ),
                ),
                const SizedBox(height: 12),

                // Date Pickers
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: dialogContext, // ✅ Gunakan dialogContext agar aman
                            initialDate: validFrom ?? DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null)
                            setDialogState(() => validFrom = picked);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Valid From *',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today, size: 20),
                          ),
                          child: Text(
                            validFrom != null
                                ? _displayDateFormat.format(validFrom!)
                                : 'Select Date',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: dialogContext, // ✅ Gunakan dialogContext agar aman
                            initialDate:
                                validUntil ??
                                (validFrom ?? DateTime.now()).add(
                                  const Duration(days: 7),
                                ),
                            firstDate: validFrom ?? DateTime.now(),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null)
                            setDialogState(() => validUntil = picked);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Valid Until *',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today, size: 20),
                          ),
                          child: Text(
                            validUntil != null
                                ? _displayDateFormat.format(validUntil!)
                                : 'Select Date',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: imageController,
                  decoration: const InputDecoration(
                    labelText: 'Image URL *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sortController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Sort Order',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Checkbox(
                      value: isActive,
                      onChanged: (val) =>
                          setDialogState(() => isActive = val ?? true),
                    ),
                    const Text('Is Active (Visible in App)'),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => navigator.pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty ||
                    validFrom == null ||
                    validUntil == null) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Please fill title and both dates'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final data = {
                  'title': titleController.text.trim(),
                  'description': descController.text.trim(),
                  'discount_percentage': int.tryParse(discountController.text),
                  'valid_from': _dbDateFormat.format(validFrom!),
                  'valid_until': _dbDateFormat.format(validUntil!),
                  'image_url': imageController.text.trim(),
                  'sort_order': int.tryParse(sortController.text) ?? 0,
                  'is_active': isActive,
                  // ✅ BARU: Simpan service_type dan promo_code ke database
                  'service_type': selectedServiceType,
                  'promo_code': selectedPromoCode,
                };

                try {
                  if (isEdit) {
                    final String id = existing['id'] as String;
                    await Supabase.instance.client
                        .from('special_offers')
                        .update(data)
                        .eq('id', id);
                  } else {
                    await Supabase.instance.client
                        .from('special_offers')
                        .insert(data);
                  }

                  if (!mounted) return;
                  navigator.pop();
                  _fetchOffers();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        isEdit ? 'Updated successfully' : 'Added successfully',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGold,
              ),
              child: Text(
                isEdit ? 'Save Changes' : 'Add Offer',
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
          'Manage Special Offers',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin/dashboard'),
        ),
      ),
      body: _isLoading
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
                    'No special offers found.',
                    style: TextStyle(
                      fontFamily: 'Lato',
                      color: AppColors.textGrey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showOfferDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add First Offer'),
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
                final o = _offers[index];
                final discount = o['discount_percentage'];

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image:
                                    o['image_url'] != null &&
                                        o['image_url'].toString().isNotEmpty
                                    ? DecorationImage(
                                        image: NetworkImage(o['image_url']),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                                color: const Color(0xFFCD5C5C).withOpacity(0.1),
                              ),
                              child:
                                  o['image_url'] == null ||
                                      o['image_url'].toString().isEmpty
                                  ? const Icon(
                                      Icons.local_offer,
                                      color: Color(0xFFCD5C5C),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    o['title'],
                                    style: const TextStyle(
                                      fontFamily: 'Playfair Display',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (discount != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '$discount% OFF',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: (o['is_active'] == true)
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: 8,
                                    color: (o['is_active'] == true)
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    (o['is_active'] == true)
                                        ? 'Active'
                                        : 'Inactive',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: (o['is_active'] == true)
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        // ✅ BARU: Tampilkan Badge Service Type & Promo Code
                        if (o['service_type'] != null ||
                            o['promo_code'] != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                if (o['service_type'] != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryGold.withOpacity(
                                        0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      o['service_type']
                                          .toString()
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.darkCharcoal,
                                      ),
                                    ),
                                  ),
                                if (o['promo_code'] != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.local_offer,
                                          size: 12,
                                          color: Colors.green,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Code: ${o['promo_code']}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: AppColors.textGrey,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${_displayDateFormat.format(DateTime.parse(o['valid_from']))} - ${_displayDateFormat.format(DateTime.parse(o['valid_until']))}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textGrey,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              onPressed: () => _showOfferDialog(offer: o),
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              tooltip: 'Edit',
                              constraints: const BoxConstraints(
                                minWidth: 40,
                                minHeight: 40,
                              ),
                            ),
                            IconButton(
                              onPressed: () =>
                                  _deleteOffer(o['id'], o['title']),
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: 'Delete',
                              constraints: const BoxConstraints(
                                minWidth: 40,
                                minHeight: 40,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showOfferDialog(),
        backgroundColor: AppColors.darkCharcoal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Offer'),
      ),
      // ✅ BARU: Pindahkan tombol ke kiri bawah agar tidak menutupi tombol Edit/Delete
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat, 
    );
  }
}
