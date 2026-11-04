import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';

class AdminRestaurantsScreen extends StatefulWidget {
  const AdminRestaurantsScreen({super.key});

  @override
  State<AdminRestaurantsScreen> createState() => _AdminRestaurantsScreenState();
}

class _AdminRestaurantsScreenState extends State<AdminRestaurantsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _restaurants = [];
  List<Map<String, dynamic>> _properties = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      // Fetch restaurants
      final restaurantsResponse = await Supabase.instance.client
          .from('restaurants')
          .select()
          .order('sort_order', ascending: true);

      // Fetch properties untuk dropdown
      final propertiesResponse = await Supabase.instance.client
          .from('properties')
          .select('id, name')
          .order('sort_order', ascending: true);

      if (mounted) {
        setState(() {
          _restaurants = List<Map<String, dynamic>>.from(restaurantsResponse);
          _properties = List<Map<String, dynamic>>.from(propertiesResponse);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteRestaurant(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Restaurant?'),
        content: Text(
          'Are you sure you want to delete "$name"? This will also delete all associated menu items.',
        ),
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
            .from('restaurants')
            .delete()
            .eq('id', id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Restaurant deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _fetchData();
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

  String _getPropertyName(String? propertyId) {
    if (propertyId == null) return 'Unknown Property';
    final prop = _properties.firstWhere(
      (p) => p['id'] == propertyId,
      orElse: () => {'name': 'Unknown'},
    );
    return prop['name'] ?? 'Unknown';
  }

  void _showRestaurantDialog({Map<String, dynamic>? restaurant}) {
    // ✅ SNAPSHOT NON-NULLABLE
    final Map<String, dynamic> existing = restaurant ?? <String, dynamic>{};
    final bool isEdit = existing.isNotEmpty;

    // ✅ AMBIL REFERENCES SEBELUM await
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final nameController = TextEditingController(text: existing['name'] ?? '');
    final cuisineController = TextEditingController(
      text: existing['cuisine_type'] ?? '',
    );
    final descController = TextEditingController(
      text: existing['description'] ?? '',
    );
    final hoursController = TextEditingController(
      text: existing['operating_hours'] ?? '',
    );
    final imageController = TextEditingController(
      text: existing['cover_image'] ?? '',
    );
    final sortController = TextEditingController(
      text: existing['sort_order']?.toString() ?? '0',
    );

    // Property dropdown
    // ✅ PERBAIKAN: Casting eksplisit ke String?
    String? selectedPropertyId = existing['property_id'] as String?;
    bool isActive = existing['is_active'] ?? true;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Restaurant' : 'Add New Restaurant'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ✅ PERBAIKAN: Tambahkan <String> pada map dan DropdownMenuItem
                DropdownButtonFormField<String>(
                  value: selectedPropertyId,
                  decoration: const InputDecoration(labelText: 'Property *'),
                  items: _properties.map<DropdownMenuItem<String>>((p) {
                    return DropdownMenuItem<String>(
                      value: p['id'] as String, // Casting eksplisit ke String
                      child: Text(p['name'] as String),
                    );
                  }).toList(),
                  onChanged: (val) =>
                      setDialogState(() => selectedPropertyId = val),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Restaurant Name *',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cuisineController,
                  decoration: const InputDecoration(
                    labelText: 'Cuisine Type (e.g., Japanese, Italian)',
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
                  controller: hoursController,
                  decoration: const InputDecoration(
                    labelText: 'Operating Hours (e.g., 18:00 - 23:00)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: imageController,
                  decoration: const InputDecoration(
                    labelText: 'Cover Image URL (Optional)',
                  ),
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
                if (nameController.text.trim().isEmpty ||
                    selectedPropertyId == null)
                  return;

                final data = {
                  'property_id': selectedPropertyId,
                  'name': nameController.text.trim(),
                  'cuisine_type': cuisineController.text.trim(),
                  'description': descController.text.trim(),
                  'operating_hours': hoursController.text.trim(),
                  'cover_image': imageController.text.trim().isEmpty
                      ? null
                      : imageController.text.trim(),
                  'sort_order': int.tryParse(sortController.text) ?? 0,
                  'is_active': isActive,
                };

                try {
                  if (isEdit) {
                    final String id = existing['id'] as String;
                    await Supabase.instance.client
                        .from('restaurants')
                        .update(data)
                        .eq('id', id);
                  } else {
                    await Supabase.instance.client
                        .from('restaurants')
                        .insert(data);
                  }

                  if (!mounted) return;

                  navigator.pop();
                  _fetchData();

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
              child: Text(isEdit ? 'Save Changes' : 'Add Restaurant'),
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
          'Manage Restaurants',
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
          : _restaurants.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.restaurant_outlined,
                    size: 64,
                    color: AppColors.textGrey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No restaurants found.',
                    style: TextStyle(
                      fontFamily: 'Lato',
                      color: AppColors.textGrey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showRestaurantDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add First Restaurant'),
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
              itemCount: _restaurants.length,
              itemBuilder: (context, index) {
                final r = _restaurants[index];
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
                        // === HEADER ===
                        Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: const Color(0xFF6B8E23).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.restaurant,
                                color: Color(0xFF6B8E23),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r['name'],
                                    style: const TextStyle(
                                      fontFamily: 'Playfair Display',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    r['cuisine_type'] ?? 'No cuisine type',
                                    style: const TextStyle(
                                      fontStyle: FontStyle.italic,
                                      fontSize: 12,
                                      color: AppColors.textGrey,
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
                                color: (r['is_active'] == true)
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
                                    color: (r['is_active'] == true)
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    (r['is_active'] == true)
                                        ? 'Active'
                                        : 'Inactive',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: (r['is_active'] == true)
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // === PROPERTY & HOURS ===
                        Row(
                          children: [
                            const Icon(
                              Icons.business,
                              size: 14,
                              color: AppColors.textGrey,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _getPropertyName(r['property_id']),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textGrey,
                                ),
                              ),
                            ),
                            if (r['operating_hours'] != null &&
                                r['operating_hours'].toString().isNotEmpty) ...[
                              const Icon(
                                Icons.access_time,
                                size: 14,
                                color: AppColors.textGrey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                r['operating_hours'],
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textGrey,
                                ),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),

                        // === TOMBOL AKSI ===
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => context.go(
                                '/admin/menu-items?restaurantId=${r['id']}&restaurantName=${Uri.encodeComponent(r['name'])}',
                              ),
                              icon: const Icon(
                                Icons.restaurant_menu,
                                size: 18,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Manage Menu',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.darkCharcoal,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 2,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: () =>
                                      _showRestaurantDialog(restaurant: r),
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.blue,
                                  ),
                                  tooltip: 'Edit',
                                  constraints: const BoxConstraints(
                                    minWidth: 40,
                                    minHeight: 40,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      _deleteRestaurant(r['id'], r['name']),
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
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
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRestaurantDialog(),
        backgroundColor: AppColors.darkCharcoal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Restaurant'),
      ),
    );
  }
}
