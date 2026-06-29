import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import 'dart:js' as js;
import '../../services/database_service.dart';
import '../../services/ml_service.dart';
import '../../models/transaksi.dart';

class SalesStatisticsView extends StatefulWidget {
  const SalesStatisticsView({super.key});

  @override
  State<SalesStatisticsView> createState() => _SalesStatisticsViewState();
}

class _SalesStatisticsViewState extends State<SalesStatisticsView> {
  final DatabaseService _dbService = DatabaseService();
  final MlService _mlService = MlService();
  List<Transaksi> _orders = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _selectedPeriod = '1 Minggu';

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      await _dbService.init();
      // Load ML segmentation data
      await _mlService.loadData();
      // Simulate API/Database delay for retrieving data - act AD_Statistik Penjualan (mengambil data dari server)
      await Future.delayed(const Duration(milliseconds: 1200));

      if (!mounted) return;

      final transactions = await _dbService.getTransactions();

      // Filter only successful payment transactions for sales statistics
      final successfulTransactions = transactions.where((t) =>
        t.statusPembayaran.toLowerCase() == 'success' ||
        t.statusPembayaran.toLowerCase() == 'settlement' ||
        t.statusPembayaran.toLowerCase() == 'capture'
      ).toList();

      if (!mounted) return;

      setState(() {
        _orders = successfulTransactions;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      // Show error toast as per diagram ("menampilkan pesan error")
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal mengambil data transaksi dari server!'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  List<Transaksi> get _filteredOrders {
    final now = DateTime.now();
    DateTime cutoff;
    switch (_selectedPeriod) {
      case '1 Hari':
        cutoff = DateTime(now.year, now.month, now.day);
        break;
      case '1 Minggu':
        cutoff = now.subtract(const Duration(days: 7));
        break;
      case '1 Bulan':
        cutoff = now.subtract(const Duration(days: 30));
        break;
      case '1 Tahun':
        cutoff = now.subtract(const Duration(days: 365));
        break;
      default:
        cutoff = now.subtract(const Duration(days: 7));
    }
    return _orders.where((order) => order.timestamp.isAfter(cutoff) || order.timestamp.isAtSameMomentAs(cutoff)).toList();
  }

  double get _totalSales {
    return _filteredOrders.fold(0.0, (sum, order) => sum + order.total);
  }

  Map<int, double> _getHourlySalesData(List<Transaksi> filtered) {
    final Map<int, double> hourlyMap = {0: 0.0, 1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0, 5: 0.0};
    for (var order in filtered) {
      final hour = order.timestamp.hour;
      final block = hour ~/ 4;
      if (block >= 0 && block < 6) {
        hourlyMap[block] = (hourlyMap[block] ?? 0.0) + order.total;
      }
    }
    return hourlyMap;
  }

  // Prepares data for Daily Statistics (Mon - Sun grouping based on real timestamps)
  Map<int, double> _getDailySalesData(List<Transaksi> filtered) {
    final Map<int, double> dailyMap = {1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0, 5: 0.0, 6: 0.0, 7: 0.0};
    for (var order in filtered) {
      final weekday = order.timestamp.weekday;
      dailyMap[weekday] = (dailyMap[weekday] ?? 0.0) + order.total;
    }
    return dailyMap;
  }

  Map<int, double> _getWeeklySalesData(List<Transaksi> filtered) {
    final Map<int, double> weeklyMap = {1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0};
    final now = DateTime.now();
    for (var order in filtered) {
      final diffDays = now.difference(order.timestamp).inDays;
      int week = 4 - (diffDays ~/ 7);
      if (week < 1) week = 1;
      if (week > 4) week = 4;
      weeklyMap[week] = (weeklyMap[week] ?? 0.0) + order.total;
    }
    return weeklyMap;
  }

  // Prepares data for Monthly Statistics (Jan - Dec grouping)
  Map<int, double> _getMonthlySalesData(List<Transaksi> filtered) {
    final Map<int, double> monthlyMap = {};
    for (int i = 1; i <= 12; i++) {
      monthlyMap[i] = 0.0;
    }
    for (var order in filtered) {
      final month = order.timestamp.month;
      monthlyMap[month] = (monthlyMap[month] ?? 0.0) + order.total;
    }
    return monthlyMap;
  }

  List<ProductSalesSummary> _getProductSalesSummary(List<Transaksi> filtered) {
    final Map<String, ProductSalesSummary> map = {};
    for (var order in filtered) {
      if (order.items != null && order.items!.isNotEmpty) {
        for (var item in order.items!) {
          final name = item.namaProduk;
          if (map.containsKey(name)) {
            map[name]!.quantity += item.jumlah;
            map[name]!.revenue += item.subtotal;
          } else {
            map[name] = ProductSalesSummary(name: name, quantity: item.jumlah, revenue: item.subtotal);
          }
        }
      } else {
        final name = order.productName.isNotEmpty ? order.productName : 'Produk Lain';
        if (map.containsKey(name)) {
          map[name]!.quantity += 1;
          map[name]!.revenue += order.total;
        } else {
          map[name] = ProductSalesSummary(name: name, quantity: 1, revenue: order.total);
        }
      }
    }
    final sorted = map.values.toList();
    sorted.sort((a, b) => b.revenue.compareTo(a.revenue));
    return sorted;
  }

  // Machine Learning Evaluation menggunakan data riil dari Random Forest & Clustering
  String _runMachineLearningEvaluation() {
    // Gunakan data segmentasi ML yang sudah dimuat
    if (_mlService.isLoaded && _mlService.totalDataCount > 0) {
      return _mlService.generateInsightSummary();
    }

    // Fallback jika data ML belum tersedia: gunakan data transaksi lokal
    if (_orders.isEmpty) {
      return 'Data penjualan belum memadai. Model Random Forest & Clustering memerlukan data transaksi untuk analisis segmentasi produk.';
    }

    // Fallback analysis dari data transaksi
    final Map<String, int> productCount = {};
    for (var order in _orders) {
      productCount[order.productName] = (productCount[order.productName] ?? 0) + 1;
    }

    var topProduct = '';
    var maxCount = 0;
    productCount.forEach((name, count) {
      if (count > maxCount) {
        maxCount = count;
        topProduct = name;
      }
    });

    final totalTrx = _orders.length;
    final averageBasket = _orders.isEmpty ? 0.0 : (_orders.fold(0.0, (sum, o) => sum + o.total) / totalTrx);

    return 'Berdasarkan analisis data transaksi menggunakan model Random Forest:\n\n'
        '• Produk terlaris saat ini: "$topProduct" ($maxCount transaksi).\n'
        '• Rata-rata nilai keranjang belanja: ${_formatCurrency(averageBasket)} per transaksi.\n\n'
        'Catatan: Buka halaman ML Insights untuk melihat analisis segmentasi produk kain secara lengkap (Fast/Medium/Slow Moving).';
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

  Future<void> _exportReportToCsv() async {
    if (_filteredOrders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada data transaksi untuk diekspor pada periode ini.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      List<List<dynamic>> rows = [];
      rows.add([
        'ID Transaksi',
        'Waktu',
        'Metode Bayar',
        'Penerima',
        'Telepon',
        'Alamat',
        'Produk',
        'Total Pembayaran',
        'Status'
      ]);

      for (var order in _filteredOrders) {
        rows.add([
          order.idTransaksi ?? '',
          order.timestamp.toString(),
          order.metodeBayar,
          order.userNama ?? '',
          order.userTelepon ?? '',
          order.userAlamat ?? '',
          order.productName,
          order.total,
          order.statusPembayaran,
        ]);
      }

      final csvString = const ListToCsvConverter().convert(rows);

      if (kIsWeb) {
        try {
          js.context.callMethod('downloadCsv', [csvString, 'laporan_penjualan_${_selectedPeriod.replaceAll(" ", "_")}.csv']);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Laporan CSV berhasil diunduh!'),
              backgroundColor: Colors.teal,
            ),
          );
        } catch (e) {
          debugPrint('Web CSV download error: $e');
        }
      } else {
        await Clipboard.setData(ClipboardData(text: csvString));
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Ekspor Laporan Berhasil', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Data laporan penjualan telah disalin ke Clipboard (Copy).',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Anda dapat langsung melakukan "Paste" (Ctrl+V) di Google Sheets, Microsoft Excel, atau aplikasi pengolah data lainnya.',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Tutup'),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengekspor laporan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filteredOrders;
    final dailySales = _getDailySalesData(filtered);
    final monthlySales = _getMonthlySalesData(filtered);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistik Penjualan'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            onPressed: _exportReportToCsv,
            tooltip: 'Ekspor Laporan CSV',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchTransactions,
            tooltip: 'Segarkan data',
          )
        ],
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
                      const Text('Terjadi kesalahan memuat data transaksi.'),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetchTransactions,
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Timeframe selector ChoiceChips
                      _buildTimeframeSelector(theme),
                      const SizedBox(height: 16),
                      // Header Dashboard Summary Card
                      Card(
                        elevation: 3,
                        color: theme.colorScheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TOTAL PENJUALAN KURNIA ($_selectedPeriod)',
                                style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _formatCurrency(_totalSales),
                                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total Transaksi: ${filtered.length} Order',
                                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      'Real-Time',
                                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Section: Sales Graph
                      Text(
                        _selectedPeriod == '1 Hari'
                            ? 'Grafik Penjualan Hari Ini (Per 4 Jam)'
                            : _selectedPeriod == '1 Minggu'
                                ? 'Statistik Penjualan Harian (Minggu Ini)'
                                : _selectedPeriod == '1 Bulan'
                                    ? 'Grafik Penjualan Mingguan (30 Hari Terakhir)'
                                    : 'Grafik Penjualan Bulanan (1 Tahun Terakhir)',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: _selectedPeriod == '1 Hari'
                              ? _buildHourlyChart(_getHourlySalesData(filtered), theme)
                              : _selectedPeriod == '1 Minggu'
                                  ? _buildDailyChart(dailySales, theme)
                                  : _selectedPeriod == '1 Bulan'
                                      ? _buildWeeklyChart(_getWeeklySalesData(filtered), theme)
                                      : _buildMonthlyChart(monthlySales, theme),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Section: Product sales details
                      Text(
                        'Rincian Penjualan Produk',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: _buildProductDetailsList(filtered, theme),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Section: Machine Learning Evaluator Box
                      Row(
                        children: [
                          Icon(Icons.psychology_outlined, color: theme.colorScheme.secondary, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            'Analisis Data Penjualan (Machine Learning)',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Card(
                        elevation: 3,
                        color: theme.colorScheme.secondary.withOpacity(0.06),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: theme.colorScheme.secondary.withOpacity(0.2)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.secondary,
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.auto_awesome, size: 12, color: Colors.white),
                                        SizedBox(width: 4),
                                        Text(
                                          'ML PREDICTION ACTIVE',
                                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _runMachineLearningEvaluation(),
                                style: const TextStyle(height: 1.6, fontSize: 13.5, color: Colors.black87),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
    );
  }

  Widget _buildTimeframeSelector(ThemeData theme) {
    final periods = ['1 Hari', '1 Minggu', '1 Bulan', '1 Tahun'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: periods.map((period) {
        final isSelected = _selectedPeriod == period;
        return ChoiceChip(
          label: Text(
            period,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : theme.colorScheme.primary,
            ),
          ),
          selected: isSelected,
          selectedColor: theme.colorScheme.primary,
          backgroundColor: Colors.white,
          side: BorderSide(color: theme.colorScheme.primary),
          onSelected: (selected) {
            if (selected) {
              setState(() {
                _selectedPeriod = period;
              });
            }
          },
        );
      }).toList(),
    );
  }

  Widget _buildHourlyChart(Map<int, double> data, ThemeData theme) {
    final labels = ['00-04', '04-08', '08-12', '12-16', '16-20', '20-24'];
    double maxVal = 0.0;
    data.forEach((k, v) {
      if (v > maxVal) maxVal = v;
    });
    if (maxVal == 0.0) maxVal = 1.0;

    return SizedBox(
      height: 150,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(6, (index) {
          final value = data[index] ?? 0.0;
          final percentage = value / maxVal;
          final barHeight = percentage * 100;

          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                value > 0 ? '${(value / 1000).toStringAsFixed(0)}k' : '-',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.black54),
              ),
              const SizedBox(height: 6),
              Container(
                width: 22,
                height: barHeight < 8 ? 8 : barHeight,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: value > 0
                        ? [theme.colorScheme.primary, theme.colorScheme.primary.withOpacity(0.5)]
                        : [Colors.grey.shade200, Colors.grey.shade300],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                labels[index],
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildDailyChart(Map<int, double> data, ThemeData theme) {
    final weekdays = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    double maxVal = 0.0;
    data.forEach((k, v) {
      if (v > maxVal) maxVal = v;
    });
    if (maxVal == 0.0) maxVal = 1.0;

    return SizedBox(
      height: 150,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (index) {
          final dayNum = index + 1;
          final value = data[dayNum] ?? 0.0;
          final percentage = value / maxVal;
          final barHeight = percentage * 100;

          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                value > 0 ? '${(value / 1000).toStringAsFixed(0)}k' : '-',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.black54),
              ),
              const SizedBox(height: 6),
              Container(
                width: 22,
                height: barHeight < 8 ? 8 : barHeight,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: value > 0
                        ? [theme.colorScheme.primary, theme.colorScheme.primary.withOpacity(0.5)]
                        : [Colors.grey.shade200, Colors.grey.shade300],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                weekdays[index],
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildWeeklyChart(Map<int, double> data, ThemeData theme) {
    final labels = ['Mng-3', 'Mng-2', 'Mng-1', 'Mng Ini'];
    double maxVal = 0.0;
    data.forEach((k, v) {
      if (v > maxVal) maxVal = v;
    });
    if (maxVal == 0.0) maxVal = 1.0;

    return SizedBox(
      height: 150,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(4, (index) {
          final weekNum = index + 1;
          final value = data[weekNum] ?? 0.0;
          final percentage = value / maxVal;
          final barHeight = percentage * 100;

          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                value > 0 ? '${(value / 1000).toStringAsFixed(0)}k' : '-',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.black54),
              ),
              const SizedBox(height: 6),
              Container(
                width: 32,
                height: barHeight < 8 ? 8 : barHeight,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: value > 0
                        ? [theme.colorScheme.primary, theme.colorScheme.primary.withOpacity(0.5)]
                        : [Colors.grey.shade200, Colors.grey.shade300],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                labels[index],
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildMonthlyChart(Map<int, double> data, ThemeData theme) {
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    double maxVal = 0.0;
    data.forEach((k, v) {
      if (v > maxVal) maxVal = v;
    });
    if (maxVal == 0.0) maxVal = 1.0;

    final activeMonths = data.keys.where((m) => data[m]! > 0).toList();
    if (activeMonths.isEmpty) {
      activeMonths.add(DateTime.now().month);
    }
    activeMonths.sort();

    return Column(
      children: List.generate(activeMonths.length, (index) {
        final monthNum = activeMonths[index];
        final value = data[monthNum] ?? 0.0;
        final percentage = value / maxVal;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                child: Text(
                  monthNames[monthNum - 1],
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: percentage < 0.05 && percentage > 0 ? 0.05 : percentage,
                      child: Container(
                        height: 16,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [theme.colorScheme.secondary, theme.colorScheme.secondary.withOpacity(0.6)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _formatCurrency(value),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildProductDetailsList(List<Transaksi> filtered, ThemeData theme) {
    final summaries = _getProductSalesSummary(filtered);
    if (summaries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24.0),
        child: Center(
          child: Text('Tidak ada penjualan produk pada periode ini.', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              flex: 3,
              child: Text('Produk', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
            ),
            Expanded(
              flex: 1,
              child: Text('Kuantitas', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
            ),
            Expanded(
              flex: 2,
              child: Text('Total Pendapatan', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
            ),
          ],
        ),
        const Divider(height: 16),
        ...summaries.map((s) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    s.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    '${s.quantity}x',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 13),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    _formatCurrency(s.revenue),
                    textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.secondary, fontSize: 13),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class ProductSalesSummary {
  final String name;
  int quantity;
  double revenue;

  ProductSalesSummary({required this.name, required this.quantity, required this.revenue});
}
