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
      // ✅ LANGKAH 1: Ambil semua data reviews terlebih dahulu
      final reviewsResponse = await Supabase.instance.client
          .from('reviews')
          .select('*') // Tidak perlu join profiles di sini
          .order('created_at', ascending: false);

      final reviewsList = (reviewsResponse as List)
          .cast<Map<String, dynamic>>();

      // ✅ LANGKAH 2: Ambil semua ID user yang unik dari reviews
      final userIds = reviewsList
          .map((r) => r['user_id'] as String)
          .toSet()
          .toList();

      // ✅ LANGKAH 3: Ambil data profiles hanya untuk user yang mereview
      List<Map<String, dynamic>> profilesList = [];
      if (userIds.isNotEmpty) {
        final profilesResponse = await Supabase.instance.client
            .from('profiles')
            .select('id, full_name')
            .inFilter('id', userIds);

        profilesList = (profilesResponse as List).cast<Map<String, dynamic>>();
      }

      // ✅ LANGKAH 4: Gabungkan nama user ke dalam data review
      for (var review in reviewsList) {
        final profile = profilesList.firstWhere(
          (p) => p['id'] == review['user_id'],
          orElse: () => {'full_name': 'Unknown User'},
        );
        // Simpan nama user ke dalam map review agar mudah dipanggil di UI
        review['user_name'] = profile['full_name'] ?? 'Unknown User';
      }

      if (mounted) {
        setState(() {
          _reviews = reviewsList;
          _isLoading = false;
        });
        print(
          '✅ [ADMIN] Berhasil memuat ${_reviews.length} reviews dengan nama user.',
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
          _fetchReviews(); // Refresh list
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
              if (replyText.isEmpty) return; // Cegah kirim balasan kosong

              try {
                // ✅ LANGKAH 1: Simpan ke Database (Tetap kita lakukan agar data aman)
                await Supabase.instance.client
                    .from('reviews')
                    .update({
                      'admin_reply': replyText,
                      'admin_reply_at': DateTime.now().toIso8601String(),
                    })
                    .eq('id', reviewId);

                // ✅ LANGKAH 2: Tutup Dialog
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }

                // ✅ LANGKAH 3: UPDATE UI SECARA LOKAL (INSTAN, TANPA FLICKER!)
                if (mounted) {
                  // Cari index review yang baru saja dibalas di dalam list _reviews
                  final index = _reviews.indexWhere((r) => r['id'] == reviewId);
                  
                  if (index != -1) {
                    setState(() {
                      // Update data di memori secara langsung
                      _reviews[index]['admin_reply'] = replyText;
                      _reviews[index]['admin_reply_at'] = DateTime.now().toIso8601String();
                    });
                  }

                  // Tampilkan notifikasi sukses
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

                  // ✅ CEK APAKAH SUDAH DIBALAS
                  final hasReplied =
                      review['admin_reply'] != null &&
                      review['admin_reply'].toString().isNotEmpty;

                  // ✅ PENTING: Tambahkan ValueKey agar Flutter paksa rebuild kartu ini jika status berubah
                  return Card(
                    key: ValueKey('review_${review['id']}_$hasReplied'),
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: hasReplied
                            ? Colors.green.shade400
                            : Colors.transparent,
                        width: hasReplied ? 1.5 : 0,
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
                                      '${itemType.toUpperCase()} • ${DateFormat('dd MMM yyyy').format(date)}',
                                      style: const TextStyle(
                                        fontFamily: 'Lato',
                                        fontSize: 11,
                                        color: AppColors.textGrey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // ✅ BADGE REPLIED
                              if (hasReplied) ...[
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

                              // ✅ TOMBOL REPLY (Warna berubah dinamis)
                              IconButton(
                                icon: Icon(
                                  Icons.reply,
                                  color: hasReplied
                                      ? Colors.green.shade700
                                      : AppColors.primaryGold, // ✅ Berubah jadi Hijau
                                  size: 22,
                                ),
                                onPressed: () => _showReplyDialog(review),
                                tooltip: hasReplied
                                    ? 'Edit Reply'
                                    : 'Reply to Review',
                              ),

                              // TOMBOL DELETE
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
