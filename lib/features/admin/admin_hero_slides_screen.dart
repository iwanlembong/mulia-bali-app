import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';

class AdminHeroSlidesScreen extends StatefulWidget {
  const AdminHeroSlidesScreen({super.key});

  @override
  State<AdminHeroSlidesScreen> createState() => _AdminHeroSlidesScreenState();
}

class _AdminHeroSlidesScreenState extends State<AdminHeroSlidesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _slides = [];

  @override
  void initState() {
    super.initState();
    _fetchSlides();
  }

  Future<void> _fetchSlides() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('hero_slides')
          .select()
          .order('sort_order', ascending: true);

      if (mounted) {
        setState(() {
          _slides = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching slides: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteSlide(String id, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Slide?'),
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
            .from('hero_slides')
            .delete()
            .eq('id', id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Slide deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _fetchSlides();
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

  void _showSlideDialog({Map<String, dynamic>? slide}) {
    // ✅ SNAPSHOT NON-NULLABLE & GUARD CONTEXT
    final Map<String, dynamic> existing = slide ?? <String, dynamic>{};
    final bool isEdit = existing.isNotEmpty;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final titleController = TextEditingController(
      text: existing['title'] ?? '',
    );
    final subtitleController = TextEditingController(
      text: existing['subtitle'] ?? '',
    );
    final imageController = TextEditingController(
      text: existing['image_url'] ?? '',
    );
    final linkController = TextEditingController(
      text: existing['link_url'] ?? '',
    );
    final sortController = TextEditingController(
      text: existing['sort_order']?.toString() ?? '0',
    );
    bool isActive = existing['is_active'] ?? true;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Hero Slide' : 'Add New Hero Slide'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title * (e.g., The Mulia)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: subtitleController,
                  decoration: const InputDecoration(
                    labelText: 'Subtitle (e.g., All-Suite Beachfront Resort)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: imageController,
                  decoration: const InputDecoration(labelText: 'Image URL *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: linkController,
                  decoration: const InputDecoration(
                    labelText: 'Link URL (Optional, e.g., /properties)',
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
                if (titleController.text.trim().isEmpty ||
                    imageController.text.trim().isEmpty)
                  return;

                final data = {
                  'title': titleController.text.trim(),
                  'subtitle': subtitleController.text.trim(),
                  'image_url': imageController.text.trim(),
                  'link_url': linkController.text.trim().isEmpty
                      ? null
                      : linkController.text.trim(),
                  'sort_order': int.tryParse(sortController.text) ?? 0,
                  'is_active': isActive,
                };

                try {
                  if (isEdit) {
                    final String id = existing['id'] as String;
                    await Supabase.instance.client
                        .from('hero_slides')
                        .update(data)
                        .eq('id', id);
                  } else {
                    await Supabase.instance.client
                        .from('hero_slides')
                        .insert(data);
                  }

                  if (!mounted) return;

                  navigator.pop();
                  _fetchSlides();

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
              child: Text(isEdit ? 'Save Changes' : 'Add Slide'),
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
          'Manage Hero Slides',
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
          : _slides.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.image_outlined,
                    size: 64,
                    color: AppColors.textGrey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No hero slides found.',
                    style: TextStyle(
                      fontFamily: 'Lato',
                      color: AppColors.textGrey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showSlideDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add First Slide'),
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
              itemCount: _slides.length,
              itemBuilder: (context, index) {
                final s = _slides[index];
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
                                    s['image_url'] != null &&
                                        s['image_url'].toString().isNotEmpty
                                    ? DecorationImage(
                                        image: NetworkImage(s['image_url']),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                                color: AppColors.primaryGold.withOpacity(0.1),
                              ),
                              child:
                                  s['image_url'] == null ||
                                      s['image_url'].toString().isEmpty
                                  ? const Icon(
                                      Icons.image,
                                      color: AppColors.primaryGold,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s['title'],
                                    style: const TextStyle(
                                      fontFamily: 'Playfair Display',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    s['subtitle'] ?? 'No subtitle',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textGrey,
                                      fontStyle: FontStyle.italic,
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
                                    color: (s['is_active'] == true)
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    (s['is_active'] == true)
                                        ? 'Active'
                                        : 'Inactive',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: (s['is_active'] == true)
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (s['link_url'] != null &&
                                s['link_url'].toString().isNotEmpty)
                              Text(
                                'Link: ${s['link_url']}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.primaryGold,
                                ),
                              ),
                            const Spacer(),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: () => _showSlideDialog(slide: s),
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
                                      _deleteSlide(s['id'], s['title']),
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
        onPressed: () => _showSlideDialog(),
        backgroundColor: AppColors.darkCharcoal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Slide'),
      ),
    );
  }
}
