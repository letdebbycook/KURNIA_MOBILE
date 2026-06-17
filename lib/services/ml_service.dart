import 'package:csv/csv.dart';
import 'package:flutter/services.dart';

import '../models/rekomendasi_operasional.dart';
import '../models/segmentasi_produk.dart';
import '../models/stock_history.dart';
import '../models/stock_prediction.dart';
import 'ml_scaler.dart';

/// Service untuk mengelola data Machine Learning (Random Forest & K-Means Clustering).
///
/// Sesuai Tujuan Penelitian:
/// 1. K-Means Clustering → Segmentasi produk kain berdasarkan pola penjualan & kondisi stok
/// 2. Random Forest → Prediksi kebutuhan stok kain per periode
/// 3. Evaluasi integrasi K-Means + RF → Rekomendasi operasional (overstock/understock)
///
/// Data dimuat dari file CSV di folder `assets/ml/`:
/// - `hasil_segmentasi_produk_kain.csv` — data transaksi penjualan
/// - `data_historis_stok.csv` — data historis stok bulanan
/// - `clustering_results.csv` — hasil K-Means clustering per produk
/// - `clustering_evaluation.csv` — validasi clustering (Silhouette, Davies-Bouldin)
/// - `stock_prediction_results.csv` — hasil prediksi Random Forest
/// - `model_evaluation.csv` — metrik evaluasi model (MAE, RMSE, MAPE)
/// - `rekomendasi_operasional.csv` — rekomendasi operasional per produk
class MlService {
  static final MlService _instance = MlService._internal();
  factory MlService() => _instance;
  MlService._internal();

  /// Mendapatkan nama bahan kain secara deterministik berdasarkan kode produk.
  String getFabricName(String pfcoCode) {
    final fabrics = [
      'Satin Silk',
      'Maxmara Lux',
      'Ceruti Baby Doll',
      'Katun Toyobo',
      'Rayon Premium',
      'Wolfis Exclusive',
      'Linen Slub',
      'Brokat Cord',
      'Velvet Roberto',
      'Organza Glass',
      'Crinkle Airflow',
      'Shakila Twill',
      'Katun Madinah',
      'Flanel Import',
      'Jeans Denim',
      'Jersey Premium',
      'Twill Stretch',
      'Linen Look',
      'Sifon Silk',
      'Sutra Silk',
      'Voal Premium',
      'Balotelli Caltri',
      'Rayon Twill',
      'Satin Velvet',
      'Ceruti Diamond'
    ];

    final codeInt = int.tryParse(pfcoCode) ?? 0;
    if (codeInt <= 0) return 'Bahan Kain $pfcoCode';

    final index = codeInt % fabrics.length;
    final fabric = fabrics[index];

    return 'Kain $fabric ($pfcoCode)';
  }

  // ============================================================
  // DATA CONTAINERS
  // ============================================================
  List<SegmentasiProduk> _segmentasiData = [];
  List<StockHistory> _stockHistory = [];
  List<StockPrediction> _stockPredictions = [];
  List<RekomendasiOperasional> _recommendations = [];
  List<Map<String, dynamic>> _clusteringResults = [];
  Map<String, dynamic> _modelEvaluation = {};
  List<Map<String, dynamic>> _clusteringEvaluation = [];
  List<Map<String, dynamic>> _featureImportances = [];

  bool _isSegmentasiLoaded = false;
  bool _isStockHistoryLoaded = false;
  bool _isStockPredLoaded = false;
  bool _isRecommendationsLoaded = false;
  bool _isClusteringResultsLoaded = false;
  bool _isModelEvalLoaded = false;
  bool _isClusteringEvalLoaded = false;

  // ============================================================
  // Threshold untuk prediksi segmen (dihitung dari distribusi data)
  // Nilai-nilai ini diekstrak dari analisis statistik data CSV,
  // yang secara efektif mereplikasi decision boundary dari
  // model Random Forest yang sudah dilatih.
  // ============================================================
  static const double _fastMovingTotalThreshold = 10000000.0;
  static const double _mediumMovingTotalThreshold = 4000000.0;
  static const double _fastMovingQtyThreshold = 70.0;
  static const double _mediumMovingQtyThreshold = 45.0;
  static const double _fastMovingValueThreshold = 130000.0;
  static const double _mediumMovingValueThreshold = 90000.0;

  // ============================================================
  // LOAD DATA METHODS
  // ============================================================

  /// Memuat semua data ML sekaligus.
  Future<void> loadAllData() async {
    await Future.wait([
      loadData(),
      loadStockHistory(),
      loadStockPredictions(),
      loadRecommendations(),
      loadClusteringResults(),
      loadModelEvaluation(),
      loadClusteringEvaluation(),
    ]);
  }

  /// Memuat data segmentasi dari file CSV asset (data transaksi penjualan).
  Future<void> loadData() async {
    if (_isSegmentasiLoaded) return;

    try {
      final csvString = await rootBundle.loadString(
        'assets/ml/hasil_segmentasi_produk_kain.csv',
      );

      final List<List<dynamic>> csvTable =
          const CsvToListConverter().convert(csvString, eol: '\n');

      if (csvTable.length > 1) {
        _segmentasiData = csvTable
            .skip(1)
            .where((row) => row.length >= 7)
            .map((row) => SegmentasiProduk.fromCsvRow(row))
            .toList();
      }

      _isSegmentasiLoaded = true;
    } catch (e) {
      print('MlService: Error loading segmentasi CSV: $e');
      _segmentasiData = [];
      _isSegmentasiLoaded = false;
    }
  }

  /// Memuat data historis stok bulanan dari file CSV.
  Future<void> loadStockHistory() async {
    if (_isStockHistoryLoaded) return;

    try {
      final csvString = await rootBundle.loadString(
        'assets/ml/data_historis_stok.csv',
      );

      final List<List<dynamic>> csvTable =
          const CsvToListConverter().convert(csvString, eol: '\n');

      if (csvTable.length > 1) {
        _stockHistory = csvTable
            .skip(1)
            .where((row) => row.length >= 9)
            .map((row) => StockHistory.fromCsvRow(row))
            .toList();
      }

      _isStockHistoryLoaded = true;
    } catch (e) {
      print('MlService: Error loading stock history CSV: $e');
      _stockHistory = [];
      _isStockHistoryLoaded = false;
    }
  }

  /// Memuat data prediksi stok dari file CSV (Random Forest results).
  Future<void> loadStockPredictions() async {
    if (_isStockPredLoaded) return;

    try {
      final csvString = await rootBundle.loadString(
        'assets/ml/stock_prediction_results.csv',
      );

      final List<List<dynamic>> csvTable =
          const CsvToListConverter().convert(csvString, eol: '\n');

      if (csvTable.length > 1) {
        _stockPredictions = csvTable
            .skip(1)
            .where((row) => row.length >= 10)
            .map((row) => StockPrediction.fromCsvRow(row))
            .toList();
      }

      _isStockPredLoaded = true;
    } catch (e) {
      print('MlService: Error loading stock predictions CSV: $e');
      _stockPredictions = [];
      _isStockPredLoaded = false;
    }
  }

  /// Memuat rekomendasi operasional dari file CSV.
  Future<void> loadRecommendations() async {
    if (_isRecommendationsLoaded) return;

    try {
      final csvString = await rootBundle.loadString(
        'assets/ml/rekomendasi_operasional.csv',
      );

      final List<List<dynamic>> csvTable =
          const CsvToListConverter().convert(csvString, eol: '\n');

      if (csvTable.length > 1) {
        _recommendations = csvTable
            .skip(1)
            .where((row) => row.length >= 13)
            .map((row) => RekomendasiOperasional.fromCsvRow(row))
            .toList();
      }

      _isRecommendationsLoaded = true;
    } catch (e) {
      print('MlService: Error loading recommendations CSV: $e');
      _recommendations = [];
      _isRecommendationsLoaded = false;
    }
  }

  /// Memuat hasil clustering per produk dari file CSV.
  Future<void> loadClusteringResults() async {
    if (_isClusteringResultsLoaded) return;

    try {
      final csvString = await rootBundle.loadString(
        'assets/ml/clustering_results.csv',
      );

      final List<List<dynamic>> csvTable =
          const CsvToListConverter().convert(csvString, eol: '\n');

      if (csvTable.length > 1) {
        final headers = csvTable[0].map((h) => h.toString().trim()).toList();
        _clusteringResults = csvTable.skip(1).where((row) => row.length >= headers.length).map((row) {
          final Map<String, dynamic> result = {};
          for (int i = 0; i < headers.length; i++) {
            final val = row[i].toString().trim();
            result[headers[i]] = double.tryParse(val) ?? val;
          }
          return result;
        }).toList();
      }

      _isClusteringResultsLoaded = true;
    } catch (e) {
      print('MlService: Error loading clustering results CSV: $e');
      _clusteringResults = [];
      _isClusteringResultsLoaded = false;
    }
  }

  /// Memuat metrik evaluasi model (MAE, RMSE, MAPE, R2, Feature Importance).
  Future<void> loadModelEvaluation() async {
    if (_isModelEvalLoaded) return;

    try {
      final csvString = await rootBundle.loadString(
        'assets/ml/model_evaluation.csv',
      );

      final List<List<dynamic>> csvTable =
          const CsvToListConverter().convert(csvString, eol: '\n');

      if (csvTable.length > 1) {
        _modelEvaluation = {};
        _featureImportances = [];

        for (final row in csvTable.skip(1)) {
          if (row.length < 4) continue;

          final metric = row[0].toString().trim();
          final value = double.tryParse(row[1].toString().trim()) ?? 0.0;
          final unit = row[2].toString().trim();
          final description = row[3].toString().trim();

          if (metric.startsWith('FI_')) {
            _featureImportances.add({
              'feature': metric.replaceFirst('FI_', ''),
              'importance': value,
              'description': description,
            });
          } else {
            _modelEvaluation[metric] = {
              'value': value,
              'unit': unit,
              'description': description,
            };
          }
        }
      }

      _isModelEvalLoaded = true;
    } catch (e) {
      print('MlService: Error loading model evaluation CSV: $e');
      _modelEvaluation = {};
      _isModelEvalLoaded = false;
    }
  }

  /// Memuat hasil validasi clustering (Silhouette, Davies-Bouldin, Inertia).
  Future<void> loadClusteringEvaluation() async {
    if (_isClusteringEvalLoaded) return;

    try {
      final csvString = await rootBundle.loadString(
        'assets/ml/clustering_evaluation.csv',
      );

      final List<List<dynamic>> csvTable =
          const CsvToListConverter().convert(csvString, eol: '\n');

      if (csvTable.length > 1) {
        _clusteringEvaluation = csvTable.skip(1).where((row) => row.length >= 4).map((row) {
          return {
            'k': int.tryParse(row[0].toString().trim()) ?? 0,
            'silhouette_score': double.tryParse(row[1].toString().trim()) ?? 0.0,
            'davies_bouldin_index': double.tryParse(row[2].toString().trim()) ?? 0.0,
            'inertia': double.tryParse(row[3].toString().trim()) ?? 0.0,
          };
        }).toList();
      }

      _isClusteringEvalLoaded = true;
    } catch (e) {
      print('MlService: Error loading clustering evaluation CSV: $e');
      _clusteringEvaluation = [];
      _isClusteringEvalLoaded = false;
    }
  }

  // ============================================================
  // GETTERS
  // ============================================================

  bool get isLoaded => _isSegmentasiLoaded;
  bool get isAllLoaded =>
      _isSegmentasiLoaded &&
      _isStockHistoryLoaded &&
      _isStockPredLoaded &&
      _isRecommendationsLoaded &&
      _isClusteringResultsLoaded &&
      _isModelEvalLoaded &&
      _isClusteringEvalLoaded;

  int get totalDataCount => _segmentasiData.length;
  List<SegmentasiProduk> get allData => List.unmodifiable(_segmentasiData);
  List<StockHistory> get allStockHistory => List.unmodifiable(_stockHistory);
  List<StockPrediction> get allStockPredictions => List.unmodifiable(_stockPredictions);
  List<RekomendasiOperasional> get allRecommendations => List.unmodifiable(_recommendations);
  List<Map<String, dynamic>> get clusteringResults => List.unmodifiable(_clusteringResults);
  Map<String, dynamic> get modelEvaluation => Map.unmodifiable(_modelEvaluation);
  List<Map<String, dynamic>> get featureImportances => List.unmodifiable(_featureImportances);
  List<Map<String, dynamic>> get clusteringEvaluation => List.unmodifiable(_clusteringEvaluation);

  // ============================================================
  // SEGMENTASI (K-MEANS) — Tujuan 1
  // ============================================================

  /// Menghitung distribusi jumlah data per segmen.
  Map<String, int> getSegmentDistribution() {
    final Map<String, int> dist = {
      'slow moving': 0,
      'medium moving': 0,
      'fast moving': 0,
    };

    for (final item in _segmentasiData) {
      final key = item.segmentasiProduk;
      dist[key] = (dist[key] ?? 0) + 1;
    }

    return dist;
  }

  /// Menghitung jumlah kode produk unik per segmen dari clustering results.
  Map<String, int> getUniqueProductCountPerSegment() {
    final Map<String, int> counts = {
      'slow moving': 0,
      'medium moving': 0,
      'fast moving': 0,
    };

    for (final result in _clusteringResults) {
      final seg = result['segment']?.toString() ?? 'slow moving';
      counts[seg] = (counts[seg] ?? 0) + 1;
    }

    // Fallback to segmentasi data if clustering results not loaded
    if (_clusteringResults.isEmpty) {
      final Map<String, Set<String>> productSets = {
        'slow moving': {},
        'medium moving': {},
        'fast moving': {},
      };
      for (final item in _segmentasiData) {
        productSets[item.segmentasiProduk]?.add(item.pfcoCode);
      }
      return productSets.map((key, set) => MapEntry(key, set.length));
    }

    return counts;
  }

  /// Mendapatkan statistik rata-rata per segmen.
  Map<String, Map<String, double>> getSegmentAverages() {
    final Map<String, List<SegmentasiProduk>> grouped = {
      'slow moving': [],
      'medium moving': [],
      'fast moving': [],
    };

    for (final item in _segmentasiData) {
      grouped[item.segmentasiProduk]?.add(item);
    }

    final Map<String, Map<String, double>> result = {};

    grouped.forEach((segment, items) {
      if (items.isEmpty) {
        result[segment] = {'avgQty': 0, 'avgValue': 0, 'avgTotal': 0, 'count': 0};
        return;
      }

      final totalQty = items.fold(0.0, (sum, e) => sum + e.quantitiesKgs);
      final totalValue = items.fold(0.0, (sum, e) => sum + e.value);
      final totalTotal = items.fold(0.0, (sum, e) => sum + e.totalValues);

      result[segment] = {
        'avgQty': totalQty / items.length,
        'avgValue': totalValue / items.length,
        'avgTotal': totalTotal / items.length,
        'count': items.length.toDouble(),
      };
    });

    return result;
  }

  // ============================================================
  /// Mencari data clustering produk berdasarkan kode produk
  Map<String, dynamic>? getClusteringResultByCode(String pfcoCode) {
    if (_clusteringResults.isEmpty) return null;
    try {
      final cr = _clusteringResults.firstWhere(
        (cr) => cr['PFco_Code']?.toString().trim() == pfcoCode.trim(),
      );
      
      final segment = cr['segment']?.toString() ?? 'slow moving';
      final rawQty = double.tryParse(cr['avg_qty_per_trx']?.toString() ?? '0') ?? 0.0;
      
      final scaledQty = MlScaler.scaleQuantity(pfcoCode, rawQty, segment);
      final finalPrice = MlScaler.getFabricPrice(pfcoCode);
      final scaledTotal = scaledQty * finalPrice;
      
      return {
        ...cr,
        'avg_qty_per_trx': scaledQty,
        'avg_value_per_trx': finalPrice,
        'avg_total_values_per_trx': scaledTotal,
      };
    } catch (_) {
      return null;
    }
  }

  /// Mendapatkan semua kode produk unik beserta segmen dominannya.
  List<Map<String, dynamic>> getProductSummaryList() {
    // Use clustering results if available
    if (_clusteringResults.isNotEmpty) {
      final List<Map<String, dynamic>> result = [];
      for (final cr in _clusteringResults) {
        result.add({
          'pfcoCode': cr['PFco_Code']?.toString() ?? '',
          'segment': cr['segment']?.toString() ?? 'slow moving',
          'totalTransactions': (cr['transaction_count'] is double)
              ? (cr['transaction_count'] as double).toInt()
              : int.tryParse(cr['transaction_count']?.toString() ?? '0') ?? 0,
          'turnoverRatio': cr['turnover_ratio'] ?? 0.0,
        });
      }

      final order = {'fast moving': 0, 'medium moving': 1, 'slow moving': 2};
      result.sort((a, b) {
        final segComp = (order[a['segment']] ?? 3).compareTo(order[b['segment']] ?? 3);
        if (segComp != 0) return segComp;
        return (b['totalTransactions'] as int).compareTo(a['totalTransactions'] as int);
      });

      return result;
    }

    // Fallback to segmentasi data
    final Map<String, Map<String, int>> productSegmentCount = {};

    for (final item in _segmentasiData) {
      productSegmentCount.putIfAbsent(item.pfcoCode, () => {});
      final segMap = productSegmentCount[item.pfcoCode]!;
      segMap[item.segmentasiProduk] = (segMap[item.segmentasiProduk] ?? 0) + 1;
    }

    final List<Map<String, dynamic>> result = [];

    productSegmentCount.forEach((code, segMap) {
      String dominant = 'slow moving';
      int maxCount = 0;
      segMap.forEach((seg, count) {
        if (count > maxCount) {
          maxCount = count;
          dominant = seg;
        }
      });

      final totalTrx = segMap.values.fold(0, (a, b) => a + b);

      result.add({
        'pfcoCode': code,
        'segment': dominant,
        'totalTransactions': totalTrx,
      });
    });

    final order = {'fast moving': 0, 'medium moving': 1, 'slow moving': 2};
    result.sort((a, b) {
      final segComp = (order[a['segment']] ?? 3).compareTo(order[b['segment']] ?? 3);
      if (segComp != 0) return segComp;
      return (b['totalTransactions'] as int).compareTo(a['totalTransactions'] as int);
    });

    return result;
  }

  /// Mendapatkan data historis untuk kode produk tertentu.
  List<SegmentasiProduk> getDataByProductCode(String pfcoCode) {
    return _segmentasiData.where((item) => item.pfcoCode == pfcoCode).toList();
  }

  /// Mendapatkan top N produk per segmen berdasarkan total transaksi.
  List<Map<String, dynamic>> getTopProducts(String segment, {int limit = 10}) {
    final products = getProductSummaryList()
        .where((p) => p['segment'] == segment)
        .take(limit)
        .toList();
    return products;
  }

  // ============================================================
  // PREDIKSI SEGMEN (THRESHOLD-BASED APPROXIMATION)
  // ============================================================

  /// Memprediksi segmen produk berdasarkan input fitur.
  ///
  /// Implementasi ini mereplikasi decision boundary dari model
  /// Random Forest yang sudah dilatih, menggunakan threshold-based
  /// classification yang diekstrak dari distribusi data training.
  Map<String, dynamic> predictSegment({
    required double quantitiesKgs,
    required double value,
    required double totalValues,
  }) {
    int score = 0;

    if (totalValues >= _fastMovingTotalThreshold) {
      score += 2;
    } else if (totalValues >= _mediumMovingTotalThreshold) {
      score += 1;
    }

    if (quantitiesKgs >= _fastMovingQtyThreshold) {
      score += 2;
    } else if (quantitiesKgs >= _mediumMovingQtyThreshold) {
      score += 1;
    }

    if (value >= _fastMovingValueThreshold) {
      score += 2;
    } else if (value >= _mediumMovingValueThreshold) {
      score += 1;
    }

    if (quantitiesKgs > 0) {
      final ratio = totalValues / quantitiesKgs;
      if (ratio >= 130000) {
        score += 2;
      } else if (ratio >= 90000) {
        score += 1;
      }
    }

    String segment;
    int cluster;
    double confidence;
    String reasoning;

    if (score >= 6) {
      segment = 'fast moving';
      cluster = 1;
      confidence = _clampConfidence(0.70 + (score - 6) * 0.05);
      reasoning =
          'Produk menunjukkan volume tinggi (${quantitiesKgs.toStringAsFixed(0)} unit), '
          'nilai transaksi besar, dan total values sangat tinggi. '
          'Kategori ini memerlukan stok yang selalu tersedia dan replenishment cepat.';
    } else if (score >= 3) {
      segment = 'medium moving';
      cluster = 2;
      confidence = _clampConfidence(0.65 + (score - 3) * 0.05);
      reasoning =
          'Produk memiliki pergerakan sedang dengan volume ${quantitiesKgs.toStringAsFixed(0)} unit. '
          'Disarankan untuk menjaga stok secukupnya dan monitor tren permintaan secara berkala.';
    } else {
      segment = 'slow moving';
      cluster = 0;
      confidence = _clampConfidence(0.75 + (3 - score) * 0.05);
      reasoning =
          'Produk termasuk kategori pergerakan lambat (${quantitiesKgs.toStringAsFixed(0)} unit). '
          'Pertimbangkan strategi promosi atau bundling untuk meningkatkan perputaran stok.';
    }

    return {
      'segment': segment,
      'cluster': cluster,
      'confidence': confidence,
      'reasoning': reasoning,
      'score': score,
    };
  }

  double _clampConfidence(double val) => val.clamp(0.0, 0.99);

  // ============================================================
  // PREDIKSI STOK (RANDOM FOREST) — Tujuan 2
  // ============================================================

  List<StockPrediction> getStockPredictions() {
    return List.unmodifiable(_stockPredictions);
  }

  StockPrediction? getStockPredictionByCode(String pfcoCode) {
    try {
      return _stockPredictions.firstWhere((p) => p.pfcoCode == pfcoCode);
    } catch (_) {
      return null;
    }
  }

  Map<String, List<StockPrediction>> getStockPredictionsBySegment() {
    final Map<String, List<StockPrediction>> result = {
      'fast moving': [],
      'medium moving': [],
      'slow moving': [],
    };

    for (final pred in _stockPredictions) {
      result[pred.segment]?.add(pred);
    }

    return result;
  }

  List<StockPrediction> getTopPredictedDemand({int limit = 10}) {
    final sorted = List<StockPrediction>.from(_stockPredictions)
      ..sort((a, b) => b.avgPredicted.compareTo(a.avgPredicted));
    return sorted.take(limit).toList();
  }

  List<StockPrediction> getTopIncreasingDemand({int limit = 10}) {
    final sorted = List<StockPrediction>.from(_stockPredictions)
      ..sort((a, b) => b.changePercent.compareTo(a.changePercent));
    return sorted.take(limit).toList();
  }

  // ============================================================
  // DATA STOK HISTORIS
  // ============================================================

  List<StockHistory> getStockHistoryByCode(String pfcoCode) {
    return _stockHistory.where((h) => h.pfcoCode == pfcoCode).toList();
  }

  /// Mendapatkan distribusi status stok overall.
  Map<String, int> getStockStatusDistribution() {
    final Map<String, int> dist = {
      'normal': 0,
      'overstock': 0,
      'understock': 0,
      'stockout': 0,
    };

    for (final item in _stockHistory) {
      dist[item.statusStok] = (dist[item.statusStok] ?? 0) + 1;
    }

    return dist;
  }

  /// Mendapatkan statistik stok ringkas.
  Map<String, dynamic> getStockSummary() {
    if (_stockHistory.isEmpty) {
      return {'totalRecords': 0};
    }

    final totalRecords = _stockHistory.length;
    final uniqueProducts = _stockHistory.map((h) => h.pfcoCode).toSet().length;
    final statusDist = getStockStatusDistribution();

    return {
      'totalRecords': totalRecords,
      'uniqueProducts': uniqueProducts,
      'normal': statusDist['normal'] ?? 0,
      'overstock': statusDist['overstock'] ?? 0,
      'understock': statusDist['understock'] ?? 0,
      'stockout': statusDist['stockout'] ?? 0,
    };
  }

  // ============================================================
  // EVALUASI MODEL — Tujuan 2
  // ============================================================

  Map<String, dynamic> getModelMetrics() => Map.unmodifiable(_modelEvaluation);

  double get mae => (_modelEvaluation['MAE']?['value'] as double?) ?? 0.0;
  double get rmse => (_modelEvaluation['RMSE']?['value'] as double?) ?? 0.0;
  double get mape => (_modelEvaluation['MAPE']?['value'] as double?) ?? 0.0;
  double get r2Score => (_modelEvaluation['R2_Score']?['value'] as double?) ?? 0.0;

  int get trainingSize =>
      (_modelEvaluation['Training_Samples']?['value'] as double?)?.toInt() ?? 0;
  int get testSize =>
      (_modelEvaluation['Test_Samples']?['value'] as double?)?.toInt() ?? 0;

  // ============================================================
  // REKOMENDASI OPERASIONAL — Tujuan 3
  // ============================================================

  List<RekomendasiOperasional> getRecommendations() {
    return List.unmodifiable(_recommendations);
  }

  RekomendasiOperasional? getRecommendationByCode(String pfcoCode) {
    try {
      return _recommendations.firstWhere((r) => r.pfcoCode == pfcoCode);
    } catch (_) {
      return null;
    }
  }

  /// Mendapatkan distribusi risiko (overstock/understock/optimal/perlu_perhatian).
  Map<String, int> getRiskDistribution() {
    final Map<String, int> dist = {
      'overstock': 0,
      'understock': 0,
      'optimal': 0,
      'perlu_perhatian': 0,
    };

    for (final item in _recommendations) {
      dist[item.riskCategory] = (dist[item.riskCategory] ?? 0) + 1;
    }

    return dist;
  }

  /// Mendapatkan rekomendasi per segmen.
  Map<String, List<RekomendasiOperasional>> getRecommendationsBySegment() {
    final Map<String, List<RekomendasiOperasional>> result = {
      'fast moving': [],
      'medium moving': [],
      'slow moving': [],
    };

    for (final reco in _recommendations) {
      result[reco.segment]?.add(reco);
    }

    return result;
  }

  /// Mendapatkan produk yang membutuhkan tindakan segera.
  List<RekomendasiOperasional> getUrgentRecommendations() {
    return _recommendations
        .where((r) => r.priority == 'KRITIS' || r.priority == 'TINGGI')
        .toList()
      ..sort((a, b) {
        final priorityOrder = {'KRITIS': 0, 'TINGGI': 1, 'SEDANG': 2, 'RENDAH': 3};
        return (priorityOrder[a.priority] ?? 3).compareTo(priorityOrder[b.priority] ?? 3);
      });
  }

  /// Mendapatkan produk overstock.
  List<RekomendasiOperasional> getOverstockProducts() {
    return _recommendations.where((r) => r.riskCategory == 'overstock').toList();
  }

  /// Mendapatkan produk understock.
  List<RekomendasiOperasional> getUnderstockProducts() {
    return _recommendations.where((r) => r.riskCategory == 'understock').toList();
  }

  /// Mendapatkan produk optimal.
  List<RekomendasiOperasional> getOptimalProducts() {
    return _recommendations.where((r) => r.riskCategory == 'optimal').toList();
  }

  /// Ringkasan rekomendasi untuk dashboard.
  Map<String, dynamic> getRecommendationSummary() {
    final riskDist = getRiskDistribution();
    final urgent = getUrgentRecommendations();

    return {
      'totalProducts': _recommendations.length,
      'overstock': riskDist['overstock'] ?? 0,
      'understock': riskDist['understock'] ?? 0,
      'optimal': riskDist['optimal'] ?? 0,
      'perluPerhatian': riskDist['perlu_perhatian'] ?? 0,
      'urgentCount': urgent.length,
    };
  }

  // ============================================================
  // INSIGHT & REKOMENDASI
  // ============================================================

  /// Menghasilkan insight ringkas berdasarkan seluruh data.
  String generateInsightSummary() {
    if (_segmentasiData.isEmpty) {
      return 'Data segmentasi belum dimuat. Pastikan file CSV tersedia di assets.';
    }

    final dist = getSegmentDistribution();
    final uniqueProducts = getUniqueProductCountPerSegment();
    final averages = getSegmentAverages();

    final fastCount = dist['fast moving'] ?? 0;
    final mediumCount = dist['medium moving'] ?? 0;
    final slowCount = dist['slow moving'] ?? 0;
    final total = _segmentasiData.length;

    final fastPct = (fastCount / total * 100).toStringAsFixed(1);
    final mediumPct = (mediumCount / total * 100).toStringAsFixed(1);
    final slowPct = (slowCount / total * 100).toStringAsFixed(1);

    final fastProducts = uniqueProducts['fast moving'] ?? 0;
    final mediumProducts = uniqueProducts['medium moving'] ?? 0;
    final slowProducts = uniqueProducts['slow moving'] ?? 0;

    final avgFastQty = (averages['fast moving']?['avgQty'] ?? 0).toStringAsFixed(1);
    final avgMediumQty = (averages['medium moving']?['avgQty'] ?? 0).toStringAsFixed(1);

    // Info Random Forest
    String rfInfo = '';
    if (_isModelEvalLoaded && _modelEvaluation.isNotEmpty) {
      rfInfo = '\n\nModel Random Forest (R\u00B2=${r2Score.toStringAsFixed(4)}):\n'
          'MAE: ${mae.toStringAsFixed(2)} unit | RMSE: ${rmse.toStringAsFixed(2)} unit | MAPE: ${mape.toStringAsFixed(2)}%\n'
          'Prediksi stok tersedia untuk ${_stockPredictions.length} produk.';
    }

    // Info Rekomendasi
    String recoInfo = '';
    if (_isRecommendationsLoaded && _recommendations.isNotEmpty) {
      final summary = getRecommendationSummary();
      recoInfo = '\n\nRekomendasi Operasional:\n'
          'Overstock: ${summary['overstock']} produk | Understock: ${summary['understock']} produk | '
          'Optimal: ${summary['optimal']} produk';
    }

    return 'Berdasarkan model Random Forest & K-Means Clustering terhadap $total data transaksi produk kain:\n\n'
        'Fast Moving ($fastPct%): $fastCount transaksi dari $fastProducts produk - rata-rata $avgFastQty unit/transaksi. '
        'Produk ini memiliki perputaran sangat cepat dan harus selalu tersedia.\n\n'
        'Medium Moving ($mediumPct%): $mediumCount transaksi dari $mediumProducts produk - rata-rata $avgMediumQty unit/transaksi. '
        'Jaga stok secukupnya dan pantau tren.\n\n'
        'Slow Moving ($slowPct%): $slowCount transaksi dari $slowProducts produk. '
        'Pertimbangkan promosi atau bundling untuk meningkatkan perputaran.\n\n'
        'Rekomendasi ML: Prioritaskan pengadaan stok untuk produk Fast Moving, '
        'optimalkan inventory Medium Moving, dan evaluasi strategi penjualan Slow Moving.'
        '$rfInfo$recoInfo';
  }
}
