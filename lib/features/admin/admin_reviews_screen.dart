import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';

class AdminReviewsScreen extends StatefulWidget {
  const AdminReviewsScreen({super.key});

  @override
  State<AdminReviewsScreen> createState() => _AdminReviewsScreenState();
}

class _AdminReviewsScreenState extends State<AdminReviewsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _reviews = [];

  @override
  void initState() {
    super.initState();
    _fetchReviews();
  }

  Future<void> _fetchReviews() async {
    setState(() => _isLoading = true);
    try {
      // 1. Ambil semua data reviews
      final reviewsResponse = await Supabase.instance.client
          .from('reviews')
          .select('*')
          .order('created_at', ascending: false);

      final reviewsList = (reviewsResponse as List)
          .cast<Map<String, dynamic>>();
      if (reviewsList.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // 2. Ambil data profiles (Nama User)
      final userIds = reviewsList
          .map((r) => r['user_id'] as String)
          .toSet()
          .toList();
      List<Map<String, dynamic>> profilesList = [];
      if (userIds.isNotEmpty) {
        final profilesResponse = await Supabase.instance.client
            .from('profiles')
            .select('id, full_name')
            .inFilter('id', userIds);
        profilesList = (profilesResponse as List).cast<Map<String, dynamic>>();
      }

      // 3. KELOMPOKKAN item_id berdasarkan item_type untuk Batch Fetching (Agar Cepat!)
      Map<String, List<String>> itemsByType = {};
      for (var review in reviewsList) {
        String type = review['item_type'] ?? 'general';
        String id = review['item_id'] ?? '';
        if (id.isNotEmpty) {
          if (!itemsByType.containsKey(type)) itemsByType[type] = [];
          if (!itemsByType[type]!.contains(id)) itemsByType[type]!.add(id);
        }
      }

      // 4. Ambil Nama Item dari masing-masing tabel
      Map<String, String> itemNames = {}; // Key: item_id, Value: item_name
      
      for (var entry in itemsByType.entries) {
        String type = entry.key;
        List<String> ids = entry.value;

        String tableName = '';
        String nameColumn = 'name';

        switch (type) {
          case 'property':
            tableName = 'properties';
            nameColumn = 'name'; // atau 'property_name'
            break;
          case 'spa':
            tableName = 'spa_services';
            nameColumn = 'name'; // atau 'service_name'
            break;
          case 'dining':
            // ✅ PRIORITAS 1: Coba ambil dari menu_items dulu
            tableName = 'menu_items';
            nameColumn = 'name'; // atau 'dish_name' atau 'menu_name'
            break;
          case 'wedding':
            tableName = 'weddings';
            nameColumn = 'package_name'; // atau 'package_name'
            break;
        }

        if (tableName.isNotEmpty) {
          try {
            print(' [DEBUG] Mencari nama untuk $type di tabel $tableName dengan IDs: $ids');
            
            final res = await Supabase.instance.client
                .from(tableName)
                .select('id, $nameColumn')
                .inFilter('id', ids);

            print('✅ [DEBUG] Ditemukan ${res.length} item dari $tableName');

            for (var item in (res as List)) {
              itemNames[item['id']] = item[nameColumn] ?? 'Unknown Item';
              print('   - ${item['id']}: ${item[nameColumn]}');
            }
            
            // ✅ FALLBACK: Jika tidak ada hasil dari menu_items, coba cari di restaurants
            if (type == 'dining' && res.isEmpty) {
              print('⚠️ [DEBUG] Tidak ditemukan di menu_items, mencoba di restaurants...');
              final restaurantRes = await Supabase.instance.client
                  .from('restaurants')
                  .select('id, name')
                  .inFilter('id', ids);
              
              for (var item in (restaurantRes as List)) {
                itemNames[item['id']] = item['name'] ?? 'Unknown Restaurant';
                print('   - Found in restaurants: ${item['id']}: ${item['name']}');
              }
            }
            
          } catch (e) {
            print('❌ [ADMIN] Gagal mengambil nama untuk $type dari $tableName: $e');
          }
        }
      }

      // 5. Gabungkan Nama User dan Nama Item ke dalam data review
      for (var review in reviewsList) {
        // Gabung Nama User
        final profile = profilesList.firstWhere(
          (p) => p['id'] == review['user_id'],
          orElse: () => {'full_name': 'Unknown User'},
        );
        review['user_name'] = profile['full_name'] ?? 'Unknown User';

        // Gabung Nama Item
        review['item_name'] =
            itemNames[review['item_id']] ??
            (review['item_type'] ?? 'Unknown Item').toUpperCase();
      }

      if (mounted) {
        setState(() {
          _reviews = reviewsList;
          _isLoading = false;
        });
        print(
          '✅ [ADMIN] Berhasil memuat ${_reviews.length} reviews dengan detail lengkap.',
        );
      }
    } catch (e) {
      print('❌ [ADMIN] Error fetching reviews: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteReview(String reviewId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Review?'),
        content: const Text(
          'Are you sure you want to permanently delete this review? This action cannot be undone.',
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
            .from('reviews')
            .delete()
            .eq('id', reviewId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Review deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _fetchReviews();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete review'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _approveReview(String reviewId) async {
    try {
      // 1. Update database
      await Supabase.instance.client
          .from('reviews')
          .update({'is_approved': true})
          .eq('id', reviewId);

      if (mounted) {
        // 2. Update UI secara lokal agar INSTAN (tanpa flicker/scroll jump)
        final index = _reviews.indexWhere((r) => r['id'] == reviewId);
        if (index != -1) {
          setState(() {
            _reviews[index]['is_approved'] = true;
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Review Approved & Published!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _revertToPending(String reviewId) async {
    try {
      // 1. Update database: kembalikan is_approved menjadi false
      await Supabase.instance.client
          .from('reviews')
          .update({'is_approved': false})
          .eq('id', reviewId);

      if (mounted) {
        // 2. Update UI secara lokal agar INSTAN (tanpa flicker)
        final index = _reviews.indexWhere((r) => r['id'] == reviewId);
        if (index != -1) {
          setState(() {
            _reviews[index]['is_approved'] = false;
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Review reverted to Pending'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to revert: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showReplyDialog(Map<String, dynamic> review) {
    final replyController = TextEditingController(
      text: review['admin_reply'] ?? '',
    );
    final reviewId = review['id'];

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Reply to Review',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'User: ${review['user_name'] ?? 'Unknown'}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: AppColors.textGrey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '"${review['comment']}"',
              style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: replyController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Type your reply here...',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: AppColors.offWhite,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final replyText = replyController.text.trim();
              if (replyText.isEmpty) return;

              try {
                await Supabase.instance.client
                    .from('reviews')
                    .update({
                      'admin_reply': replyText,
                      'admin_reply_at': DateTime.now().toIso8601String(),
                    })
                    .eq('id', reviewId);

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }

                if (mounted) {
                  final index = _reviews.indexWhere((r) => r['id'] == reviewId);
                  if (index != -1) {
                    setState(() {
                      _reviews[index]['admin_reply'] = replyText;
                      _reviews[index]['admin_reply_at'] = DateTime.now()
                          .toIso8601String();
                    });
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Reply updated successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to send reply: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGold,
            ),
            child: const Text(
              'Send Reply',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'spa':
        return Icons.spa;
      case 'dining':
        return Icons.restaurant;
      case 'wedding':
        return Icons.favorite;
      case 'property':
        return Icons.hotel;
      default:
        return Icons.star;
    }
  }

  Color _getColor(String type) {
    switch (type) {
      case 'spa':
        return const Color(0xFF8B7355);
      case 'dining':
        return const Color(0xFF6B8E23);
      case 'wedding':
        return Colors.pink.shade300;
      case 'property':
        return AppColors.primaryGold;
      default:
        return AppColors.textGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        backgroundColor: AppColors.darkCharcoal,
        foregroundColor: Colors.white,
        title: const Text(
          'Manage Reviews',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchReviews),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGold),
            )
          : _reviews.isEmpty
          ? const Center(
              child: Text(
                'No reviews found.',
                style: TextStyle(fontFamily: 'Lato', color: AppColors.textGrey),
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchReviews,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _reviews.length,
                itemBuilder: (context, index) {
                  final review = _reviews[index];
                  final userName = review['user_name'] ?? 'Unknown User';
                  final itemType = review['item_type'] ?? 'general';
                  final rating = review['rating'] as int;
                  final comment = review['comment'] ?? '';
                  final date = DateTime.parse(review['created_at']);
                  final color = _getColor(itemType);

                  // ✅ CEK STATUS APPROVAL & REPLY
                  final isApproved = review['is_approved'] == true;
                  final hasReplied =
                      review['admin_reply'] != null &&
                      review['admin_reply'].toString().isNotEmpty;

                  // ✅ PENTING: ValueKey mencakup isApproved agar rebuild saat di-approve
                  return Card(
                    key: ValueKey('review_${review['id']}_$isApproved'),
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      // Border hijau jika sudah di-reply, border orange jika masih pending
                      side: BorderSide(
                        color: hasReplied
                            ? Colors.green.shade400
                            : (isApproved
                                  ? Colors.transparent
                                  : Colors.orange.shade400),
                        width: hasReplied ? 1.5 : (isApproved ? 0 : 1.5),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: color.withOpacity(0.1),
                                child: Icon(
                                  _getIcon(itemType),
                                  color: color,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userName,
                                      style: const TextStyle(
                                        fontFamily: 'Lato',
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '${review['item_name'] ?? itemType.toUpperCase()} • ${DateFormat('dd MMM yyyy').format(date)}',
                                      style: const TextStyle(
                                        fontFamily: 'Lato',
                                        fontSize: 11,
                                        color: AppColors.textGrey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // ✅ 1. BADGE PENDING (Muncul jika BELUM di-approve)
                              if (!isApproved) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.orange.shade400,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.hourglass_empty,
                                        color: Colors.orange.shade700,
                                        size: 12,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Pending',
                                        style: TextStyle(
                                          color: Colors.orange.shade700,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],

                              // ✅ 2. BADGE REPLIED (Muncul jika SUDAH di-approve DAN sudah di-reply)
                              if (isApproved && hasReplied) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.green.shade300,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.green.shade700,
                                        size: 12,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Replied',
                                        style: TextStyle(
                                          color: Colors.green.shade700,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],

                              // ✅ 3. TOMBOL APPROVE (Hanya muncul jika BELUM di-approve)
                              if (!isApproved)
                                IconButton(
                                  icon: const Icon(
                                    Icons.check_circle_outline,
                                    color: Colors.green,
                                    size: 26,
                                  ),
                                  onPressed: () => _approveReview(review['id']),
                                  tooltip: 'Approve & Publish Review',
                                ),

                              // ✅ 3. TOMBOL REVERT TO PENDING (Hanya muncul jika SUDAH di-approve)
                              if (isApproved)
                                IconButton(
                                  icon: const Icon(
                                    Icons.hourglass_bottom,
                                    color: Colors.orange,
                                    size: 24,
                                  ),
                                  onPressed: () =>
                                      _revertToPending(review['id']),
                                  tooltip: 'Revert to Pending',
                                ),

                              // ✅ 4. TOMBOL REPLY (Hanya muncul jika SUDAH di-approve)
                              if (isApproved)
                                IconButton(
                                  icon: Icon(
                                    Icons.reply,
                                    color: hasReplied
                                        ? Colors.green.shade700
                                        : AppColors.primaryGold,
                                    size: 22,
                                  ),
                                  onPressed: () => _showReplyDialog(review),
                                  tooltip: hasReplied
                                      ? 'Edit Reply'
                                      : 'Reply to Review',
                                ),

                              // ✅ 5. TOMBOL DELETE (Selalu muncul)
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                  size: 22,
                                ),
                                onPressed: () => _deleteReview(review['id']),
                                tooltip: 'Delete Review',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          Row(
                            children: List.generate(5, (i) {
                              return Icon(
                                i < rating ? Icons.star : Icons.star_border,
                                color: AppColors.primaryGold,
                                size: 18,
                              );
                            }),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            comment,
                            style: const TextStyle(
                              fontFamily: 'Lato',
                              fontSize: 13,
                              color: AppColors.darkCharcoal,
                              height: 1.5,
                            ),
                          ),

                          // ✅ PREVIEW BALASAN
                          if (hasReplied) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Your Reply:',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textGrey,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    review['admin_reply'],
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.darkCharcoal,
                                      fontStyle: FontStyle.italic,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
