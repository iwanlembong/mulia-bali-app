import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';

class AdminRoomsScreen extends StatefulWidget {
  final String propertyId;
  final String propertyName;

  const AdminRoomsScreen({
    super.key,
    required this.propertyId,
    required this.propertyName,
  });

  @override
  State<AdminRoomsScreen> createState() => _AdminRoomsScreenState();
}

class _AdminRoomsScreenState extends State<AdminRoomsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _rooms = [];

  @override
  void initState() {
    super.initState();
    _fetchRooms();
  }

  Future<void> _fetchRooms() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('rooms')
          .select()
          .eq('property_id', widget.propertyId)
          .order('sort_order', ascending: true);

      if (mounted) {
        setState(() {
          _rooms = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching rooms: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteRoom(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Room?'),
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
        await Supabase.instance.client.from('rooms').delete().eq('id', id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Room deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _fetchRooms();
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

  void _showRoomDialog({Map<String, dynamic>? room}) {
    // ✅ 1. SNAPSHOT NON-NULLABLE & EKSTRAK ID DENGAN AMAN
    final Map<String, dynamic> existing = room ?? <String, dynamic>{};
    final bool isEdit = existing.isNotEmpty;
    final String? roomId =
        existing['id'] as String?; // ✅ INI MASIH DIPAKAI NANTI

    // ✅ 2. AMBIL REFERENCES SEBELUM AWAIT (Mencegah use_build_context_synchronously)
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // ✅ 3. CONTROLLERS
    final nameController = TextEditingController(text: existing['name'] ?? '');
    final priceController = TextEditingController(
      text: existing['price_per_night']?.toString() ?? '',
    );
    final guestsController = TextEditingController(
      text: existing['max_guests']?.toString() ?? '2',
    );
    final bedController = TextEditingController(
      text: existing['bed_type'] ?? '',
    );
    final sizeController = TextEditingController(
      text: existing['size_sqm']?.toString() ?? '',
    );
    final imageController = TextEditingController(
      text: existing['image_url'] ?? '',
    );
    bool isAvailable = existing['is_available'] ?? true;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Room' : 'Add New Room'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Room Name *'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Price/night (IDR)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: guestsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Max Guests',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: bedController,
                        decoration: const InputDecoration(
                          labelText: 'Bed Type (e.g., King)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: sizeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Size (sqm)',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: imageController,
                  decoration: const InputDecoration(
                    labelText: 'Image URL (Optional)',
                    hintText: 'https://...',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Checkbox(
                      value: isAvailable,
                      onChanged: (val) =>
                          setDialogState(() => isAvailable = val ?? true),
                    ),
                    const Text('Is Available for Booking'),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              // ✅ 4. GUNAKAN 'navigator' DI SINI (Bukan Navigator.pop(context))
              onPressed: () => navigator.pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;

                final data = {
                  'property_id': widget.propertyId,
                  'name': nameController.text.trim(),
                  'price_per_night': int.tryParse(priceController.text) ?? 0,
                  'max_guests': int.tryParse(guestsController.text) ?? 2,
                  'bed_type': bedController.text.trim(),
                  'size_sqm': double.tryParse(sizeController.text),
                  'image_url': imageController.text.trim().isEmpty
                      ? null
                      : imageController.text.trim(),
                  'is_available': isAvailable,
                };

                try {
                  // ✅ 5. GUNAKAN 'roomId' DI SINI
                  if (isEdit && roomId != null) {
                    await Supabase.instance.client
                        .from('rooms')
                        .update(data)
                        .eq('id', roomId);
                  } else {
                    await Supabase.instance.client.from('rooms').insert(data);
                  }

                  // ✅ 6. GUARD CONTEXT SETELAH AWAIT
                  if (!mounted) return;

                  // ✅ 7. GUNAKAN 'navigator' DAN 'messenger' DI SINI
                  navigator.pop();
                  _fetchRooms();

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
              child: Text(isEdit ? 'Save Changes' : 'Add Room'),
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
            const Text(
              'Manage Rooms',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
            Text(
              widget.propertyName,
              style: const TextStyle(
                fontFamily: 'Playfair Display',
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin/properties'),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGold),
            )
          : _rooms.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.meeting_room_outlined,
                    size: 64,
                    color: AppColors.textGrey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No rooms found for ${widget.propertyName}.',
                    style: const TextStyle(
                      fontFamily: 'Lato',
                      color: AppColors.textGrey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showRoomDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add First Room'),
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
              itemCount: _rooms.length,
              itemBuilder: (context, index) {
                final r = _rooms[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.primaryGold.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.bed,
                        color: AppColors.primaryGold,
                      ),
                    ),
                    title: Text(
                      r['name'],
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
                          'IDR ${r['price_per_night']?.toString() ?? '0'} / night',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryGold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.person_outline,
                              size: 14,
                              color: AppColors.textGrey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${r['max_guests']} Guests',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textGrey,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.king_bed,
                              size: 14,
                              color: AppColors.textGrey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              r['bed_type'] ?? 'N/A',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textGrey,
                              ),
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
                          onPressed: () => _showRoomDialog(room: r),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Delete',
                          onPressed: () => _deleteRoom(r['id'], r['name']),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRoomDialog(),
        backgroundColor: AppColors.darkCharcoal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Room'),
      ),
    );
  }
}
