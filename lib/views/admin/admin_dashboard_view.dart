import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/product.dart';
import '../../widgets/product_image_helper.dart';
import '../auth/login_view.dart';
import '../shared/notifikasi_view.dart';
import 'add_product_view.dart';
import 'admin_orders_view.dart';
import 'sales_statistics_view.dart';
import 'ml_insights_view.dart';

class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({super.key});

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView> {
  final DatabaseService _dbService = DatabaseService();
  List<Product> _products = [];
  bool _isLoading = true;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

 Future<void> _loadProducts() async {
  setState(() {
    _isLoading = true;
  });

  await _dbService.init();

  final products = await _dbService.getProducts();

  if (!mounted) return;

  setState(() {
    _products = products;
    _currentPage = 1;
    _isLoading = false;
  });
}

  void _handleDeleteProduct(Product product) async {
    // Show deletion dialog confirmation
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Katalog'),
        content: Text('Apakah Anda yakin ingin menghapus "${product.name}" dari katalog?'),
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
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });

      // Emulate DB delete call
      final success = await _dbService.deleteProduct(product.idProduk!);

      if (!mounted) return;

      if (success) {
        // Show Success Toast/Snackbar as per Activity Diagram ("tampil pesan 'katalog berhasil dihapus'")
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('"${product.name}" berhasil dihapus dari katalog!'),
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
            content: Text('Gagal menghapus katalog.'),
            backgroundColor: Colors.red,
          ),
        );
      }

      // Reload
      _loadProducts();
    }
  }

  String _formatCurrency(double amount) {
    // Basic Rupiah formatting
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
              'KURNIA MOBILE',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              'Dashboard Admin',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          // Order Management Button
          IconButton(
            icon: const Icon(Icons.assignment_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AdminOrdersView()),
              );
            },
            tooltip: 'Kelola Pesanan',
          ),
          // ML Insights Button
          IconButton(
            icon: const Icon(Icons.psychology_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MlInsightsView()),
              );
            },
            tooltip: 'ML Insights',
          ),
          // Sales Stats Button
          IconButton(
            icon: const Icon(Icons.bar_chart_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SalesStatisticsView()),
              );
            },
            tooltip: 'Statistik Penjualan',
          ),
          // Refresh Button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProducts,
            tooltip: 'Segarkan data',
          ),
          FutureBuilder<int>(
            future: _dbService.getUnreadNotificationCount(1),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none_outlined),
                    tooltip: 'Notifikasi Admin',
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotifikasiView(
                            idUser: 1,
                            role: 'admin',
                          ),
                        ),
                      );
                      setState(() {});
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        alignment: Alignment.center,
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          // Logout Button
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginView()),
              );
            },
            tooltip: 'Keluar aplikasi',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'Katalog barang kosong',
                        style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () async {
                          final added = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AddProductView()),
                          );
                          if (added == true) {
                            _loadProducts();
                          }
                        },
                        child: const Text('Tambah Katalog Pertama'),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                        child: Text(
                          'Daftar Katalog Barang (${_products.length} Item)',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      () {
                        final totalItems = _products.length;
                        final startIndex = (_currentPage - 1) * 10;
                        final endIndex = startIndex + 10 > totalItems ? totalItems : startIndex + 10;
                        final paginatedProducts = totalItems == 0
                            ? <Product>[]
                            : _products.sublist(startIndex, endIndex);

                        return Expanded(
                          child: paginatedProducts.isEmpty
                              ? Center(
                                  child: Text(
                                    'Tidak ada katalog',
                                    style: TextStyle(color: Colors.grey.shade600),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: paginatedProducts.length,
                                  itemBuilder: (context, index) {
                                    final product = paginatedProducts[index];
                                    return Card(
                                      margin: const EdgeInsets.symmetric(vertical: 6.0),
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: ListTile(
                                        onTap: () => _showProductDetails(product),
                                        contentPadding: const EdgeInsets.all(8.0),
                                        leading: ClipRRect(
                                          borderRadius: BorderRadius.circular(8.0),
                                          child: ProductImageHelper.buildProductImage(
                                            product.imageUrl,
                                            width: 60,
                                            height: 60,
                                            fit: BoxFit.cover,
                                            errorWidget: Container(
                                              width: 60,
                                              height: 60,
                                              color: theme.colorScheme.primaryContainer,
                                              child: Icon(
                                                Icons.image_not_supported_outlined,
                                                color: theme.colorScheme.onPrimaryContainer,
                                              ),
                                            ),
                                          ),
                                        ),
                                        title: Text(
                                          product.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 4),
                                            Text(
                                              product.description,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              _formatCurrency(product.price),
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: theme.colorScheme.secondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                                          onPressed: () => _handleDeleteProduct(product),
                                          tooltip: 'Hapus Barang',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        );
                      }(),
                      _buildPaginationControls(theme),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Navigate to add product view
          final added = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddProductView()),
          );
          if (added == true) {
            _loadProducts(); // Refresh
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Katalog Baru'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _showProductDetails(Product product) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
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
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ProductImageHelper.buildProductImage(
                      product.imageUrl,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorWidget: Container(
                        height: 200,
                        color: theme.colorScheme.primaryContainer,
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          size: 48,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    product.name,
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatCurrency(product.price),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'Deskripsi Produk',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.description,
                    style: TextStyle(color: Colors.grey.shade700, height: 1.5, fontSize: 14),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.pop(context);
                            final updated = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AddProductView(product: product),
                              ),
                            );
                            if (updated == true) {
                              _loadProducts();
                            }
                          },
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Edit / Ubah Produk', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _handleDeleteProduct(product);
                        },
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        label: const Text('Hapus', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPaginationControls(ThemeData theme) {
    final totalPages = (_products.length / 10).ceil();
    if (totalPages <= 1) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
          icon: const Icon(Icons.chevron_left),
          color: theme.colorScheme.primary,
        ),
        ...List.generate(totalPages, (index) {
          final pageNum = index + 1;
          final isSelected = pageNum == _currentPage;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: InkWell(
              onTap: () => setState(() => _currentPage = pageNum),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? theme.colorScheme.primary : Colors.grey.shade300,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$pageNum',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.black87,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }),
        IconButton(
          onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
          icon: const Icon(Icons.chevron_right),
          color: theme.colorScheme.primary,
        ),
      ],
    );
  }
}
