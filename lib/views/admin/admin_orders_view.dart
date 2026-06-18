import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/transaksi.dart';
import '../../widgets/product_image_helper.dart';

class AdminOrdersView extends StatefulWidget {
  const AdminOrdersView({super.key});

  @override
  State<AdminOrdersView> createState() => _AdminOrdersViewState();
}

class _AdminOrdersViewState extends State<AdminOrdersView> {
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
      final orders = await _dbService.getTransactions();
      
      if (!mounted) return;
      setState(() {
        _allOrders = orders;
        _isLoading = false;
      });
      _onSearchOrFilterChanged();
    } catch (e) {
      debugPrint('Error loading orders: $e');
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
        final matchesQuery = order.productName.toLowerCase().contains(query) ||
            (order.userNama ?? '').toLowerCase().contains(query) ||
            order.midtransOrderId.toLowerCase().contains(query);

        if (_selectedFilter == 'Semua') {
          return matchesQuery;
        } else if (_selectedFilter == 'Pending') {
          return matchesQuery && order.statusPesanan.toLowerCase() == 'pending';
        } else if (_selectedFilter == 'Dikemas') {
          return matchesQuery && order.statusPesanan.toLowerCase() == 'dikemas';
        } else if (_selectedFilter == 'Diantar') {
          return matchesQuery && order.statusPesanan.toLowerCase() == 'diantar';
        } else if (_selectedFilter == 'Selesai') {
          return matchesQuery && order.statusPesanan.toLowerCase() == 'selesai';
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

  Widget _buildStatusBadge(String status, bool isPayment) {
    Color bgColor;
    Color textColor;
    IconData icon;
    String label = status;

    if (isPayment) {
      switch (status.toLowerCase()) {
        case 'success':
        case 'settlement':
        case 'capture':
          bgColor = Colors.green.shade50;
          textColor = Colors.green.shade800;
          icon = Icons.verified;
          label = 'Lunas';
          break;
        case 'pending':
          bgColor = Colors.amber.shade50;
          textColor = Colors.amber.shade900;
          icon = Icons.schedule;
          label = 'Belum Bayar';
          break;
        default:
          bgColor = Colors.red.shade50;
          textColor = Colors.red.shade800;
          icon = Icons.error_outline;
          label = 'Gagal';
      }
    } else {
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
      }
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

  void _showOrderDetailSheet(Transaksi order) {
    final theme = Theme.of(context);
    final txIdStr = order.idTransaksi != null ? 'TRX_00${order.idTransaksi}' : 'TRX_N/A';
    String newStatus = order.statusPesanan;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
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
                    
                    const Text(
                      'KELOLA PESANAN PELANGGAN',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(thickness: 1.2),
                    const SizedBox(height: 12),

                    // Customer Details
                    Text(
                      'Informasi Pelanggan:',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildInvoiceRow('Nama Pelanggan', order.userNama ?? 'N/A', isBold: true),
                    _buildInvoiceRow('No. Telepon', order.userTelepon ?? 'N/A'),
                    _buildInvoiceRow('Alamat Pengiriman', order.userAlamat ?? 'Alamat belum diatur', isMultiline: true),
                    
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),

                    // Order Details
                    Text(
                      'Informasi Pesanan:',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildInvoiceRow('ID Transaksi', txIdStr, isBold: true),
                    if (order.midtransOrderId.isNotEmpty)
                      _buildInvoiceRow('ID Order Midtrans', order.midtransOrderId),
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
                    _buildInvoiceRow('Status Pembayaran', order.statusPembayaran, isStatus: true, isPayment: true),
                    
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),

                    Text(
                      'Item Pembelian:',
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

                    _buildInvoiceRow(
                      'TOTAL DITERIMA',
                      _formatCurrency(order.total),
                      isBold: true,
                      fontSize: 16,
                      color: theme.colorScheme.primary,
                    ),

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 12),

                    // Status Management Stepper/Radio
                    Text(
                      'Perbarui Status Pengiriman:',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Stepper-like Segmented buttons or chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['pending', 'dikemas', 'diantar', 'selesai'].map((status) {
                        final isSelected = newStatus == status;
                        Color statusColor = Colors.grey;
                        IconData statusIcon = Icons.hourglass_empty;

                        if (status == 'dikemas') {
                          statusColor = Colors.blue;
                          statusIcon = Icons.inventory_2_outlined;
                        } else if (status == 'diantar') {
                          statusColor = Colors.orange;
                          statusIcon = Icons.local_shipping_outlined;
                        } else if (status == 'selesai') {
                          statusColor = Colors.green;
                          statusIcon = Icons.check_circle_outline;
                        }

                        return ChoiceChip(
                          avatar: Icon(
                            statusIcon,
                            size: 14,
                            color: isSelected ? Colors.white : statusColor,
                          ),
                          label: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: statusColor,
                          backgroundColor: Colors.grey.shade100,
                          onSelected: (val) {
                            if (val) {
                              setSheetState(() {
                                newStatus = status;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    
                    const SizedBox(height: 32),

                    // Update Action Button
                    ElevatedButton.icon(
                      onPressed: () async {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const Center(child: CircularProgressIndicator()),
                        );

                        final success = await _dbService.updateOrderStatus(order.idTransaksi!, newStatus);
                        
                        if (mounted) Navigator.pop(context); // Pop loading
                        if (mounted) Navigator.pop(sheetContext); // Pop sheet

                        if (success) {
                          _fetchOrders(); // Reload orders list
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.check_circle, color: Colors.white),
                                    const SizedBox(width: 8),
                                    Text('Status pesanan berhasil diubah menjadi ${newStatus.toUpperCase()}'),
                                  ],
                                ),
                                backgroundColor: Colors.green.shade600,
                              ),
                            );
                          }
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Gagal memperbarui status pesanan.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('SIMPAN PERUBAHAN STATUS', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInvoiceRow(String label, String value,
      {bool isBold = false, double fontSize = 13, Color? color, bool isStatus = false, bool isPayment = false, bool isMultiline = false}) {
    Widget valueWidget;
    if (isStatus) {
      valueWidget = _buildStatusBadge(value, isPayment);
    } else {
      valueWidget = isMultiline
          ? Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  fontSize: fontSize,
                  color: color ?? Colors.black87,
                ),
              ),
            )
          : Text(
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
        crossAxisAlignment: isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: fontSize),
          ),
          const SizedBox(width: 16),
          valueWidget,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Pesanan Pelanggan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 60, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text(
                        'Gagal Memuat Pesanan',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _fetchOrders,
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Search Bar
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Cari berdasarkan Nama, Order ID, atau Produk...',
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

                      // Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: ['Semua', 'Pending', 'Dikemas', 'Diantar', 'Selesai'].map((filter) {
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

                      // Order List
                      Expanded(
                        child: _filteredOrders.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Tidak ada pesanan untuk filter ini',
                                      style: TextStyle(color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: _filteredOrders.length,
                                itemBuilder: (context, index) {
                                  final order = _filteredOrders[index];
                                  final txIdStr = order.idTransaksi != null
                                      ? 'TRX_00${order.idTransaksi}'
                                      : 'TRX_N/A';

                                  return Card(
                                    elevation: 2,
                                    margin: const EdgeInsets.only(bottom: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: InkWell(
                                      onTap: () => _showOrderDetailSheet(order),
                                      borderRadius: BorderRadius.circular(16),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
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
                                                    _buildStatusBadge(order.statusPembayaran, true),
                                                    const SizedBox(width: 8),
                                                    _buildStatusBadge(order.statusPesanan, false),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              order.productName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  'Pelanggan: ${order.userNama ?? "N/A"}',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade700,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                  ),
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
                                            const SizedBox(height: 4),
                                            Text(
                                              _formatDateTime(order.timestamp),
                                              style: TextStyle(
                                                color: Colors.grey.shade500,
                                                fontSize: 11,
                                              ),
                                            ),
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
    );
  }
}
