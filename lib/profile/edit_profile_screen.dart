import 'package:flutter/material.dart';

import '../services/session_service.dart';
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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _emailController = TextEditingController(text: widget.currentEmail);
    _phoneController = TextEditingController(text: widget.currentPhone);
    _nikController = TextEditingController();
    _loadUserNik();
    _loadUserAvatar();
  }

  Future<void> _loadUserAvatar() async {
    final avatar = await SessionService.getUserAvatar();
    if (mounted) {
      setState(() => _avatarUrl = avatar);
    }
  }

  Future<void> _loadUserNik() async {
    final nik = await SessionService.getUserNik();
    if (mounted) {
      _nikController.text = nik;
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
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
                  size: 22,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Pilih Avatar Supabase Storage',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF062056),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Akan disimpan otomatis ke bucket Supabase Storage "avatars" (Maks 2MB, PNG).',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: GridView.builder(
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

                        final url = await SupabaseStorageService.uploadAvatar(
                          userIdOrEmail: email,
                          imageBytes: bytes,
                        );

                        if (url != null) {
                          await SessionService.setUserAvatar(url);
                          if (mounted) {
                            setState(() {
                              _avatarUrl = url;
                              _isUploadingAvatar = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  '✅ Foto profil berhasil diunggah ke Supabase Storage (avatars)!',
                                ),
                                backgroundColor: Color(0xFF10B981),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } else {
                          if (mounted) setState(() => _isUploadingAvatar = false);
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
            ),
          ],
        ),
      ),
    );
  }

  void _saveProfile() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final nik = _nikController.text.trim();

    await SessionService.saveUserSession(
      name: name,
      emailOrPhone: email,
      phone: phone,
      nik: nik,
    );

    if (mounted) {
      Navigator.of(context).pop(name);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil berhasil diperbarui!'),
          backgroundColor: Color(0xFF10B981),
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
                              ? Image.network(
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
                                )
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
                    'Nomor Identitas (NIK)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _nikController,
                    readOnly: true,
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      suffixIcon: const Icon(
                        Icons.lock_rounded,
                        size: 16,
                        color: Colors.grey,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'NIK telah divalidasi dengan Dukcapil nasional dan tidak dapat diubah manual.',
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
