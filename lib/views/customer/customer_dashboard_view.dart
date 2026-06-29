import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/database_service.dart';
import '../../services/cart_service.dart';
import '../../services/wishlist_service.dart';
import '../../models/product.dart';
import '../../widgets/product_image_helper.dart';
import '../auth/login_view.dart';
import '../shared/notifikasi_view.dart';
import 'cart_view.dart';
import 'profile_view.dart';
import 'order_history_view.dart';
import 'wishlist_view.dart';

class CustomerDashboardView extends StatefulWidget {
  final String username;
  final int idUser;
  const CustomerDashboardView({super.key, this.username = 'customer', this.idUser = 2});

  @override
  State<CustomerDashboardView> createState() => _CustomerDashboardViewState();
}

class _CustomerDashboardViewState extends State<CustomerDashboardView> {
  final DatabaseService _dbService = DatabaseService();
  final CartService _cartService = CartService();
  final WishlistService _wishlistService = WishlistService();
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();
  int _currentPage = 1;
  String _selectedCategory = 'Semua';
  double? _minPrice;
  double? _maxPrice;
  String _sortBy = 'Terbaru';

  // Bottom Navigation tab index
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _searchController.addListener(_onSearchOrCategoryChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchOrCategoryChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _launchWhatsApp() async {
    final url = Uri.parse('https://wa.me/+6285355443060');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak dapat membuka WhatsApp. Silakan hubungi +6285355443060.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
    });
    await _dbService.init();
    if (!mounted) return;
    final products = await _dbService.getProducts();
    if (!mounted) return;
    setState(() {
      _products = products;
      _filteredProducts = _products;
      _currentPage = 1;
      _isLoading = false;
    });
  }

  void _onSearchOrCategoryChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      var temp = _products.where((product) {
        final matchesQuery = product.name.toLowerCase().contains(query) ||
            product.description.toLowerCase().contains(query);
        final matchesCategory = _selectedCategory == 'Semua' ||
            product.kategori == _selectedCategory;
        final matchesMinPrice = _minPrice == null || product.price >= _minPrice!;
        final matchesMaxPrice = _maxPrice == null || product.price <= _maxPrice!;
        return matchesQuery && matchesCategory && matchesMinPrice && matchesMaxPrice;
      }).toList();

      if (_sortBy == 'Terbaru') {
        temp.sort((a, b) => (b.idProduk ?? 0).compareTo(a.idProduk ?? 0));
      } else if (_sortBy == 'Terlama') {
        temp.sort((a, b) => (a.idProduk ?? 0).compareTo(b.idProduk ?? 0));
      } else if (_sortBy == 'Harga Terendah') {
        temp.sort((a, b) => a.price.compareTo(b.price));
      } else if (_sortBy == 'Harga Tertinggi') {
        temp.sort((a, b) => b.price.compareTo(a.price));
      } else if (_sortBy == 'Nama A-Z') {
        temp.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      } else if (_sortBy == 'Nama Z-A') {
        temp.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
      }

      _filteredProducts = temp;
      _currentPage = 1;
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatCurrency(product.price),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                      _buildStockBadge(product.stok),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kategori: ${product.kategori}',
                    style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
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
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),
                  
                  // Product Reviews Section
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _dbService.getReviews(product.idProduk!),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ));
                      }
                      final reviews = snapshot.data ?? [];
                      double avgRating = 0.0;
                      if (reviews.isNotEmpty) {
                        final totalRating = reviews.fold<int>(0, (sum, item) => sum + (item['rating'] as int));
                        avgRating = totalRating / reviews.length;
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Ulasan Produk',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.star, color: Colors.amber, size: 20),
                                  const SizedBox(width: 4),
                                  Text(
                                    reviews.isEmpty
                                        ? 'Belum ada ulasan'
                                        : '${avgRating.toStringAsFixed(1)} / 5.0 (${reviews.length})',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (reviews.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                'Belum ada ulasan untuk produk ini.',
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontStyle: FontStyle.italic),
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: reviews.length > 3 ? 3 : reviews.length, // Show up to 3 reviews
                              itemBuilder: (context, index) {
                                final rev = reviews[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8.0),
                                  color: Colors.grey.shade50,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide(color: Colors.grey.shade200),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                rev['user_nama'] as String,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Row(
                                              children: List.generate(5, (starIdx) {
                                                return Icon(
                                                  starIdx < (rev['rating'] as int)
                                                      ? Icons.star
                                                      : Icons.star_border,
                                                  color: Colors.amber,
                                                  size: 12,
                                                );
                                              }),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          rev['komentar'] as String,
                                          style: TextStyle(color: Colors.grey.shade800, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          if (reviews.length > 3)
                            TextButton(
                              onPressed: () {
                                _showAllReviewsDialog(product, reviews);
                              },
                              child: const Text('Lihat Semua Ulasan'),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: product.stok <= 0 ? null : () {
                            if (_cartService.quantityOf(product) >= product.stok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Batas stok tercapai! Stok tersedia: ${product.stok}'),
                                  backgroundColor: Colors.orange.shade800,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }
                            _cartService.addProduct(product);
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${product.name} ditambahkan ke keranjang!'),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: theme.colorScheme.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                          icon: Icon(product.stok <= 0 ? Icons.inventory_2_outlined : Icons.add_shopping_cart, size: 18),
                          label: Text(product.stok <= 0 ? 'Stok Habis' : 'Keranjang', style: const TextStyle(fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: product.stok <= 0 ? null : () {
                            if (_cartService.quantityOf(product) >= product.stok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Batas stok tercapai! Stok tersedia: ${product.stok}'),
                                  backgroundColor: Colors.orange.shade800,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }
                            _cartService.addProduct(product);
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CartView(idUser: widget.idUser),
                              ),
                            );
                          },
                          icon: const Icon(Icons.payment_outlined, size: 18),
                          label: const Text('Beli Sekarang', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Title text changes based on current tab
    final title = _currentIndex == 0
        ? 'Katalog Toko Pelanggan'
        : _currentIndex == 1
            ? 'Wishlist Saya'
            : _currentIndex == 2
                ? 'Riwayat Pesanan'
                : 'Profil Saya';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'KURNIA MOBILE',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          if (_currentIndex == 0)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadProducts,
              tooltip: 'Segarkan data',
            ),
          if (_currentIndex == 0)
            ListenableBuilder(
              listenable: _cartService,
              builder: (context, _) {
                final count = _cartService.totalItems;
                return Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.shopping_cart_outlined),
                      tooltip: 'Keranjang',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CartView(idUser: widget.idUser),
                          ),
                        );
                      },
                    ),
                    if (count > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                          child: Text(
                            '$count',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          FutureBuilder<int>(
            future: _dbService.getUnreadNotificationCount(widget.idUser),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none_outlined),
                    tooltip: 'Notifikasi',
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NotifikasiView(
                            idUser: widget.idUser,
                            role: 'customer',
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
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginView()),
              );
            },
            tooltip: 'Keluar',
          ),
        ],
      ),
      body: _currentIndex == 0
          ? _buildStorefrontTab(theme)
          : _currentIndex == 1
              ? WishlistView(
                  onNavigateToStorefront: () {
                    setState(() {
                      _currentIndex = 0;
                    });
                  },
                )
              : _currentIndex == 2
                  ? OrderHistoryView(
                      idUser: widget.idUser,
                      onNavigateToStorefront: () {
                        setState(() {
                          _currentIndex = 0;
                        });
                      },
                    )
                  : ProfileView(username: widget.username, idUser: widget.idUser),
      floatingActionButton: FloatingActionButton(
        onPressed: _launchWhatsApp,
        backgroundColor: const Color(0xFF25D366),
        foregroundColor: Colors.white,
        tooltip: 'Customer Service WhatsApp',
        child: const Icon(Icons.chat_outlined, size: 28),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.storefront_outlined),
            activeIcon: Icon(Icons.storefront),
            label: 'Belanja',
          ),
          BottomNavigationBarItem(
            icon: ListenableBuilder(
              listenable: _wishlistService,
              builder: (context, _) {
                final count = _wishlistService.totalItems;
                return Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count', style: const TextStyle(fontSize: 9)),
                  child: const Icon(Icons.favorite_outline),
                );
              },
            ),
            activeIcon: const Icon(Icons.favorite),
            label: 'Wishlist',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Riwayat',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  Widget _buildStorefrontTab(ThemeData theme) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Card & Search Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.8)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Halo, ${widget.username}!',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Cari dan beli Kain Anda dengan mudah di Kurnia Mobile.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      // Search bar with advanced filter button
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Cari Kain ...',
                                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: Icon(Icons.tune, color: theme.colorScheme.primary),
                              onPressed: _showAdvancedFilterSheet,
                              tooltip: 'Pencarian Lanjut',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Horizontal Category Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['Semua', 'Umum', 'Lain-lain'].map((cat) {
                      final isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0, bottom: 12.0),
                        child: ChoiceChip(
                          label: Text(
                            cat,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: theme.colorScheme.primary,
                          backgroundColor: Colors.grey.shade200,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedCategory = cat;
                              });
                              _onSearchOrCategoryChanged();
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  'Katalog Produk Tersedia',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),

                // Storefront grid
                () {
                  final totalItems = _filteredProducts.length;
                  final startIndex = (_currentPage - 1) * 10;
                  final endIndex = startIndex + 10 > totalItems ? totalItems : startIndex + 10;
                  final paginatedProducts = totalItems == 0 
                      ? <Product>[] 
                      : _filteredProducts.sublist(startIndex, endIndex);

                  return Expanded(
                    child: paginatedProducts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off_outlined, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  'Produk tidak ditemukan',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          )
                        : GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.72,
                            ),
                            itemCount: paginatedProducts.length,
                            itemBuilder: (context, index) {
                              final product = paginatedProducts[index];
                            return GestureDetector(
                              onTap: () => _showProductDetails(product),
                              child: Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Image with wishlist heart overlay
                                    Expanded(
                                      child: Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                            child: SizedBox(
                                              width: double.infinity,
                                              child: ProductImageHelper.buildProductImage(
                                                product.imageUrl,
                                                fit: BoxFit.cover,
                                                errorWidget: Container(
                                                  color: theme.colorScheme.primaryContainer,
                                                  child: Icon(
                                                    Icons.image_not_supported_outlined,
                                                    color: theme.colorScheme.onPrimaryContainer,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          // Wishlist heart button
                                          Positioned(
                                            top: 6,
                                            right: 6,
                                            child: ListenableBuilder(
                                              listenable: _wishlistService,
                                              builder: (context, _) {
                                                final isWished = _wishlistService.containsProduct(product);
                                                return GestureDetector(
                                                  onTap: () {
                                                    final added = _wishlistService.toggleWishlist(product);
                                                    ScaffoldMessenger.of(context).clearSnackBars();
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          added
                                                              ? '${product.name} ditambahkan ke wishlist!'
                                                              : '${product.name} dihapus dari wishlist.',
                                                        ),
                                                        behavior: SnackBarBehavior.floating,
                                                        backgroundColor: added ? Colors.pink.shade400 : Colors.grey.shade600,
                                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                        duration: const Duration(seconds: 1),
                                                      ),
                                                    );
                                                  },
                                                  child: Container(
                                                    width: 30,
                                                    height: 30,
                                                    decoration: BoxDecoration(
                                                      color: Colors.white.withValues(alpha: 0.9),
                                                      shape: BoxShape.circle,
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black.withValues(alpha: 0.1),
                                                          blurRadius: 4,
                                                        ),
                                                      ],
                                                    ),
                                                    child: Icon(
                                                      isWished ? Icons.favorite : Icons.favorite_outline,
                                                      size: 16,
                                                      color: isWished ? Colors.pink.shade400 : Colors.grey.shade500,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Content details
                                    Padding(
                                      padding: const EdgeInsets.all(10.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                product.kategori,
                                                style: TextStyle(color: theme.colorScheme.primary, fontSize: 10, fontWeight: FontWeight.bold),
                                              ),
                                              Text(
                                                product.stok > 0 ? 'Stok: ${product.stok}' : 'Habis',
                                                style: TextStyle(
                                                  color: product.stok > 0 ? (product.stok <= 5 ? Colors.orange : Colors.grey.shade600) : Colors.red,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _formatCurrency(product.price),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: theme.colorScheme.secondary,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          ListenableBuilder(
                                            listenable: _cartService,
                                            builder: (context, _) {
                                              final qty = _cartService.quantityOf(product);
                                              
                                              if (product.stok <= 0) {
                                                return SizedBox(
                                                  width: double.infinity,
                                                  child: ElevatedButton.icon(
                                                    onPressed: null,
                                                    icon: const Icon(Icons.inventory_2_outlined, size: 14),
                                                    label: const Text('Stok Habis', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                                    style: ElevatedButton.styleFrom(
                                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                                      backgroundColor: Colors.grey.shade300,
                                                      foregroundColor: Colors.grey.shade600,
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                    ),
                                                  ),
                                                );
                                              }

                                              return qty == 0
                                                  ? SizedBox(
                                                      width: double.infinity,
                                                      child: ElevatedButton.icon(
                                                        onPressed: () {
                                                          _cartService.addProduct(product);
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            SnackBar(
                                                              content: Text('${product.name} ditambahkan ke keranjang!'),
                                                              behavior: SnackBarBehavior.floating,
                                                              backgroundColor: theme.colorScheme.primary,
                                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                              duration: const Duration(seconds: 1),
                                                            ),
                                                          );
                                                        },
                                                        icon: const Icon(Icons.add_shopping_cart, size: 14),
                                                        label: const Text('Tambah', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                                        style: ElevatedButton.styleFrom(
                                                          padding: const EdgeInsets.symmetric(vertical: 6),
                                                          backgroundColor: theme.colorScheme.primary,
                                                          foregroundColor: Colors.white,
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                        ),
                                                      ),
                                                    )
                                                  : Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        GestureDetector(
                                                          onTap: () => _cartService.decrementQuantity(product),
                                                          child: Container(
                                                            width: 28,
                                                            height: 28,
                                                            decoration: BoxDecoration(
                                                              border: Border.all(color: theme.colorScheme.primary),
                                                              borderRadius: BorderRadius.circular(6),
                                                            ),
                                                            child: Icon(
                                                              qty == 1 ? Icons.delete_outline : Icons.remove,
                                                              size: 16,
                                                              color: qty == 1 ? Colors.red : theme.colorScheme.primary,
                                                            ),
                                                          ),
                                                        ),
                                                        Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                                        GestureDetector(
                                                          onTap: () {
                                                            if (qty >= product.stok) {
                                                              ScaffoldMessenger.of(context).clearSnackBars();
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                SnackBar(
                                                                  content: Text('Batas stok tercapai! Stok tersedia: ${product.stok}'),
                                                                  backgroundColor: Colors.orange.shade800,
                                                                  behavior: SnackBarBehavior.floating,
                                                                ),
                                                              );
                                                            } else {
                                                              _cartService.incrementQuantity(product);
                                                            }
                                                          },
                                                          child: Container(
                                                            width: 28,
                                                            height: 28,
                                                            decoration: BoxDecoration(
                                                              color: theme.colorScheme.primary,
                                                              borderRadius: BorderRadius.circular(6),
                                                            ),
                                                            child: const Icon(Icons.add, size: 16, color: Colors.white),
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
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
          );
  }

  Widget _buildPaginationControls(ThemeData theme) {
    final totalPages = (_filteredProducts.length / 10).ceil();
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

  Widget _buildStockBadge(int stok) {
    Color color = Colors.green;
    String label = 'Stok: $stok';
    if (stok == 0) {
      color = Colors.red;
      label = 'Habis';
    } else if (stok <= 5) {
      color = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color, width: 1.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showAllReviewsDialog(Product product, List<Map<String, dynamic>> reviews) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Semua Ulasan - ${product.name}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: reviews.length,
              itemBuilder: (context, index) {
                final rev = reviews[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12.0),
                  color: Colors.grey.shade50,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                rev['user_nama'] as String,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Row(
                              children: List.generate(5, (starIdx) {
                                return Icon(
                                  starIdx < (rev['rating'] as int)
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: Colors.amber,
                                  size: 12,
                                );
                              }),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          rev['komentar'] as String,
                          style: TextStyle(color: Colors.grey.shade800, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            )
          ],
        );
      },
    );
  }

  void _showAdvancedFilterSheet() {
    final theme = Theme.of(context);
    final minController = TextEditingController(text: _minPrice?.toStringAsFixed(0) ?? '');
    final maxController = TextEditingController(text: _maxPrice?.toStringAsFixed(0) ?? '');
    String tempSortBy = _sortBy;
    String tempCategory = _selectedCategory;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
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
                    Text(
                      'Pencarian Lanjut',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Kategori',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: tempCategory,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: ['Semua', 'Umum', 'Lain-lain'].map((cat) {
                        return DropdownMenuItem(value: cat, child: Text(cat));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() => tempCategory = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Rentang Harga',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: minController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Harga Min',
                              prefixText: 'Rp ',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: maxController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Harga Max',
                              prefixText: 'Rp ',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Urutkan Berdasarkan',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: tempSortBy,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: [
                        'Terbaru',
                        'Terlama',
                        'Harga Terendah',
                        'Harga Tertinggi',
                        'Nama A-Z',
                        'Nama Z-A'
                      ].map((sort) {
                        return DropdownMenuItem(value: sort, child: Text(sort));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() => tempSortBy = val);
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _minPrice = null;
                                _maxPrice = null;
                                _sortBy = 'Terbaru';
                                _selectedCategory = 'Semua';
                              });
                              _onSearchOrCategoryChanged();
                              Navigator.pop(context);
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Reset', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _minPrice = double.tryParse(minController.text);
                                _maxPrice = double.tryParse(maxController.text);
                                _sortBy = tempSortBy;
                                _selectedCategory = tempCategory;
                              });
                              _onSearchOrCategoryChanged();
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Terapkan', style: TextStyle(fontWeight: FontWeight.bold)),
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
      },
    );
  }
}
