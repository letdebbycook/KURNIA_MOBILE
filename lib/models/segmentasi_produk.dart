/// Model class untuk data segmentasi produk kain dari hasil clustering ML.
///
/// Setiap baris dalam CSV `hasil_segmentasi_produk_kain.csv` di-mapping
/// menjadi satu instance [SegmentasiProduk].
class SegmentasiProduk {
  final String date;
  final double quantitiesKgs;
  final double value;
  final String pfcoCode;
  final double totalValues;
  final int cluster;
  final String segmentasiProduk;

  SegmentasiProduk({
    required this.date,
    required this.quantitiesKgs,
    required this.value,
    required this.pfcoCode,
    required this.totalValues,
    required this.cluster,
    required this.segmentasiProduk,
  });

  /// Parse dari satu baris CSV (list of strings) sesuai urutan kolom:
  /// DATE, QUANTITIES_Kgs, VALUE, PFco_Code, Total_values, cluster, segmentasi_produk
  factory SegmentasiProduk.fromCsvRow(List<dynamic> row) {
    return SegmentasiProduk(
      date: row[0].toString().trim(),
      quantitiesKgs: double.tryParse(row[1].toString().trim()) ?? 0.0,
      value: double.tryParse(row[2].toString().trim()) ?? 0.0,
      pfcoCode: row[3].toString().trim(),
      totalValues: double.tryParse(row[4].toString().trim()) ?? 0.0,
      cluster: int.tryParse(row[5].toString().trim()) ?? 0,
      segmentasiProduk: row[6].toString().trim(),
    );
  }

  /// Label segmentasi yang ramah pengguna.
  String get segmentLabel {
    switch (segmentasiProduk) {
      case 'fast moving':
        return 'Fast Moving';
      case 'medium moving':
        return 'Medium Moving';
      default:
        return 'Slow Moving';
    }
  }
}
