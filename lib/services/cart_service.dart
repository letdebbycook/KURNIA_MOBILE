import 'package:flutter/material.dart';
import '../models/cart_item.dart';
import '../models/product.dart';

class CartService extends ChangeNotifier {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  int get totalItems => _items.fold(0, (sum, item) => sum + item.quantity);

  double get totalPrice => _items.fold(0.0, (sum, item) => sum + item.subtotal);

  bool get isEmpty => _items.isEmpty;

  void addProduct(Product product) {
    final index = _items.indexWhere((item) => item.product.idProduk == product.idProduk);
    if (index >= 0) {
      _items[index].quantity++;
    } else {
      _items.add(CartItem(product: product, quantity: 1));
    }
    notifyListeners();
  }

  void incrementQuantity(Product product) {
    final index = _items.indexWhere((item) => item.product.idProduk == product.idProduk);
    if (index >= 0) {
      _items[index].quantity++;
      notifyListeners();
    }
  }

  void decrementQuantity(Product product) {
    final index = _items.indexWhere((item) => item.product.idProduk == product.idProduk);
    if (index >= 0) {
      if (_items[index].quantity > 1) {
        _items[index].quantity--;
      } else {
        _items.removeAt(index);
      }
      notifyListeners();
    }
  }

  void removeProduct(Product product) {
    _items.removeWhere((item) => item.product.idProduk == product.idProduk);
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }

  bool containsProduct(Product product) {
    return _items.any((item) => item.product.idProduk == product.idProduk);
  }

  int quantityOf(Product product) {
    final index = _items.indexWhere((item) => item.product.idProduk == product.idProduk);
    return index >= 0 ? _items[index].quantity : 0;
  }
}
