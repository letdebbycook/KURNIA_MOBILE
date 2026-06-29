import 'package:flutter/material.dart';
import '../../services/database_service.dart';

class AddressBookView extends StatefulWidget {
  final int idUser;
  const AddressBookView({super.key, required this.idUser});

  @override
  State<AddressBookView> createState() => _AddressBookViewState();
}

class _AddressBookViewState extends State<AddressBookView> {
  final DatabaseService _dbService = DatabaseService();
  List<Map<String, dynamic>> _addresses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    setState(() {
      _isLoading = true;
    });
    await _dbService.init();
    final addresses = await _dbService.getAddresses(widget.idUser);
    setState(() {
      _addresses = addresses;
      _isLoading = false;
    });
  }

  void _showAddressForm({Map<String, dynamic>? address}) {
    final theme = Theme.of(context);
    final isEdit = address != null;
    final labelController = TextEditingController(text: address?['label'] ?? '');
    final nameController = TextEditingController(text: address?['nama_penerima'] ?? '');
    final phoneController = TextEditingController(text: address?['telepon_penerima'] ?? '');
    final addressController = TextEditingController(text: address?['alamat_lengkap'] ?? '');
    bool isUtama = address?['is_utama'] ?? false;

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
                      isEdit ? 'Ubah Alamat' : 'Tambah Alamat Baru',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: labelController,
                      decoration: InputDecoration(
                        labelText: 'Label Alamat (e.g. Rumah, Kantor)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Nama Penerima',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Nomor Telepon Penerima',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: addressController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Alamat Lengkap',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Jadikan Alamat Utama', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Alamat ini akan otomatis terpilih saat checkout'),
                      value: isUtama,
                      activeColor: theme.colorScheme.primary,
                      onChanged: (val) {
                        setSheetState(() {
                          isUtama = val;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async {
                        final label = labelController.text.trim();
                        final nama = nameController.text.trim();
                        final telepon = phoneController.text.trim();
                        final alamat = addressController.text.trim();

                        if (label.isEmpty || nama.isEmpty || telepon.isEmpty || alamat.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Semua kolom wajib diisi!'), backgroundColor: Colors.red),
                          );
                          return;
                        }

                        Navigator.pop(context);
                        bool success;
                        if (isEdit) {
                          success = await _dbService.updateAddress(
                            address['id_alamat'] as int,
                            label,
                            nama,
                            telepon,
                            alamat,
                            isUtama,
                            widget.idUser,
                          );
                        } else {
                          success = await _dbService.insertAddress(
                            widget.idUser,
                            label,
                            nama,
                            telepon,
                            alamat,
                            isUtama,
                          );
                        }

                        if (success) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(isEdit ? 'Alamat berhasil diperbarui' : 'Alamat baru berhasil ditambahkan'),
                              backgroundColor: Colors.teal,
                            ),
                          );
                          _loadAddresses();
                        } else {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(content: Text('Gagal menyimpan alamat'), backgroundColor: Colors.red),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(isEdit ? 'SIMPAN PERUBAHAN' : 'TAMBAH ALAMAT', style: const TextStyle(fontWeight: FontWeight.bold)),
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

  void _deleteAddress(int idAlamat) async {
    final success = await _dbService.deleteAddress(idAlamat);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alamat berhasil dihapus'), backgroundColor: Colors.teal),
      );
      _loadAddresses();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menghapus alamat'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buku Alamat Saya', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddressForm(),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Alamat Baru', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _addresses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_off_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'Belum ada alamat tersimpan.',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tambahkan alamat untuk mempermudah checkout.',
                        style: TextStyle(color: Colors.grey.shade50, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _addresses.length,
                  itemBuilder: (context, index) {
                    final addr = _addresses[index];
                    final isUtama = addr['is_utama'] as bool;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isUtama ? theme.colorScheme.primary : Colors.grey.shade200,
                          width: isUtama ? 2.0 : 1.0,
                        ),
                      ),
                      elevation: isUtama ? 3 : 1,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isUtama ? theme.colorScheme.primary : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        addr['label'],
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isUtama ? Colors.white : Colors.grey.shade800,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    if (isUtama) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade50,
                                          border: Border.all(color: Colors.orange),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'Utama',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.blue),
                                      onPressed: () => _showAddressForm(address: addr),
                                      tooltip: 'Ubah Alamat',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Hapus Alamat', style: TextStyle(fontWeight: FontWeight.bold)),
                                            content: const Text('Apakah Anda yakin ingin menghapus alamat ini?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context),
                                                child: const Text('Batal'),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.pop(context);
                                                  _deleteAddress(addr['id_alamat'] as int);
                                                },
                                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                                                child: const Text('Hapus'),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                      tooltip: 'Hapus Alamat',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              addr['nama_penerima'],
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              addr['telepon_penerima'],
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              addr['alamat_lengkap'],
                              style: TextStyle(color: Colors.grey.shade800, fontSize: 14, height: 1.4),
                            ),
                            if (!isUtama) ...[
                              const SizedBox(height: 12),
                              const Divider(),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () async {
                                    final success = await _dbService.setPrimaryAddress(widget.idUser, addr['id_alamat'] as int);
                                    if (success) {
                                      _loadAddresses();
                                    }
                                  },
                                  child: const Text('Set Sebagai Utama'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
