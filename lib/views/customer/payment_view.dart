import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/product.dart';
import '../../models/transaksi.dart';
import '../../widgets/product_image_helper.dart';

class PaymentView extends StatefulWidget {
  final Product product;
  final int idUser;
  const PaymentView({super.key, required this.product, required this.idUser});

  @override
  State<PaymentView> createState() => _PaymentViewState();
}

class _PaymentViewState extends State<PaymentView> {
  final DatabaseService _dbService = DatabaseService();
  String _selectedBank = 'Bank Central Asia (BCA)';
  bool _isProcessing = false;
  bool _isPaid = false;
  Transaksi? _createdOrder;

  final List<Map<String, String>> _banks = [
    {'name': 'Bank Central Asia (BCA)', 'code': 'BCA', 'account': '8839-0129-3847-001', 'owner': 'PT KURNIA MOBILE INDONESIA'},
    {'name': 'Bank Mandiri', 'code': 'MANDIRI', 'account': '137-00-29183-948', 'owner': 'PT KURNIA MOBILE INDONESIA'},
    {'name': 'Bank Rakyat Indonesia (BRI)', 'code': 'BRI', 'account': '0029-01-002938-30-2', 'owner': 'PT KURNIA MOBILE INDONESIA'},
    {'name': 'Bank Negara Indonesia (BNI)', 'code': 'BNI', 'account': '0239-4829-10', 'owner': 'PT KURNIA MOBILE INDONESIA'},
  ];

  @override
  void initState() {
    super.initState();
    _dbService.init();
  }

  void _handlePayment() async {
    setState(() {
      _isProcessing = true;
    });

    // Emulate payment processing and validation (e.g. checking transfer status)
    await Future.delayed(const Duration(seconds: 2));

    final selectedBankData = _banks.firstWhere((b) => b['name'] == _selectedBank);

    // Create Transaksi object matching MySQL DDL attributes
    final order = Transaksi(
      idUser: widget.idUser,
      metodeBayar: 'Transfer Bank (${selectedBankData['code']})',
      total: widget.product.price,
      productName: widget.product.name,
      timestamp: DateTime.now(),
    );

    // Call database setData() -> saveTransaksi
    final success = await _dbService.saveTransaksi(order);

    if (!mounted) return;

    setState(() {
      _isProcessing = false;
    });

    if (success) {
      // Fetch latest transaction to show the auto-increment id
      final txList = await _dbService.getTransactions();
      final savedTx = txList.isNotEmpty ? txList.last : order;

      setState(() {
        _isPaid = true;
        _createdOrder = savedTx;
      });

      // Show "Pembayaran berhasil" snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Pembayaran Berhasil! Transaksi telah diproses.'),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Terjadi kesalahan saat menyimpan data pembayaran.'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
    final selectedBankData = _banks.firstWhere((b) => b['name'] == _selectedBank);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isPaid ? 'Bukti Pembayaran' : 'Halaman Pembayaran'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _isProcessing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text(
                    'Memvalidasi Pembayaran...',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Mohon tidak menutup aplikasi saat kami menverifikasi transfer Anda.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : _isPaid && _createdOrder != null
              ? _buildReceiptView(theme)
              : _buildCheckoutForm(theme, selectedBankData),
    );
  }

  Widget _buildCheckoutForm(ThemeData theme, Map<String, String> bankData) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Order Summary Card (rincian pesanan)
          Text(
            'Rincian Pesanan',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ProductImageHelper.buildProductImage(
                      widget.product.imageUrl,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorWidget: Container(
                        width: 80,
                        height: 80,
                        color: theme.colorScheme.primaryContainer,
                        child: Icon(Icons.image, color: theme.colorScheme.onPrimaryContainer),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.product.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.product.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _formatCurrency(widget.product.price),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.secondary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Payment Method Selector
          Text(
            'Metode Pembayaran',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pilih Bank Transfer:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedBank,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: _banks.map((bank) {
                      return DropdownMenuItem<String>(
                        value: bank['name'],
                        child: Text(bank['name']!, style: const TextStyle(fontSize: 14)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedBank = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  // Bank Detail Instructions Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Instruksi Transfer ${bankData['code']}:',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Nomor Rekening:', style: TextStyle(fontSize: 12)),
                            SelectableText(
                              bankData['account']!,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Atas Nama:', style: TextStyle(fontSize: 12)),
                            Text(
                              bankData['owner']!,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Transfer:', style: TextStyle(fontSize: 12)),
                            Text(
                              _formatCurrency(widget.product.price),
                              style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.secondary, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Pay Now Button
          ElevatedButton(
            onPressed: _handlePayment,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'BAYAR SEKARANG',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  // Invoice / Payment Proof Screen ("kirim bukti pembayaran ke pelanggan" -> Tampil di layar sebagai receipt)
  Widget _buildReceiptView(ThemeData theme) {
    final order = _createdOrder!;
    final txIdStr = order.idTransaksi != null ? 'TRX_00${order.idTransaksi}' : 'TRX_N/A';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          // Receipt Header Icon
          const Center(
            child: CircleAvatar(
              radius: 36,
              backgroundColor: Colors.green,
              child: Icon(Icons.check, size: 48, color: Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Pembayaran Berhasil!',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.green),
          ),
          Text(
            'Bukti pembayaran elektronik Anda telah diterbitkan.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 32),

          // Decorative Ticket Card Receipt
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      'BUKTI TRANSAKSI RESMI (MySQL)',
                      style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 11, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'KURNIA MOBILE E-COMMERCE',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(thickness: 1.2, color: Colors.grey),
                  const SizedBox(height: 16),

                  _buildReceiptRow('ID Transaksi (Auto)', txIdStr, isBoldValue: true),
                  _buildReceiptRow('ID Pelanggan (FK)', 'USER_00${order.idUser}'),
                  _buildReceiptRow('Tanggal & Waktu', '${order.timestamp.day}-${order.timestamp.month}-${order.timestamp.year} ${order.timestamp.hour.toString().padLeft(2, '0')}:${order.timestamp.minute.toString().padLeft(2, '0')} WIB'),
                  _buildReceiptRow('Metode Pembayaran', order.metodeBayar),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  _buildReceiptRow('Nama Produk', order.productName),
                  _buildReceiptRow('Harga Satuan', _formatCurrency(order.total)),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  _buildReceiptRow(
                    'TOTAL DIBAYAR',
                    _formatCurrency(order.total),
                    isBoldValue: true,
                    valueColor: theme.colorScheme.primary,
                    fontSize: 16,
                  ),

                  const SizedBox(height: 24),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified, size: 16, color: Colors.green.shade700),
                          const SizedBox(width: 6),
                          Text(
                            'Lunas / Sukses',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Return Home Button
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Go back to Dashboard
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('KEMBALI KE STOREFRONT', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value,
      {bool isBoldValue = false, Color? valueColor, double fontSize = 13}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: fontSize)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: isBoldValue ? FontWeight.bold : FontWeight.normal,
                color: valueColor ?? Colors.black87,
                fontSize: fontSize,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
