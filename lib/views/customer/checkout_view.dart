import 'package:flutter/material.dart';
import '../../models/cart_item.dart';
import '../../models/transaksi.dart';
import '../../services/database_service.dart';
import '../../services/cart_service.dart';
import '../../widgets/product_image_helper.dart';

class CheckoutView extends StatefulWidget {
  final List<CartItem> cartItems;
  final int idUser;

  const CheckoutView({
    super.key,
    required this.cartItems,
    required this.idUser,
  });

  @override
  State<CheckoutView> createState() => _CheckoutViewState();
}

class _CheckoutViewState extends State<CheckoutView> {
  final DatabaseService _dbService = DatabaseService();
  final CartService _cartService = CartService();

  String _selectedPayment = 'Bank Central Asia (BCA)';
  bool _isProcessing = false;
  bool _isSuccess = false;
  List<Transaksi> _savedOrders = [];

  final List<Map<String, String>> _banks = [
    {'name': 'Bank Central Asia (BCA)', 'code': 'BCA', 'account': '8839-0129-3847-001'},
    {'name': 'Bank Mandiri', 'code': 'MANDIRI', 'account': '137-00-29183-948'},
    {'name': 'Bank Rakyat Indonesia (BRI)', 'code': 'BRI', 'account': '0029-01-002938-30-2'},
    {'name': 'Bank Negara Indonesia (BNI)', 'code': 'BNI', 'account': '0239-4829-10'},
    {'name': 'GoPay / OVO / DANA', 'code': 'E-WALLET', 'account': '0812-3456-7890'},
    {'name': 'COD (Bayar di Tempat)', 'code': 'COD', 'account': '-'},
  ];

  double get _totalPrice => widget.cartItems.fold(0.0, (sum, item) => sum + item.subtotal);
  int get _totalItems => widget.cartItems.fold(0, (sum, item) => sum + item.quantity);

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

  Future<void> _handleCheckout() async {
    setState(() => _isProcessing = true);

    await _dbService.init();
    await Future.delayed(const Duration(seconds: 2));

    final bankData = _banks.firstWhere((b) => b['name'] == _selectedPayment);
    final metodeBayar = bankData['code'] == 'COD'
        ? 'COD (Bayar di Tempat)'
        : 'Transfer ${bankData['code']}';

    final now = DateTime.now();
    final List<Transaksi> savedOrders = [];

    // Save one transaction per cart item (preserving productName per item)
    for (final cartItem in widget.cartItems) {
      for (int i = 0; i < cartItem.quantity; i++) {
        final transaksi = Transaksi(
          idUser: widget.idUser,
          metodeBayar: metodeBayar,
          total: cartItem.product.price,
          productName: cartItem.product.name,
          timestamp: now,
        );
        final success = await _dbService.saveTransaksi(transaksi);
        if (success) {
          savedOrders.add(transaksi);
        }
      }
    }

    if (!mounted) return;

    if (savedOrders.isNotEmpty) {
      _cartService.clearCart();
      setState(() {
        _isProcessing = false;
        _isSuccess = true;
        _savedOrders = savedOrders;
      });
    } else {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal menyimpan transaksi. Periksa koneksi database.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isSuccess ? 'Transaksi Berhasil' : 'Checkout'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _isProcessing
          ? _buildProcessingView(theme)
          : _isSuccess
              ? _buildSuccessView(theme)
              : _buildCheckoutForm(theme),
    );
  }

  Widget _buildProcessingView(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: theme.colorScheme.primary),
          const SizedBox(height: 28),
          const Text(
            'Memproses Pembayaran...',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Menyimpan transaksi ke database.\nMohon tidak menutup aplikasi.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutForm(ThemeData theme) {
    final bankData = _banks.firstWhere((b) => b['name'] == _selectedPayment);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Ringkasan Item Section
          Text('Ringkasan Pesanan',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  ...widget.cartItems.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: ProductImageHelper.buildProductImage(
                                item.product.imageUrl,
                                width: 52,
                                height: 52,
                                fit: BoxFit.cover,
                                errorWidget: Container(
                                  width: 52,
                                  height: 52,
                                  color: theme.colorScheme.primaryContainer,
                                  child: Icon(Icons.image, color: theme.colorScheme.onPrimaryContainer, size: 20),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.product.name,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${item.quantity} × ${_formatCurrency(item.product.price)}',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              _formatCurrency(item.subtotal),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.secondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('$_totalItems item', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      Text(
                        _formatCurrency(_totalPrice),
                        style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary, fontSize: 15),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Metode Pembayaran
          Text('Metode Pembayaran',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedPayment,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      prefixIcon: const Icon(Icons.payment_outlined),
                    ),
                    items: _banks.map((bank) {
                      return DropdownMenuItem<String>(
                        value: bank['name'],
                        child: Text(bank['name']!, style: const TextStyle(fontSize: 14)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _selectedPayment = value);
                    },
                  ),
                  if (bankData['code'] != 'COD') ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${bankData['code'] == 'E-WALLET' ? 'Nomor E-Wallet' : 'No. Rekening'} ${bankData['code']}:',
                            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.amber.shade900, fontSize: 12),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(bankData['account']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              Text(
                                _formatCurrency(_totalPrice),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.secondary,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'a.n. PT KURNIA MOBILE INDONESIA',
                            style: TextStyle(color: Colors.grey.shade700, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Price breakdown
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: theme.colorScheme.primary.withValues(alpha: 0.05),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildSummaryRow('Subtotal ($_totalItems item)', _formatCurrency(_totalPrice), theme),
                  const SizedBox(height: 8),
                  _buildSummaryRow('Ongkos Kirim', 'GRATIS', theme, valueColor: Colors.green.shade600),
                  const Divider(height: 20),
                  _buildSummaryRow('TOTAL', _formatCurrency(_totalPrice), theme,
                      isBold: true, valueColor: theme.colorScheme.primary, fontSize: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          ElevatedButton(
            onPressed: _handleCheckout,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              elevation: 3,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline, size: 20),
                const SizedBox(width: 8),
                Text(
                  'KONFIRMASI PEMBAYARAN - ${_formatCurrency(_totalPrice)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outlined, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  'Transaksi Aman & Terenkripsi',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView(ThemeData theme) {
    final now = DateTime.now();
    final totalSaved = _savedOrders.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          // Success animation placeholder
          Center(
            child: Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, size: 52, color: Colors.white),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Pembayaran Berhasil!',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$totalSaved transaksi telah disimpan ke database.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 32),

          // Receipt Card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      'BUKTI TRANSAKSI RESMI',
                      style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 11, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Center(
                    child: Text(
                      'KURNIA MOBILE E-COMMERCE',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(thickness: 1.2),
                  const SizedBox(height: 12),
                  _buildReceiptRow('Tanggal', '${now.day}-${now.month}-${now.year}'),
                  _buildReceiptRow('Waktu', '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} WIB'),
                  _buildReceiptRow('Metode Bayar', _banks.firstWhere((b) => b['name'] == _selectedPayment)['code']!),
                  _buildReceiptRow('ID Pelanggan', 'USER_00${widget.idUser}'),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  // Item list
                  ...widget.cartItems.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${item.product.name} ×${item.quantity}',
                                style: const TextStyle(fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              _formatCurrency(item.subtotal),
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TOTAL DIBAYAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(
                        _formatCurrency(_totalPrice),
                        style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
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
                            'LUNAS / SUKSES',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800, fontSize: 12, letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          ElevatedButton(
            onPressed: () {
              // Pop back to dashboard safely
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('KEMBALI KE STOREFRONT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, ThemeData theme,
      {bool isBold = false, Color? valueColor, double fontSize = 13}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: fontSize)),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? Colors.black87,
            fontSize: fontSize,
          ),
        ),
      ],
    );
  }
}
