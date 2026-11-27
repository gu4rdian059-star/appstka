import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/session_service.dart';
import '../services/supabase_service.dart';
import '../services/supabase_storage_service.dart';

class EditProfileScreen extends StatefulWidget {
  final String currentName;
  final String currentEmail;
  final String currentPhone;

  const EditProfileScreen({
    super.key,
    this.currentName = 'Pengguna TKA',
    this.currentEmail = '',
    this.currentPhone = '',
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _nikController;

  int _docType = 0; // 0: KTP/NIK, 1: Paspor
  int _gender = 0; // 0: Laki-laki, 1: Perempuan
  DateTime _birthDate = DateTime(1994, 6, 26);
  String? _avatarUrl;
  bool _isUploadingAvatar = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _emailController = TextEditingController(text: widget.currentEmail);
    _phoneController = TextEditingController(text: widget.currentPhone);
    _nikController = TextEditingController();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final name = await SessionService.getUserName();
    final email = await SessionService.getUserEmail();
    final phone = await SessionService.getUserPhone();
    final nik = await SessionService.getUserNik();
    final avatar = await SessionService.getUserAvatar();
    final birthDate = await SessionService.getUserBirthDate();
    final gender = await SessionService.getUserGender();
    final docType = await SessionService.getUserDocType();

    if (mounted) {
      setState(() {
        if (_nameController.text.isEmpty && name.isNotEmpty) {
          _nameController.text = name;
        }
        if (_emailController.text.isEmpty && email != null && email.isNotEmpty) {
          _emailController.text = email;
        }
        if (_phoneController.text.isEmpty && phone.isNotEmpty) {
          _phoneController.text = phone;
        }
        if (_nikController.text.isEmpty && nik.isNotEmpty) {
          _nikController.text = nik;
        }
        if (_avatarUrl == null && avatar != null && avatar.isNotEmpty) {
          _avatarUrl = avatar;
        }
        if (birthDate != null) _birthDate = birthDate;
        _gender = gender;
        _docType = docType;
      });
    }

    // Ambil data terbaru langsung dari Supabase tabel 'users' jika tersedia
    try {
      final cleanEmail = (email ?? widget.currentEmail).toLowerCase().trim();
      if (cleanEmail.isNotEmpty) {
        final client = SupabaseService.client;
        final res = await client
            .from('users')
            .select()
            .eq('email', cleanEmail)
            .maybeSingle();

        if (res != null && mounted) {
          setState(() {
            if (res['full_name'] != null &&
                res['full_name'].toString().isNotEmpty) {
              _nameController.text = res['full_name'].toString();
            }
            if (res['phone'] != null && res['phone'].toString().isNotEmpty) {
              _phoneController.text = res['phone'].toString();
            }
            if (res['nik'] != null && res['nik'].toString().isNotEmpty) {
              _nikController.text = res['nik'].toString();
            }
            if (res['avatar_url'] != null &&
                res['avatar_url'].toString().isNotEmpty) {
              _avatarUrl = res['avatar_url'].toString();
            }
            if (res['gender'] != null) {
              final g = res['gender'].toString().toLowerCase();
              _gender = g.contains('perempuan') ? 1 : 0;
            }
            if (res['birth_date'] != null) {
              try {
                _birthDate = DateTime.parse(res['birth_date'].toString());
              } catch (_) {}
            }
            if (res['document_type'] != null) {
              final d = res['document_type'].toString().toLowerCase();
              _docType = d.contains('paspor') ? 1 : 0;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Catatan ambil profil dari Supabase: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _nikController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  void _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate,
      firstDate: DateTime(1940),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 12)),
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 75,
      );

      if (pickedFile == null) return;

      final bytes = await pickedFile.readAsBytes();
      final mimeType = pickedFile.mimeType ?? 'image/jpeg';
      final email = _emailController.text.trim().isNotEmpty
          ? _emailController.text.trim()
          : widget.currentEmail;

      // 1. Simpan fallback foto lokal dalam format base64 Data URI
      final String base64Url = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      // Langsung pasang foto di UI seketika agar tidak blank/menunggu lama
      if (mounted) {
        setState(() {
          _avatarUrl = base64Url;
          _isUploadingAvatar = true;
        });
      }
      await SessionService.setUserAvatar(base64Url);

      // 2. Coba unggah ke cloud Supabase Storage (bucket: avatars)
      final res = await SupabaseStorageService.uploadAvatarDetailed(
        userIdOrEmail: email,
        imageBytes: bytes,
        mimeType: mimeType,
      );

      String finalUrl = base64Url;
      bool cloudSuccess = false;

      if (res.success && res.url != null) {
        finalUrl = res.url!;
        cloudSuccess = true;
        await SessionService.setUserAvatar(finalUrl);
        await SessionService.syncUserProfileToSupabase(
          name: _nameController.text.trim(),
          email: email,
          phone: _phoneController.text.trim(),
          nik: _nikController.text.trim(),
          birthDate: _birthDate,
          gender: _gender,
          docType: _docType,
          avatarUrl: finalUrl,
        );
      }

      if (mounted) {
        setState(() {
          _avatarUrl = finalUrl;
          _isUploadingAvatar = false;
        });

        if (cloudSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '✅ Foto profil dari perangkat berhasil diunggah ke Supabase Storage (avatars)!',
              ),
              backgroundColor: Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          // Beritahu pengguna secara spesifik jika Supabase membatasi via RLS Policy
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                res.isRlsError
                    ? '⚠️ Foto profil aktif. Bucket "avatars" memerlukan Policy RLS INSERT untuk public di Supabase.'
                    : '⚠️ Foto profil aktif. (${res.error ?? "Gagal upload cloud"})',
              ),
              backgroundColor: const Color(0xFFE65100),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error pick and upload avatar: $e');
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memilih/mengunggah foto: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showAvatarBottomSheet() {
    final name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : widget.currentName;
    final initials = name
        .split(' ')
        .where((e) => e.isNotEmpty)
        .map((w) => w[0].toUpperCase())
        .take(2)
        .join();

    final themes = [
      {
        'title': 'Executive Navy',
        'badge': 'VIP',
        'primary': const Color(0xFF062056),
        'secondary': const Color(0xFF1E3A8A),
      },
      {
        'title': 'Velocity Orange',
        'badge': 'TKA',
        'primary': const Color(0xFFEA580C),
        'secondary': const Color(0xFFF97316),
      },
      {
        'title': 'Emerald Express',
        'badge': 'PRO',
        'primary': const Color(0xFF065F46),
        'secondary': const Color(0xFF10B981),
      },
      {
        'title': 'Royal Amethyst',
        'badge': 'ELITE',
        'primary': const Color(0xFF581C87),
        'secondary': const Color(0xFF8B5CF6),
      },
      {
        'title': 'Crimson Ruby',
        'badge': 'FIRST',
        'primary': const Color(0xFF9F1239),
        'secondary': const Color(0xFFF43F5E),
      },
      {
        'title': 'Midnight Gold',
        'badge': 'GOLD',
        'primary': const Color(0xFF0F172A),
        'secondary': const Color(0xFFD97706),
      },
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(
                    Icons.cloud_upload_rounded,
                    color: Color(0xFF062056),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Ubah Foto Profil',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF062056),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Foto yang dipilih akan tersimpan di Supabase Storage (bucket: avatars).',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 18),

              // Tombol Unggah dari Perangkat (Galeri & Kamera)
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickAndUploadAvatar(ImageSource.gallery);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF062056), Color(0xFF1E3A8A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF062056).withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.photo_library_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Galeri Perangkat',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickAndUploadAvatar(ImageSource.camera);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFD),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF062056),
                            width: 1.5,
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt_rounded,
                              color: Color(0xFF062056),
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Buka Kamera',
                              style: TextStyle(
                                color: Color(0xFF062056),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Separator
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'ATAU PILIH AVATAR DESAIN TKA',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade500,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                ],
              ),

              const SizedBox(height: 14),

              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                itemCount: themes.length,
                itemBuilder: (context, i) {
                  final t = themes[i];
                  final pColor = t['primary'] as Color;
                  final sColor = t['secondary'] as Color;
                  final badge = t['badge'] as String;
                  final title = t['title'] as String;

                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      Navigator.pop(ctx);
                      setState(() => _isUploadingAvatar = true);
                      try {
                        final bytes =
                            await SupabaseStorageService.generateStylizedAvatarPng(
                              name: name,
                              bgColor: pColor,
                              secondaryColor: sColor,
                              badge: badge,
                            );

                        final email = _emailController.text.trim().isNotEmpty
                            ? _emailController.text.trim()
                            : widget.currentEmail;

                        // Langsung render di UI seketika
                        final base64Fallback =
                            'data:image/png;base64,${base64Encode(bytes)}';
                        if (mounted) {
                          setState(() {
                            _avatarUrl = base64Fallback;
                            _isUploadingAvatar = false;
                          });
                        }
                        await SessionService.setUserAvatar(base64Fallback);

                        final res =
                            await SupabaseStorageService.uploadAvatarDetailed(
                              userIdOrEmail: email,
                              imageBytes: bytes,
                              mimeType: 'image/png',
                            );

                        String finalUrl = base64Fallback;
                        if (res.success && res.url != null) {
                          finalUrl = res.url!;
                          await SessionService.setUserAvatar(finalUrl);
                          await SessionService.syncUserProfileToSupabase(
                            name: _nameController.text.trim(),
                            email: email,
                            avatarUrl: finalUrl,
                          );
                        }

                        if (mounted) {
                          setState(() {
                            _avatarUrl = finalUrl;
                            _isUploadingAvatar = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                res.success
                                    ? '✅ Foto profil avatar desain berhasil diunggah ke Supabase Storage!'
                                    : '✅ Avatar desain berhasil diterapkan pada profil!',
                              ),
                              backgroundColor: const Color(0xFF10B981),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        debugPrint('Gagal upload avatar: $e');
                        if (mounted) setState(() => _isUploadingAvatar = false);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [pColor, sColor],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              initials.isNotEmpty ? initials : 'TK',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF062056),
                            ),
                          ),
                          Text(
                            badge,
                            style: TextStyle(
                              fontSize: 9.5,
                              color: pColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveProfile() async {
    if (_isSaving) return;

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final nik = _nikController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama lengkap tidak boleh kosong!'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    // 1. Simpan ke penyimpanan lokal
    await SessionService.saveUserSession(
      name: name,
      emailOrPhone: email,
      phone: phone,
      nik: nik,
      birthDate: _birthDate,
      gender: _gender,
      docType: _docType,
    );

    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      await SessionService.setUserAvatar(_avatarUrl!);
    }

    // 2. Sinkronkan ke database Supabase tabel 'users'
    final synced = await SessionService.syncUserProfileToSupabase(
      name: name,
      email: email,
      phone: phone,
      nik: nik,
      birthDate: _birthDate,
      gender: _gender,
      docType: _docType,
      avatarUrl: _avatarUrl,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.of(context).pop(name);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            synced
                ? '✅ Profil berhasil disimpan & disinkronkan ke database Supabase!'
                : '✅ Profil berhasil disimpan di perangkat!',
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF062056)),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Edit Profil',
          style: TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF062056),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.help_outline_rounded,
              color: Color(0xFF062056),
            ),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(
              Icons.info_outline_rounded,
              color: Color(0xFF062056),
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            // Avatar & Tombol Ubah Foto
            Center(
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF062056),
                            width: 2.5,
                          ),
                        ),
                        child: ClipOval(
                          child: _isUploadingAvatar
                              ? const Center(
                                  child: SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Color(0xFF062056),
                                    ),
                                  ),
                                )
                              : _avatarUrl != null && _avatarUrl!.isNotEmpty
                              ? (_avatarUrl!.startsWith('data:image')
                                  ? Image.memory(
                                      base64Decode(
                                        _avatarUrl!.contains(',')
                                            ? _avatarUrl!.split(',').last
                                            : _avatarUrl!,
                                      ),
                                      width: 84,
                                      height: 84,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.network(
                                      _avatarUrl!,
                                      width: 84,
                                      height: 84,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => CircleAvatar(
                                        radius: 38,
                                        backgroundColor: const Color(0xFF062056),
                                        child: Text(
                                          _nameController.text.trim().isNotEmpty
                                              ? _nameController.text
                                                  .trim()
                                                  .split(' ')
                                                  .where((e) => e.isNotEmpty)
                                                  .map((w) => w[0].toUpperCase())
                                                  .take(2)
                                                  .join()
                                              : 'TK',
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ))
                              : CircleAvatar(
                                  radius: 38,
                                  backgroundColor: const Color(0xFF062056),
                                  child: Text(
                                    _nameController.text.trim().isNotEmpty
                                        ? _nameController.text
                                            .trim()
                                            .split(' ')
                                            .where((e) => e.isNotEmpty)
                                            .map((w) => w[0].toUpperCase())
                                            .take(2)
                                            .join()
                                        : 'TK',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.cloud_done_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      side: const BorderSide(color: Color(0xFF062056)),
                    ),
                    onPressed: _showAvatarBottomSheet,
                    icon: const Icon(
                      Icons.camera_alt_outlined,
                      size: 14,
                      color: Color(0xFF062056),
                    ),
                    label: const Text(
                      'Ubah Foto Profil (Supabase)',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF062056),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.storage_rounded,
                        size: 12,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Bucket: avatars (Maks 2MB, JPG/PNG)',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Card Status Kredensial Akun
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'STATUS KREDENSIAL AKUN',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'User ID TKA',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Row(
                        children: [
                          const Text(
                            'TKA-8821940',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF062056),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 12,
                            color: Colors.grey.shade500,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Member Silver Priority',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Akun Terverifikasi e-KTP',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Section Data Pribadi Penumpang
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Data Pribadi Penumpang',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF062056),
                    ),
                  ),
                  const Divider(height: 20),

                  // Nama Lengkap
                  const Text(
                    'Nama Lengkap (Sesuai KTP)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFD),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Tipe Dokumen Identitas
                  const Text(
                    'Tipe Dokumen Identitas',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('KTP / NIK'),
                        selected: _docType == 0,
                        selectedColor: const Color(0xFF062056),
                        labelStyle: TextStyle(
                          color: _docType == 0 ? Colors.white : Colors.black87,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (val) => setState(() => _docType = 0),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Paspor'),
                        selected: _docType == 1,
                        selectedColor: const Color(0xFF062056),
                        labelStyle: TextStyle(
                          color: _docType == 1 ? Colors.white : Colors.black87,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (val) => setState(() => _docType = 1),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Nomor Identitas (NIK)
                  const Text(
                    'Nomor Identitas (NIK / No. Paspor)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _nikController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFD),
                      hintText: 'Contoh: 3514062607090001',
                      suffixIcon: const Icon(
                        Icons.badge_outlined,
                        size: 18,
                        color: Color(0xFF062056),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Nomor identitas resmi yang tertera pada KTP/Paspor untuk verifikasi tiket.',
                    style: TextStyle(fontSize: 10.5, color: Colors.grey),
                  ),

                  const SizedBox(height: 14),

                  // Tanggal Lahir
                  const Text(
                    'Tanggal Lahir',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: _pickBirthDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFD),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDate(_birthDate),
                            style: const TextStyle(fontSize: 13),
                          ),
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 16,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Jenis Kelamin
                  const Text(
                    'Jenis Kelamin',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Row(
                        children: [
                          Radio<int>(
                            value: 0,
                            groupValue: _gender,
                            activeColor: const Color(0xFF062056),
                            onChanged: (val) =>
                                setState(() => _gender = val ?? 0),
                          ),
                          const Text(
                            'Laki-laki',
                            style: TextStyle(fontSize: 12.5),
                          ),
                        ],
                      ),
                      const SizedBox(width: 18),
                      Row(
                        children: [
                          Radio<int>(
                            value: 1,
                            groupValue: _gender,
                            activeColor: const Color(0xFF062056),
                            onChanged: (val) =>
                                setState(() => _gender = val ?? 1),
                          ),
                          const Text(
                            'Perempuan',
                            style: TextStyle(fontSize: 12.5),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Section Kontak & Notifikasi Perjalanan
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kontak & Notifikasi Perjalanan',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF062056),
                    ),
                  ),
                  const Divider(height: 20),

                  // Email
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Alamat Email Tiket',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                        ),
                        child: const Text(
                          'Ubah',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF062056),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _emailController,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFD),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Nomor Handphone
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Nomor Handphone (WhatsApp / SMS)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'OTP Aktif',
                          style: TextStyle(
                            fontSize: 9.5,
                            color: Color(0xFF2E7D32),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _phoneController,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFD),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Notice
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: Color(0xFF64748B),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ketentuan Boarding Stasiun KA: Perubahan nama atau NIK harus sesuai dengan dokumen identitas resmi untuk keperluan verifikasi tiket di boarding gate stasiun kereta api.',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF64748B),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Tombol Simpan & Batal
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF062056),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _saveProfile,
                child: const Text(
                  'Simpan Perubahan',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text(
                  'Batalkan',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
