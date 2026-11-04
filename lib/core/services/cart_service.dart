import 'package:flutter/foundation.dart'; // ✅ Untuk ValueNotifier
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cart_model.dart';
import 'auth_service.dart';

class CartService {
  // ✅ GLOBAL NOTIFIER: Agar semua screen bisa mendengar perubahan count
  static final ValueNotifier<int> itemCountNotifier = ValueNotifier<int>(0);

  static Future<Cart?> getOrCreateActiveCart() async {
    final userId = AuthService.currentUserId;
    if (userId == null) return null;

    try {
      final response = await Supabase.instance.client
          .from('carts')
          .select()
          .eq('user_id', userId)
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        final itemsResponse = await Supabase.instance.client
            .from('cart_items')
            .select()
            .eq('cart_id', response['id']);

        final items = (itemsResponse as List)
            .map((item) => CartItem.fromMap(item as Map<String, dynamic>))
            .toList();

        return Cart.fromMap(response, items: items);
      } else {
        final newCart = await Supabase.instance.client
            .from('carts')
            .insert({'user_id': userId, 'status': 'active', 'total_amount': 0})
            .select()
            .single();

        return Cart.fromMap(newCart);
      }
    } catch (e) {
      print('Error getting/creating cart: $e');
      return null;
    }
  }

  static Future<bool> addToCart({
    required String itemType,
    required String itemId,
    required String itemName,
    required int unitPrice,
    int quantity = 1,
    Map<String, dynamic> metadata = const {},
  }) async {
    try {
      final cart = await getOrCreateActiveCart();
      if (cart == null) return false;

      final totalPrice = unitPrice * quantity;

      await Supabase.instance.client.from('cart_items').insert({
        'cart_id': cart.id,
        'item_type': itemType,
        'item_id': itemId,
        'item_name': itemName,
        'quantity': quantity,
        'unit_price': unitPrice,
        'total_price': totalPrice,
        'metadata': metadata,
      });

      await _updateItemCount(); // ✅ AUTO UPDATE NOTIFIER
      return true;
    } catch (e) {
      print('Error adding to cart: $e');
      return false;
    }
  }

  static Future<bool> removeFromCart(String itemId) async {
    try {
      await Supabase.instance.client
          .from('cart_items')
          .delete()
          .eq('id', itemId);
      await _updateItemCount(); // ✅ AUTO UPDATE NOTIFIER
      return true;
    } catch (e) {
      print('Error removing from cart: $e');
      return false;
    }
  }

  static Future<bool> updateQuantity(String itemId, int newQuantity) async {
    try {
      final itemResponse = await Supabase.instance.client
          .from('cart_items')
          .select()
          .eq('id', itemId)
          .single();

      final unitPrice = itemResponse['unit_price'] as int;
      final newTotal = unitPrice * newQuantity;

      await Supabase.instance.client
          .from('cart_items')
          .update({'quantity': newQuantity, 'total_price': newTotal})
          .eq('id', itemId);

      await _updateItemCount(); // ✅ AUTO UPDATE NOTIFIER
      return true;
    } catch (e) {
      print('Error updating quantity: $e');
      return false;
    }
  }

  static Future<bool> clearCart() async {
    try {
      final cart = await getOrCreateActiveCart();
      if (cart == null) return false;
      await Supabase.instance.client
          .from('cart_items')
          .delete()
          .eq('cart_id', cart.id);
      await _updateItemCount();
      return true;
    } catch (e) {
      print('Error clearing cart: $e');
      return false;
    }
  }

  static Future<bool> checkoutCart() async {
    try {
      final cart = await getOrCreateActiveCart();
      if (cart == null) return false;
      await Supabase.instance.client
          .from('carts')
          .update({'status': 'checked_out'})
          .eq('id', cart.id);
      await _updateItemCount();
      return true;
    } catch (e) {
      print('Error checking out cart: $e');
      return false;
    }
  }

  static Future<int> getCartItemCount() async {
    try {
      final cart = await getOrCreateActiveCart();
      return cart?.items.length ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // ✅ FUNGSI INTERNAL: Update ValueNotifier secara otomatis
  static Future<void> _updateItemCount() async {
    final count = await getCartItemCount();
    itemCountNotifier.value = count;
  }
}
