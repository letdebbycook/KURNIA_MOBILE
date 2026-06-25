import '../services/ml_scaler.dart';

/// Model class untuk rekomendasi operasional berdasarkan
/// integrasi K-Means Clustering dan Random Forest.
///
/// Setiap baris dalam CSV `rekomendasi_operasional.csv` di-mapping
/// menjadi satu instance [RekomendasiOperasional].
///
/// Sesuai Tujuan 3: menyusun rekomendasi operasional bagi pengelola
/// toko/ritel tekstil untuk meminimalkan overstock dan understock.
class RekomendasiOperasional {
  final String pfcoCode;
  final String segment;
  final String riskCategory;
  final String priority;
  final String action;
  final double currentStockKg;
  final double predictedNeedKg;
  final double safetyStockKg;
  final double restockQtyKg;
  final double turnoverRatio;
  final double stockoutPct;
  final double overstockPct;
  final String suggestion;

  RekomendasiOperasional({
    required this.pfcoCode,
    required this.segment,
    required this.riskCategory,
    required this.priority,
    required this.action,
    required this.currentStockKg,
    required this.predictedNeedKg,
    required this.safetyStockKg,
    required this.restockQtyKg,
    required this.turnoverRatio,
    required this.stockoutPct,
    required this.overstockPct,
    required this.suggestion,
  });

  /// Parse dari satu baris CSV sesuai urutan kolom:
  /// PFco_Code, segment, risk_category, priority, action,
  /// current_stock_kg, predicted_need_kg, safety_stock_kg,
  /// restock_qty_kg, turnover_ratio, stockout_pct, overstock_pct, suggestion
  factory RekomendasiOperasional.fromCsvRow(List<dynamic> row) {
    final pfco = row[0].toString().trim();
    final seg = row[1].toString().trim();
    final risk = row[2].toString().trim();
    final rawCurrent = double.tryParse(row[5].toString().trim()) ?? 0.0;
    final rawNeed = double.tryParse(row[6].toString().trim()) ?? 0.0;
    final rawSafety = double.tryParse(row[7].toString().trim()) ?? 0.0;
    final rawRestock = double.tryParse(row[8].toString().trim()) ?? 0.0;

    final current = MlScaler.scaleRecommendationField(pfco, rawCurrent, 'stock', seg);
    final need = MlScaler.scaleRecommendationField(pfco, rawNeed, 'stock', seg);
    final safety = MlScaler.scaleRecommendationField(pfco, rawSafety, 'safety', seg);
    
    double restock = 0.0;
    if (current < need + safety) {
      restock = (need + safety - current).roundToDouble();
      if (restock > 0) {
        restock = restock.clamp(20.0, 125.0);
      }
    }

    String dynamicSeg;
    if (need >= 70.0) {
      dynamicSeg = 'fast moving';
    } else if (need >= 45.0) {
      dynamicSeg = 'medium moving';
    } else {
      dynamicSeg = 'slow moving';
    }
    
    String finalSuggestion = '';
    switch (risk) {
      case 'understock':
        finalSuggestion = 'Stok kurang (${current.toInt()} unit vs kebutuhan ${need.toInt()} unit). Segera restock minimal ${restock.toInt()} unit + safety stock ${safety.toInt()} unit.';
        break;
      case 'overstock':
        finalSuggestion = 'Stok berlebih (${current.toInt()} unit vs kebutuhan ${need.toInt()} unit). Kurangi pembelian dan pertimbangkan promosi/bundling untuk menghabiskan stok.';
        break;
      case 'perlu_perhatian':
        finalSuggestion = 'Stok mendekati batas minimum. Siapkan order pembelian ${(need + safety - current).clamp(20.0, 125.0).toInt()} unit untuk periode berikutnya.';
        break;
      default:
        finalSuggestion = 'Stok dalam kondisi optimal (${current.toInt()} unit). Pertahankan pola restocking saat ini.';
    }

    return RekomendasiOperasional(
      pfcoCode: pfco,
      segment: dynamicSeg,
      riskCategory: risk,
      priority: row[3].toString().trim(),
      action: row[4].toString().trim(),
      currentStockKg: current,
      predictedNeedKg: need,
      safetyStockKg: safety,
      restockQtyKg: restock,
      turnoverRatio: double.tryParse(row[9].toString().trim()) ?? 0.0,
      stockoutPct: double.tryParse(row[10].toString().trim()) ?? 0.0,
      overstockPct: double.tryParse(row[11].toString().trim()) ?? 0.0,
      suggestion: finalSuggestion,
    );
  }

  /// Label segmen yang ramah pengguna
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

  /// Label risiko yang ramah pengguna
  String get riskLabel {
    switch (riskCategory) {
      case 'overstock':
        return 'Overstock';
      case 'understock':
        return 'Understock';
      case 'perlu_perhatian':
        return 'Perlu Perhatian';
      default:
        return 'Optimal';
    }
  }

  /// Selisih stok vs kebutuhan (positif = kelebihan, negatif = kekurangan)
  double get stockDifference => currentStockKg - predictedNeedKg;

  /// Apakah kondisi stok memerlukan tindakan segera
  bool get needsAction =>
      riskCategory == 'understock' || riskCategory == 'overstock';
}
