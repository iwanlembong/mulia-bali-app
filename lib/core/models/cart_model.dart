class CartItem {
  final String id;
  final String cartId;
  final String itemType; // 'spa', 'dining', 'wedding'
  final String itemId;
  final String itemName;
  final int quantity;
  final int unitPrice;
  final int totalPrice;
  final Map<String, dynamic> metadata; // date, time, guests, dll

  CartItem({
    required this.id,
    required this.cartId,
    required this.itemType,
    required this.itemId,
    required this.itemName,
    this.quantity = 1,
    required this.unitPrice,
    required this.totalPrice,
    this.metadata = const {},
  });

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      id: map['id'] as String,
      cartId: map['cart_id'] as String,
      itemType: map['item_type'] as String,
      itemId: map['item_id'] as String,
      itemName: map['item_name'] as String,
      quantity: map['quantity'] as int? ?? 1,
      unitPrice: map['unit_price'] as int? ?? 0,
      totalPrice: map['total_price'] as int? ?? 0,
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cart_id': cartId,
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

class Cart {
  final String id;
  final String userId;
  final String status; // 'active', 'checked_out', 'abandoned'
  final int totalAmount;
  final List<CartItem> items;
  final DateTime createdAt;

  Cart({
    required this.id,
    required this.userId,
    this.status = 'active',
    this.totalAmount = 0,
    this.items = const [],
    required this.createdAt,
  });

  factory Cart.fromMap(Map<String, dynamic> map, {List<CartItem>? items}) {
    return Cart(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      status: map['status'] as String? ?? 'active',
      totalAmount: map['total_amount'] as int? ?? 0,
      items: items ?? [],
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
