import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/database_service.dart';
import '../../models/user_profile.dart';

class ProfileView extends StatefulWidget {
  final String username;
  const ProfileView({super.key, required this.username});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final _formKey = GlobalKey<FormState>();
  final _dbService = DatabaseService();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _alamatController = TextEditingController();

  // Predefined avatar seeds for template chooser
  final List<String> _avatars = [
    'https://api.dicebear.com/7.x/adventurer/png?seed=Budi',
    'https://api.dicebear.com/7.x/adventurer/png?seed=Kurnia',
    'https://api.dicebear.com/7.x/adventurer/png?seed=Mobile',
    'https://api.dicebear.com/7.x/adventurer/png?seed=User',
  ];

  late String _selectedAvatarUrl;
  String? _uploadedPhotoBase64;
  bool _useUploadedPhoto = false;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _alamatController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _isLoading = true;
    });

    await _dbService.init();
    final profile = await _dbService.getUserProfile(widget.username);

    if (!mounted) return;

    setState(() {
      _nameController.text = profile.fullName;
      _phoneController.text = profile.phoneNumber;
      _alamatController.text = profile.alamat;
      
      // Determine if image URL is an uploaded photo (base64) or one of the templates
      if (profile.imageUrl.startsWith('data:image/')) {
        _uploadedPhotoBase64 = profile.imageUrl;
        _useUploadedPhoto = true;
        _selectedAvatarUrl = _avatars[0];
      } else if (_avatars.contains(profile.imageUrl)) {
        _selectedAvatarUrl = profile.imageUrl;
        _useUploadedPhoto = false;
        _uploadedPhotoBase64 = null;
      } else {
        // Fallback or previously stored custom URL/path
        if (profile.imageUrl.isNotEmpty && 
            (profile.imageUrl.startsWith('http') || profile.imageUrl.startsWith('data:image/'))) {
          _uploadedPhotoBase64 = profile.imageUrl;
          _useUploadedPhoto = true;
        } else {
          _useUploadedPhoto = false;
        }
        _selectedAvatarUrl = _avatars[0];
      }

      _isLoading = false;
    });
  }

  void _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    // Simulate validation and database network latency - act AD_Profil / AD_Update_Profil
    await Future.delayed(const Duration(milliseconds: 1200));

    final fullName = _nameController.text.trim();
    final phoneNumber = _phoneController.text.trim();
    final alamat = _alamatController.text.trim();
    final imageUrl = _useUploadedPhoto 
        ? (_uploadedPhotoBase64 ?? '') 
        : _selectedAvatarUrl;

    final updatedProfile = UserProfile(
      username: widget.username,
      fullName: fullName,
      phoneNumber: phoneNumber,
      alamat: alamat,
      imageUrl: imageUrl,
    );

    // Call database insertData() or updateData()
    final success = await _dbService.saveUserProfile(updatedProfile);

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    if (success) {
      // Display success message: "menambahkan notifikasi sukses ke halaman" & "Melihat notifikasi sukses"
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Profil Anda berhasil diperbarui!'),
            ],
          ),
          backgroundColor: Colors.teal.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      // Reload profile view
      _loadProfileData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal memperbarui data profil.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  ImageProvider? _buildAvatarImageProvider(String imageUrl) {
    if (imageUrl.isEmpty) return null;

    if (imageUrl.startsWith('data:image/')) {
      try {
        final commaIndex = imageUrl.indexOf(',');
        if (commaIndex != -1) {
          final base64Str = imageUrl.substring(commaIndex + 1);
          return MemoryImage(base64Decode(base64Str));
        }
      } catch (e) {
        debugPrint('Error decoding base64 image provider: $e');
      }
    }
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return NetworkImage(imageUrl);
    }
    return null;
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        if (bytes.length > 2 * 1024 * 1024) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ukuran gambar terlalu besar. Maksimal 2 MB.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        setState(() {
          _uploadedPhotoBase64 = base64Str;
          _useUploadedPhoto = true;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengambil gambar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Pilih dari Galeri'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Ambil Foto dari Kamera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              if (_useUploadedPhoto && _uploadedPhotoBase64 != null && _uploadedPhotoBase64!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Hapus Foto Unggahan', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _uploadedPhotoBase64 = null;
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final avatarImageProvider = _buildAvatarImageProvider(
      _useUploadedPhoto
          ? (_uploadedPhotoBase64 ?? '')
          : _selectedAvatarUrl,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Current User Avatar
            Center(
              child: GestureDetector(
                onTap: _showImageSourceDialog,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.colorScheme.primary, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withOpacity(0.15),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 54,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        backgroundImage: avatarImageProvider,
                        onBackgroundImageError: avatarImageProvider != null
                            ? (exception, stackTrace) {
                                // Safe fallback for broken image URLs
                              }
                            : null,
                        child: (_useUploadedPhoto && (_uploadedPhotoBase64 == null || _uploadedPhotoBase64!.isEmpty))
                            ? Icon(Icons.person, size: 48, color: theme.colorScheme.onPrimaryContainer)
                            : null,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 4,
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: theme.colorScheme.primary,
                        child: const Icon(Icons.edit, size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '@${widget.username}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 32),

            // Profile Form Fields
            Text(
              'Detail Informasi',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Full Name Input
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Nama Lengkap',
                prefixIcon: const Icon(Icons.badge_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Nama lengkap tidak boleh kosong';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Phone Number Input
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Nomor Telepon',
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Nomor telepon tidak boleh kosong';
                }
                if (value.trim().length < 9) {
                  return 'Masukkan nomor telepon yang valid';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Alamat Input
            TextFormField(
              controller: _alamatController,
              maxLines: 3,
              keyboardType: TextInputType.streetAddress,
              decoration: InputDecoration(
                labelText: 'Alamat Lengkap',
                hintText: 'Masukkan alamat lengkap pengiriman...',
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 40),
                  child: Icon(Icons.location_on_outlined),
                ),
                alignLabelWithHint: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Alamat tidak boleh kosong';
                }
                if (value.trim().length < 10) {
                  return 'Masukkan alamat yang lebih lengkap';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Photo Selection Area
            Text(
              'Foto Profil',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                ChoiceChip(
                  label: const Text('Template Avatar'),
                  selected: !_useUploadedPhoto,
                  onSelected: (val) {
                    setState(() {
                      _useUploadedPhoto = false;
                      _selectedAvatarUrl = _avatars[0];
                    });
                  },
                ),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('Unggah Foto'),
                  selected: _useUploadedPhoto,
                  onSelected: (val) {
                    setState(() {
                      _useUploadedPhoto = true;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Avatar Templates or Camera/Gallery Upload Option
            if (!_useUploadedPhoto)
              SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _avatars.length,
                  itemBuilder: (context, index) {
                    final avatarUrl = _avatars[index];
                    final isSelected = _selectedAvatarUrl == avatarUrl;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedAvatarUrl = avatarUrl;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 12.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? theme.colorScheme.primary : Colors.grey.shade300,
                            width: isSelected ? 2.5 : 1,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 26,
                          backgroundImage: NetworkImage(avatarUrl),
                        ),
                      ),
                    );
                  },
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Galeri Foto'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('Kamera'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_uploadedPhotoBase64 != null && _uploadedPhotoBase64!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _uploadedPhotoBase64 = null;
                          });
                        },
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                        label: const Text(
                          'Hapus Foto Pilihan',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            const SizedBox(height: 36),

            // Save Buttons
            ElevatedButton(
              onPressed: _isSaving ? null : _handleSave,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'SIMPAN PERUBAHAN',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
