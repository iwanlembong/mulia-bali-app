import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/notification_model.dart';
import '../../core/services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  List<NotificationItem> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final notifications = await NotificationService.getUserNotifications();
    if (mounted) {
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleTap(NotificationItem notif) async {
    // 1. Tandai sebagai sudah dibaca jika belum
    if (!notif.isRead) {
      await NotificationService.markAsRead(notif.id);
      _loadNotifications(); // Refresh list agar titik emas hilang
    }

    // 2. Tampilkan Detail Notifikasi (Modal Bottom Sheet)
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.transparent,
      builder: (context) => _buildNotificationDetailSheet(notif),
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
          'Notifikasi',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: () async {
                await NotificationService.markAllAsRead();
                _loadNotifications();
              },
              child: const Text(
                'Mark all as read',
                style: TextStyle(color: AppColors.primaryGold),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGold),
            )
          : _notifications.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 64,
                    color: AppColors.textGrey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(
                      fontFamily: 'Lato',
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadNotifications,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _notifications.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final notif = _notifications[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: _getIconColor(notif.type)
                          .withOpacity(0.1),
                      child: Icon(
                        _getIcon(notif.type),
                        color: _getIconColor(notif.type),
                      ),
                    ),
                    title: Text(
                      notif.title,
                      style: TextStyle(
                        fontFamily: 'Lato',
                        fontSize: 14,
                        fontWeight: notif.isRead
                            ? FontWeight.normal
                            : FontWeight.bold,
                        color: AppColors.darkCharcoal,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          notif.message,
                          style: const TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 12,
                            color: AppColors.textGrey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('dd MMM yyyy, HH:mm').format(
                            notif.createdAt,
                          ), // ✅ PERBAIKAN: Hapus 'id_ID'
                          style: const TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    trailing: notif.isRead
                        ? null
                        : const Icon(
                            Icons.circle,
                            size: 8,
                            color: AppColors.primaryGold,
                          ),
                    onTap: () => _handleTap(notif),
                  );
                },
              ),
            ),
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'booking':
        return Icons.bed_outlined;
      case 'reward':
        return Icons.card_giftcard_outlined;
      default:
        return Icons.info_outline;
    }
  }

  Color _getIconColor(String type) {
    switch (type) {
      case 'booking':
        return Colors.blue.shade700;
      case 'reward':
        return Colors.purple.shade700;
      default:
        return AppColors.textGrey;
    }
  }

  // ✅ BARU: Widget untuk menampilkan detail notifikasi
  Widget _buildNotificationDetailSheet(NotificationItem notif) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle (Garis kecil di atas)
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Header: Icon & Judul
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getIconColor(notif.type).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(_getIcon(notif.type), color: _getIconColor(notif.type), size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  notif.title,
                  style: const TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkCharcoal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Pesan Lengkap
          Text(
            notif.message,
            style: const TextStyle(
              fontFamily: 'Lato',
              fontSize: 15,
              color: AppColors.textGrey,
              height: 1.6, // Jarak antar baris agar mudah dibaca
            ),
          ),
          const SizedBox(height: 24),
          
          // Tanggal & Waktu
          Row(
            children: [
              const Icon(Icons.access_time, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                // Menggunakan format default agar aman dari error LocaleDataException
                DateFormat('dd MMM yyyy, HH:mm').format(notif.createdAt), 
                style: const TextStyle(fontFamily: 'Lato', fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // Tombol Tutup
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkCharcoal,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Tutup', style: TextStyle(fontFamily: 'Lato', fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
