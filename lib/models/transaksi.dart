class Transaksi {
  final int? idTransaksi;
  final int idUser;
  final String metodeBayar;
  final double total;
  final String productName; // helper
  final DateTime timestamp; // helper

  Transaksi({
    this.idTransaksi,
    required this.idUser,
    required this.metodeBayar,
    required this.total,
    required this.productName,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id_transaksi': idTransaksi,
        'id_user': idUser,
        'metode_bayar': metodeBayar,
        'total': total,
        'productName': productName,
        'timestamp': timestamp.toIso8601String(),
      };

  factory Transaksi.fromJson(Map<String, dynamic> json) => Transaksi(
        idTransaksi: json['id_transaksi'] as int?,
        idUser: json['id_user'] as int,
        metodeBayar: json['metode_bayar'] as String,
        total: (json['total'] as num).toDouble(),
        productName: json['productName'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}
