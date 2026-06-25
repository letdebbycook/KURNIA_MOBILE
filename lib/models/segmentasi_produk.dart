import '../services/ml_scaler.dart';

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
    final pfco = row[3].toString().trim();
    final seg = row[6].toString().trim();
    final rawQty = double.tryParse(row[1].toString().trim()) ?? 0.0;
    
    final scaledQty = MlScaler.scaleQuantity(pfco, rawQty, seg);
    final finalPrice = MlScaler.getFabricPrice(pfco);
    final scaledTotal = scaledQty * finalPrice;

    String dynamicSeg;
    int dynamicCluster;
    if (scaledQty >= 70.0) {
      dynamicSeg = 'fast moving';
      dynamicCluster = 1;
    } else if (scaledQty >= 45.0) {
      dynamicSeg = 'medium moving';
      dynamicCluster = 2;
    } else {
      dynamicSeg = 'slow moving';
      dynamicCluster = 0;
    }

    return SegmentasiProduk(
      date: row[0].toString().trim(),
      quantitiesKgs: scaledQty,
      value: finalPrice,
      pfcoCode: pfco,
      totalValues: scaledTotal,
      cluster: dynamicCluster,
      segmentasiProduk: dynamicSeg,
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
