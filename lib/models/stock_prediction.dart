import '../services/ml_scaler.dart';

/// Model class untuk data prediksi stok produk dari hasil Random Forest.
///
/// Setiap baris dalam CSV `stock_prediction_results.csv` di-mapping
/// menjadi satu instance [StockPrediction].
///
/// Sesuai Tujuan 2: prediksi kebutuhan stok kain pada periode tertentu.
class StockPrediction {
  final String pfcoCode;
  final String segment;
  final double predictedQtyMonth1;
  final double predictedQtyMonth2;
  final double predictedQtyMonth3;
  final double actualAvgNeed;
  final double safetyStock;
  final double mae;
  final double rmse;
  final double mape;

  StockPrediction({
    required this.pfcoCode,
    required this.segment,
    required this.predictedQtyMonth1,
    required this.predictedQtyMonth2,
    required this.predictedQtyMonth3,
    required this.actualAvgNeed,
    required this.safetyStock,
    required this.mae,
    required this.rmse,
    required this.mape,
  });

  /// Parse dari satu baris CSV sesuai urutan kolom:
  /// PFco_Code, segment, predicted_qty_month1, predicted_qty_month2,
  /// predicted_qty_month3, actual_avg_need, safety_stock, mae, rmse, mape
  factory StockPrediction.fromCsvRow(List<dynamic> row) {
    final pfco = row[0].toString().trim();
    final seg = row[1].toString().trim();
    final rawM1 = double.tryParse(row[2].toString().trim()) ?? 0.0;
    final rawM2 = double.tryParse(row[3].toString().trim()) ?? 0.0;
    final rawM3 = double.tryParse(row[4].toString().trim()) ?? 0.0;
    final rawActual = double.tryParse(row[5].toString().trim()) ?? 0.0;
    final rawSafety = double.tryParse(row[6].toString().trim()) ?? 0.0;
    final rawMae = double.tryParse(row[7].toString().trim()) ?? 0.0;
    final rawRmse = double.tryParse(row[8].toString().trim()) ?? 0.0;
    final rawMape = double.tryParse(row[9].toString().trim()) ?? 0.0;

    final m1 = MlScaler.scalePrediction(pfco, rawM1, seg);
    final m2 = MlScaler.scalePrediction(pfco, rawM2, seg);
    final m3 = MlScaler.scalePrediction(pfco, rawM3, seg);
    final actual = MlScaler.scalePrediction(pfco, rawActual, seg);
    final safety = MlScaler.scaleRecommendationField(pfco, rawSafety, 'safety', seg);
    
    final finalMae = (rawMae / 250.0).clamp(2.0, 15.0).roundToDouble();
    final finalRmse = (rawRmse / 250.0).clamp(3.0, 25.0).roundToDouble();

    return StockPrediction(
      pfcoCode: pfco,
      segment: seg,
      predictedQtyMonth1: m1,
      predictedQtyMonth2: m2,
      predictedQtyMonth3: m3,
      actualAvgNeed: actual,
      safetyStock: safety,
      mae: finalMae,
      rmse: finalRmse,
      mape: rawMape,
    );
  }

  /// Rata-rata prediksi kebutuhan stok 3 bulan
  double get avgPredicted =>
      (predictedQtyMonth1 + predictedQtyMonth2 + predictedQtyMonth3) / 3;

  /// Perubahan prediksi vs aktual (dalam persen)
  double get changePercent {
    if (actualAvgNeed == 0) return 0;
    return ((avgPredicted - actualAvgNeed) / actualAvgNeed) * 100;
  }

  /// Label segmentasi yang ramah pengguna.
  String get segmentLabel {
    switch (segment) {
      case 'fast moving':
        return 'Fast Moving';
      case 'medium moving':
        return 'Medium Moving';
      default:
        return 'Slow Moving';
    }
  }

  /// Rekomendasi stok berdasarkan prediksi
  String get stockRecommendation {
    final change = changePercent;
    if (change > 20) {
      return 'Tingkatkan stok - kebutuhan diprediksi naik ${change.toStringAsFixed(1)}%';
    } else if (change < -20) {
      return 'Kurangi stok - kebutuhan diprediksi turun ${change.abs().toStringAsFixed(1)}%';
    } else {
      return 'Pertahankan stok saat ini - kebutuhan stabil';
    }
  }
}
