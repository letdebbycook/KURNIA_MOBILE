class Transaksi {
  final int? idTransaksi;
  final int idUser;
  final String metodeBayar;
  final double total;
  final String productName; // helper
  final DateTime timestamp; // helper
  final String statusPembayaran;
  final String midtransOrderId;
  final String midtransRedirectUrl;
  final String statusPesanan;
  final String? userNama;
  final String? userTelepon;
  final String? userAlamat;

  Transaksi({
    this.idTransaksi,
    required this.idUser,
    required this.metodeBayar,
    required this.total,
    required this.productName,
    required this.timestamp,
    this.statusPembayaran = 'pending',
    this.midtransOrderId = '',
    this.midtransRedirectUrl = '',
    this.statusPesanan = 'pending',
    this.userNama,
    this.userTelepon,
    this.userAlamat,
  });

  Map<String, dynamic> toJson() => {
        'id_transaksi': idTransaksi,
        'id_user': idUser,
        'metode_bayar': metodeBayar,
        'total': total,
        'productName': productName,
        'timestamp': timestamp.toIso8601String(),
        'status_pembayaran': statusPembayaran,
        'midtrans_order_id': midtransOrderId,
        'midtrans_redirect_url': midtransRedirectUrl,
        'status_pesanan': statusPesanan,
        'user_nama': userNama,
        'user_telepon': userTelepon,
        'user_alamat': userAlamat,
      };

  factory Transaksi.fromJson(Map<String, dynamic> json) => Transaksi(
        idTransaksi: json['id_transaksi'] as int?,
        idUser: json['id_user'] as int,
        metodeBayar: json['metode_bayar'] as String,
        total: (json['total'] as num).toDouble(),
        productName: (json['productName'] as String?) ?? '',
        timestamp: DateTime.parse(json['timestamp'] as String),
        statusPembayaran: (json['status_pembayaran'] as String?) ?? 'pending',
        midtransOrderId: (json['midtrans_order_id'] as String?) ?? '',
        midtransRedirectUrl: (json['midtrans_redirect_url'] as String?) ?? '',
        statusPesanan: (json['status_pesanan'] as String?) ?? 'pending',
        userNama: json['user_nama'] as String?,
        userTelepon: json['user_telepon'] as String?,
        userAlamat: json['user_alamat'] as String?,
      );
}
