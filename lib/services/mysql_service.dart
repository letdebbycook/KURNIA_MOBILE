import 'package:mysql1/mysql1.dart';

class MysqlService {
  static Future<MySqlConnection> getConnection() async {
    final hosts = ['127.0.0.1', '10.0.2.2', '192.168.18.18'];
    for (final host in hosts) {
      try {
        return await MySqlConnection.connect(
          ConnectionSettings(
            host: host,
            port: 3306,
            user: 'root',
            password: null, // null is required for passwordless authentication in MariaDB
            db: 'kurnia_mobile',
            timeout: const Duration(seconds: 2),
          ),
        );
      } catch (e) {
        print('Connection to host $host failed: $e');
      }
    }
    throw Exception('Could not connect to database on any configured hosts.');
  }
}