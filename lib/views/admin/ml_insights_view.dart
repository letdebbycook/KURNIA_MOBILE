import 'package:flutter/material.dart';
import '../../services/ml_service.dart';

/// Halaman analisis Machine Learning (Random Forest & Clustering)
/// untuk Admin — menampilkan segmentasi produk, distribusi cluster,
/// prediksi segmen baru, dan statistik detail.
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

  // Tab controller
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
      await _mlService.loadData();

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
              'Random Forest & Clustering Analysis',
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
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          tabs: const [
            Tab(icon: Icon(Icons.pie_chart_outline, size: 20), text: 'Segmentasi'),
            Tab(icon: Icon(Icons.auto_awesome, size: 20), text: 'Prediksi'),
            Tab(icon: Icon(Icons.table_chart_outlined, size: 20), text: 'Detail Produk'),
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
                    _buildPredictionTab(theme),
                    _buildProductDetailTab(theme),
                  ],
                ),
    );
  }

  // =============================================================
  // TAB 1: SEGMENTASI OVERVIEW
  // =============================================================

  Widget _buildSegmentationTab(ThemeData theme) {
    final total = _distribution.values.fold(0, (a, b) => a + b);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header info card
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
                    Text(
                      'Random Forest & K-Means Clustering',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Total $total data transaksi produk kain telah dianalisis menggunakan model Machine Learning.',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'MODEL ACTIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3 Segment Summary Cards
          Text(
            'Distribusi Segmentasi Produk',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),

          _buildSegmentCard(
            theme,
            title: 'Fast Moving',
            subtitle: 'Produk perputaran cepat',
            count: _distribution['fast moving'] ?? 0,
            uniqueProducts: _uniqueProducts['fast moving'] ?? 0,
            total: total,
            color: Colors.green.shade600,
            icon: Icons.rocket_launch,
          ),
          const SizedBox(height: 10),
          _buildSegmentCard(
            theme,
            title: 'Medium Moving',
            subtitle: 'Produk perputaran sedang',
            count: _distribution['medium moving'] ?? 0,
            uniqueProducts: _uniqueProducts['medium moving'] ?? 0,
            total: total,
            color: Colors.orange.shade600,
            icon: Icons.speed,
          ),
          const SizedBox(height: 10),
          _buildSegmentCard(
            theme,
            title: 'Slow Moving',
            subtitle: 'Produk perputaran lambat',
            count: _distribution['slow moving'] ?? 0,
            uniqueProducts: _uniqueProducts['slow moving'] ?? 0,
            total: total,
            color: Colors.red.shade400,
            icon: Icons.hourglass_bottom,
          ),

          const SizedBox(height: 24),

          // Visual Cluster Distribution
          Text(
            'Visualisasi Distribusi Cluster',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
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

          // Statistik Rata-rata per Segmen
          Text(
            'Statistik Rata-rata per Segmen',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          _buildAverageStatsTable(theme),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSegmentCard(
    ThemeData theme, {
    required String title,
    required String subtitle,
    required int count,
    required int uniqueProducts,
    required int total,
    required Color color,
    required IconData icon,
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
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 6),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: percentage / 100,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: color,
                  ),
                ),
                Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                Text(
                  '$uniqueProducts produk',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
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
              SizedBox(
                width: 110,
                child: Text(
                  seg['label'] as String,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: seg['color'] as Color,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: pct < 0.02 && pct > 0 ? 0.02 : pct,
                      child: Container(
                        height: 20,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              seg['color'] as Color,
                              (seg['color'] as Color).withValues(alpha: 0.6),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 6),
                        child: pct > 0.05
                            ? Text(
                                '${(pct * 100).toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 50,
                child: Text(
                  '$count',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
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
          columnWidths: const {
            0: FlexColumnWidth(2),
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
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Segmen', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                ),
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Avg Qty (Kg)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                ),
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Avg Value', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                ),
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Avg Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                ),
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
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(_formatNumber(stats?['avgQty'] ?? 0), style: const TextStyle(fontSize: 11)),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(_formatNumber(stats?['avgValue'] ?? 0), style: const TextStyle(fontSize: 11)),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(_formatNumber(stats?['avgTotal'] ?? 0), style: const TextStyle(fontSize: 11)),
        ),
      ],
    );
  }

  // =============================================================
  // TAB 2: PREDIKSI SEGMEN
  // =============================================================

  Widget _buildPredictionTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Card(
            elevation: 3,
            color: theme.colorScheme.secondary.withValues(alpha: 0.06),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.secondary.withValues(alpha: 0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      color: theme.colorScheme.secondary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Prediksi Segmentasi Produk',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Masukkan data produk untuk memprediksi segmen menggunakan model Random Forest.',
                          style: TextStyle(fontSize: 11, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Input Form
          Form(
            key: _formKey,
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Input Data Produk',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _qtyController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Quantities (Kg)',
                        hintText: 'Contoh: 54.02',
                        prefixIcon: Icon(Icons.scale, color: theme.colorScheme.primary),
                        helperText: 'Berat produk dalam kilogram',
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Wajib diisi';
                        if (double.tryParse(val) == null) return 'Masukkan angka valid';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _valueController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Value (Rp)',
                        hintText: 'Contoh: 12960.0',
                        prefixIcon: Icon(Icons.monetization_on_outlined, color: theme.colorScheme.primary),
                        helperText: 'Nilai transaksi dalam Rupiah',
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Wajib diisi';
                        if (double.tryParse(val) == null) return 'Masukkan angka valid';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _totalController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Total Values',
                        hintText: 'Contoh: 700099.2',
                        prefixIcon: Icon(Icons.functions, color: theme.colorScheme.primary),
                        helperText: 'Total akumulasi nilai (Qty × Value)',
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Wajib diisi';
                        if (double.tryParse(val) == null) return 'Masukkan angka valid';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    ElevatedButton.icon(
                      onPressed: _runPrediction,
                      icon: const Icon(Icons.psychology, size: 20),
                      label: const Text(
                        'JALANKAN PREDIKSI',
                        style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Quick fill buttons
                    Row(
                      children: [
                        const Text('Contoh: ', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(width: 4),
                        _buildQuickFillChip('Slow', '54.02', '12960', '700099.2', Colors.red.shade300),
                        const SizedBox(width: 6),
                        _buildQuickFillChip('Medium', '1763', '460800', '812418048', Colors.orange.shade400),
                        const SizedBox(width: 6),
                        _buildQuickFillChip('Fast', '7793', '1898208', '14792772908', Colors.green.shade500),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Prediction Result
          if (_predictionResult != null) _buildPredictionResult(theme),
        ],
      ),
    );
  }

  Widget _buildQuickFillChip(String label, String qty, String value, String total, Color color) {
    return GestureDetector(
      onTap: () {
        _qtyController.text = qty;
        _valueController.text = value;
        _totalController.text = total;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
        ),
      ),
    );
  }

  Widget _buildPredictionResult(ThemeData theme) {
    final segment = _predictionResult!['segment'] as String;
    final confidence = _predictionResult!['confidence'] as double;
    final reasoning = _predictionResult!['reasoning'] as String;
    final cluster = _predictionResult!['cluster'] as int;

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

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: segColor.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: segColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 12, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'HASIL PREDIKSI',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: segColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(segIcon, color: segColor, size: 32),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        segment.split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' '),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: segColor,
                        ),
                      ),
                      Text(
                        'Cluster $cluster • Confidence: ${(confidence * 100).toStringAsFixed(0)}%',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Confidence bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: confidence,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(segColor),
              ),
            ),
            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: segColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline, size: 18, color: segColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reasoning,
                      style: const TextStyle(fontSize: 12, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =============================================================
  // TAB 3: DETAIL PRODUK
  // =============================================================

  Widget _buildProductDetailTab(ThemeData theme) {
    final products = _mlService.getProductSummaryList();

    // Group by segment for better organization
    final fastProducts = products.where((p) => p['segment'] == 'fast moving').toList();
    final mediumProducts = products.where((p) => p['segment'] == 'medium moving').toList();
    final slowProducts = products.where((p) => p['segment'] == 'slow moving').take(50).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Fast Moving Products
          if (fastProducts.isNotEmpty) ...[
            _buildProductSectionHeader(
              'Fast Moving Products',
              '${fastProducts.length} produk',
              Colors.green.shade600,
              Icons.rocket_launch,
            ),
            const SizedBox(height: 8),
            ...fastProducts.map((p) => _buildProductTile(p, Colors.green.shade600)),
            const SizedBox(height: 16),
          ],

          // Medium Moving Products
          if (mediumProducts.isNotEmpty) ...[
            _buildProductSectionHeader(
              'Medium Moving Products',
              '${mediumProducts.length} produk',
              Colors.orange.shade600,
              Icons.speed,
            ),
            const SizedBox(height: 8),
            ...mediumProducts.map((p) => _buildProductTile(p, Colors.orange.shade600)),
            const SizedBox(height: 16),
          ],

          // Slow Moving Products (limited to 50)
          if (slowProducts.isNotEmpty) ...[
            _buildProductSectionHeader(
              'Slow Moving Products',
              '${products.where((p) => p['segment'] == 'slow moving').length} produk (menampilkan 50)',
              Colors.red.shade400,
              Icons.hourglass_bottom,
            ),
            const SizedBox(height: 8),
            ...slowProducts.map((p) => _buildProductTile(p, Colors.red.shade400)),
          ],

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildProductSectionHeader(String title, String subtitle, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductTile(Map<String, dynamic> product, Color color) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        dense: true,
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            product['pfcoCode'].toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 10,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        title: Text(
          'Kode Produk: ${product['pfcoCode']}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        subtitle: Text(
          '${product['totalTransactions']} transaksi',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            (product['segment'] as String).split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' '),
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
          ),
        ),
      ),
    );
  }
}
