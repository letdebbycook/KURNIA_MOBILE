import 'package:flutter/material.dart';
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
  final _urlController = TextEditingController();

  // Predefined avatar seeds for template chooser
  final List<String> _avatars = [
    'https://api.dicebear.com/7.x/adventurer/png?seed=Budi',
    'https://api.dicebear.com/7.x/adventurer/png?seed=Kurnia',
    'https://api.dicebear.com/7.x/adventurer/png?seed=Mobile',
    'https://api.dicebear.com/7.x/adventurer/png?seed=User',
  ];

  late String _selectedAvatarUrl;
  bool _useCustomUrl = false;
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
    _urlController.dispose();
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
      
      // Determine if image URL is custom or one of the templates
      if (_avatars.contains(profile.imageUrl)) {
        _selectedAvatarUrl = profile.imageUrl;
        _useCustomUrl = false;
      } else {
        _selectedAvatarUrl = profile.imageUrl;
        _urlController.text = profile.imageUrl;
        _useCustomUrl = true;
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
    final imageUrl = _useCustomUrl ? _urlController.text.trim() : _selectedAvatarUrl;

    final updatedProfile = UserProfile(
      username: widget.username,
      fullName: fullName,
      phoneNumber: phoneNumber,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Current User Avatar
            Center(
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
                      backgroundImage: NetworkImage(
                        _useCustomUrl ? _urlController.text : _selectedAvatarUrl,
                      ),
                      onBackgroundImageError: (exception, stackTrace) {
                        // Safe fallback for broken image URLs
                      },
                      child: (_useCustomUrl && _urlController.text.isEmpty)
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
                  selected: !_useCustomUrl,
                  onSelected: (val) {
                    setState(() {
                      _useCustomUrl = false;
                      _selectedAvatarUrl = _avatars[0];
                    });
                  },
                ),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('Kustom URL'),
                  selected: _useCustomUrl,
                  onSelected: (val) {
                    setState(() {
                      _useCustomUrl = true;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Avatar Templates or Custom URL input
            if (!_useCustomUrl)
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
              TextFormField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: 'URL Gambar Profil Web (https://...)',
                  prefixIcon: const Icon(Icons.link_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) {
                  if (_useCustomUrl) {
                    if (value == null || value.trim().isEmpty) {
                      return 'URL gambar kustom tidak boleh kosong';
                    }
                  }
                  return null;
                },
                onChanged: (_) {
                  setState(() {}); // Refresh preview
                },
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
