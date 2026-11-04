import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; // Untuk format mata uang IDR

import '../../core/constants/app_colors.dart';

class AdminSpaScreen extends StatefulWidget {
  const AdminSpaScreen({super.key});

  @override
  State<AdminSpaScreen> createState() => _AdminSpaScreenState();
}

class _AdminSpaScreenState extends State<AdminSpaScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _spaServices = [];

  // Formatter untuk mata uang IDR
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'IDR ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _fetchSpaServices();
  }

  Future<void> _fetchSpaServices() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('spa_services')
          .select()
          .order('sort_order', ascending: true);

      if (mounted) {
        setState(() {
          _spaServices = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching spa services: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteService(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Spa Service?'),
        content: Text('Are you sure you want to delete "$name"?'),
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
        await Supabase.instance.client.from('spa_services').delete().eq('id', id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Spa service deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _fetchSpaServices();
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

  void _showServiceDialog({Map<String, dynamic>? service}) {
    // ✅ SNAPSHOT NON-NULLABLE
    final Map<String, dynamic> existing = service ?? <String, dynamic>{};
    final bool isEdit = existing.isNotEmpty;

    // ✅ AMBIL REFERENCES SEBELUM await
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final nameController = TextEditingController(text: existing['name'] ?? '');
    final categoryController = TextEditingController(text: existing['category'] ?? '');
    final descController = TextEditingController(text: existing['description'] ?? '');
    final durationController = TextEditingController(
      text: existing['duration_minutes']?.toString() ?? '',
    );
    final priceController = TextEditingController(
      text: existing['price']?.toString() ?? '',
    );
    final imageController = TextEditingController(text: existing['image_url'] ?? '');
    final sortController = TextEditingController(
      text: existing['sort_order']?.toString() ?? '0',
    );
    bool isActive = existing['is_active'] ?? true;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Spa Service' : 'Add New Spa Service'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Service Name *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Category (e.g., Massage, Facial)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: durationController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Duration (mins)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Price (IDR)',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: imageController,
                  decoration: const InputDecoration(labelText: 'Image URL (Optional)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sortController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Sort Order'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Checkbox(
                      value: isActive,
                      onChanged: (val) => setDialogState(() => isActive = val ?? true),
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
                if (nameController.text.trim().isEmpty) return;

                final data = {
                  'name': nameController.text.trim(),
                  'category': categoryController.text.trim(),
                  'description': descController.text.trim(),
                  'duration_minutes': int.tryParse(durationController.text),
                  'price': int.tryParse(priceController.text) ?? 0,
                  'image_url': imageController.text.trim().isEmpty ? null : imageController.text.trim(),
                  'sort_order': int.tryParse(sortController.text) ?? 0,
                  'is_active': isActive,
                };

                try {
                  if (isEdit) {
                    final String id = existing['id'] as String;
                    await Supabase.instance.client
                        .from('spa_services')
                        .update(data)
                        .eq('id', id);
                  } else {
                    await Supabase.instance.client
                        .from('spa_services')
                        .insert(data);
                  }

                  if (!mounted) return;

                  navigator.pop();
                  _fetchSpaServices();

                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(isEdit ? 'Updated successfully' : 'Added successfully'),
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
              child: Text(isEdit ? 'Save Changes' : 'Add Service'),
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
          'Manage Spa Services',
          style: TextStyle(fontFamily: 'Playfair Display', fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin/dashboard'),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGold))
          : _spaServices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.spa_outlined, size: 64, color: AppColors.textGrey),
                      const SizedBox(height: 16),
                      const Text(
                        'No spa services found.',
                        style: TextStyle(fontFamily: 'Lato', color: AppColors.textGrey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _showServiceDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add First Service'),
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
                  itemCount: _spaServices.length,
                  itemBuilder: (context, index) {
                    final s = _spaServices[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // === HEADER: Icon + Nama + Kategori ===
                            Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF8B7355).withOpacity(0.1), // Warna earthy untuk spa
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.spa, color: Color(0xFF8B7355)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s['name'],
                                        style: const TextStyle(
                                          fontFamily: 'Playfair Display',
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        s['category'] ?? 'Uncategorized',
                                        style: const TextStyle(
                                          fontStyle: FontStyle.italic,
                                          fontSize: 12,
                                          color: AppColors.textGrey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Badge status
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (s['is_active'] == true)
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
                                        color: (s['is_active'] == true) ? Colors.green : Colors.red,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        (s['is_active'] == true) ? 'Active' : 'Inactive',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: (s['is_active'] == true) ? Colors.green : Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                            
                            // === DETAIL: Durasi & Harga ===
                            Row(
                              children: [
                                const Icon(Icons.access_time, size: 16, color: AppColors.textGrey),
                                const SizedBox(width: 6),
                                Text(
                                  '${s['duration_minutes']} mins',
                                  style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
                                ),
                                const SizedBox(width: 16),
                                const Icon(Icons.attach_money, size: 16, color: AppColors.primaryGold),
                                const SizedBox(width: 6),
                                Text(
                                  _currencyFormat.format(s['price'] ?? 0),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.darkCharcoal,
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                            
                            // === TOMBOL AKSI ===
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  onPressed: () => _showServiceDialog(service: s),
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  tooltip: 'Edit',
                                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                ),
                                IconButton(
                                  onPressed: () => _deleteService(s['id'], s['name']),
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  tooltip: 'Delete',
                                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
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
        onPressed: () => _showServiceDialog(),
        backgroundColor: AppColors.darkCharcoal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Spa Service'),
      ),
    );
  }
}