import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mysql1/mysql1.dart';

import '../models/user.dart';
import '../models/product.dart';
import '../models/transaksi.dart';
import '../models/user_profile.dart';

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
        image_url=?
        WHERE username=?
        ''',
        [
          profile.fullName,
          profile.phoneNumber,
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
          timestamp
        )
        VALUES
        (
          ?,?,?,?,?
        )
        ''',
        [
          transaksi.idUser,
          transaksi.metodeBayar,
          transaksi.total,
          transaksi.productName,
          transaksi.timestamp,
        ],
      );

      return true;
    } catch (e) {
      print(e);
      return false;
    }
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
      SELECT *
      FROM transaksi
      ORDER BY id_transaksi DESC
      ''',
    );

    return result.map((row) {
      return Transaksi(
        idTransaksi: row['id_transaksi'],
        idUser: row['id_user'],
        metodeBayar: row['metode_bayar'],
        total: (row['total'] as num).toDouble(),
        productName: row['productName'],
        timestamp: DateTime.parse(
          row['timestamp'].toString(),
        ),
      );
    }).toList();
  }

  // ======================================================
  // STATISTIK
  // ======================================================

  Future<double> getTotalPenjualan() async {
    if (kIsWeb) {
      final list = await getTransactions();
      return list.fold<double>(0.0, (sum, item) => sum + item.total);
    }

    final result = await conn.query(
      '''
      SELECT SUM(total) total
      FROM transaksi
      ''',
    );

    return result.first['total'] == null
        ? 0
        : (result.first['total'] as num).toDouble();
  }

  Future<int> getJumlahTransaksi() async {
    if (kIsWeb) {
      final list = await getTransactions();
      return list.length;
    }

    final result = await conn.query(
      '''
      SELECT COUNT(*) jumlah
      FROM transaksi
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