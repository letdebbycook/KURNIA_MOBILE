import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:js' as js;
import 'package:flutter/foundation.dart';
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

  String _selectedPayment = 'Midtrans (Pembayaran Online)';
  bool _isProcessing = false;
  bool _isSuccess = false;
  List<Transaksi> _savedOrders = [];

  final List<Map<String, String>> _banks = [
    {'name': 'Midtrans (Pembayaran Online)', 'code': 'MIDTRANS', 'account': '-'},
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

  void _openPayment(String redirectUrl) {
    if (kIsWeb) {
      String? snapToken;
      try {
        final uri = Uri.parse(redirectUrl);
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
        js.context.callMethod('redirectToUrl', [redirectUrl]);
        return;
      } catch (e) {
        debugPrint('JS redirectToUrl error, falling back: $e');
      }

      // Fallback 2: Direct URL Launch (popup window)
      try {
        final uri = Uri.parse(redirectUrl);
        launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('Launch URL error fallback: $e');
      }
    } else {
      final uri = Uri.parse(redirectUrl);
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _handleCheckout() async {
    setState(() => _isProcessing = true);

    await _dbService.init();
    // Short delay for UI feedback feel
    await Future.delayed(const Duration(milliseconds: 300));

    final metodeBayar = 'Midtrans';
    final now = DateTime.now();
    final List<Transaksi> savedOrders = [];

    // Midtrans Sandbox SNAP Payment Gateway Integration
    try {
      final dummyTransaksi = Transaksi(
        idUser: widget.idUser,
        metodeBayar: metodeBayar,
        total: _totalPrice,
        productName: widget.cartItems.map((e) => e.product.name).join(', '),
        timestamp: now,
      );

      final res = await _dbService.createMidtransTransaction(dummyTransaksi, widget.cartItems);
      if (res != null && res['midtrans_redirect_url'] != null) {
        final redirectUrl = res['midtrans_redirect_url'] as String;

        // Reconstruct transaction lists to show success info
        final orderId = res['midtrans_order_id'] as String;
        for (final cartItem in widget.cartItems) {
          for (int i = 0; i < cartItem.quantity; i++) {
            savedOrders.add(Transaksi(
              idUser: widget.idUser,
              metodeBayar: metodeBayar,
              total: cartItem.product.price,
              productName: cartItem.product.name,
              timestamp: now,
              statusPembayaran: 'pending',
              midtransOrderId: orderId,
              midtransRedirectUrl: redirectUrl,
            ));
          }
        }

        // Launch the payment redirection page
        _openPayment(redirectUrl);
      }
    } catch (e) {
      debugPrint('Midtrans Snap initiation error: $e');
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
            content: Text('Gagal memproses transaksi. Periksa koneksi internet.'),
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
    // Midtrans only, no bankData dropdown selection needed

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
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.security, color: theme.colorScheme.primary, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Midtrans (Pembayaran Online)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Mendukung Transfer Bank, GoPay, ShopeePay, Alfamart, dll.',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Text(
                      'SANDBOX',
                      style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold, fontSize: 9),
                    ),
                  ),
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
    final isPendingPayment = _savedOrders.isNotEmpty &&
        _savedOrders.any((t) => t.statusPembayaran == 'pending');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          // Success/Pending animation placeholder
          Center(
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: isPendingPayment ? Colors.amber : Colors.green,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPendingPayment ? Icons.payment_outlined : Icons.check,
                size: 48,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isPendingPayment ? 'Instruksi Pembayaran Dibuka!' : 'Pesanan Berhasil Dibuat!',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: isPendingPayment ? Colors.amber.shade800 : Colors.green.shade700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isPendingPayment
                ? 'Silakan selesaikan pembayaran pada halaman Midtrans Sandbox yang baru saja dibuka.'
                : '$totalSaved transaksi telah sukses disimpan ke database.',
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
                  if (isPendingPayment && _savedOrders.isNotEmpty)
                    _buildReceiptRow('Order ID Midtrans', _savedOrders.first.midtransOrderId),
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
                        color: isPendingPayment ? Colors.amber.shade50 : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: isPendingPayment ? Colors.amber.shade200 : Colors.green.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPendingPayment ? Icons.schedule : Icons.verified,
                            size: 16,
                            color: isPendingPayment ? Colors.amber.shade800 : Colors.green.shade700,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isPendingPayment ? 'PENDING / BELUM BAYAR' : 'LUNAS / SUKSES',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isPendingPayment ? Colors.amber.shade900 : Colors.green.shade800,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
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

          if (isPendingPayment && _savedOrders.isNotEmpty) ...[
            ElevatedButton.icon(
              onPressed: () async {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(child: CircularProgressIndicator()),
                );
                
                final orderId = _savedOrders.first.midtransOrderId;
                final res = await _dbService.checkMidtransStatus(orderId);
                
                if (mounted) Navigator.pop(context);
                
                if (res != null && res['status'] == 'success') {
                  final localStatus = res['local_status'] as String;
                  if (localStatus == 'success') {
                    setState(() {
                      _savedOrders = _savedOrders.map((t) => Transaksi(
                        idTransaksi: t.idTransaksi,
                        idUser: t.idUser,
                        metodeBayar: t.metodeBayar,
                        total: t.total,
                        productName: t.productName,
                        timestamp: t.timestamp,
                        statusPembayaran: 'success',
                        midtransOrderId: t.midtransOrderId,
                        midtransRedirectUrl: t.midtransRedirectUrl,
                      )).toList();
                    });
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
                          content: Text('Pembayaran belum diterima. Status: ${res['transaction_status']}'),
                          backgroundColor: Colors.amber,
                        ),
                      );
                    }
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Gagal memeriksa status pembayaran. Coba lagi.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('SELESAI / CEK STATUS PEMBAYARAN', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (isPendingPayment && _savedOrders.isNotEmpty && _savedOrders.first.midtransRedirectUrl.isNotEmpty) ...[
            ElevatedButton.icon(
              onPressed: () {
                _openPayment(_savedOrders.first.midtransRedirectUrl);
              },
              icon: const Icon(Icons.payment_outlined),
              label: const Text('BUKA KEMBALI HALAMAN BAYAR', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                backgroundColor: Colors.amber.shade700,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (!isPendingPayment) ...[
            ElevatedButton.icon(
              onPressed: () {
                final uri = Uri.parse('https://dashboard.sandbox.midtrans.com/');
                launchUrl(uri, mode: LaunchMode.externalApplication);
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              icon: const Icon(Icons.dashboard_outlined),
              label: const Text('SELESAI & MASUK KE DASHBOARD MIDTRANS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                elevation: 3,
              ),
            ),
            const SizedBox(height: 12),
          ],

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
