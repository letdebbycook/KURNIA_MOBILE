import 'package:flutter/material.dart';
import '../models/product.dart';

/// Service untuk mengelola wishlist pelanggan (in-memory).
/// Menggunakan ChangeNotifier agar UI bisa reaktif terhadap perubahan.
class WishlistService extends ChangeNotifier {
  static final WishlistService _instance = WishlistService._internal();
  factory WishlistService() => _instance;
  WishlistService._internal();

  final List<Product> _items = [];

  List<Product> get items => List.unmodifiable(_items);

  int get totalItems => _items.length;

  bool get isEmpty => _items.isEmpty;

  /// Cek apakah produk sudah ada di wishlist.
  bool containsProduct(Product product) {
    return _items.any((item) => item.idProduk == product.idProduk);
  }

  /// Toggle wishlist: tambah jika belum ada, hapus jika sudah ada.
  /// Returns true jika ditambahkan, false jika dihapus.
  bool toggleWishlist(Product product) {
    if (containsProduct(product)) {
      _items.removeWhere((item) => item.idProduk == product.idProduk);
      notifyListeners();
      return false;
    } else {
      _items.add(product);
      notifyListeners();
      return true;
    }
  }

  /// Tambah produk ke wishlist.
  void addProduct(Product product) {
    if (!containsProduct(product)) {
      _items.add(product);
      notifyListeners();
    }
  }

  /// Hapus produk dari wishlist.
  void removeProduct(Product product) {
    _items.removeWhere((item) => item.idProduk == product.idProduk);
    notifyListeners();
  }

  /// Bersihkan seluruh wishlist.
  void clearWishlist() {
    _items.clear();
    notifyListeners();
  }
}
