import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mysql1/mysql1.dart';

import '../models/user.dart';
import '../models/product.dart';
import '../models/transaksi.dart';
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
        (nama,deskripsi,harga,imageUrl)
        VALUES(?,?,?,?)
        ''',
        [
          product.name,
          product.description,
          product.price,
          product.imageUrl,
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
        imageUrl=?
        WHERE id_produk=?
        ''',
        [
          product.name,
          product.description,
          product.price,
          product.imageUrl,
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
      SELECT t.*, u.nama AS user_nama, u.telepon AS user_telepon, u.alamat AS user_alamat
      FROM transaksi t
      LEFT JOIN users u ON t.id_user = u.id_user
      ORDER BY t.id_transaksi DESC
      ''',
    );

    return result.map((row) {
      return Transaksi(
        idTransaksi: row['id_transaksi'],
        idUser: row['id_user'],
        metodeBayar: row['metode_bayar'],
        total: (row['total'] as num).toDouble(),
        productName: row['productName'] ?? '',
        timestamp: DateTime.parse(row['timestamp'].toString()),
        statusPembayaran: row['status_pembayaran'] ?? 'pending',
        statusPesanan: row['status_pesanan'] ?? 'pending',
        midtransOrderId: row['midtrans_order_id'] ?? '',
        midtransRedirectUrl: row['midtrans_redirect_url'] ?? '',
        userNama: row['user_nama'],
        userTelepon: row['user_telepon'],
        userAlamat: row['user_alamat'],
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
      SELECT t.*, u.nama AS user_nama, u.telepon AS user_telepon, u.alamat AS user_alamat
      FROM transaksi t
      LEFT JOIN users u ON t.id_user = u.id_user
      WHERE t.id_user = ?
      ORDER BY t.id_transaksi DESC
      ''',
      [idUser],
    );

    return result.map((row) {
      return Transaksi(
        idTransaksi: row['id_transaksi'],
        idUser: row['id_user'],
        metodeBayar: row['metode_bayar'],
        total: (row['total'] as num).toDouble(),
        productName: row['productName'] ?? '',
        timestamp: DateTime.parse(row['timestamp'].toString()),
        statusPembayaran: row['status_pembayaran'] ?? 'pending',
        statusPesanan: row['status_pesanan'] ?? 'pending',
        midtransOrderId: row['midtrans_order_id'] ?? '',
        midtransRedirectUrl: row['midtrans_redirect_url'] ?? '',
        userNama: row['user_nama'],
        userTelepon: row['user_telepon'],
        userAlamat: row['user_alamat'],
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

  Future<void> close() async {
    if (kIsWeb) return;
    await _connection?.close();
    _connection = null;
  }
}