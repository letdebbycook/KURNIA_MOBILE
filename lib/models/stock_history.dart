import '../services/ml_scaler.dart';

/// Model class untuk data historis stok bulanan per produk.
///
/// Setiap baris dalam CSV `data_historis_stok.csv` di-mapping
/// menjadi satu instance [StockHistory].
class StockHistory {
  final String pfcoCode;
  final int tahun;
  final int bulan;
  final double stokAwal;
  final double stokMasuk;
  final double penjualan;
  final double stokAkhir;
  final double safetyStock;
  final String statusStok;

  StockHistory({
    required this.pfcoCode,
    required this.tahun,
    required this.bulan,
    required this.stokAwal,
    required this.stokMasuk,
    required this.penjualan,
    required this.stokAkhir,
    required this.safetyStock,
    required this.statusStok,
  });

  /// Parse dari satu baris CSV sesuai urutan kolom:
  /// PFco_Code, tahun, bulan, stok_awal, stok_masuk, penjualan,
  /// stok_akhir, safety_stock, status_stok
  factory StockHistory.fromCsvRow(List<dynamic> row) {
    final pfco = row[0].toString().trim();
    final rawAwal = double.tryParse(row[3].toString().trim()) ?? 0.0;
    final rawMasuk = double.tryParse(row[4].toString().trim()) ?? 0.0;
    final rawSales = double.tryParse(row[5].toString().trim()) ?? 0.0;
    final rawSafety = double.tryParse(row[7].toString().trim()) ?? 0.0;
    final status = row[8].toString().trim();
    
    // Tentukan segmen secara kasar berdasarkan safety stock untuk scaling
    final segment = rawSafety > 1000 ? 'fast moving' : rawSafety > 200 ? 'medium moving' : 'slow moving';
    
    final sales = MlScaler.scaleQuantity(pfco, rawSales, segment);
    final safety = MlScaler.scaleRecommendationField(pfco, rawSafety, 'safety', segment);
    final awal = MlScaler.scaleRecommendationField(pfco, rawAwal, 'stock', segment);
    final masuk = MlScaler.scaleRecommendationField(pfco, rawMasuk, 'stock', segment);
    
    double akhir = awal + masuk - sales;
    if (akhir < 0) {
      akhir = 0.0;
    }
    akhir = akhir.roundToDouble();

    return StockHistory(
      pfcoCode: pfco,
      tahun: int.tryParse(row[1].toString().trim()) ?? 0,
      bulan: int.tryParse(row[2].toString().trim()) ?? 0,
      stokAwal: awal,
      stokMasuk: masuk,
      penjualan: sales,
      stokAkhir: akhir,
      safetyStock: safety,
      statusStok: status,
    );
  }

  /// Label periode yang ramah pengguna (contoh: "Jan 2024")
  String get periodLabel {
    const monthNames = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    final name = bulan >= 1 && bulan <= 12 ? monthNames[bulan] : '?';
    return '$name $tahun';
  }

  /// Label status yang ramah pengguna
  String get statusLabel {
    switch (statusStok) {
      case 'stockout':
        return 'Stockout';
      case 'understock':
        return 'Understock';
      case 'overstock':
        return 'Overstock';
      default:
        return 'Normal';
    }
  }

  /// Apakah stok dalam kondisi bermasalah
  bool get isProblematic =>
      statusStok == 'stockout' || statusStok == 'understock';
}
