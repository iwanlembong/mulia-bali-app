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
          'Notifications',
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
                          fontSize: 16,
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
                      
                      // ✅ Hanya 1 parameter
                      final iconColor = _getIconColor(notif.type); 
                      
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: iconColor.withOpacity(0.1),
                          child: Icon(
                            // // ✅ Hanya 1 parameter
                            _getIcon(notif.type),
                            color: iconColor,
                            size: 22,
                          ),
                        ),
                        title: Text(
                          notif.title,
                          style: TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 14,
                            fontWeight: notif.isRead ? FontWeight.normal : FontWeight.bold,
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
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('dd MMM yyyy, HH:mm').format(notif.createdAt),
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

  // ✅ SEDERHANA: Langsung baca dari database, tidak perlu tebak-tebakan
  IconData _getIcon(String type) {
    switch (type.toLowerCase()) {
      case 'reservation':
        return Icons.bed_outlined; // 🛏️ Kamar
      case 'booking':
        return Icons.receipt_long; // 🧾 Services
      case 'reward':
        return Icons.card_giftcard_outlined; // 🎁 Voucher
      default:
        return Icons.notifications_active;
    }
  }

  Color _getIconColor(String type) {
    switch (type.toLowerCase()) {
      case 'reservation':
        return const Color(0xFF9370DB); // 🟣 Ungu
      case 'booking':
        return Colors.blue.shade700; // 🔵 Biru
      case 'reward':
        return Colors.green.shade700; // 🟢 Hijau
      default:
        return AppColors.primaryGold;
    }
  }

  // ✅ Widget untuk menampilkan detail notifikasi
  Widget _buildNotificationDetailSheet(NotificationItem notif) {
    // ✅ PERBAIKAN: Panggil method dengan 3 parameter
    final iconColor = _getIconColor(notif.type);
    
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

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  // ✅ PERBAIKAN: Panggil method dengan 3 parameter
                  _getIcon(notif.type),
                  color: iconColor,
                  size: 28,
                ),
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

          Text(
            notif.message,
            style: const TextStyle(
              fontFamily: 'Lato',
              fontSize: 15,
              color: AppColors.textGrey,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              const Icon(Icons.access_time, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                DateFormat('dd MMM yyyy, HH:mm').format(notif.createdAt),
                style: const TextStyle(
                  fontFamily: 'Lato',
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkCharcoal,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Close',
                style: TextStyle(
                  fontFamily: 'Lato',
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}