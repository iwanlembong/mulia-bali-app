class OrderItem {
  final String id;
  final String orderId;
  final String itemType; // 'spa', 'dining', 'wedding'
  final String itemId;
  final String itemName;
  final int quantity;
  final int unitPrice;
  final int totalPrice;
  final Map<String, dynamic> metadata; // date, time, guests, venue, dll
  final DateTime createdAt;

  OrderItem({
    required this.id,
    required this.orderId,
    required this.itemType,
    required this.itemId,
    required this.itemName,
    this.quantity = 1,
    required this.unitPrice,
    required this.totalPrice,
    this.metadata = const {},
    required this.createdAt,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'] as String,
      orderId: map['order_id'] as String,
      itemType: map['item_type'] as String,
      itemId: map['item_id'] as String,
      itemName: map['item_name'] as String,
      quantity: map['quantity'] as int? ?? 1,
      unitPrice: map['unit_price'] as int? ?? 0,
      totalPrice: map['total_price'] as int? ?? 0,
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'order_id': orderId,
      'item_type': itemType,
      'item_id': itemId,
      'item_name': itemName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
      'metadata': metadata,
    };
  }
}

class Order {
  final String id;
  final String userId;
  final String orderNumber;
  final String status; // 'pending', 'confirmed', 'cancelled', 'completed'
  final int totalAmount;

  // ✅ BARU: Field untuk Promo dan Diskon
  final int discountAmount;
  final String? promoCode;

  // ✅ BARU: Field untuk Voucher
  final String? voucherId; // ✅ TAMBAHKAN INI
  final int voucherDiscountAmount; // ✅ TAMBAHKAN INI

  final DateTime orderDate;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<OrderItem> items;

  // ✅ BARU: Data user dari tabel profiles
  final String? userName;
  final String? userEmail;

  // Payment method
  final String? paymentMethod;
  final String? paymentProofUrl;
  final String? rejectionReason; // ✅ TAMBAHKAN INI

  // ✅ TAMBAHKAN BARIS INI DI DALAM CLASS ORDER
  final String? weddingStatus;
  final int? guestCount;
  final String? eventDate;

  Order({
    required this.id,
    required this.userId,
    required this.orderNumber,
    this.status = 'pending',
    this.discountAmount = 0, // ✅ Default 0 jika tidak ada diskon
    this.promoCode, // ✅ Bisa null
    this.voucherId, // ✅ TAMBAHKAN INI
    this.voucherDiscountAmount = 0, // ✅ TAMBAHKAN INI
    this.totalAmount = 0,
    required this.orderDate,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
    this.userName,
    this.userEmail,
    this.paymentMethod,
    this.paymentProofUrl,
    this.rejectionReason, // ✅ TAMBAHKAN INI
    // ✅ TAMBAHKAN DI CONSTRUCTOR
    this.weddingStatus,
    this.guestCount,
    this.eventDate,
  });

  factory Order.fromMap(Map<String, dynamic> map, {List<OrderItem>? items}) {
    // ✅ Ambil data profile jika ada (hasil join)
    final profileData = map['profiles'] as Map<String, dynamic>?;

    return Order(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      orderNumber: map['order_number'] as String,
      status: map['status'] as String? ?? 'pending',
      totalAmount: map['total_amount'] as int? ?? 0,
      // ✅ PARSE DATA DISKON DARI DATABASE
      discountAmount: (map['discount_amount'] as num?)?.toInt() ?? 0,
      promoCode: map['promo_code'] as String?,
      voucherId: map['voucher_id'] as String?, // ✅ TAMBAHKAN INI
      // ✅ HARUS TERTULIS SEPERTI INI:
      voucherDiscountAmount:
          (map['voucher_discount_amount'] as num?)?.toInt() ?? 0,
      orderDate: DateTime.parse(map['order_date'] as String),
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      items: items ?? [],
      // ✅ 2. PERBAIKAN KRITIS: Baca dari JOIN, JIKA TIDAK ADA, baca dari injeksi langsung kita
      userName:
          (profileData?['full_name'] as String?) ??
          (map['user_name'] as String?),
      userEmail:
          (profileData?['email'] as String?) ?? (map['user_email'] as String?),

      paymentMethod: map['payment_method'] as String?,
      paymentProofUrl: map['payment_proof_url'] as String?,
      rejectionReason: map['rejection_reason'] as String?, // ✅ TAMBAHKAN INI
      // ✅ TAMBAHKAN MAPPING DARI DATABASE
      weddingStatus: map['wedding_status'] as String?,
      guestCount: map['guest_count'] as int?,
      eventDate: map['event_date'] as String?,
    );
  }

  // ✅ Helper: Status badge color
  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'cancelled':
        return 'Cancelled';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }

  // ✅ Helper: Format order date untuk tampilan
  String get formattedDate {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${orderDate.day} ${months[orderDate.month - 1]} ${orderDate.year}';
  }
}
