import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mysql1/mysql1.dart';

import '../models/user.dart';
import '../models/product.dart';
import '../models/transaksi.dart';
import '../models/detail_transaksi.dart';
import '../models/notifikasi.dart';
import '../models/user_profile.dart';
import '../models/cart_item.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  MySqlConnection? _connection;

  static const String _baseUrl = 'http://localhost/kurnia_api/api.php';

  Future<void> init() async {
    if (kIsWeb) return; // Web does not use raw TCP sockets
    if (_connection != null) return;

    final hosts = ['127.0.0.1', '10.0.2.2', '192.168.18.18'];
    for (final host in hosts) {
      try {
        _connection = await MySqlConnection.connect(
          ConnectionSettings(
            host: host,
            port: 3306,
            user: 'root',
            password: null, // null is required for passwordless authentication in MariaDB
            db: 'kurnia_mobile',
            timeout: const Duration(seconds: 2),
          ),
        );
        break;
      } catch (e) {
        print('Connection to host $host failed: $e');
      }
    }

    if (_connection == null) {
      throw Exception('Could not connect to database on any configured hosts.');
    }

    // Run schema migrations for localhost database
    await runMigrations();
  }

  Future<void> runMigrations() async {
    if (kIsWeb || _connection == null) return;
    try {
      // 1. Create notifikasi table if not exists
      await conn.query('''
        CREATE TABLE IF NOT EXISTS notifikasi (
          id_notifikasi INT AUTO_INCREMENT PRIMARY KEY,
          id_user INT NOT NULL,
          judul VARCHAR(100) NOT NULL,
          pesan TEXT NOT NULL,
          is_read TINYINT(1) DEFAULT 0,
          timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
      ''');

      // 2. Add kategori and stok columns to produk table if they do not exist
      try {
        await conn.query('ALTER TABLE produk ADD COLUMN kategori VARCHAR(50) DEFAULT "Lain-lain"');
      } catch (_) {}
      try {
        await conn.query('ALTER TABLE produk ADD COLUMN stok INT DEFAULT 0');
      } catch (_) {}

      // 3. Create ulasan table if not exists
      await conn.query('''
        CREATE TABLE IF NOT EXISTS ulasan (
          id_ulasan INT AUTO_INCREMENT PRIMARY KEY,
          id_produk INT NOT NULL,
          id_user INT NOT NULL,
          rating INT NOT NULL,
          komentar TEXT NULL,
          timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (id_produk) REFERENCES produk(id_produk) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
      ''');

      // 4. Create address_book table if not exists
      await conn.query('''
        CREATE TABLE IF NOT EXISTS address_book (
          id_alamat INT AUTO_INCREMENT PRIMARY KEY,
          id_user INT NOT NULL,
          label VARCHAR(50) NOT NULL,
          nama_penerima VARCHAR(100) NOT NULL,
          telepon_penerima VARCHAR(20) NOT NULL,
          alamat_lengkap TEXT NOT NULL,
          is_utama TINYINT(1) DEFAULT 0,
          FOREIGN KEY (id_user) REFERENCES users(id_user) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
      ''');
    } catch (e) {
      print('Auto migration error: $e');
    }
  }

  MySqlConnection get conn => _connection!;

  // ======================================================
  // LOGIN
  // ======================================================

  Future<AppUser?> validateUserLogin(
    String username,
    String password,
  ) async {
    if (kIsWeb) {
      try {
        final response = await http.get(Uri.parse('$_baseUrl?action=get_users'));
        if (response.statusCode == 200) {
          final List<dynamic> list = jsonDecode(response.body);
          for (var item in list) {
            if (item['username'].toString().toLowerCase() == username.toLowerCase() &&
                item['password'].toString() == password) {
              return AppUser.fromJson(item);
            }
          }
        }
      } catch (e) {
        print('Web login error: $e');
      }
      return null;
    }

    final result = await conn.query(
      '''
      SELECT *
      FROM users
      WHERE username = ?
      AND password = ?
      LIMIT 1
      ''',
      [username, password],
    );

    if (result.isEmpty) return null;

    final row = result.first;

    return AppUser(
      idUser: row['id_user'],
      username: row['username'],
      password: row['password'],
      email: row['email'],
      nama: row['nama'],
      telepon: row['telepon'],
    );
  }

  // ======================================================
  // REGISTER
  // ======================================================

  Future<bool> registerUser(AppUser user) async {
    if (kIsWeb) {
      try {
        final response = await http.post(
          Uri.parse('$_baseUrl?action=register_user'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(user.toJson()),
        );
        if (response.statusCode == 200) {
          final res = jsonDecode(response.body);
          return res['status'] == 'success';
        }
      } catch (e) {
        print('Web register error: $e');
      }
      return false;
    }

    try {
      await conn.query(
        '''
        INSERT INTO users
        (username,password,email,nama,telepon)
        VALUES(?,?,?,?,?)
        ''',
        [
          user.username,
          user.password,
          user.email,
          user.nama,
          user.telepon,
        ],
      );

      return true;
    } catch (e) {
      print(e);
      return false;
    }
  }

  // ======================================================
  // USER CRUD
  // ======================================================

  Future<List<AppUser>> getUsers() async {
    if (kIsWeb) {
      try {
        final response = await http.get(Uri.parse('$_baseUrl?action=get_users'));
        if (response.statusCode == 200) {
          final List<dynamic> list = jsonDecode(response.body);
          return list.map((item) => AppUser.fromJson(item)).toList();
        }
      } catch (e) {
        print('Web get users error: $e');
      }
      return [];
    }

    final result = await conn.query(
      "SELECT * FROM users",
    );

    return result
        .map(
          (row) => AppUser(
            idUser: row['id_user'],
            username: row['username'],
            password: row['password'],
            email: row['email'],
            nama: row['nama'],
            telepon: row['telepon'],
          ),
        )
        .toList();
  }

  Future<bool> updateUser(AppUser user) async {
    if (kIsWeb) {
      return false;
    }

    try {
      await conn.query(
        '''
        UPDATE users
        SET
        username=?,
        password=?,
        email=?,
        nama=?,
        telepon=?
        WHERE id_user=?
        ''',
        [
          user.username,
          user.password,
          user.email,
          user.nama,
          user.telepon,
          user.idUser,
        ],
      );

      return true;
    } catch (e) {
      print(e);
      return false;
    }
  }

  Future<bool> deleteUser(int idUser) async {
    if (kIsWeb) {
      return false;
    }

    try {
      await conn.query(
        "DELETE FROM users WHERE id_user=?",
        [idUser],
      );

      return true;
    } catch (e) {
      print(e);
      return false;
    }
  }

  // ======================================================
  // PRODUK
  // ======================================================

  Future<List<Product>> getProducts() async {
    if (kIsWeb) {
      try {
        final response = await http.get(Uri.parse('$_baseUrl?action=get_products'));
        if (response.statusCode == 200) {
          final List<dynamic> list = jsonDecode(response.body);
          return list.map((item) => Product.fromJson(item)).toList();
        }
      } catch (e) {
        print('Web get products error: $e');
      }
      return [];
    }

    final result = await conn.query(
      "SELECT * FROM produk ORDER BY id_produk DESC",
    );

    return result.map((row) {
      return Product(
        idProduk: row['id_produk'],
        name: row['nama'],
        description: row['deskripsi'],
        price: (row['harga'] as num).toDouble(),
        imageUrl: row['imageUrl'],
        kategori: row['kategori'] ?? 'Lain-lain',
        stok: row['stok'] ?? 0,
      );
    }).toList();
  }

  Future<bool> insertProduct(Product product) async {
    if (kIsWeb) {
      try {
        final response = await http.post(
          Uri.parse('$_baseUrl?action=insert_product'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(product.toJson()),
        );
        if (response.statusCode == 200) {
          final res = jsonDecode(response.body);
          return res['status'] == 'success';
        }
      } catch (e) {
        print('Web insert product error: $e');
      }
      return false;
    }

    try {
      await conn.query(
        '''
        INSERT INTO produk
        (nama,deskripsi,harga,imageUrl,kategori,stok)
        VALUES(?,?,?,?,?,?)
        ''',
        [
          product.name,
          product.description,
          product.price,
          product.imageUrl,
          product.kategori,
          product.stok,
        ],
      );

      return true;
    } catch (e) {
      print(e);
      return false;
    }
  }

  Future<bool> updateProduct(Product product) async {
    if (kIsWeb) {
      try {
        final payload = product.toJson();
        final response = await http.post(
          Uri.parse('$_baseUrl?action=update_product'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        );
        if (response.statusCode == 200) {
          final res = jsonDecode(response.body);
          return res['status'] == 'success';
        }
      } catch (e) {
        print('Web update product error: $e');
      }
      return false;
    }

    try {
      await conn.query(
        '''
        UPDATE produk
        SET
        nama=?,
        deskripsi=?,
        harga=?,
        imageUrl=?,
        kategori=?,
        stok=?
        WHERE id_produk=?
        ''',
        [
          product.name,
          product.description,
          product.price,
          product.imageUrl,
          product.kategori,
          product.stok,
          product.idProduk,
        ],
      );

      return true;
    } catch (e) {
      print(e);
      return false;
    }
  }

  Future<bool> deleteProduct(int idProduk) async {
    if (kIsWeb) {
      try {
        final response = await http.get(Uri.parse('$_baseUrl?action=delete_product&id=$idProduk'));
        if (response.statusCode == 200) {
          final res = jsonDecode(response.body);
          return res['status'] == 'success';
        }
      } catch (e) {
        print('Web delete product error: $e');
      }
      return false;
    }

    try {
      await conn.query(
        '''
        DELETE FROM produk
        WHERE id_produk=?
        ''',
        [idProduk],
      );

      return true;
    } catch (e) {
      print(e);
      return false;
    }
  }

  // ======================================================
  // PROFILE
  // ======================================================

  Future<UserProfile> getUserProfile(
    String username,
  ) async {
    if (kIsWeb) {
      try {
        final response = await http.get(Uri.parse('$_baseUrl?action=get_profile&username=$username'));
        if (response.statusCode == 200) {
          final res = jsonDecode(response.body);
          if (res['status'] != 'error') {
            return UserProfile.fromJson(res);
          }
        }
      } catch (e) {
        print('Web get profile error: $e');
      }
      return UserProfile(
        username: username,
        fullName: '',
        phoneNumber: '',
        imageUrl: '',
      );
    }

    final result = await conn.query(
      '''
      SELECT *
      FROM users
      WHERE username=?
      LIMIT 1
      ''',
      [username],
    );

    if (result.isEmpty) {
      return UserProfile(
        username: username,
        fullName: '',
        phoneNumber: '',
        imageUrl: '',
      );
    }

    final row = result.first;

    return UserProfile(
      username: row['username'],
      fullName: row['nama'] ?? '',
      phoneNumber: row['telepon'] ?? '',
      alamat: row['alamat'] ?? '',
      imageUrl: row['image_url'] ?? '',
    );
  }

  Future<bool> saveUserProfile(
    UserProfile profile,
  ) async {
    if (kIsWeb) {
      try {
        final response = await http.post(
          Uri.parse('$_baseUrl?action=save_profile'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(profile.toJson()),
        );
        if (response.statusCode == 200) {
          final res = jsonDecode(response.body);
          return res['status'] == 'success';
        }
      } catch (e) {
        print('Web save profile error: $e');
      }
      return false;
    }

    try {
      await conn.query(
        '''
        UPDATE users
        SET
        nama=?,
        telepon=?,
        alamat=?,
        image_url=?
        WHERE username=?
        ''',
        [
          profile.fullName,
          profile.phoneNumber,
          profile.alamat,
          profile.imageUrl,
          profile.username,
        ],
      );

      return true;
    } catch (e) {
      print(e);
      return false;
    }
  }

  // ======================================================
  // TRANSAKSI
  // ======================================================

  Future<bool> saveTransaksi(
    Transaksi transaksi,
  ) async {
    if (kIsWeb) {
      try {
        final response = await http.post(
          Uri.parse('$_baseUrl?action=save_transaksi'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(transaksi.toJson()),
        );
        if (response.statusCode == 200) {
          final res = jsonDecode(response.body);
          return res['status'] == 'success';
        }
      } catch (e) {
        print('Web save transaksi error: $e');
      }
      return false;
    }

    try {
      await conn.query(
        '''
        INSERT INTO transaksi
        (
          id_user,
          metode_bayar,
          total,
          productName,
          timestamp,
          status_pembayaran,
          midtrans_order_id,
          midtrans_redirect_url
        )
        VALUES
        (
          ?,?,?,?,?,?,?,?
        )
        ''',
        [
          transaksi.idUser,
          transaksi.metodeBayar,
          transaksi.total,
          transaksi.productName,
          transaksi.timestamp,
          transaksi.statusPembayaran,
          transaksi.midtransOrderId,
          transaksi.midtransRedirectUrl,
        ],
      );

      return true;
    } catch (e) {
      print(e);
      return false;
    }
  }

  Future<Map<String, dynamic>?> createMidtransTransaction(
    Transaksi transaksi,
    List<CartItem> cartItems,
  ) async {
    final Map<String, dynamic> payload = transaksi.toJson();
    payload['items'] = cartItems.map((item) => {
      'productName': item.product.name,
      'price': item.product.price,
      'quantity': item.quantity,
    }).toList();

    if (kIsWeb) {
      try {
        final response = await http.post(
          Uri.parse('$_baseUrl?action=create_midtrans_transaction'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        );
        if (response.statusCode == 200) {
          final res = jsonDecode(response.body);
          if (res['status'] == 'success') {
            return res;
          }
        }
      } catch (e) {
        print('Web create midtrans transaction error: $e');
      }
      return null;
    }

    // Native implementation calling PHP bridge
    try {
      final hosts = ['127.0.0.1', '10.0.2.2', '192.168.18.18'];
      for (final host in hosts) {
        try {
          final response = await http.post(
            Uri.parse('http://$host/kurnia_api/api.php?action=create_midtrans_transaction'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          ).timeout(const Duration(seconds: 2));
          if (response.statusCode == 200) {
            final res = jsonDecode(response.body);
            if (res['status'] == 'success') {
              return res;
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      print('Native create midtrans transaction error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> checkMidtransStatus(String orderId) async {
    if (kIsWeb) {
      try {
        final response = await http.get(
          Uri.parse('$_baseUrl?action=check_midtrans_status&order_id=$orderId'),
        );
        if (response.statusCode == 200) {
          return jsonDecode(response.body);
        }
      } catch (e) {
        print('Web check midtrans status error: $e');
      }
      return null;
    }

    try {
      final hosts = ['127.0.0.1', '10.0.2.2', '192.168.18.18'];
      for (final host in hosts) {
        try {
          final response = await http.get(
            Uri.parse('http://$host/kurnia_api/api.php?action=check_midtrans_status&order_id=$orderId'),
          ).timeout(const Duration(seconds: 2));
          if (response.statusCode == 200) {
            return jsonDecode(response.body);
          }
        } catch (_) {}
      }
    } catch (e) {
      print('Native check midtrans status error: $e');
    }
    return null;
  }

  Future<List<Transaksi>> getTransactions() async {
    if (kIsWeb) {
      try {
        final response = await http.get(Uri.parse('$_baseUrl?action=get_transactions'));
        if (response.statusCode == 200) {
          final List<dynamic> list = jsonDecode(response.body);
          return list.map((item) => Transaksi.fromJson(item)).toList();
        }
      } catch (e) {
        print('Web get transactions error: $e');
      }
      return [];
    }

    final result = await conn.query(
      '''
      SELECT t.*, d.id_detail, d.id_produk, d.jumlah, d.harga_satuan, d.subtotal, p.nama AS nama_produk, p.imageUrl AS gambar_produk, u.nama AS user_nama, u.telepon AS user_telepon, u.alamat AS user_alamat
      FROM transaksi t
      LEFT JOIN detail_transaksi d ON t.id_transaksi = d.id_transaksi
      LEFT JOIN produk p ON d.id_produk = p.id_produk
      LEFT JOIN users u ON t.id_user = u.id_user
      ORDER BY t.id_transaksi DESC
      ''',
    );

    final Map<int, Map<String, dynamic>> txMap = {};
    final Map<int, List<DetailTransaksi>> txItems = {};
    final List<int> orderedIds = [];

    for (var row in result) {
      final id = row['id_transaksi'] as int;
      if (!txMap.containsKey(id)) {
        orderedIds.add(id);
        txMap[id] = {
          'id_transaksi': id,
          'id_user': row['id_user'],
          'metode_bayar': row['metode_bayar'],
          'total': row['total'],
          'productName': row['productName'],
          'timestamp': row['timestamp'],
          'status_pembayaran': row['status_pembayaran'],
          'status_pesanan': row['status_pesanan'],
          'midtrans_order_id': row['midtrans_order_id'],
          'midtrans_redirect_url': row['midtrans_redirect_url'],
          'user_nama': row['user_nama'],
          'user_telepon': row['user_telepon'],
          'user_alamat': row['user_alamat'],
        };
        txItems[id] = [];
      }

      if (row['id_detail'] != null) {
        txItems[id]!.add(DetailTransaksi(
          idDetail: row['id_detail'] as int?,
          idTransaksi: id,
          idProduk: row['id_produk'] as int,
          namaProduk: (row['nama_produk'] as String?) ?? '',
          gambarProduk: (row['gambar_produk'] as String?) ?? '',
          jumlah: row['jumlah'] as int,
          hargaSatuan: (row['harga_satuan'] as num).toDouble(),
          subtotal: (row['subtotal'] as num).toDouble(),
        ));
      }
    }

    return orderedIds.map((id) {
      final tx = txMap[id]!;
      return Transaksi(
        idTransaksi: id,
        idUser: tx['id_user'] as int,
        metodeBayar: (tx['metode_bayar'] as String?) ?? '',
        total: (tx['total'] as num).toDouble(),
        productName: (tx['productName'] as String?) ?? '',
        timestamp: tx['timestamp'] is DateTime
            ? tx['timestamp'] as DateTime
            : DateTime.parse(tx['timestamp'].toString()),
        statusPembayaran: (tx['status_pembayaran'] as String?) ?? 'pending',
        statusPesanan: (tx['status_pesanan'] as String?) ?? 'pending',
        midtransOrderId: (tx['midtrans_order_id'] as String?) ?? '',
        midtransRedirectUrl: (tx['midtrans_redirect_url'] as String?) ?? '',
        userNama: tx['user_nama'] as String?,
        userTelepon: tx['user_telepon'] as String?,
        userAlamat: tx['user_alamat'] as String?,
        items: txItems[id],
      );
    }).toList();
  }

  Future<List<Transaksi>> getTransactionsByUserId(int idUser) async {
    if (kIsWeb) {
      try {
        final response = await http.get(Uri.parse('$_baseUrl?action=get_transactions_by_user&id_user=$idUser'));
        if (response.statusCode == 200) {
          final List<dynamic> list = jsonDecode(response.body);
          return list.map((item) => Transaksi.fromJson(item)).toList();
        }
      } catch (e) {
        print('Web get transactions by user error: $e');
      }
      return [];
    }

    final result = await conn.query(
      '''
      SELECT t.*, d.id_detail, d.id_produk, d.jumlah, d.harga_satuan, d.subtotal, p.nama AS nama_produk, p.imageUrl AS gambar_produk, u.nama AS user_nama, u.telepon AS user_telepon, u.alamat AS user_alamat
      FROM transaksi t
      LEFT JOIN detail_transaksi d ON t.id_transaksi = d.id_transaksi
      LEFT JOIN produk p ON d.id_produk = p.id_produk
      LEFT JOIN users u ON t.id_user = u.id_user
      WHERE t.id_user = ?
      ORDER BY t.id_transaksi DESC
      ''',
      [idUser],
    );

    final Map<int, Map<String, dynamic>> txMap = {};
    final Map<int, List<DetailTransaksi>> txItems = {};
    final List<int> orderedIds = [];

    for (var row in result) {
      final id = row['id_transaksi'] as int;
      if (!txMap.containsKey(id)) {
        orderedIds.add(id);
        txMap[id] = {
          'id_transaksi': id,
          'id_user': row['id_user'],
          'metode_bayar': row['metode_bayar'],
          'total': row['total'],
          'productName': row['productName'],
          'timestamp': row['timestamp'],
          'status_pembayaran': row['status_pembayaran'],
          'status_pesanan': row['status_pesanan'],
          'midtrans_order_id': row['midtrans_order_id'],
          'midtrans_redirect_url': row['midtrans_redirect_url'],
          'user_nama': row['user_nama'],
          'user_telepon': row['user_telepon'],
          'user_alamat': row['user_alamat'],
        };
        txItems[id] = [];
      }

      if (row['id_detail'] != null) {
        txItems[id]!.add(DetailTransaksi(
          idDetail: row['id_detail'] as int?,
          idTransaksi: id,
          idProduk: row['id_produk'] as int,
          namaProduk: (row['nama_produk'] as String?) ?? '',
          gambarProduk: (row['gambar_produk'] as String?) ?? '',
          jumlah: row['jumlah'] as int,
          hargaSatuan: (row['harga_satuan'] as num).toDouble(),
          subtotal: (row['subtotal'] as num).toDouble(),
        ));
      }
    }

    return orderedIds.map((id) {
      final tx = txMap[id]!;
      return Transaksi(
        idTransaksi: id,
        idUser: tx['id_user'] as int,
        metodeBayar: (tx['metode_bayar'] as String?) ?? '',
        total: (tx['total'] as num).toDouble(),
        productName: (tx['productName'] as String?) ?? '',
        timestamp: tx['timestamp'] is DateTime
            ? tx['timestamp'] as DateTime
            : DateTime.parse(tx['timestamp'].toString()),
        statusPembayaran: (tx['status_pembayaran'] as String?) ?? 'pending',
        statusPesanan: (tx['status_pesanan'] as String?) ?? 'pending',
        midtransOrderId: (tx['midtrans_order_id'] as String?) ?? '',
        midtransRedirectUrl: (tx['midtrans_redirect_url'] as String?) ?? '',
        userNama: tx['user_nama'] as String?,
        userTelepon: tx['user_telepon'] as String?,
        userAlamat: tx['user_alamat'] as String?,
        items: txItems[id],
      );
    }).toList();
  }

  Future<bool> updateOrderStatus(int idTransaksi, String statusPesanan) async {
    if (kIsWeb) {
      try {
        final response = await http.post(
          Uri.parse('$_baseUrl?action=update_order_status'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'id_transaksi': idTransaksi,
            'status_pesanan': statusPesanan,
          }),
        );
        if (response.statusCode == 200) {
          final res = jsonDecode(response.body);
          return res['status'] == 'success';
        }
      } catch (e) {
        print('Web update order status error: $e');
      }
      return false;
    }

    try {
      await conn.query(
        '''
        UPDATE transaksi
        SET status_pesanan = ?
        WHERE id_transaksi = ?
        ''',
        [statusPesanan, idTransaksi],
      );
      return true;
    } catch (e) {
      print('Native update order status error: $e');
      return false;
    }
  }

  Future<bool> deleteTransaction({int? idTransaksi, String? midtransOrderId}) async {
    final orderIdParam = midtransOrderId ?? '';
    final idParam = idTransaksi ?? 0;
    
    if (kIsWeb) {
      try {
        final response = await http.get(
          Uri.parse('$_baseUrl?action=delete_transaction&id=$idParam&order_id=$orderIdParam'),
        );
        if (response.statusCode == 200) {
          final res = jsonDecode(response.body);
          return res['status'] == 'success';
        }
      } catch (e) {
        print('Web delete transaction error: $e');
      }
      return false;
    }

    try {
      if (midtransOrderId != null && midtransOrderId.isNotEmpty) {
        await conn.query(
          "DELETE FROM transaksi WHERE midtrans_order_id = ? AND status_pembayaran = 'pending'",
          [midtransOrderId],
        );
      } else {
        await conn.query(
          "DELETE FROM transaksi WHERE id_transaksi = ? AND status_pembayaran = 'pending'",
          [idTransaksi],
        );
      }
      return true;
    } catch (e) {
      print('Native delete transaction error: $e');
      return false;
    }
  }

  // ======================================================
  // STATISTIK
  // ======================================================

  Future<double> getTotalPenjualan() async {
    if (kIsWeb) {
      final list = await getTransactions();
      return list
          .where((t) =>
              t.statusPembayaran.toLowerCase() == 'success' ||
              t.statusPembayaran.toLowerCase() == 'settlement' ||
              t.statusPembayaran.toLowerCase() == 'capture')
          .fold<double>(0.0, (sum, item) => sum + item.total);
    }

    final result = await conn.query(
      '''
      SELECT SUM(total) total
      FROM transaksi
      WHERE status_pembayaran IN ('success', 'settlement', 'capture')
      ''',
    );

    return result.first['total'] == null
        ? 0
        : (result.first['total'] as num).toDouble();
  }

  Future<int> getJumlahTransaksi() async {
    if (kIsWeb) {
      final list = await getTransactions();
      return list
          .where((t) =>
              t.statusPembayaran.toLowerCase() == 'success' ||
              t.statusPembayaran.toLowerCase() == 'settlement' ||
              t.statusPembayaran.toLowerCase() == 'capture')
          .length;
    }

    final result = await conn.query(
      '''
      SELECT COUNT(*) jumlah
      FROM transaksi
      WHERE status_pembayaran IN ('success', 'settlement', 'capture')
      ''',
    );

    return result.first['jumlah'];
  }

  // ======================================================
  // NOTIFIKASI
  // ======================================================

  Future<List<Notifikasi>> getNotifications(int idUser) async {
    if (kIsWeb) {
      try {
        final response = await http.get(Uri.parse('$_baseUrl?action=get_notifications&id_user=$idUser'));
        if (response.statusCode == 200) {
          final List<dynamic> list = jsonDecode(response.body);
          return list.map((item) => Notifikasi.fromJson(item)).toList();
        }
      } catch (e) {
        print('Web get notifications error: $e');
      }
      return [];
    }

    try {
      final result = await conn.query(
        'SELECT * FROM notifikasi WHERE id_user = ? ORDER BY id_notifikasi DESC',
        [idUser],
      );
      return result.map((row) {
        return Notifikasi(
          idNotifikasi: row['id_notifikasi'],
          idUser: row['id_user'],
          judul: row['judul'] ?? '',
          pesan: row['pesan'] ?? '',
          isRead: row['is_read'] == 1,
          timestamp: DateTime.parse(row['timestamp'].toString()),
        );
      }).toList();
    } catch (e) {
      print('Native get notifications error: $e');
      return [];
    }
  }

  Future<bool> markNotificationsAsRead(int idUser) async {
    if (kIsWeb) {
      try {
        final response = await http.get(Uri.parse('$_baseUrl?action=mark_notifications_read&id_user=$idUser'));
        if (response.statusCode == 200) {
          final res = jsonDecode(response.body);
          return res['status'] == 'success';
        }
      } catch (e) {
        print('Web mark notifications read error: $e');
      }
      return false;
    }

    try {
      await conn.query(
        'UPDATE notifikasi SET is_read = 1 WHERE id_user = ?',
        [idUser],
      );
      return true;
    } catch (e) {
      print('Native mark notifications read error: $e');
      return false;
    }
  }

  Future<int> getUnreadNotificationCount(int idUser) async {
    final list = await getNotifications(idUser);
    return list.where((n) => !n.isRead).length;
  }

  // ======================================================
  // STOK MANAJEMEN
  // ======================================================

  Future<bool> reduceProductStock(int idProduk, int quantity) async {
    if (kIsWeb) {
      try {
        final response = await http.post(
          Uri.parse('$_baseUrl?action=reduce_stock'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'id_produk': idProduk, 'quantity': quantity}),
        );
        if (response.statusCode == 200) {
          final res = jsonDecode(response.body);
          return res['status'] == 'success';
        }
      } catch (e) {
        print('Web reduce stock error: $e');
      }
      return false;
    }

    try {
      await conn.query(
        'UPDATE produk SET stok = GREATEST(0, stok - ?) WHERE id_produk = ?',
        [quantity, idProduk],
      );
      return true;
    } catch (e) {
      print('Native reduce stock error: $e');
      return false;
    }
  }

  // ======================================================
  // ULASAN / RATING
  // ======================================================

  Future<List<Map<String, dynamic>>> getReviews(int idProduk) async {
    if (kIsWeb) {
      try {
        final response = await http.get(Uri.parse('$_baseUrl?action=get_reviews&id_produk=$idProduk'));
        if (response.statusCode == 200) {
          final List<dynamic> list = jsonDecode(response.body);
          return list.map((item) => item as Map<String, dynamic>).toList();
        }
      } catch (e) {
        print('Web get reviews error: $e');
      }
      return [];
    }

    try {
      final result = await conn.query(
        '''
        SELECT u.*, us.nama AS user_nama
        FROM ulasan u
        LEFT JOIN users us ON u.id_user = us.id_user
        WHERE u.id_produk = ?
        ORDER BY u.id_ulasan DESC
        ''',
        [idProduk],
      );
      return result.map((row) => {
        'id_ulasan': row['id_ulasan'],
        'id_produk': row['id_produk'],
        'id_user': row['id_user'],
        'rating': row['rating'],
        'komentar': row['komentar'] ?? '',
        'timestamp': row['timestamp'].toString(),
        'user_nama': row['user_nama'] ?? 'Pelanggan',
      }).toList();
    } catch (e) {
      print('Native get reviews error: $e');
      return [];
    }
  }

  Future<bool> insertReview(int idProduk, int idUser, int rating, String komentar) async {
    if (kIsWeb) {
      try {
        final response = await http.post(
          Uri.parse('$_baseUrl?action=insert_review'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'id_produk': idProduk,
            'id_user': idUser,
            'rating': rating,
            'komentar': komentar,
          }),
        );
        if (response.statusCode == 200) {
          final res = jsonDecode(response.body);
          return res['status'] == 'success';
        }
      } catch (e) {
        print('Web insert review error: $e');
      }
      return false;
    }

    try {
      await conn.query(
        '''
        INSERT INTO ulasan (id_produk, id_user, rating, komentar, timestamp)
        VALUES (?, ?, ?, ?, ?)
        ''',
        [idProduk, idUser, rating, komentar, DateTime.now()],
      );
      return true;
    } catch (e) {
      print('Native insert review error: $e');
      return false;
    }
  }

  // ======================================================
  // ADDRESS BOOK
  // ======================================================

  Future<List<Map<String, dynamic>>> getAddresses(int idUser) async {
    if (kIsWeb) {
      try {
        final response = await http.get(Uri.parse('$_baseUrl?action=get_addresses&id_user=$idUser'));
        if (response.statusCode == 200) {
          final List<dynamic> list = jsonDecode(response.body);
          return list.map((item) => item as Map<String, dynamic>).toList();
        }
      } catch (e) {
        print('Web get addresses error: $e');
      }
      return [];
    }

    try {
      final result = await conn.query(
        'SELECT * FROM address_book WHERE id_user = ? ORDER BY is_utama DESC, id_alamat DESC',
        [idUser],
      );
      return result.map((row) => {
        'id_alamat': row['id_alamat'],
        'id_user': row['id_user'],
        'label': row['label'] ?? '',
        'nama_penerima': row['nama_penerima'] ?? '',
        'telepon_penerima': row['telepon_penerima'] ?? '',
        'alamat_lengkap': row['alamat_lengkap'] ?? '',
        'is_utama': row['is_utama'] == 1,
      }).toList();
    } catch (e) {
      print('Native get addresses error: $e');
      return [];
    }
  }

  Future<bool> insertAddress(int idUser, String label, String nama, String telepon, String alamat, bool isUtama) async {
    if (kIsWeb) {
      try {
        final response = await http.post(
          Uri.parse('$_baseUrl?action=insert_address'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'id_user': idUser,
            'label': label,
            'nama_penerima': nama,
            'telepon_penerima': telepon,
            'alamat_lengkap': alamat,
            'is_utama': isUtama ? 1 : 0,
          }),
        );
        if (response.statusCode == 200) {
          final res = jsonDecode(response.body);
          return res['status'] == 'success';
        }
      } catch (e) {
        print('Web insert address error: $e');
      }
      return false;
    }

    try {
      if (isUtama) {
        // Reset other addresses to is_utama = 0
        await conn.query('UPDATE address_book SET is_utama = 0 WHERE id_user = ?', [idUser]);
      }
      await conn.query(
        '''
        INSERT INTO address_book (id_user, label, nama_penerima, telepon_penerima, alamat_lengkap, is_utama)
        VALUES (?, ?, ?, ?, ?, ?)
        ''',
        [idUser, label, nama, telepon, alamat, isUtama ? 1 : 0],
      );
      return true;
    } catch (e) {
      print('Native insert address error: $e');
      return false;
    }
  }

  Future<bool> updateAddress(int idAlamat, String label, String nama, String telepon, String alamat, bool isUtama, int idUser) async {
    if (kIsWeb) {
      try {
        final response = await http.post(
          Uri.parse('$_baseUrl?action=update_address'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'id_alamat': idAlamat,
            'label': label,
            'nama_penerima': nama,
            'telepon_penerima': telepon,
            'alamat_lengkap': alamat,
            'is_utama': isUtama ? 1 : 0,
          }),
        );
        if (response.statusCode == 200) {
          final res = jsonDecode(response.body);
          return res['status'] == 'success';
        }
      } catch (e) {
        print('Web update address error: $e');
      }
      return false;
    }

    try {
      if (isUtama) {
        // Reset other addresses to is_utama = 0
        await conn.query('UPDATE address_book SET is_utama = 0 WHERE id_user = ?', [idUser]);
      }
      await conn.query(
        '''
        UPDATE address_book
        SET label = ?, nama_penerima = ?, telepon_penerima = ?, alamat_lengkap = ?, is_utama = ?
        WHERE id_alamat = ?
        ''',
        [label, nama, telepon, alamat, isUtama ? 1 : 0, idAlamat],
      );
      return true;
    } catch (e) {
      print('Native update address error: $e');
      return false;
    }
  }

  Future<bool> deleteAddress(int idAlamat) async {
    if (kIsWeb) {
      try {
        final response = await http.get(Uri.parse('$_baseUrl?action=delete_address&id=$idAlamat'));
        if (response.statusCode == 200) {
          final res = jsonDecode(response.body);
          return res['status'] == 'success';
        }
      } catch (e) {
        print('Web delete address error: $e');
      }
      return false;
    }

    try {
      await conn.query('DELETE FROM address_book WHERE id_alamat = ?', [idAlamat]);
      return true;
    } catch (e) {
      print('Native delete address error: $e');
      return false;
    }
  }

  Future<bool> setPrimaryAddress(int idUser, int idAlamat) async {
    if (kIsWeb) return false;
    try {
      await conn.query('UPDATE address_book SET is_utama = 0 WHERE id_user = ?', [idUser]);
      await conn.query('UPDATE address_book SET is_utama = 1 WHERE id_alamat = ?', [idAlamat]);
      return true;
    } catch (e) {
      print('Native set primary address error: $e');
      return false;
    }
  }

  Future<void> close() async {
    if (kIsWeb) return;
    await _connection?.close();
    _connection = null;
  }
}