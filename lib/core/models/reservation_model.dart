import 'package:intl/intl.dart';

class Reservation {
  final String id;
  final String? userId;
  final String roomId;
  final String propertyId;
  final String reservationNumber;
  final int roomCount;
  final DateTime checkIn;
  final DateTime checkOut;
  final int nights;
  final int adults;
  final int children;
  final int pricePerNight;
  final int totalAmount;
  final String status;
  final String? specialRequests;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  // ✅ Data Kamar (Denormalized untuk kemudahan UI)
  final String? roomName;
  final String? roomImageUrl;

  // ✅ TAMBAHKAN 2 FIELD INI DI BAWAH
  final String? guestName;
  final String? guestEmail;

  // ✅ 1. TAMBAHKAN 2 VARIABEL INI DI BAWAH
  final int? discountAmount;
  final String? promoCode;

  // ✅ BARU: VOUCHERS 2 field ini
  final int? voucherDiscountAmount;
  final String? voucherId;

  // ✅ BARU: Tambahkan 2 field ini
  final String? paymentMethod;
  final String? paymentProofUrl;

  final String? rejectionReason; // ✅ BARU

  Reservation({
    required this.id,
    this.userId, // ✅ TAMBAHKAN BARIS INI
    required this.roomId,
    required this.propertyId,
    required this.reservationNumber,
    this.roomCount = 1,
    required this.checkIn,
    required this.checkOut,
    required this.nights,
    this.adults = 2,
    this.children = 0,
    required this.pricePerNight,
    required this.totalAmount,
    this.status = 'pending',
    this.specialRequests,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.roomName,
    this.roomImageUrl,
    // ✅ TAMBAHKAN 2 PARAMETER INI DI BAWAH (sebelum kurung kurawal tutup)
    this.guestName,
    this.guestEmail,

    // ✅ 2. TAMBAHKAN 2 PARAMETER INI DI CONSTRUCTOR
    this.discountAmount,
    this.promoCode,

    // ✅ 2. TAMBAHKAN 2 PARAMETER INI DI CONSTRUCTOR
    this.voucherDiscountAmount,
    this.voucherId,

    // ✅ BARU: Tambahkan 2 field ini untuk payment
    this.paymentMethod,
    this.paymentProofUrl,

    this.rejectionReason, // ✅ BARU
  });

  factory Reservation.fromMap(Map<String, dynamic> map) {
    // Ambil data room jika ada (hasil JOIN)
    final roomData = map['rooms'] as Map<String, dynamic>?;

    return Reservation(
      id: map['id'] as String? ?? '',
      userId: map['user_id'] as String?, // ✅ TAMBAHKAN BARIS INI
      reservationNumber: map['reservation_number'] as String? ?? '',
      roomId: map['room_id'] as String? ?? '',
      
      roomCount: (map['room_count'] as num?)?.toInt() ?? 1,
      checkIn: DateTime.tryParse(map['check_in']?.toString() ?? '') ?? DateTime.now(),
      checkOut: DateTime.tryParse(map['check_out']?.toString() ?? '') ?? DateTime.now(),
      adults: (map['adults'] as num?)?.toInt() ?? 0,
      children: (map['children'] as num?)?.toInt() ?? 0,
      pricePerNight: (map['price_per_night'] as num?)?.toInt() ?? 0,
      status: map['status'] as String? ?? 'pending',
      totalAmount: (map['total_amount'] as num?)?.toInt() ?? 0, 

      propertyId: map['property_id'] as String? ?? '',
   
      // ✅ PERBAIKAN KRITIS: Tambahkan '?' agar NULL di database tidak menyebabkan crash
      promoCode: map['promo_code'] as String?,
      voucherId: map['voucher_id'] as String?,
      rejectionReason: map['rejection_reason'] as String?,
      paymentMethod: map['payment_method'] as String?,
      paymentProofUrl: map['payment_proof_url'] as String?,
      specialRequests: map['special_requests'] as String?,
      
      // ✅ Pastikan diskon juga di-cast dengan aman
      discountAmount: (map['discount_amount'] as num?)?.toInt() ?? 0,
      voucherDiscountAmount: (map['voucher_discount_amount'] as num?)?.toInt() ?? 0,
      
      
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      
      // Jika Anda melakukan JOIN dengan tabel rooms, pastikan ini aman:
      roomName: map['rooms'] != null ? map['rooms']['name'] as String? : null,
      roomImageUrl: roomData?['image_url'] as String?,
      

      // ✅ PERBAIKAN KRITIS: Safe parsing untuk guestName
      guestName: (map['user'] as Map?)?['full_name'] as String? 
                 ?? (map['profiles'] as Map?)?['full_name'] as String? 
                 ?? (map['guest_name'] as String?),

      nights: map['nights'] as int? ?? 1,
      notes: map['notes'] as String?,
      guestEmail: map['guest_email'] as String?,

       // ✅ BARU
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'room_id': roomId,
      'property_id': propertyId,
      'reservation_number': reservationNumber,
      'room_count': roomCount,
      'check_in': DateFormat('yyyy-MM-dd').format(checkIn),
      'check_out': DateFormat('yyyy-MM-dd').format(checkOut),
      'adults': adults,
      'children': children,
      'price_per_night': pricePerNight,
      'special_requests': specialRequests,
      'notes': notes,
    };
  }

  // ✅ Helper: Status Label
  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'checked_in':
        return 'Checked In';
      case 'checked_out':
        return 'Checked Out';
      case 'cancelled':
        return 'Cancelled';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }

  // ✅ Helper: Format Tanggal Check-in/Check-out
  String get formattedDates {
    final formatter = DateFormat('dd MMM yyyy');
    return '${formatter.format(checkIn)} - ${formatter.format(checkOut)}';
  }

  String get formattedCheckIn => DateFormat('dd MMM yyyy').format(checkIn);
  String get formattedCheckOut => DateFormat('dd MMM yyyy').format(checkOut);
}
