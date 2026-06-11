import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import '../models/transaksi.dart';
import '../models/user.dart';
import '../models/user_profile.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static const String _productsKey = 'kurnia_products';
  static const String _transactionsKey = 'kurnia_transactions';
  static const String _usersKey = 'kurnia_users'; // JSON list of AppUser
  static const String _profilesKey = 'kurnia_profiles'; // JSON map of username -> profile

  late SharedPreferences _prefs;
  bool _initialized = false;

  // Initialize SharedPreferences
  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
    await _seedDefaultUsersAndProfilesIfNeeded();
    await _seedDefaultProductsIfNeeded();
  }

  // --- Products CRUD (db_Produk) ---

  // Get Data - act AD_Read Katalog Barang
  List<Product> getProducts() {
    final String? productsJson = _prefs.getString(_productsKey);
    if (productsJson == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(productsJson);
      return decoded.map((item) => Product.fromJson(item)).toList();
    } catch (e) {
      return [];
    }
  }

  // Insert Data - act AD_Create Katalog Barang
  Future<bool> insertProduct(Product product) async {
    try {
      final List<Product> products = getProducts();
      // Validate duplicates
      if (products.any((p) => p.name.toLowerCase() == product.name.toLowerCase())) {
        return false;
      }
      
      // Auto-increment integer id_produk simulation
      int nextId = 1;
      if (products.isNotEmpty) {
        nextId = products.map((p) => p.idProduk ?? 0).reduce((a, b) => a > b ? a : b) + 1;
      }

      final newProduct = Product(
        idProduk: nextId,
        name: product.name,
        description: product.description,
        price: product.price,
        imageUrl: product.imageUrl,
      );

      products.add(newProduct);
      final String encoded = jsonEncode(products.map((p) => p.toJson()).toList());
      await _prefs.setString(_productsKey, encoded);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Delete Data - act AD_Delete Katalog Barang
  Future<bool> deleteProduct(int id) async {
    try {
      final List<Product> products = getProducts();
      products.removeWhere((p) => p.idProduk == id);
      final String encoded = jsonEncode(products.map((p) => p.toJson()).toList());
      await _prefs.setString(_productsKey, encoded);
      return true;
    } catch (e) {
      return false;
    }
  }

  // --- Transactions Operations (db_Transaksi) ---

  // Set Data - act AD_Form Pemesanan
  Future<bool> saveTransaksi(Transaksi transaction) async {
    try {
      final List<Transaksi> transactions = getTransactions();
      
      // Auto-increment integer id_transaksi simulation
      int nextId = 1;
      if (transactions.isNotEmpty) {
        nextId = transactions.map((t) => t.idTransaksi ?? 0).reduce((a, b) => a > b ? a : b) + 1;
      }

      final newTrx = Transaksi(
        idTransaksi: nextId,
        idUser: transaction.idUser,
        metodeBayar: transaction.metodeBayar,
        total: transaction.total,
        productName: transaction.productName,
        timestamp: transaction.timestamp,
      );

      transactions.add(newTrx);
      final String encoded = jsonEncode(transactions.map((t) => t.toJson()).toList());
      await _prefs.setString(_transactionsKey, encoded);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Get Data
  List<Transaksi> getTransactions() {
    final String? txJson = _prefs.getString(_transactionsKey);
    if (txJson == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(txJson);
      return decoded.map((item) => Transaksi.fromJson(item)).toList();
    } catch (e) {
      return [];
    }
  }

  // --- User Authentication & CRUD (db_User) ---

  // Insert Data - act AD_Register
  Future<bool> registerUser(AppUser user) async {
    try {
      final List<AppUser> users = getUsers();
      if (users.any((u) => u.username.toLowerCase() == user.username.toLowerCase())) {
        return false; // Duplicate check (validation block)
      }

      // Auto-increment id_user simulation
      int nextId = 1;
      if (users.isNotEmpty) {
        nextId = users.map((u) => u.idUser ?? 0).reduce((a, b) => a > b ? a : b) + 1;
      }

      final newUser = AppUser(
        idUser: nextId,
        username: user.username,
        password: user.password,
        email: user.email,
        nama: user.nama,
        telepon: user.telepon,
      );

      users.add(newUser);
      await _prefs.setString(_usersKey, jsonEncode(users.map((u) => u.toJson()).toList()));

      // Create a default blank profile for the new user
      final defaultProfile = UserProfile(
        username: newUser.username,
        fullName: newUser.nama,
        phoneNumber: newUser.telepon,
        imageUrl: 'https://api.dicebear.com/7.x/adventurer/png?seed=${newUser.username}',
      );
      await saveUserProfile(defaultProfile);

      return true;
    } catch (e) {
      return false;
    }
  }

  // Validate Credentials - act Activity Diagram (Login)
  AppUser? validateUserLogin(String username, String password) {
    final lowerUser = username.toLowerCase();
    final List<AppUser> users = getUsers();
    
    for (var user in users) {
      if (user.username.toLowerCase() == lowerUser && user.password == password) {
        return user; // Return full user details (contains idUser)
      }
    }
    return null;
  }

  List<AppUser> getUsers() {
    final String? usersJson = _prefs.getString(_usersKey);
    if (usersJson == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(usersJson);
      return decoded.map((u) => AppUser.fromJson(u)).toList();
    } catch (e) {
      return [];
    }
  }

  // --- Profile CRUD Operations ---

  // Get Profile Data - act AD_Profil / AD_Update_Profil
  UserProfile getUserProfile(String username) {
    final String? profilesJson = _prefs.getString(_profilesKey);
    if (profilesJson != null) {
      try {
        final Map<String, dynamic> profiles = jsonDecode(profilesJson);
        if (profiles.containsKey(username.toLowerCase())) {
          return UserProfile.fromJson(profiles[username.toLowerCase()]);
        }
      } catch (_) {}
    }

    // Fallback if none exists
    final List<AppUser> users = getUsers();
    final matchingUser = users.firstWhere(
      (u) => u.username.toLowerCase() == username.toLowerCase(),
      orElse: () => AppUser(username: username, password: '', email: '', nama: username, telepon: ''),
    );

    return UserProfile(
      username: username,
      fullName: matchingUser.nama.isNotEmpty ? matchingUser.nama : username,
      phoneNumber: matchingUser.telepon.isNotEmpty ? matchingUser.telepon : '',
      imageUrl: 'https://api.dicebear.com/7.x/adventurer/png?seed=$username',
    );
  }

  // Insert / Update Profile Data - act AD_Profil & AD_Update_Profil
  Future<bool> saveUserProfile(UserProfile profile) async {
    try {
      final String? profilesJson = _prefs.getString(_profilesKey);
      final Map<String, dynamic> profiles = profilesJson != null ? jsonDecode(profilesJson) : {};
      
      profiles[profile.username.toLowerCase()] = profile.toJson();
      await _prefs.setString(_profilesKey, jsonEncode(profiles));

      // Also sync user profile details back to db_User fields
      final List<AppUser> users = getUsers();
      final userIndex = users.indexWhere((u) => u.username.toLowerCase() == profile.username.toLowerCase());
      if (userIndex != -1) {
        final oldUser = users[userIndex];
        users[userIndex] = AppUser(
          idUser: oldUser.idUser,
          username: oldUser.username,
          password: oldUser.password,
          email: oldUser.email,
          nama: profile.fullName,
          telepon: profile.phoneNumber,
        );
        await _prefs.setString(_usersKey, jsonEncode(users.map((u) => u.toJson()).toList()));
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  // --- Default Seed Helpers ---

  Future<void> _seedDefaultUsersAndProfilesIfNeeded() async {
    final List<AppUser> existing = getUsers();
    if (existing.isEmpty) {
      final List<AppUser> defaultUsers = [
        AppUser(
          idUser: 1,
          username: 'admin',
          password: 'admin',
          email: 'admin@kurnia.com',
          nama: 'Administrator',
          telepon: '081122334455',
        ),
        AppUser(
          idUser: 2,
          username: 'customer',
          password: 'customer',
          email: 'cust@kurnia.com',
          nama: 'Budi Santoso',
          telepon: '081234567890',
        ),
      ];
      await _prefs.setString(_usersKey, jsonEncode(defaultUsers.map((u) => u.toJson()).toList()));

      for (var u in defaultUsers) {
        final defaultProfile = UserProfile(
          username: u.username,
          fullName: u.nama,
          phoneNumber: u.telepon,
          imageUrl: 'https://api.dicebear.com/7.x/adventurer/png?seed=${u.username}',
        );
        await saveUserProfile(defaultProfile);
      }
    }
  }

  Future<void> _seedDefaultProductsIfNeeded() async {
    final List<Product> existing = getProducts();
    if (existing.isEmpty) {
      final List<Product> defaultProducts = [
        Product(
          idProduk: 1,
          name: 'Beras Premium Kurnia 5kg',
          description: 'Beras kualitas super poles premium, sangat pulen, bersih, dan harum alami.',
          price: 78500.0,
          imageUrl: 'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=600&auto=format&fit=crop&q=80',
        ),
        Product(
          idProduk: 2,
          name: 'Minyak Goreng SunCo 2L',
          description: 'Minyak goreng kelapa sawit bermutu tinggi, bening dan tidak cepat hitam.',
          price: 38900.0,
          imageUrl: 'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=600&auto=format&fit=crop&q=80',
        ),
        Product(
          idProduk: 3,
          name: 'Gula Pasir Gulaku 1kg',
          description: 'Gula tebu pilihan bermutu tinggi, bersih, putih manis alami.',
          price: 17500.0,
          imageUrl: 'https://images.unsplash.com/photo-1581798459219-318e76aecc7b?w=600&auto=format&fit=crop&q=80',
        ),
        Product(
          idProduk: 4,
          name: 'Tepung Terigu Segitiga Biru 1kg',
          description: 'Tepung terigu serbaguna protein sedang, cocok untuk aneka kue dan gorengan.',
          price: 14500.0,
          imageUrl: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=600&auto=format&fit=crop&q=80',
        ),
      ];
      final String encoded = jsonEncode(defaultProducts.map((p) => p.toJson()).toList());
      await _prefs.setString(_productsKey, encoded);
    }
  }

  Future<void> clearAll() async {
    await _prefs.remove(_productsKey);
    await _prefs.remove(_transactionsKey);
    await _prefs.remove(_usersKey);
    await _prefs.remove(_profilesKey);
    await _seedDefaultUsersAndProfilesIfNeeded();
    await _seedDefaultProductsIfNeeded();
  }
}
