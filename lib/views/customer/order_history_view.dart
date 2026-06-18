import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:js' as js;
import 'package:flutter/foundation.dart';
import '../../services/database_service.dart';
import '../../models/transaksi.dart';
import '../../widgets/product_image_helper.dart';

class OrderHistoryView extends StatefulWidget {
  final int idUser;
  final VoidCallback? onNavigateToStorefront;
  const OrderHistoryView({super.key, required this.idUser, this.onNavigateToStorefront});

  @override
  State<OrderHistoryView> createState() => _OrderHistoryViewState();
}

class _OrderHistoryViewState extends State<OrderHistoryView> {
  final DatabaseService _dbService = DatabaseService();
  List<Transaksi> _allOrders = [];
  List<Transaksi> _filteredOrders = [];
  bool _isLoading = true;
  bool _hasError = false;

  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'Semua';

  @override
  void initState() {
    super.initState();
    _fetchOrders();
    _searchController.addListener(_onSearchOrFilterChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchOrFilterChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      await _dbService.init();
      // Simulate API/Database latency to align with existing design
      await Future.delayed(const Duration(milliseconds: 1000));
      
      final orders = await _dbService.getTransactionsByUserId(widget.idUser);
      
      if (!mounted) return;
      setState(() {
        _allOrders = orders;
        _isLoading = false;
      });
      _onSearchOrFilterChanged();
    } catch (e) {
      debugPrint('Error loading order history: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  void _onSearchOrFilterChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredOrders = _allOrders.where((order) {
        // Filter by Product Name
        final matchesQuery = order.productName.toLowerCase().contains(query);
        
        // Filter by Payment Method type
        if (_selectedFilter == 'Semua') {
          return matchesQuery;
        } else if (_selectedFilter == 'Transfer BCA') {
          return matchesQuery && order.metodeBayar.contains('BCA');
        } else if (_selectedFilter == 'Transfer Mandiri') {
          return matchesQuery && order.metodeBayar.contains('MANDIRI');
        } else if (_selectedFilter == 'Transfer BRI') {
          return matchesQuery && order.metodeBayar.contains('BRI');
        } else if (_selectedFilter == 'Transfer BNI') {
          return matchesQuery && order.metodeBayar.contains('BNI');
        }
        return matchesQuery;
      }).toList();
    });
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

  String _formatDateTime(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day-$month-$year $hour:$minute WIB';
  }

  void _launchPaymentUrl(String urlString) {
    if (kIsWeb) {
      String? snapToken;
      try {
        final uri = Uri.parse(urlString);
        if (uri.pathSegments.isNotEmpty) {
          snapToken = uri.pathSegments.last;
        }
      } catch (_) {}

      if (snapToken != null && snapToken.isNotEmpty) {
        try {
          js.context.callMethod('payWithMidtrans', [snapToken]);
          return;
        } catch (e) {
          debugPrint('JS payWithMidtrans error, falling back: $e');
        }
      }

      // Fallback 1: Use window.redirectToUrl
      try {
        js.context.callMethod('redirectToUrl', [urlString]);
        return;
      } catch (e) {
        debugPrint('JS redirectToUrl error, falling back: $e');
      }

      // Fallback 2: Direct URL Launch (popup window)
      try {
        final uri = Uri.parse(urlString);
        launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('Launch URL error fallback: $e');
      }
    } else {
      final uri = Uri.parse(urlString);
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    IconData icon;
    String label;

    switch (status.toLowerCase()) {
      case 'success':
      case 'settlement':
      case 'capture':
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade800;
        icon = Icons.verified;
        label = 'Sukses';
        break;
      case 'pending':
        bgColor = Colors.amber.shade50;
        textColor = Colors.amber.shade900;
        icon = Icons.schedule;
        label = 'Pending';
        break;
      case 'deny':
      case 'cancel':
      case 'expire':
      case 'failure':
        bgColor = Colors.red.shade50;
        textColor = Colors.red.shade800;
        icon = Icons.error_outline;
        label = 'Gagal';
        break;
      default:
        bgColor = Colors.grey.shade50;
        textColor = Colors.grey.shade800;
        icon = Icons.help_outline;
        label = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderStateBadge(String status) {
    Color bgColor;
    Color textColor;
    IconData icon;
    String label;

    switch (status.toLowerCase()) {
      case 'pending':
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
        icon = Icons.hourglass_empty;
        label = 'Pending';
        break;
      case 'dikemas':
        bgColor = Colors.blue.shade50;
        textColor = Colors.blue.shade800;
        icon = Icons.inventory_2_outlined;
        label = 'Dikemas';
        break;
      case 'diantar':
        bgColor = Colors.orange.shade50;
        textColor = Colors.orange.shade800;
        icon = Icons.local_shipping_outlined;
        label = 'Diantar';
        break;
      case 'selesai':
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade800;
        icon = Icons.check_circle_outline;
        label = 'Selesai';
        break;
      default:
        bgColor = Colors.grey.shade50;
        textColor = Colors.grey.shade800;
        icon = Icons.help_outline;
        label = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderProgressTrack(String currentStatus) {
    final statuses = ['pending', 'dikemas', 'diantar', 'selesai'];
    final currentIndex = statuses.indexOf(currentStatus.toLowerCase());
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(statuses.length, (index) {
          final statusName = statuses[index];
          final isActive = index <= currentIndex;
          final isDone = index < currentIndex;
          
          Color activeColor = Colors.grey;
          IconData iconData = Icons.radio_button_unchecked;
          String displayLabel = 'Menunggu';

          if (statusName == 'pending') {
            activeColor = Colors.amber.shade700;
            iconData = Icons.payment;
            displayLabel = 'Bayar';
          } else if (statusName == 'dikemas') {
            activeColor = Colors.blue;
            iconData = Icons.inventory_2;
            displayLabel = 'Dikemas';
          } else if (statusName == 'diantar') {
            activeColor = Colors.orange;
            iconData = Icons.local_shipping;
            displayLabel = 'Diantar';
          } else if (statusName == 'selesai') {
            activeColor = Colors.green;
            iconData = Icons.check_circle;
            displayLabel = 'Selesai';
          }

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isActive ? activeColor : Colors.grey.shade200,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isDone ? Icons.check : iconData,
                          size: 16,
                          color: isActive ? Colors.white : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        displayLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          color: isActive ? activeColor : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (index < statuses.length - 1)
                  Container(
                    width: 20,
                    height: 2,
                    color: index < currentIndex ? activeColor : Colors.grey.shade300,
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  void _showOrderInvoice(Transaksi order) {
    final theme = Theme.of(context);
    final txIdStr = order.idTransaksi != null ? 'TRX_00${order.idTransaksi}' : 'TRX_N/A';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Invoice Title
                const Text(
                  'RINCIAN TRANSAKSI',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'KURNIA MOBILE E-COMMERCE',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildOrderProgressTrack(order.statusPesanan),
                const SizedBox(height: 16),
                const Divider(thickness: 1.2),
                const SizedBox(height: 12),

                // Transaction Details Rows
                _buildInvoiceRow('Status Transaksi', order.statusPembayaran, isStatus: true, theme: theme),
                _buildInvoiceRow('ID Transaksi', txIdStr, isBold: true),
                _buildInvoiceRow('Tanggal & Waktu', _formatDateTime(order.timestamp)),
                () {
                  String courierInfo = '-';
                  String basePaymentMethod = order.metodeBayar;
                  if (order.metodeBayar.contains('(') && order.metodeBayar.contains(')')) {
                    final startIndex = order.metodeBayar.indexOf('(') + 1;
                    final endIndex = order.metodeBayar.indexOf(')');
                    courierInfo = order.metodeBayar.substring(startIndex, endIndex);
                    basePaymentMethod = order.metodeBayar.substring(0, startIndex - 1).trim();
                  }
                  return Column(
                    children: [
                      _buildInvoiceRow('Metode Pembayaran', basePaymentMethod),
                      if (courierInfo != '-')
                        _buildInvoiceRow('Kurir & Ongkir', courierInfo),
                    ],
                  );
                }(),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                
                // Product details row
                Text(
                  'Detail Pembelian:',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                (() {
                  double itemsSum = 0;
                  if (order.items != null) {
                    for (var item in order.items!) {
                      itemsSum += item.subtotal;
                    }
                  }
                  final shippingFee = order.total - itemsSum;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (order.items != null && order.items!.isNotEmpty) ...[
                        ...order.items!.map((item) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade100),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(
                                    width: 50,
                                    height: 50,
                                    child: ProductImageHelper.buildProductImage(
                                      item.gambarProduk,
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.namaProduk,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${item.jumlah} pcs x ${_formatCurrency(item.hargaSatuan)}',
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatCurrency(item.subtotal),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                          );
                        }),
                        if (shippingFee > 0.01) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade100),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: 50,
                                    height: 50,
                                    color: Colors.orange.shade50,
                                    child: Icon(Icons.local_shipping_outlined, color: Colors.orange.shade700),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Biaya Pengiriman (Ongkir)',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Pengiriman Kurir',
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatCurrency(shippingFee),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ] else ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                order.productName,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              _formatCurrency(order.total),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ],
                  );
                })(),
                const SizedBox(height: 16),
                const Divider(thickness: 1.2),
                const SizedBox(height: 12),

                // Total price row
                _buildInvoiceRow(
                  'TOTAL DIBAYAR',
                  _formatCurrency(order.total),
                  isBold: true,
                  fontSize: 16,
                  color: theme.colorScheme.primary,
                ),
                
                const SizedBox(height: 32),
                
                if (order.statusPembayaran.toLowerCase() == 'pending') ...[
                  ElevatedButton.icon(
                    onPressed: () async {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const Center(child: CircularProgressIndicator()),
                      );

                      final res = await _dbService.checkMidtransStatus(order.midtransOrderId);
                      
                      if (mounted) Navigator.pop(context);
                      if (mounted) Navigator.pop(sheetContext);

                      if (res != null && res['status'] == 'success') {
                        final localStatus = res['local_status'] as String;
                        if (localStatus == 'success') {
                          _fetchOrders();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Pembayaran berhasil dikonfirmasi!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Status Midtrans: ${res['transaction_status']}'),
                                backgroundColor: Colors.amber,
                              ),
                            );
                          }
                        }
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Gagal memeriksa status. Coba lagi.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Cek Status Pembayaran', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (order.statusPembayaran.toLowerCase() == 'pending') ...[
                  OutlinedButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: const Text('Batalkan Pesanan'),
                          content: const Text('Apakah Anda yakin ingin membatalkan pesanan ini? Transaksi pending ini akan dihapus permanen dari riwayat.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Batal'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Batalkan'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const Center(child: CircularProgressIndicator()),
                        );

                        final success = await _dbService.deleteTransaction(
                          idTransaksi: order.idTransaksi,
                          midtransOrderId: order.midtransOrderId,
                        );

                        if (mounted) Navigator.pop(context); // Pop loading
                        if (mounted) Navigator.pop(sheetContext); // Pop sheet

                        if (success) {
                          _fetchOrders(); // Refresh orders list
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Pesanan berhasil dibatalkan dan dihapus.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Gagal membatalkan pesanan.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Batalkan & Hapus Pesanan', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (order.statusPembayaran.toLowerCase() == 'pending' &&
                    order.midtransRedirectUrl.isNotEmpty) ...[
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _launchPaymentUrl(order.midtransRedirectUrl);
                    },
                    icon: const Icon(Icons.payment_outlined),
                    label: const Text('Bayar Sekarang (Midtrans)', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (order.statusPembayaran.toLowerCase() == 'success' ||
                    order.statusPembayaran.toLowerCase() == 'settlement' ||
                    order.statusPembayaran.toLowerCase() == 'capture') ...[
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      final uri = Uri.parse('https://dashboard.sandbox.midtrans.com/');
                      launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                    icon: const Icon(Icons.dashboard_outlined),
                    label: const Text('Masuk ke Dashboard Midtrans', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                if (order.statusPesanan.toLowerCase() == 'diantar') ...[
                  ElevatedButton.icon(
                    onPressed: () async {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const Center(child: CircularProgressIndicator()),
                      );

                      final success = await _dbService.updateOrderStatus(order.idTransaksi!, 'selesai');
                      
                      if (mounted) Navigator.pop(context); // Pop loading
                      if (mounted) Navigator.pop(sheetContext); // Pop sheet

                      if (success) {
                        _fetchOrders();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Pesanan berhasil diselesaikan! Terima kasih telah berbelanja.'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Gagal menyelesaikan pesanan.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Konfirmasi Barang Diterima', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Row(
                                children: [
                                  Icon(Icons.print, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text('Sedang menyiapkan pencetakan struk...'),
                                ],
                              ),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: theme.colorScheme.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        },
                        icon: const Icon(Icons.print_outlined),
                        label: const Text('Cetak Struk', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInvoiceRow(String label, String value,
      {bool isBold = false, double fontSize = 13, Color? color, bool isStatus = false, ThemeData? theme}) {
    Widget valueWidget;
    if (isStatus && theme != null) {
      valueWidget = _buildStatusBadge(value);
    } else {
      valueWidget = Text(
        value,
        style: TextStyle(
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontSize: fontSize,
          color: color ?? Colors.black87,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: fontSize),
          ),
          valueWidget,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Memuat riwayat transaksi...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : _hasError
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 60, color: Colors.red),
                        const SizedBox(height: 16),
                        const Text(
                          'Gagal Memuat Riwayat',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Terjadi masalah saat mengambil data dari server database kurnia.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _fetchOrders,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Coba Lagi'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchOrders,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Search Bar
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Cari transaksi berdasarkan nama produk...',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Filter Chips Row
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              'Semua',
                              'Transfer BCA',
                              'Transfer Mandiri',
                              'Transfer BRI',
                              'Transfer BNI'
                            ].map((filter) {
                              final isSelected = _selectedFilter == filter;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ChoiceChip(
                                  label: Text(
                                    filter,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  selected: isSelected,
                                  selectedColor: theme.colorScheme.primary,
                                  backgroundColor: Colors.grey.shade200,
                                  onSelected: (val) {
                                    if (val) {
                                      setState(() {
                                        _selectedFilter = filter;
                                      });
                                      _onSearchOrFilterChanged();
                                    }
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Section Title
                        Text(
                          'Daftar Pembelian Anda',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Orders List
                        Expanded(
                          child: _filteredOrders.isEmpty
                              ? _buildEmptyState(theme)
                              : ListView.builder(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  itemCount: _filteredOrders.length,
                                  itemBuilder: (context, index) {
                                    final order = _filteredOrders[index];
                                    final txIdStr = order.idTransaksi != null
                                        ? 'TRX_00${order.idTransaksi}'
                                        : 'TRX_N/A';
                                    
                                    // Determine icon based on payment bank
                                    IconData payIcon = Icons.payments_outlined;
                                    if (order.metodeBayar.contains('BCA')) {
                                      payIcon = Icons.account_balance_outlined;
                                    } else if (order.metodeBayar.contains('Mandiri')) {
                                      payIcon = Icons.account_balance_outlined;
                                    } else if (order.metodeBayar.contains('BRI')) {
                                      payIcon = Icons.account_balance_outlined;
                                    } else if (order.metodeBayar.contains('BNI')) {
                                      payIcon = Icons.account_balance_outlined;
                                    }
                                    
                                    return Card(
                                      elevation: 2,
                                      margin: const EdgeInsets.only(bottom: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: InkWell(
                                        onTap: () => _showOrderInvoice(order),
                                        borderRadius: BorderRadius.circular(16),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Card Header: ID and Status
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    txIdStr,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.grey,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                   Row(
                                                     children: [
                                                       _buildStatusBadge(order.statusPembayaran),
                                                       const SizedBox(width: 6),
                                                       _buildOrderStateBadge(order.statusPesanan),
                                                     ],
                                                   ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),

                                              // Product details
                                              Text(
                                                order.productName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),

                                              Text(
                                                _formatDateTime(order.timestamp),
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 11,
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              const Divider(height: 1),
                                              const SizedBox(height: 12),

                                              // Card Footer: Payment and Price
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        payIcon,
                                                        size: 16,
                                                        color: theme.colorScheme.secondary,
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        order.metodeBayar,
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Text(
                                                    _formatCurrency(order.total),
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      color: theme.colorScheme.primary,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (order.statusPembayaran.toLowerCase() == 'pending' &&
                                                  order.midtransRedirectUrl.isNotEmpty) ...[
                                                const SizedBox(height: 12),
                                                const Divider(height: 1),
                                                const SizedBox(height: 12),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.end,
                                                  children: [
                                                    TextButton.icon(
                                                      onPressed: () => _launchPaymentUrl(order.midtransRedirectUrl),
                                                      icon: const Icon(Icons.payment_outlined, size: 16),
                                                      label: const Text('Bayar Sekarang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                      style: TextButton.styleFrom(
                                                        foregroundColor: Colors.amber.shade900,
                                                        backgroundColor: Colors.amber.shade50,
                                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(10),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    final bool isSearchActive = _searchController.text.isNotEmpty || _selectedFilter != 'Semua';
    
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSearchActive ? Icons.search_off_outlined : Icons.receipt_long_outlined,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isSearchActive ? 'Pesanan Tidak Ditemukan' : 'Belum Ada Transaksi',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isSearchActive
                    ? 'Cobalah kata kunci lain atau ubah penyaringan bank transfer Anda.'
                    : 'Anda belum pernah melakukan pemesanan. Segera pilih produk kebutuhan Anda di toko!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 24),
              if (!isSearchActive)
                ElevatedButton.icon(
                  onPressed: widget.onNavigateToStorefront,
                  icon: const Icon(Icons.shopping_bag_outlined),
                  label: const Text('Mulai Belanja', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
