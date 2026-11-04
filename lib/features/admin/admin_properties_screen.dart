import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';

class AdminPropertiesScreen extends StatefulWidget {
  const AdminPropertiesScreen({super.key});

  @override
  State<AdminPropertiesScreen> createState() => _AdminPropertiesScreenState();
}

class _AdminPropertiesScreenState extends State<AdminPropertiesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _properties = [];

  @override
  void initState() {
    super.initState();
    _fetchProperties();
  }

  Future<void> _fetchProperties() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('properties')
          .select()
          .order('sort_order', ascending: true);

      if (mounted) {
        setState(() {
          _properties = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching properties: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteProperty(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Property?'),
        content: Text(
          'Are you sure you want to delete "$name"? This will also delete all associated rooms.',
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
        await Supabase.instance.client.from('properties').delete().eq('id', id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Property deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _fetchProperties();
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

    void _showPropertyDialog({Map<String, dynamic>? property}) {
    // ✅ 1. SNAPSHOT NON-NULLABLE
    final Map<String, dynamic> existing = property ?? <String, dynamic>{};
    final bool isEdit = existing.isNotEmpty;

    // ✅ 2. AMBIL REFERENCES SEBELUM AWAIT
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // ✅ 3. CONTROLLERS
    final nameController = TextEditingController(text: existing['name'] ?? '');
    final taglineController = TextEditingController(text: existing['tagline'] ?? '');
    final locationController = TextEditingController(text: existing['location'] ?? '');
    final descController = TextEditingController(text: existing['description'] ?? '');
    final ratingController = TextEditingController(text: existing['star_rating']?.toString() ?? '5');
    final sortController = TextEditingController(text: existing['sort_order']?.toString() ?? '0');
    
    // ✅ BARU: Controller untuk Cover Image
    final coverImageController = TextEditingController(text: existing['cover_image'] ?? '');
    
    // ✅ HIGHLIGHTS CONTROLLER
    final highlightsRaw = existing['highlights'];
    String highlightsText = '';
    if (highlightsRaw is List) {
      highlightsText = highlightsRaw.join(', ');
    }
    final highlightsController = TextEditingController(text: highlightsText);
    
    bool isActive = existing['is_active'] ?? true;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Property' : 'Add New Property'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Property Name *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: taglineController,
                  decoration: const InputDecoration(labelText: 'Tagline'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(labelText: 'Location'),
                ),
                const SizedBox(height: 12),
                // ✅ BARU: TextField untuk Cover Image
                TextField(
                  controller: coverImageController,
                  decoration: const InputDecoration(
                    labelText: 'Cover Image URL *',
                    hintText: 'https://...',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: ratingController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Star Rating'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: sortController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Sort Order'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: highlightsController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Highlights (separate with comma)',
                    hintText: 'e.g., Ocean View, Infinity Pool',
                  ),
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
                  'tagline': taglineController.text.trim(),
                  'location': locationController.text.trim(),
                  'description': descController.text.trim(),
                  // ✅ BARU: Simpan cover_image
                  'cover_image': coverImageController.text.trim().isEmpty ? null : coverImageController.text.trim(),
                  'star_rating': int.tryParse(ratingController.text) ?? 5,
                  'sort_order': int.tryParse(sortController.text) ?? 0,
                  'highlights': highlightsController.text
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList(),
                  'is_active': isActive,
                };

                try {
                  if (isEdit) {
                    final String id = existing['id'] as String;
                    await Supabase.instance.client.from('properties').update(data).eq('id', id);
                  } else {
                    await Supabase.instance.client.from('properties').insert(data);
                  }

                  if (!mounted) return;

                  navigator.pop();
                  _fetchProperties();

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
              child: Text(isEdit ? 'Save Changes' : 'Add Property'),
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
          'Manage Properties',
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
          : _properties.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.business_outlined,
                    size: 64,
                    color: AppColors.textGrey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No properties found.',
                    style: TextStyle(
                      fontFamily: 'Lato',
                      color: AppColors.textGrey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showPropertyDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add First Property'),
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
              itemCount: _properties.length,
              itemBuilder: (context, index) {
                final p = _properties[index];
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
                        // === HEADER: Icon + Nama + Tagline ===
                        Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: AppColors.primaryGold.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.business,
                                color: AppColors.primaryGold,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p['name'],
                                    style: const TextStyle(
                                      fontFamily: 'Playfair Display',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    p['tagline'] ?? 'No tagline',
                                    style: const TextStyle(
                                      fontStyle: FontStyle.italic,
                                      fontSize: 12,
                                      color: AppColors.textGrey,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            // Badge status
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: (p['is_active'] == true)
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
                                    color: (p['is_active'] == true)
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    (p['is_active'] == true)
                                        ? 'Active'
                                        : 'Inactive',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: (p['is_active'] == true)
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

                        // === LOCATION ===
                        if (p['location'] != null &&
                            p['location'].toString().isNotEmpty)
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 14,
                                color: AppColors.textGrey,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  p['location'],
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

                        // === TOMBOL AKSI: DITATA DALAM ROW YANG FLEKSIBEL ===
                        Row(
                          mainAxisAlignment: MainAxisAlignment
                              .spaceBetween, // ✅ Membagi ruang kiri & kanan
                          children: [
                            // 1. TOMBOL MANAGE ROOMS (TANPA Expanded, agar tidak mendorong tombol lain)
                            ElevatedButton.icon(
                              onPressed: () => context.go(
                                '/admin/rooms?propertyId=${p['id']}&propertyName=${Uri.encodeComponent(p['name'])}',
                              ),
                              icon: const Icon(
                                Icons.meeting_room,
                                size: 18,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Manage Rooms',
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
                                ), // ✅ Tambah padding horizontal
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 2,
                              ),
                            ),

                            // 2. GROUP TOMBOL EDIT & DELETE
                            Row(
                              mainAxisSize: MainAxisSize
                                  .min, // ✅ Hanya ambil ruang yang dibutuhkan
                              children: [
                                IconButton(
                                  onPressed: () =>
                                      _showPropertyDialog(property: p),
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
                                      _deleteProperty(p['id'], p['name']),
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
        onPressed: () => _showPropertyDialog(),
        backgroundColor: AppColors.darkCharcoal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Property'),
      ),
    );
  }
}
