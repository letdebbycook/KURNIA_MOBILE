import 'package:flutter/material.dart';
import '../../models/stock_prediction.dart';
import '../../models/rekomendasi_operasional.dart';
import '../../services/ml_service.dart';
import '../../services/ml_scaler.dart';

/// Halaman analisis Machine Learning (Random Forest & K-Means Clustering)
/// untuk Admin — sesuai 3 Tujuan Penelitian Proposal Capstone:
///
/// Tujuan 1: K-Means Clustering → Tab Segmentasi
/// Tujuan 2: Random Forest → Tab Prediksi Stok + Tab Evaluasi Model
/// Tujuan 3: Integrasi K-Means + RF → Tab Rekomendasi Operasional
///
/// Tambahan: Tab Data Stok (historis) + Tab Detail Produk
class MlInsightsView extends StatefulWidget {
  const MlInsightsView({super.key});

  @override
  State<MlInsightsView> createState() => _MlInsightsViewState();
}

class _MlInsightsViewState extends State<MlInsightsView>
    with SingleTickerProviderStateMixin {
  final MlService _mlService = MlService();
  bool _isLoading = true;
  bool _hasError = false;

  // Distribusi segmen
  Map<String, int> _distribution = {};
  Map<String, int> _uniqueProducts = {};
  Map<String, Map<String, double>> _averages = {};

  // Prediksi form
  final _formKey = GlobalKey<FormState>();
  final _qtyController = TextEditingController();
  final _valueController = TextEditingController();
  final _totalController = TextEditingController();
  Map<String, dynamic>? _predictionResult;

  // Tab controller — 6 tabs
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _qtyController.addListener(_autoCalculateTotal);
    _valueController.addListener(_autoCalculateTotal);
    _loadMlData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _qtyController.dispose();
    _valueController.dispose();
    _totalController.dispose();
    super.dispose();
  }

  Future<void> _loadMlData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      await _mlService.loadAllData();

      if (!mounted) return;

      setState(() {
        _distribution = _mlService.getSegmentDistribution();
        _uniqueProducts = _mlService.getUniqueProductCountPerSegment();
        _averages = _mlService.getSegmentAverages();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  void _runPrediction() {
    if (!_formKey.currentState!.validate()) return;

    final qty = double.tryParse(_qtyController.text) ?? 0;
    final value = double.tryParse(_valueController.text) ?? 0;
    final total = double.tryParse(_totalController.text) ?? 0;

    final result = _mlService.predictSegment(
      quantitiesKgs: qty,
      value: value,
      totalValues: total,
    );

    setState(() {
      _predictionResult = result;
    });
  }

  void _autoCalculateTotal() {
    final qty = double.tryParse(_qtyController.text);
    final val = double.tryParse(_valueController.text);
    if (qty != null && val != null) {
      final total = qty * val;
      final totalStr = total.toStringAsFixed(0);
      if (_totalController.text != totalStr) {
        _totalController.text = totalStr;
      }
    } else {
      if (_totalController.text.isNotEmpty) {
        _totalController.text = '';
      }
    }
  }

  String _formatNumber(double number) {
    if (number >= 1000000000) {
      return '${(number / 1000000000).toStringAsFixed(1)}B';
    } else if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toStringAsFixed(1);
  }

  String _formatCurrency(double amount) {
    final str = amount.toStringAsFixed(0);
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count == 3 && i != 0) {
        buffer.write('.');
        count = 0;
      }
    }
    return 'Rp ${buffer.toString().split('').reversed.join('')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Machine Learning Insights',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              'K-Means Clustering & Random Forest',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMlData,
            tooltip: 'Muat ulang data',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          tabs: const [
            Tab(icon: Icon(Icons.pie_chart_outline, size: 18), text: 'Segmentasi'),
            Tab(icon: Icon(Icons.trending_up, size: 18), text: 'Prediksi Stok'),
            Tab(icon: Icon(Icons.analytics_outlined, size: 18), text: 'Evaluasi Model'),
            Tab(icon: Icon(Icons.inventory_2_outlined, size: 18), text: 'Data Stok'),
            Tab(icon: Icon(Icons.recommend_outlined, size: 18), text: 'Rekomendasi'),
            Tab(icon: Icon(Icons.table_chart_outlined, size: 18), text: 'Detail Produk'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text('Gagal memuat data Machine Learning.'),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadMlData,
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSegmentationTab(theme),
                    _buildStockPredictionTab(theme),
                    _buildModelEvaluationTab(theme),
                    _buildStockDataTab(theme),
                    _buildRecommendationTab(theme),
                    _buildProductDetailTab(theme),
                  ],
                ),
    );
  }

  // =============================================================
  // TAB 1: SEGMENTASI (K-MEANS) — Tujuan 1
  // =============================================================

  Widget _buildSegmentationTab(ThemeData theme) {
    final total = _distribution.values.fold(0, (a, b) => a + b);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.psychology, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tujuan 1: Segmentasi K-Means Clustering',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Segmentasi $total data transaksi produk kain berdasarkan pola penjualan '
                  'dan kondisi stok menggunakan K-Means Clustering (k=3).',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildInfoBadge('K-MEANS ACTIVE'),
                    const SizedBox(width: 8),
                    _buildInfoBadge('k = 3 CLUSTERS'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Clustering Validation
          if (_mlService.clusteringEvaluation.isNotEmpty) ...[
            _buildSectionTitle(theme, 'Validasi Clustering (Silhouette & Davies-Bouldin)'),
            const SizedBox(height: 12),
            _buildClusteringValidationCard(theme),
            const SizedBox(height: 20),
          ],

          // 3 Segment Cards
          _buildSectionTitle(theme, 'Distribusi Segmentasi Produk'),
          const SizedBox(height: 12),
          _buildSegmentCard(theme, title: 'Fast Moving', subtitle: 'Produk perputaran cepat',
            count: _distribution['fast moving'] ?? 0, uniqueProducts: _uniqueProducts['fast moving'] ?? 0,
            total: total, color: Colors.green.shade600, icon: Icons.rocket_launch),
          const SizedBox(height: 10),
          _buildSegmentCard(theme, title: 'Medium Moving', subtitle: 'Produk perputaran sedang',
            count: _distribution['medium moving'] ?? 0, uniqueProducts: _uniqueProducts['medium moving'] ?? 0,
            total: total, color: Colors.orange.shade600, icon: Icons.speed),
          const SizedBox(height: 10),
          _buildSegmentCard(theme, title: 'Slow Moving', subtitle: 'Produk perputaran lambat',
            count: _distribution['slow moving'] ?? 0, uniqueProducts: _uniqueProducts['slow moving'] ?? 0,
            total: total, color: Colors.red.shade400, icon: Icons.hourglass_bottom),
          const SizedBox(height: 24),

          // Visual Bars
          _buildSectionTitle(theme, 'Visualisasi Distribusi Cluster'),
          const SizedBox(height: 12),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _buildClusterBars(theme, total),
            ),
          ),
          const SizedBox(height: 24),

          // Stats Table
          _buildSectionTitle(theme, 'Statistik Rata-rata per Segmen'),
          const SizedBox(height: 12),
          _buildAverageStatsTable(theme),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // =============================================================
  // TAB 2: PREDIKSI STOK (RANDOM FOREST) — Tujuan 2
  // =============================================================

  Widget _buildStockPredictionTab(ThemeData theme) {
    final predictions = _mlService.getStockPredictions();
    final topDemand = _mlService.getTopPredictedDemand(limit: 10);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade700, Colors.teal.shade500],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.trending_up, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tujuan 2: Prediksi Stok - Random Forest',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Prediksi kebutuhan stok untuk ${predictions.length} produk '
                  'menggunakan Random Forest Regressor (3 bulan ke depan).',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildInfoBadge('R\u00B2 = ${_mlService.r2Score.toStringAsFixed(4)}'),
                    const SizedBox(width: 8),
                    _buildInfoBadge('MAPE = ${_mlService.mape.toStringAsFixed(2)}%'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Prediksi Segmen Manual
          _buildPredictionForm(theme),
          const SizedBox(height: 20),

          // Top 10 Demand
          _buildSectionTitle(theme, 'Top 10 Kebutuhan Stok Tertinggi'),
          const SizedBox(height: 12),
          ...topDemand.map((pred) => _buildPredictionCard(theme, pred)),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPredictionForm(ThemeData theme) {
    final productSummaryList = _mlService.getProductSummaryList();

    return Card(
      elevation: 3,
      color: theme.colorScheme.secondary.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.secondary.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calculate, color: theme.colorScheme.secondary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Prediksi Segmen Produk (Otomatis & Manual)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
                    color: theme.colorScheme.secondary),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Cari produk untuk prediksi otomatis berdasarkan rata-rata transaksi, atau isi parameter manual di bawah.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            
            // Prediksi Otomatis (Autocomplete)
            Autocomplete<Map<String, dynamic>>(
              displayStringForOption: (option) =>
                  _mlService.getFabricName(option['pfcoCode']),
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<Map<String, dynamic>>.empty();
                }
                return productSummaryList.where((option) {
                  final code = option['pfcoCode'].toString().toLowerCase();
                  final fabric = _mlService.getFabricName(option['pfcoCode']).toLowerCase();
                  final query = textEditingValue.text.toLowerCase();
                  return code.contains(query) || fabric.contains(query);
                });
              },
              onSelected: (Map<String, dynamic> selection) {
                final pfcoCode = selection['pfcoCode'];
                final clusterRes = _mlService.getClusteringResultByCode(pfcoCode);
                if (clusterRes != null) {
                  final avgQty = double.tryParse(clusterRes['avg_qty_per_trx']?.toString() ?? '0') ?? 0.0;
                  final avgVal = double.tryParse(clusterRes['avg_value_per_trx']?.toString() ?? '0') ?? 0.0;
                  
                  setState(() {
                    _qtyController.text = avgQty.toStringAsFixed(0);
                    _valueController.text = avgVal.toStringAsFixed(0);
                    _totalController.text = (avgQty * avgVal).toStringAsFixed(0);
                  });
                  _runPrediction();
                }
              },
              fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                return TextField(
                  controller: textController,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: 'Cari Produk (Prediksi Otomatis)',
                    hintText: 'Masukkan nama kain atau kode produk...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: textController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              textController.clear();
                              setState(() {
                                _qtyController.clear();
                                _valueController.clear();
                                _totalController.clear();
                                _predictionResult = null;
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  style: const TextStyle(fontSize: 12),
                );
              },
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildInputField(_qtyController, 'Jumlah Barang (unit/ pcs)', Icons.inventory, onChanged: (_) => _autoCalculateTotal()),
                  const SizedBox(height: 8),
                  _buildInputField(_valueController, 'Value (Rp)', Icons.attach_money, onChanged: (_) => _autoCalculateTotal()),
                  const SizedBox(height: 8),
                  _buildInputField(_totalController, 'Total Values (Rp) - Otomatis Terisi', Icons.calculate),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _runPrediction,
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      label: const Text('Prediksi Segmen'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.secondary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_predictionResult != null) ...[
              const SizedBox(height: 16),
              _buildPredictionResult(theme),
            ],
          ],
        ),
      ),
    );
  }

  // =============================================================
  // TAB 3: EVALUASI MODEL — Tujuan 2
  // =============================================================

  Widget _buildModelEvaluationTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo.shade700, Colors.indigo.shade500],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.analytics, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Evaluasi Kinerja Model',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Metrik evaluasi model Random Forest Regressor dan K-Means Clustering '
                  'untuk mengukur akurasi prediksi kebutuhan stok.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Metrik Utama (4 cards)
          _buildSectionTitle(theme, 'Metrik Evaluasi Random Forest'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildMetricCard(theme, 'MAE', '${mae.toStringAsFixed(2)} unit',
                'Rata-rata kesalahan absolut', Colors.blue)),
              const SizedBox(width: 8),
              Expanded(child: _buildMetricCard(theme, 'RMSE', '${rmse.toStringAsFixed(2)} unit',
                'Akar rata-rata kuadrat error', Colors.orange)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildMetricCard(theme, 'MAPE', '${_mlService.mape.toStringAsFixed(2)}%',
                'Rata-rata persentase error', _mlService.mape < 30 ? Colors.green : Colors.red)),
              const SizedBox(width: 8),
              Expanded(child: _buildMetricCard(theme, 'R\u00B2', _mlService.r2Score.toStringAsFixed(4),
                'Koefisien determinasi', _mlService.r2Score > 0.8 ? Colors.green : Colors.orange)),
            ],
          ),
          const SizedBox(height: 20),

          // Konfigurasi Model
          _buildSectionTitle(theme, 'Konfigurasi Model'),
          const SizedBox(height: 12),
          _buildModelConfigCard(theme),
          const SizedBox(height: 20),

          // Feature Importance
          if (_mlService.featureImportances.isNotEmpty) ...[
            _buildSectionTitle(theme, 'Feature Importance'),
            const SizedBox(height: 12),
            _buildFeatureImportanceCard(theme),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // =============================================================
  // TAB 4: DATA STOK (HISTORIS)
  // =============================================================

  Widget _buildStockDataTab(ThemeData theme) {
    final summary = _mlService.getStockSummary();
    final statusDist = _mlService.getStockStatusDistribution();
    final total = summary['totalRecords'] as int? ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.brown.shade700, Colors.brown.shade500],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.inventory_2, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Data Historis Stok',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Data stok bulanan untuk ${summary['uniqueProducts'] ?? 0} produk '
                  '($total record). Data ini digunakan sebagai input fitur '
                  'K-Means Clustering dan Random Forest.',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Status distribution
          _buildSectionTitle(theme, 'Distribusi Status Stok'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatusCard(theme, 'Normal',
                statusDist['normal'] ?? 0, total, Colors.green.shade600, Icons.check_circle)),
              const SizedBox(width: 8),
              Expanded(child: _buildStatusCard(theme, 'Overstock',
                statusDist['overstock'] ?? 0, total, Colors.orange.shade600, Icons.arrow_upward)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildStatusCard(theme, 'Understock',
                statusDist['understock'] ?? 0, total, Colors.red.shade400, Icons.arrow_downward)),
              const SizedBox(width: 8),
              Expanded(child: _buildStatusCard(theme, 'Stockout',
                statusDist['stockout'] ?? 0, total, Colors.red.shade800, Icons.cancel)),
            ],
          ),
          const SizedBox(height: 20),

          // Visual bar chart
          _buildSectionTitle(theme, 'Visualisasi Status'),
          const SizedBox(height: 12),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildStatusBar('Normal', statusDist['normal'] ?? 0, total, Colors.green.shade600),
                  const SizedBox(height: 12),
                  _buildStatusBar('Overstock', statusDist['overstock'] ?? 0, total, Colors.orange.shade600),
                  const SizedBox(height: 12),
                  _buildStatusBar('Understock', statusDist['understock'] ?? 0, total, Colors.red.shade400),
                  const SizedBox(height: 12),
                  _buildStatusBar('Stockout', statusDist['stockout'] ?? 0, total, Colors.red.shade800),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // =============================================================
  // TAB 5: REKOMENDASI OPERASIONAL — Tujuan 3
  // =============================================================

  Widget _buildRecommendationTab(ThemeData theme) {
    final riskDist = _mlService.getRiskDistribution();
    final urgent = _mlService.getUrgentRecommendations();
    final totalReco = _mlService.allRecommendations.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple.shade700, Colors.deepPurple.shade500],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.recommend, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tujuan 3: Rekomendasi Operasional',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Integrasi K-Means + Random Forest untuk $totalReco produk. '
                  'Rekomendasi untuk meminimalkan overstock dan understock.',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Risk distribution
          _buildSectionTitle(theme, 'Distribusi Risiko Stok'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildRiskCard(theme, 'Overstock',
                riskDist['overstock'] ?? 0, totalReco, Colors.orange.shade600, Icons.trending_up)),
              const SizedBox(width: 8),
              Expanded(child: _buildRiskCard(theme, 'Understock',
                riskDist['understock'] ?? 0, totalReco, Colors.red.shade600, Icons.trending_down)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildRiskCard(theme, 'Optimal',
                riskDist['optimal'] ?? 0, totalReco, Colors.green.shade600, Icons.check_circle)),
              const SizedBox(width: 8),
              Expanded(child: _buildRiskCard(theme, 'Perhatian',
                riskDist['perlu_perhatian'] ?? 0, totalReco, Colors.amber.shade600, Icons.visibility)),
            ],
          ),
          const SizedBox(height: 20),

          // Urgent recommendations
          if (urgent.isNotEmpty) ...[
            _buildSectionTitle(theme, 'Produk Prioritas Tinggi (${urgent.length})'),
            const SizedBox(height: 12),
            ...urgent.take(15).map((reco) => _buildRecommendationCard(theme, reco)),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // =============================================================
  // TAB 6: DETAIL PRODUK
  // =============================================================

  Widget _buildProductDetailTab(ThemeData theme) {
    final products = _mlService.getProductSummaryList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blueGrey.shade700, Colors.blueGrey.shade500],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.list_alt, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Detail Produk per Segmen',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Daftar ${products.length} produk beserta segmen, prediksi stok, dan rekomendasi.',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Product list
          for (final segment in ['fast moving', 'medium moving', 'slow moving']) ...[
            _buildSectionTitle(theme, segment == 'fast moving'
                ? 'Fast Moving' : segment == 'medium moving'
                ? 'Medium Moving' : 'Slow Moving'),
            const SizedBox(height: 8),
            ...products
                .where((p) => p['segment'] == segment)
                .take(20)
                .map((product) => _buildProductCard(theme, product)),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  // =============================================================
  // SHARED WIDGET BUILDERS
  // =============================================================

  Widget _buildInfoBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.primary,
      ),
    );
  }

  Widget _buildInputField(
    TextEditingController controller,
    String label,
    IconData icon, {
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12),
        prefixIcon: Icon(icon, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
      style: const TextStyle(fontSize: 13),
      validator: (val) {
        if (val == null || val.trim().isEmpty) return 'Wajib diisi';
        if (double.tryParse(val) == null) return 'Masukkan angka valid';
        return null;
      },
    );
  }

  Widget _buildPredictionResult(ThemeData theme) {
    final result = _predictionResult!;
    final segment = result['segment'] as String;
    final confidence = result['confidence'] as double;
    final reasoning = result['reasoning'] as String;

    Color segColor;
    IconData segIcon;
    switch (segment) {
      case 'fast moving':
        segColor = Colors.green.shade600;
        segIcon = Icons.rocket_launch;
        break;
      case 'medium moving':
        segColor = Colors.orange.shade600;
        segIcon = Icons.speed;
        break;
      default:
        segColor = Colors.red.shade400;
        segIcon = Icons.hourglass_bottom;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: segColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: segColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(segIcon, color: segColor, size: 22),
              const SizedBox(width: 8),
              Text(
                segment.toUpperCase(),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: segColor),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: segColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Confidence: ${(confidence * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: segColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(reasoning, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
        ],
      ),
    );
  }

  Widget _buildClusteringValidationCard(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Table(
              columnWidths: const {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(1.5),
                2: FlexColumnWidth(1.5),
                3: FlexColumnWidth(1.5),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  children: const [
                    Padding(padding: EdgeInsets.all(8), child: Text('k', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    Padding(padding: EdgeInsets.all(8), child: Text('Silhouette', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    Padding(padding: EdgeInsets.all(8), child: Text('Davies-Bouldin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    Padding(padding: EdgeInsets.all(8), child: Text('Inertia', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  ],
                ),
                ..._mlService.clusteringEvaluation.map((row) {
                  final isK3 = row['k'] == 3;
                  return TableRow(
                    decoration: isK3 ? BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)) : null,
                    children: [
                      Padding(padding: const EdgeInsets.all(8), child: Text('k=${row['k']}${isK3 ? ' *' : ''}',
                        style: TextStyle(fontSize: 11, fontWeight: isK3 ? FontWeight.bold : FontWeight.normal, color: isK3 ? Colors.green.shade700 : null))),
                      Padding(padding: const EdgeInsets.all(8), child: Text((row['silhouette_score'] as double).toStringAsFixed(4),
                        style: TextStyle(fontSize: 11, fontWeight: isK3 ? FontWeight.bold : FontWeight.normal))),
                      Padding(padding: const EdgeInsets.all(8), child: Text((row['davies_bouldin_index'] as double).toStringAsFixed(4),
                        style: TextStyle(fontSize: 11, fontWeight: isK3 ? FontWeight.bold : FontWeight.normal))),
                      Padding(padding: const EdgeInsets.all(8), child: Text(_formatNumber(row['inertia'] as double),
                        style: TextStyle(fontSize: 11, fontWeight: isK3 ? FontWeight.bold : FontWeight.normal))),
                    ],
                  );
                }),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade700, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('k=3 dipilih sesuai proposal (fast/medium/slow moving)',
                      style: TextStyle(fontSize: 10, color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentCard(ThemeData theme, {
    required String title, required String subtitle,
    required int count, required int uniqueProducts,
    required int total, required Color color, required IconData icon,
  }) {
    final percentage = total > 0 ? (count / total * 100) : 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(value: percentage / 100, minHeight: 6,
                      backgroundColor: Colors.grey.shade200, valueColor: AlwaysStoppedAnimation<Color>(color)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$count', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
                Text('${percentage.toStringAsFixed(1)}%', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                Text('$uniqueProducts produk', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClusterBars(ThemeData theme, int total) {
    final segments = [
      {'label': 'Fast Moving', 'key': 'fast moving', 'color': Colors.green.shade600},
      {'label': 'Medium Moving', 'key': 'medium moving', 'color': Colors.orange.shade600},
      {'label': 'Slow Moving', 'key': 'slow moving', 'color': Colors.red.shade400},
    ];

    return Column(
      children: segments.map((seg) {
        final count = _distribution[seg['key'] as String] ?? 0;
        final pct = total > 0 ? count / total : 0.0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              SizedBox(width: 110, child: Text(seg['label'] as String,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: seg['color'] as Color))),
              const SizedBox(width: 8),
              Expanded(
                child: Stack(
                  children: [
                    Container(height: 20, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10))),
                    FractionallySizedBox(
                      widthFactor: pct < 0.02 && pct > 0 ? 0.02 : pct,
                      child: Container(
                        height: 20,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [seg['color'] as Color, (seg['color'] as Color).withValues(alpha: 0.6)]),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 6),
                        child: pct > 0.05 ? Text('${(pct * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)) : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(width: 50, child: Text('$count', textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAverageStatsTable(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Table(
          columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1.5), 2: FlexColumnWidth(1.5), 3: FlexColumnWidth(1.5)},
          children: [
            TableRow(
              decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
              children: const [
                Padding(padding: EdgeInsets.all(8), child: Text('Segmen', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                Padding(padding: EdgeInsets.all(8), child: Text('Avg Qty (unit)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                Padding(padding: EdgeInsets.all(8), child: Text('Avg Value', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                Padding(padding: EdgeInsets.all(8), child: Text('Avg Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
              ],
            ),
            _buildStatRow('Fast Moving', _averages['fast moving'], Colors.green.shade600),
            _buildStatRow('Medium Moving', _averages['medium moving'], Colors.orange.shade600),
            _buildStatRow('Slow Moving', _averages['slow moving'], Colors.red.shade400),
          ],
        ),
      ),
    );
  }

  TableRow _buildStatRow(String label, Map<String, double>? stats, Color color) {
    return TableRow(children: [
      Padding(padding: const EdgeInsets.all(8), child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color))),
      Padding(padding: const EdgeInsets.all(8), child: Text((stats?['avgQty'] ?? 0).toStringAsFixed(1), style: const TextStyle(fontSize: 11))),
      Padding(padding: const EdgeInsets.all(8), child: Text(_formatCurrency(stats?['avgValue'] ?? 0), style: const TextStyle(fontSize: 11))),
      Padding(padding: const EdgeInsets.all(8), child: Text(_formatCurrency(stats?['avgTotal'] ?? 0), style: const TextStyle(fontSize: 11))),
    ]);
  }

  Widget _buildPredictionCard(ThemeData theme, StockPrediction pred) {
    Color segColor;
    switch (pred.segment) {
      case 'fast moving': segColor = Colors.green.shade600; break;
      case 'medium moving': segColor = Colors.orange.shade600; break;
      default: segColor = Colors.red.shade400;
    }

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: segColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                  child: Text(pred.segmentLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: segColor)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _mlService.getFabricName(pred.pfcoCode),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text('MAPE: ${pred.mape}%', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildMiniStat('Bulan 1', '${pred.predictedQtyMonth1.toStringAsFixed(0)} unit')),
                Expanded(child: _buildMiniStat('Bulan 2', '${pred.predictedQtyMonth2.toStringAsFixed(0)} unit')),
                Expanded(child: _buildMiniStat('Bulan 3', '${pred.predictedQtyMonth3.toStringAsFixed(0)} unit')),
                Expanded(child: _buildMiniStat('Aktual', '${pred.actualAvgNeed.toStringAsFixed(0)} unit')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  double get mae => _mlService.mae;
  double get rmse => _mlService.rmse;

  Widget _buildMetricCard(ThemeData theme, String title, String value, String desc, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(desc, style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildModelConfigCard(ThemeData theme) {
    final metrics = _mlService.getModelMetrics();
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            _buildConfigRow('Algoritma', 'Random Forest Regressor'),
            _buildConfigRow('N Estimators', '${(metrics['N_Estimators']?['value'] ?? 0).toStringAsFixed(0)} trees'),
            _buildConfigRow('Max Depth', (metrics['Max_Depth']?['value'] ?? 0).toStringAsFixed(0)),
            _buildConfigRow('Training Set', '${(metrics['Training_Samples']?['value'] ?? 0).toStringAsFixed(0)} baris'),
            _buildConfigRow('Test Set', '${(metrics['Test_Samples']?['value'] ?? 0).toStringAsFixed(0)} baris'),
            _buildConfigRow('Total Features', '${(metrics['Total_Features']?['value'] ?? 0).toStringAsFixed(0)}'),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildFeatureImportanceCard(ThemeData theme) {
    final features = _mlService.featureImportances;
    final maxImp = features.isNotEmpty ? (features.first['importance'] as double) : 1.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: features.map((feat) {
            final importance = feat['importance'] as double;
            final pct = maxImp > 0 ? importance / maxImp : 0.0;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(width: 120, child: Text(feat['feature'].toString(),
                    style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 14,
                        backgroundColor: Colors.grey.shade100,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          pct > 0.5 ? Colors.indigo.shade600 : Colors.indigo.shade300),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(width: 50, child: Text('${(importance * 100).toStringAsFixed(1)}%',
                    textAlign: TextAlign.right, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatusCard(ThemeData theme, String title, int count, int total, Color color, IconData icon) {
    final pct = total > 0 ? (count / total * 100).toStringAsFixed(1) : '0.0';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text('$count', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
            Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
            Text('$pct%', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar(String label, int count, int total, Color color) {
    final pct = total > 0 ? count / total : 0.0;

    return Row(
      children: [
        SizedBox(width: 80, child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color))),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: pct, minHeight: 16,
              backgroundColor: Colors.grey.shade100, valueColor: AlwaysStoppedAnimation<Color>(color)),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(width: 60, child: Text('$count (${(pct * 100).toStringAsFixed(1)}%)',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
      ],
    );
  }

  Widget _buildRiskCard(ThemeData theme, String title, int count, int total, Color color, IconData icon) {
    final pct = total > 0 ? (count / total * 100).toStringAsFixed(1) : '0.0';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text('$count', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
            Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
            Text('$pct%', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationCard(ThemeData theme, RekomendasiOperasional reco) {
    Color riskColor;
    IconData riskIcon;
    switch (reco.riskCategory) {
      case 'overstock':
        riskColor = Colors.orange.shade600;
        riskIcon = Icons.trending_up;
        break;
      case 'understock':
        riskColor = Colors.red.shade600;
        riskIcon = Icons.trending_down;
        break;
      case 'perlu_perhatian':
        riskColor = Colors.amber.shade700;
        riskIcon = Icons.visibility;
        break;
      default:
        riskColor = Colors.green.shade600;
        riskIcon = Icons.check_circle;
    }

    Color priorityColor;
    switch (reco.priority) {
      case 'KRITIS': priorityColor = Colors.red.shade800; break;
      case 'TINGGI': priorityColor = Colors.red.shade600; break;
      case 'SEDANG': priorityColor = Colors.orange.shade600; break;
      default: priorityColor = Colors.green.shade600;
    }

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(riskIcon, color: riskColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _mlService.getFabricName(reco.pfcoCode),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: priorityColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                  child: Text(reco.priority, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: priorityColor)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: riskColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
              child: Text(reco.action, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: riskColor)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildMiniStat('Stok', '${reco.currentStockKg.toStringAsFixed(0)} unit')),
                Expanded(child: _buildMiniStat('Kebutuhan', '${reco.predictedNeedKg.toStringAsFixed(0)} unit')),
                Expanded(child: _buildMiniStat('Safety', '${reco.safetyStockKg.toStringAsFixed(0)} unit')),
                Expanded(child: _buildMiniStat('Restock', '${reco.restockQtyKg.toStringAsFixed(0)} unit')),
              ],
            ),
            const SizedBox(height: 6),
            Text(reco.suggestion, style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(ThemeData theme, Map<String, dynamic> product) {
    final pfcoCode = product['pfcoCode']?.toString() ?? '';
    final segment = product['segment']?.toString() ?? 'slow moving';
    final totalTrx = product['totalTransactions'] as int? ?? 0;

    Color segColor;
    switch (segment) {
      case 'fast moving': segColor = Colors.green.shade600; break;
      case 'medium moving': segColor = Colors.orange.shade600; break;
      default: segColor = Colors.red.shade400;
    }

    // Get recommendation if available
    final reco = _mlService.getRecommendationByCode(pfcoCode);
    final pred = _mlService.getStockPredictionByCode(pfcoCode);

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: segColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text(segment == 'fast moving' ? 'FAST' : segment == 'medium moving' ? 'MEDIUM' : 'SLOW',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: segColor)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _mlService.getFabricName(pfcoCode),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Text('$totalTrx trx', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
              ],
            ),
            if (pred != null) ...[
              const SizedBox(height: 4),
              Text('Harga: ${_formatCurrency(MlScaler.getFabricPrice(pfcoCode))}/unit | Prediksi: ${pred.avgPredicted.toStringAsFixed(0)} unit/bulan | MAPE: ${pred.mape}%',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            ],
            if (reco != null) ...[
              const SizedBox(height: 2),
              Text('${reco.action} (${reco.riskLabel})',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                  color: reco.riskCategory == 'optimal' ? Colors.green : reco.riskCategory == 'overstock' ? Colors.orange : Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}
