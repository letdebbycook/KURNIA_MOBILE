class DetailTransaksi {
  final int? idDetail;
  final int idTransaksi;
  final int idProduk;
  final String namaProduk;
  final String gambarProduk;
  final int jumlah;
  final double hargaSatuan;
  final double subtotal;

  DetailTransaksi({
    this.idDetail,
    required this.idTransaksi,
    required this.idProduk,
    required this.namaProduk,
    required this.gambarProduk,
    required this.jumlah,
    required this.hargaSatuan,
    required this.subtotal,
  });

  Map<String, dynamic> toJson() => {
        'id_detail': idDetail,
        'id_transaksi': idTransaksi,
        'id_produk': idProduk,
        'nama_produk': namaProduk,
        'gambar_produk': gambarProduk,
        'jumlah': jumlah,
        'harga_satuan': hargaSatuan,
        'subtotal': subtotal,
      };

  factory DetailTransaksi.fromJson(Map<String, dynamic> json) => DetailTransaksi(
        idDetail: json['id_detail'] as int?,
        idTransaksi: json['id_transaksi'] as int,
        idProduk: json['id_produk'] as int,
        namaProduk: (json['nama_produk'] as String?) ?? '',
        gambarProduk: (json['gambar_produk'] as String?) ?? '',
        jumlah: json['jumlah'] as int,
        hargaSatuan: (json['harga_satuan'] as num).toDouble(),
        subtotal: (json['subtotal'] as num).toDouble(),
      );
}
