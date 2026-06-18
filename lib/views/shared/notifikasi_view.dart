import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/notifikasi.dart';

class NotifikasiView extends StatefulWidget {
  final int idUser;
  final String role; // 'admin' or 'customer'
  const NotifikasiView({super.key, required this.idUser, required this.role});

  @override
  State<NotifikasiView> createState() => _NotifikasiViewState();
}

class _NotifikasiViewState extends State<NotifikasiView> {
  final DatabaseService _dbService = DatabaseService();
  List<Notifikasi> _notifications = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      await _dbService.init();
      final notifications = await _dbService.getNotifications(widget.idUser);
      
      // Auto-mark notifications as read when opening page
      if (notifications.any((n) => !n.isRead)) {
        await _dbService.markNotificationsAsRead(widget.idUser);
      }

      if (!mounted) return;
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);
    
    if (difference.inMinutes < 60) {
      final mins = difference.inMinutes < 1 ? 1 : difference.inMinutes;
      return '$mins menit yang lalu';
    } else if (difference.inHours < 24 && dt.day == now.day) {
      return 'Hari ini, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} WIB';
    } else if (dt.day == now.subtract(const Duration(days: 1)).day) {
      return 'Kemarin, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} WIB';
    }
    
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day-$month-$year $hour:$minute WIB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi Anda', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchNotifications,
            tooltip: 'Segarkan',
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
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
                          'Gagal Memuat Notifikasi',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _fetchNotifications,
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : _notifications.isEmpty
                  ? _buildEmptyState(theme)
                  : RefreshIndicator(
                      onRefresh: _fetchNotifications,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          final notification = _notifications[index];
                          
                          IconData notifIcon = Icons.notifications_none_outlined;
                          Color iconBg = Colors.grey.shade100;
                          Color iconColor = Colors.grey.shade700;

                          final titleLower = notification.judul.toLowerCase();
                          if (titleLower.contains('dibuat')) {
                            notifIcon = Icons.receipt_long_outlined;
                            iconBg = Colors.blue.shade50;
                            iconColor = Colors.blue.shade700;
                          } else if (titleLower.contains('sukses') || titleLower.contains('berhasil') || titleLower.contains('lunas') || titleLower.contains('diterima')) {
                            notifIcon = Icons.check_circle_outline_rounded;
                            iconBg = Colors.green.shade50;
                            iconColor = Colors.green.shade700;
                          } else if (titleLower.contains('gagal') || titleLower.contains('batal')) {
                            notifIcon = Icons.cancel_outlined;
                            iconBg = Colors.red.shade50;
                            iconColor = Colors.red.shade700;
                          } else if (titleLower.contains('diperbarui') || titleLower.contains('status')) {
                            notifIcon = Icons.local_shipping_outlined;
                            iconBg = Colors.orange.shade50;
                            iconColor = Colors.orange.shade700;
                          } else if (titleLower.contains('masuk')) {
                            notifIcon = Icons.assignment_turned_in_outlined;
                            iconBg = Colors.indigo.shade50;
                            iconColor = Colors.indigo.shade700;
                          }

                          return Card(
                            elevation: notification.isRead ? 0 : 2,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: notification.isRead 
                                    ? Colors.grey.shade200 
                                    : theme.colorScheme.primary.withValues(alpha: 0.15),
                                width: notification.isRead ? 1 : 1.5,
                              ),
                            ),
                            color: notification.isRead 
                                ? (isDark ? Colors.grey.shade900 : Colors.white)
                                : theme.colorScheme.primaryContainer.withValues(alpha: 0.05),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Icon Badge
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: iconBg,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(notifIcon, color: iconColor, size: 24),
                                  ),
                                  const SizedBox(width: 16),
                                  // Notification Message
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                notification.judul,
                                                style: TextStyle(
                                                  fontWeight: notification.isRead 
                                                      ? FontWeight.w600 
                                                      : FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                            if (!notification.isRead)
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  color: theme.colorScheme.primary,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          notification.pesan,
                                          style: TextStyle(
                                            color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                                            fontSize: 12.5,
                                            height: 1.4,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _formatDateTime(notification.timestamp),
                                          style: TextStyle(
                                            color: Colors.grey.shade500,
                                            fontSize: 10.5,
                                          ),
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
                    ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_off_outlined,
                size: 64,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Kotak Masuk Kosong',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Semua notifikasi pembelian dan pembaruan pesanan Anda akan muncul di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
