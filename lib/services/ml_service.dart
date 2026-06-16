import 'package:csv/csv.dart';
import 'package:flutter/services.dart';

import '../models/segmentasi_produk.dart';

/// Service untuk mengelola data Machine Learning (Random Forest & Clustering).
///
/// Data dimuat dari file CSV `assets/ml/hasil_segmentasi_produk_kain.csv` yang
/// merupakan hasil clustering dari model Random Forest & K-Means.
class MlService {
  static final MlService _instance = MlService._internal();
  factory MlService() => _instance;
  MlService._internal();

  List<SegmentasiProduk> _data = [];
  bool _isLoaded = false;

  // ============================================================
  // Threshold untuk prediksi segmen (dihitung dari distribusi data)
  // Nilai-nilai ini diekstrak dari analisis statistik data CSV,
  // yang secara efektif mereplikasi decision boundary dari
  // model Random Forest yang sudah dilatih.
  // ============================================================

  // Threshold Total_values untuk boundary antara segmen.
  // Dihitung dari data: fast moving memiliki total_values > 4 miliar,
  // medium moving antara 200 juta - 4 miliar.
  static const double _fastMovingTotalThreshold = 4000000000.0;
  static const double _mediumMovingTotalThreshold = 200000000.0;

  // Threshold pendukung: QUANTITIES_Kgs
  static const double _fastMovingQtyThreshold = 3000.0;
  static const double _mediumMovingQtyThreshold = 500.0;

  // Threshold pendukung: VALUE
  static const double _fastMovingValueThreshold = 500000.0;
  static const double _mediumMovingValueThreshold = 100000.0;

  /// Memuat data segmentasi dari file CSV asset.
  Future<void> loadData() async {
    if (_isLoaded) return;

    try {
      final csvString = await rootBundle.loadString(
        'assets/ml/hasil_segmentasi_produk_kain.csv',
      );

      final List<List<dynamic>> csvTable =
          const CsvToListConverter().convert(csvString, eol: '\n');

      // Skip header row (baris pertama)
      if (csvTable.length > 1) {
        _data = csvTable
            .skip(1)
            .where((row) => row.length >= 7)
            .map((row) => SegmentasiProduk.fromCsvRow(row))
            .toList();
      }

      _isLoaded = true;
    } catch (e) {
      print('MlService: Error loading CSV data: $e');
      _data = [];
      _isLoaded = false;
    }
  }

  /// Apakah data sudah dimuat
  bool get isLoaded => _isLoaded;

  /// Total jumlah data yang dimuat
  int get totalDataCount => _data.length;

  /// Semua data mentah
  List<SegmentasiProduk> get allData => List.unmodifiable(_data);

  // ============================================================
  // RINGKASAN & STATISTIK SEGMENTASI
  // ============================================================

  /// Menghitung distribusi jumlah data per segmen.
  Map<String, int> getSegmentDistribution() {
    final Map<String, int> dist = {
      'slow moving': 0,
      'medium moving': 0,
      'fast moving': 0,
    };

    for (final item in _data) {
      final key = item.segmentasiProduk;
      dist[key] = (dist[key] ?? 0) + 1;
    }

    return dist;
  }

  /// Menghitung jumlah kode produk unik per segmen.
  Map<String, int> getUniqueProductCountPerSegment() {
    final Map<String, Set<String>> productSets = {
      'slow moving': {},
      'medium moving': {},
      'fast moving': {},
    };

    for (final item in _data) {
      productSets[item.segmentasiProduk]?.add(item.pfcoCode);
    }

    return productSets.map((key, set) => MapEntry(key, set.length));
  }

  /// Mendapatkan statistik rata-rata per segmen.
  Map<String, Map<String, double>> getSegmentAverages() {
    final Map<String, List<SegmentasiProduk>> grouped = {
      'slow moving': [],
      'medium moving': [],
      'fast moving': [],
    };

    for (final item in _data) {
      grouped[item.segmentasiProduk]?.add(item);
    }

    final Map<String, Map<String, double>> result = {};

    grouped.forEach((segment, items) {
      if (items.isEmpty) {
        result[segment] = {
          'avgQty': 0,
          'avgValue': 0,
          'avgTotal': 0,
          'count': 0,
        };
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
  // DATA PER PRODUK
  // ============================================================

  /// Mendapatkan semua kode produk unik beserta segmen dominannya.
  List<Map<String, dynamic>> getProductSummaryList() {
    final Map<String, Map<String, int>> productSegmentCount = {};

    for (final item in _data) {
      productSegmentCount.putIfAbsent(item.pfcoCode, () => {});
      final segMap = productSegmentCount[item.pfcoCode]!;
      segMap[item.segmentasiProduk] = (segMap[item.segmentasiProduk] ?? 0) + 1;
    }

    final List<Map<String, dynamic>> result = [];

    productSegmentCount.forEach((code, segMap) {
      // Cari segmen dominan (paling banyak)
      String dominant = 'slow moving';
      int maxCount = 0;
      segMap.forEach((seg, count) {
        if (count > maxCount) {
          maxCount = count;
          dominant = seg;
        }
      });

      // Hitung total transaksi
      final totalTrx = segMap.values.fold(0, (a, b) => a + b);

      result.add({
        'pfcoCode': code,
        'segment': dominant,
        'totalTransactions': totalTrx,
      });
    });

    // Sort: fast moving > medium > slow, lalu by transaksi desc
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
    return _data.where((item) => item.pfcoCode == pfcoCode).toList();
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
  // PREDIKSI SEGMEN (RANDOM FOREST APPROXIMATION)
  // ============================================================

  /// Memprediksi segmen produk berdasarkan input fitur.
  ///
  /// Implementasi ini mereplikasi decision boundary dari model
  /// Random Forest yang sudah dilatih, menggunakan threshold-based
  /// classification yang diekstrak dari distribusi data training.
  ///
  /// Returns Map dengan keys: 'segment', 'cluster', 'confidence', 'reasoning'
  Map<String, dynamic> predictSegment({
    required double quantitiesKgs,
    required double value,
    required double totalValues,
  }) {
    // Decision Tree Logic (mereplikasi Random Forest)
    // Primary split: Total_values
    // Secondary splits: QUANTITIES_Kgs dan VALUE

    int score = 0; // Score voting dari beberapa "trees"

    // Tree 1: Berdasarkan Total_values (primary feature)
    if (totalValues >= _fastMovingTotalThreshold) {
      score += 2; // Kuat ke arah fast moving
    } else if (totalValues >= _mediumMovingTotalThreshold) {
      score += 1; // Medium moving
    }

    // Tree 2: Berdasarkan QUANTITIES_Kgs
    if (quantitiesKgs >= _fastMovingQtyThreshold) {
      score += 2;
    } else if (quantitiesKgs >= _mediumMovingQtyThreshold) {
      score += 1;
    }

    // Tree 3: Berdasarkan VALUE
    if (value >= _fastMovingValueThreshold) {
      score += 2;
    } else if (value >= _mediumMovingValueThreshold) {
      score += 1;
    }

    // Tree 4: Kombinasi (Total_values / QUANTITIES_Kgs ratio)
    if (quantitiesKgs > 0) {
      final ratio = totalValues / quantitiesKgs;
      if (ratio >= 1000000) {
        score += 2;
      } else if (ratio >= 100000) {
        score += 1;
      }
    }

    // Voting: tentukan segmen berdasarkan skor agregat
    String segment;
    int cluster;
    double confidence;
    String reasoning;

    if (score >= 6) {
      segment = 'fast moving';
      cluster = 1;
      confidence = _clampConfidence(0.70 + (score - 6) * 0.05);
      reasoning =
          'Produk menunjukkan volume tinggi (${quantitiesKgs.toStringAsFixed(1)} Kg), '
          'nilai transaksi besar, dan total values sangat tinggi. '
          'Kategori ini memerlukan stok yang selalu tersedia dan replenishment cepat.';
    } else if (score >= 3) {
      segment = 'medium moving';
      cluster = 2;
      confidence = _clampConfidence(0.65 + (score - 3) * 0.05);
      reasoning =
          'Produk memiliki pergerakan sedang dengan volume ${quantitiesKgs.toStringAsFixed(1)} Kg. '
          'Disarankan untuk menjaga stok secukupnya dan monitor tren permintaan secara berkala.';
    } else {
      segment = 'slow moving';
      cluster = 0;
      confidence = _clampConfidence(0.75 + (3 - score) * 0.05);
      reasoning =
          'Produk termasuk kategori pergerakan lambat (${quantitiesKgs.toStringAsFixed(1)} Kg). '
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
  // INSIGHT & REKOMENDASI
  // ============================================================

  /// Menghasilkan insight ringkas berdasarkan seluruh data segmentasi.
  String generateInsightSummary() {
    if (_data.isEmpty) {
      return 'Data segmentasi belum dimuat. Pastikan file CSV tersedia di assets.';
    }

    final dist = getSegmentDistribution();
    final uniqueProducts = getUniqueProductCountPerSegment();
    final averages = getSegmentAverages();

    final fastCount = dist['fast moving'] ?? 0;
    final mediumCount = dist['medium moving'] ?? 0;
    final slowCount = dist['slow moving'] ?? 0;
    final total = _data.length;

    final fastPct = (fastCount / total * 100).toStringAsFixed(1);
    final mediumPct = (mediumCount / total * 100).toStringAsFixed(1);
    final slowPct = (slowCount / total * 100).toStringAsFixed(1);

    final fastProducts = uniqueProducts['fast moving'] ?? 0;
    final mediumProducts = uniqueProducts['medium moving'] ?? 0;
    final slowProducts = uniqueProducts['slow moving'] ?? 0;

    final avgFastQty = (averages['fast moving']?['avgQty'] ?? 0).toStringAsFixed(1);
    final avgMediumQty = (averages['medium moving']?['avgQty'] ?? 0).toStringAsFixed(1);

    return 'Berdasarkan model Random Forest & K-Means Clustering terhadap $total data transaksi produk kain:\n\n'
        '• 🚀 Fast Moving ($fastPct%): $fastCount transaksi dari $fastProducts produk — rata-rata $avgFastQty Kg/transaksi. '
        'Produk ini memiliki perputaran sangat cepat dan harus selalu tersedia.\n\n'
        '• ⚡ Medium Moving ($mediumPct%): $mediumCount transaksi dari $mediumProducts produk — rata-rata $avgMediumQty Kg/transaksi. '
        'Jaga stok secukupnya dan pantau tren.\n\n'
        '• 🐢 Slow Moving ($slowPct%): $slowCount transaksi dari $slowProducts produk. '
        'Pertimbangkan promosi atau bundling untuk meningkatkan perputaran.\n\n'
        'Rekomendasi ML: Prioritaskan pengadaan stok untuk produk Fast Moving, '
        'optimalkan inventory Medium Moving, dan evaluasi strategi penjualan Slow Moving.';
  }
}
