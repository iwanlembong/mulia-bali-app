import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';

class AdminExperiencesScreen extends StatefulWidget {
  const AdminExperiencesScreen({super.key});

  @override
  State<AdminExperiencesScreen> createState() => _AdminExperiencesScreenState();
}

class _AdminExperiencesScreenState extends State<AdminExperiencesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _experiences = [];

  @override
  void initState() {
    super.initState();
    _fetchExperiences();
  }

  Future<void> _fetchExperiences() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('experiences')
          .select()
          .order('sort_order', ascending: true);
      if (mounted) {
        setState(() {
          _experiences = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteExperience(String id, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Experience?'),
        content: Text('Are you sure you want to delete "$title"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await Supabase.instance.client.from('experiences').delete().eq('id', id);
      if (mounted) {
        _fetchExperiences();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deleted successfully'), backgroundColor: Colors.green),
        );
      }
    }
  }

  // ✅ FUNGSI BARU: Mengubah string icon_name menjadi IconData Flutter
  IconData _getIconData(String? iconName) {
    if (iconName == null) return Icons.star;
    switch (iconName.toLowerCase().trim()) {
      case 'spa': return Icons.spa;
      case 'restaurant':
      case 'dining':
      case 'culinary': return Icons.restaurant;
      case 'pool': return Icons.pool;
      case 'fitness':
      case 'gym': return Icons.fitness_center;
      case 'kids':
      case 'family': return Icons.child_care;
      case 'beach':
      case 'water': return Icons.beach_access;
      default: return Icons.star; // Fallback ke bintang jika tidak dikenali
    }
  }

  void _showDialog({Map<String, dynamic>? exp}) {
    final Map<String, dynamic> existing = exp ?? <String, dynamic>{};
    final bool isEdit = existing.isNotEmpty;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final titleCtrl = TextEditingController(text: existing['title'] ?? '');
    final descCtrl = TextEditingController(text: existing['description'] ?? '');
    final iconCtrl = TextEditingController(text: existing['icon_name'] ?? 'spa');
    final imgCtrl = TextEditingController(text: existing['image_url'] ?? '');
    final sortCtrl = TextEditingController(text: existing['sort_order']?.toString() ?? '0');
    bool isActive = existing['is_active'] ?? true;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Experience' : 'Add Experience'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title * (e.g., Spa & Wellness)')),
                const SizedBox(height: 12),
                TextField(controller: descCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Short Description')),
                const SizedBox(height: 12),
                TextField(controller: iconCtrl, decoration: const InputDecoration(labelText: 'Icon Name (e.g., spa, restaurant, pool, fitness, kids, beach)')),
                const SizedBox(height: 12),
                TextField(controller: imgCtrl, decoration: const InputDecoration(labelText: 'Image URL *')),
                const SizedBox(height: 12),
                TextField(controller: sortCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Sort Order')),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Checkbox(value: isActive, onChanged: (val) => setDialogState(() => isActive = val ?? true)),
                    const Text('Is Active'),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => navigator.pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                final data = {
                  'title': titleCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                  'icon_name': iconCtrl.text.trim(),
                  'image_url': imgCtrl.text.trim(),
                  'sort_order': int.tryParse(sortCtrl.text) ?? 0,
                  'is_active': isActive,
                };
                try {
                  if (isEdit) {
                    await Supabase.instance.client.from('experiences').update(data).eq('id', existing['id'] as String);
                  } else {
                    await Supabase.instance.client.from('experiences').insert(data);
                  }
                  if (!mounted) return;
                  navigator.pop();
                  _fetchExperiences();
                  messenger.showSnackBar(SnackBar(content: Text(isEdit ? 'Updated' : 'Added'), backgroundColor: Colors.green));
                } catch (e) {
                  if (!mounted) return;
                  messenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                }
              },
              child: Text(isEdit ? 'Save' : 'Add'),
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
        title: const Text('Manage Experiences', style: TextStyle(fontFamily: 'Playfair Display', fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/admin/dashboard')),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGold))
          : _experiences.isEmpty
              ? Center(
                  child: ElevatedButton.icon(
                    onPressed: () => _showDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add First Experience'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGold, foregroundColor: Colors.white),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _experiences.length,
                  itemBuilder: (context, index) {
                    final e = _experiences[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        // ✅ PERBAIKAN: Gunakan _getIconData agar ikon dinamis
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primaryGold.withOpacity(0.1),
                          child: Icon(_getIconData(e['icon_name']), color: AppColors.primaryGold),
                        ),
                        title: Text(e['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Playfair Display')),
                        subtitle: Text(e['description'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showDialog(exp: e)),
                            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteExperience(e['id'], e['title'])),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showDialog(),
        backgroundColor: AppColors.darkCharcoal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Experience'),
      ),
    );
  }
}