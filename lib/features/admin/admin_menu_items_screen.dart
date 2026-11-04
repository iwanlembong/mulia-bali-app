import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';

class AdminMenuItemsScreen extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;

  const AdminMenuItemsScreen({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
  });

  @override
  State<AdminMenuItemsScreen> createState() => _AdminMenuItemsScreenState();
}

class _AdminMenuItemsScreenState extends State<AdminMenuItemsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _menuItems = [];

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'IDR ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _fetchMenuItems();
  }

  Future<void> _fetchMenuItems() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('menu_items')
          .select()
          .eq('restaurant_id', widget.restaurantId)
          .order('sort_order', ascending: true);

      if (mounted) {
        setState(() {
          _menuItems = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching menu items: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteMenuItem(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Menu Item?'),
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
        await Supabase.instance.client.from('menu_items').delete().eq('id', id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Menu item deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _fetchMenuItems();
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

  void _showMenuItemDialog({Map<String, dynamic>? menuItem}) {
    final Map<String, dynamic> existing = menuItem ?? <String, dynamic>{};
    final bool isEdit = existing.isNotEmpty;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final nameController = TextEditingController(text: existing['name'] ?? '');
    final descController = TextEditingController(text: existing['description'] ?? '');
    final priceController = TextEditingController(
      text: existing['price']?.toString() ?? '',
    );
    final categoryController = TextEditingController(text: existing['category'] ?? '');
    final imageController = TextEditingController(text: existing['image_url'] ?? '');
    final sortController = TextEditingController(
      text: existing['sort_order']?.toString() ?? '0',
    );
    bool isAvailable = existing['is_available'] ?? true;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Menu Item' : 'Add New Menu Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Menu Item Name *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Category (e.g., Appetizer, Main Course, Dessert)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Price (IDR)'),
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
                      value: isAvailable,
                      onChanged: (val) => setDialogState(() => isAvailable = val ?? true),
                    ),
                    const Text('Is Available'),
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
                  'restaurant_id': widget.restaurantId,
                  'name': nameController.text.trim(),
                  'category': categoryController.text.trim(),
                  'description': descController.text.trim(),
                  'price': int.tryParse(priceController.text) ?? 0,
                  'image_url': imageController.text.trim().isEmpty ? null : imageController.text.trim(),
                  'sort_order': int.tryParse(sortController.text) ?? 0,
                  'is_available': isAvailable,
                };

                try {
                  if (isEdit) {
                    final String id = existing['id'] as String;
                    await Supabase.instance.client
                        .from('menu_items')
                        .update(data)
                        .eq('id', id);
                  } else {
                    await Supabase.instance.client
                        .from('menu_items')
                        .insert(data);
                  }

                  if (!mounted) return;

                  navigator.pop();
                  _fetchMenuItems();

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
              child: Text(isEdit ? 'Save Changes' : 'Add Menu Item'),
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Manage Menu Items', style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal)),
            Text(
              widget.restaurantName,
              style: const TextStyle(fontFamily: 'Playfair Display', fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin/restaurants'),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGold))
          : _menuItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.restaurant_menu_outlined, size: 64, color: AppColors.textGrey),
                      const SizedBox(height: 16),
                      Text(
                        'No menu items found for ${widget.restaurantName}.',
                        style: const TextStyle(fontFamily: 'Lato', color: AppColors.textGrey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _showMenuItemDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add First Menu Item'),
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
                  itemCount: _menuItems.length,
                  itemBuilder: (context, index) {
                    final m = _menuItems[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6B8E23).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.restaurant_menu, color: Color(0xFF6B8E23)),
                        ),
                        title: Text(
                          m['name'],
                          style: const TextStyle(
                            fontFamily: 'Playfair Display',
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              _currencyFormat.format(m['price'] ?? 0),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryGold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.category, size: 14, color: AppColors.textGrey),
                                const SizedBox(width: 4),
                                Text(
                                  m['category'] ?? 'Uncategorized',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              tooltip: 'Edit',
                              onPressed: () => _showMenuItemDialog(menuItem: m),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: 'Delete',
                              onPressed: () => _deleteMenuItem(m['id'], m['name']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showMenuItemDialog(),
        backgroundColor: AppColors.darkCharcoal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Menu Item'),
      ),
    );
  }
}