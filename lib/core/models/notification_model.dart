class NotificationItem {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final DateTime createdAt;

  NotificationItem({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationItem.fromMap(Map<String, dynamic> map) {
    return NotificationItem(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Notifikasi Baru',
      message: map['message']?.toString() ?? '',
      type: map['type']?.toString() ?? 'general',
      // ✅ PERBAIKAN: Cek boolean dengan lebih aman
      isRead: map['is_read'] == true, 
      // ✅ PERBAIKAN: Handle tanggal dengan aman
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at'].toString()) 
          : DateTime.now(),
    );
  }
}