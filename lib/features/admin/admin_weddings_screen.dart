import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';

class AdminWeddingsScreen extends StatefulWidget {
  const AdminWeddingsScreen({super.key});

  @override
  State<AdminWeddingsScreen> createState() => _AdminWeddingsScreenState();
}

class _AdminWeddingsScreenState extends State<AdminWeddingsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _weddings = [];

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'IDR ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _fetchWeddings();
  }

  Future<void> _fetchWeddings() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('weddings')
          .select()
          .order('sort_order', ascending: true);

      if (mounted) {
        setState(() {
          _weddings = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching weddings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteWedding(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Wedding Package?'),
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
        await Supabase.instance.client.from('weddings').delete().eq('id', id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Wedding package deleted'),
              backgroundColor: Colors.green,
            ),
          );
          _fetchWeddings();
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

  void _showWeddingDialog({Map<String, dynamic>? wedding}) {
    final Map<String, dynamic> existing = wedding ?? <String, dynamic>{};
    final bool isEdit = existing.isNotEmpty;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final nameController = TextEditingController(
      text: existing['package_name'] ?? '',
    );
    final descController = TextEditingController(
      text: existing['description'] ?? '',
    );
    final priceController = TextEditingController(
      text: existing['price']?.toString() ?? '',
    );
    final imageController = TextEditingController(
      text: existing['image_url'] ?? '',
    );
    final sortController = TextEditingController(
      text: existing['sort_order']?.toString() ?? '0',
    );

    // Parse includes dari JSONB array ke string dipisah koma
    final includesRaw = existing['includes'];
    String includesText = '';
    if (includesRaw is List) {
      includesText = includesRaw.join(', ');
    }
    final includesController = TextEditingController(text: includesText);

    bool isActive = existing['is_active'] ?? true;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Wedding Package' : 'Add Wedding Package'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Package Name * (e.g., Romantic Beach Wedding)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Starting Price (IDR)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: includesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Includes (separate with comma)',
                    hintText: 'e.g., Venue, Catering, Decoration, Photographer',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: imageController,
                  decoration: const InputDecoration(labelText: 'Image URL *'),
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
                if (nameController.text.trim().isEmpty) return;

                final data = {
                  'package_name': nameController.text.trim(),
                  'description': descController.text.trim(),
                  'price': int.tryParse(priceController.text),
                  'includes': includesController.text
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList(),
                  'image_url': imageController.text.trim().isEmpty
                      ? null
                      : imageController.text.trim(),
                  'sort_order': int.tryParse(sortController.text) ?? 0,
                  'is_active': isActive,
                };

                try {
                  if (isEdit) {
                    final String id = existing['id'] as String;
                    await Supabase.instance.client
                        .from('weddings')
                        .update(data)
                        .eq('id', id);
                  } else {
                    await Supabase.instance.client
                        .from('weddings')
                        .insert(data);
                  }

                  if (!mounted) return;
                  navigator.pop();
                  _fetchWeddings();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(isEdit ? 'Updated' : 'Added'),
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
              child: Text(isEdit ? 'Save Changes' : 'Add Package'),
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
          'Manage Weddings',
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
          : _weddings.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.favorite_outline,
                    size: 64,
                    color: AppColors.textGrey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No wedding packages found.',
                    style: TextStyle(
                      fontFamily: 'Lato',
                      color: AppColors.textGrey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showWeddingDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add First Package'),
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
              itemCount: _weddings.length,
              itemBuilder: (context, index) {
                final w = _weddings[index];
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
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child:
                                  w['image_url'] != null &&
                                      w['image_url'].toString().isNotEmpty
                                  ? Image.network(
                                      w['image_url'],
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: Colors.pink.shade100
                                              .withOpacity(0.3),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.favorite,
                                          color: Colors.pink,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: Colors.pink.shade100.withOpacity(
                                          0.3,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.favorite,
                                        color: Colors.pink,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    w['package_name'],
                                    style: const TextStyle(
                                      fontFamily: 'Playfair Display',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (w['price'] != null)
                                    Text(
                                      _currencyFormat.format(w['price']),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryGold,
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
                                color: (w['is_active'] == true)
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
                                    color: (w['is_active'] == true)
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    (w['is_active'] == true)
                                        ? 'Active'
                                        : 'Inactive',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: (w['is_active'] == true)
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
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              onPressed: () => _showWeddingDialog(wedding: w),
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              tooltip: 'Edit',
                            ),
                            IconButton(
                              onPressed: () =>
                                  _deleteWedding(w['id'], w['package_name']),
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: 'Delete',
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
        onPressed: () => _showWeddingDialog(),
        backgroundColor: AppColors.darkCharcoal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Package'),
      ),
    );
  }
}
