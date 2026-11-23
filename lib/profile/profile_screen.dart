import 'dart:convert';
import 'package:flutter/material.dart';

import '../services/session_service.dart';
import '../services/supabase_service.dart';
import '../services/user_db_service.dart';
import '../login/login_screen.dart';
import 'edit_profile_screen.dart';
import 'security_screen.dart';
import '../orders/orders_screen.dart';
import '../notifications/notifications_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool embedded;
  final VoidCallback? onOpenOrders;

  const ProfileScreen({super.key, this.embedded = false, this.onOpenOrders});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _name = 'Pengguna TKA';
  String _email = '';
  String _phone = '';
  int _points = 0;
  String _tier = 'Member Baru';
  int _completedTrips = 0;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadUserSession();
  }

  Future<void> _loadUserSession() async {
    final savedName = await SessionService.getUserName();
    final savedEmail = await SessionService.getUserEmail();
    final savedPhone = await SessionService.getUserPhone();
    final points = await SessionService.getUserPoints();
    final tier = await SessionService.getUserTier();
    final avatar = await SessionService.getUserAvatar();
    final completed = await UserDatabaseService.getBookings(
      statusFilter: 'Selesai',
    );

    if (mounted) {
      setState(() {
        if (savedName.isNotEmpty) {
          _name = savedName;
        }
        if (savedEmail != null && savedEmail.isNotEmpty) {
          _email = savedEmail;
        }
        if (savedPhone.isNotEmpty) {
          _phone = savedPhone;
        }
        _points = points;
        _tier = tier;
        _avatarUrl = avatar;
        _completedTrips = completed.length;
      });
    }

    // Ambil data sinkronisasi terbaru dari Supabase profiles jika tersedia
    try {
      final cleanEmail = (savedEmail ?? '').toLowerCase().trim();
      if (cleanEmail.isNotEmpty) {
        final client = SupabaseService.client;
        final res = await client
            .from('profiles')
            .select()
            .eq('email', cleanEmail)
            .maybeSingle();

        if (res != null && mounted) {
          setState(() {
            if (res['full_name'] != null &&
                res['full_name'].toString().isNotEmpty) {
              _name = res['full_name'].toString();
            }
            if (res['phone'] != null && res['phone'].toString().isNotEmpty) {
              _phone = res['phone'].toString();
            }
            if (res['avatar_url'] != null &&
                res['avatar_url'].toString().isNotEmpty) {
              _avatarUrl = res['avatar_url'].toString();
            }
          });
        }
      }
    } catch (_) {}
  }

  void _openEditProfile() async {
    final updated = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          currentName: _name,
          currentEmail: _email,
          currentPhone: _phone,
        ),
      ),
    );
    if (mounted) {
      if (updated != null && updated.isNotEmpty) {
        setState(() => _name = updated);
      }
      await _loadUserSession();
    }
  }

  void _openSecurity() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SecurityScreen()));
  }

  void _openNotifications() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
  }

  void _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Keluar dari Akun',
          style: TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF062056),
          ),
        ),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari akun TKA Mobile?',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Keluar',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await SessionService.clearSession();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const LoginScreen(alreadyAnimated: true),
        ),
        (route) => false,
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
        leading: widget.embedded
            ? null
            : IconButton(
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Color(0xFF062056),
                ),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo_tka_full.png',
              height: 24,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Text(
                'TKA',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF062056),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Akun Saya',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF062056),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.notifications_outlined,
              color: Color(0xFF062056),
            ),
            onPressed: _openNotifications,
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ================= 1. PROFIL USER HEADER =================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF062056),
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: _avatarUrl != null && _avatarUrl!.isNotEmpty
                          ? (_avatarUrl!.startsWith('data:image')
                              ? Image.memory(
                                  base64Decode(
                                    _avatarUrl!.contains(',')
                                        ? _avatarUrl!.split(',').last
                                        : _avatarUrl!,
                                  ),
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                )
                              : Image.network(
                                  _avatarUrl!,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => CircleAvatar(
                                    backgroundColor: const Color(0xFF062056),
                                    child: Text(
                                      _name.isNotEmpty
                                          ? _name
                                              .split(' ')
                                              .where((e) => e.isNotEmpty)
                                              .map((w) => w[0].toUpperCase())
                                              .take(2)
                                              .join()
                                          : 'TK',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ))
                          : CircleAvatar(
                              backgroundColor: const Color(0xFF062056),
                              child: Text(
                                _name.isNotEmpty
                                    ? _name
                                        .split(' ')
                                        .where((e) => e.isNotEmpty)
                                        .map((w) => w[0].toUpperCase())
                                        .take(2)
                                        .join()
                                    : 'SM',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF062056),
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: _openEditProfile,
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(
                                  Icons.edit_outlined,
                                  size: 16,
                                  color: Color(0xFF062056),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    size: 10,
                                    color: Color(0xFF2E7D32),
                                  ),
                                  SizedBox(width: 3),
                                  Text(
                                    'Terverifikasi e-KTP',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2E7D32),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _email,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          _phone,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ================= 2. STATS ROW (POIN & PERJALANAN) =================
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFF3E0),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.monetization_on_rounded,
                            size: 18,
                            color: Color(0xFFF26716),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$_points Poin',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF062056),
                              ),
                            ),
                            const Text(
                              'TKA Poin',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE8F1FC),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.train_rounded,
                            size: 18,
                            color: Color(0xFF062056),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$_completedTrips Rute Selesai',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF062056),
                              ),
                            ),
                            const Text(
                              'Perjalanan',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ================= 3. MEMBER SILVER PRIORITY BANNER =================
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF062056), Color(0xFF1E3A8A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.workspace_premium_rounded,
                    color: Color(0xFFFFD700),
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Member Silver Priority',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Nikmati prioritas reservasi rute padat dan promo eksklusif.',
                          style: TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: Colors.white70),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ================= 4. GROUP 1: AKTIVITAS & PEMESANAN =================
            _buildMenuGroup(
              title: 'AKTIVITAS & PEMESANAN',
              items: [
                _MenuItem(
                  icon: Icons.receipt_long_rounded,
                  title: 'Riwayat Pemesanan & Transaksi',
                  subtitle: 'Semua arsip e-tiket dan invoice perjalanan',
                  onTap: () {
                    if (widget.onOpenOrders != null) {
                      widget.onOpenOrders!();
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const OrdersScreen()),
                      );
                    }
                  },
                ),
                _MenuItem(
                  icon: Icons.people_outline_rounded,
                  title: 'Daftar Penumpang Tersimpan',
                  subtitle: 'Kelola data e-KTP keluarga & rekan untuk pesan',
                  onTap: _openEditProfile,
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ================= 5. GROUP 2: KEAMANAN & AKUN =================
            _buildMenuGroup(
              title: 'KEAMANAN & AKUN',
              items: [
                _MenuItem(
                  icon: Icons.lock_outline_rounded,
                  title: 'Ganti Password / Kata Sandi',
                  subtitle: 'Pembaruan rutin untuk perlindungan akun',
                  onTap: _openSecurity,
                ),
                _MenuItem(
                  icon: Icons.security_rounded,
                  title: 'Pengaturan Akun & Keamanan',
                  subtitle: 'Verifikasi 2 langkah, sesi aktif & biometrik',
                  onTap: _openSecurity,
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ================= 6. GROUP 3: PREFERENSI & BANTUAN =================
            _buildMenuGroup(
              title: 'PREFERENSI & BANTUAN',
              items: [
                _MenuItem(
                  icon: Icons.notifications_active_outlined,
                  title: 'Notifikasi & Pengingat Perjalanan',
                  subtitle: 'Jadwal boarding, info keterlambatan & promo',
                  onTap: _openNotifications,
                ),
                _MenuItem(
                  icon: Icons.support_agent_rounded,
                  title: 'Pusat Bantuan & Kebijakan TKA',
                  subtitle: 'Aturan bagasi, refund tiket & pembatalan rute',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Layanan Pusat Bantuan CS TKA siap melayani 24/7.',
                        ),
                        backgroundColor: Color(0xFF062056),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                _MenuItem(
                  icon: Icons.info_outline_rounded,
                  title: 'Tentang TKA Mobile',
                  subtitle: 'Aplikasi Resmi Operasional & Pelanggan KA',
                  trailingText: 'v2.4.0',
                  onTap: () {},
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ================= 7. TOMBOL KELUAR DARI AKUN =================
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFFEE2E2), width: 1.5),
                  backgroundColor: const Color(0xFFFEF2F2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _handleLogout,
                icon: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFDC2626),
                  size: 18,
                ),
                label: const Text(
                  'Keluar dari Akun',
                  style: TextStyle(
                    color: Color(0xFFDC2626),
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),
            Text(
              'TKA Mobile Engine • Sistem Reservasi Terpadu',
              style: TextStyle(fontSize: 10.5, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuGroup({
    required String title,
    required List<_MenuItem> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.grey,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: List.generate(items.length, (i) {
              final item = items[i];
              return Column(
                children: [
                  ListTile(
                    onTap: item.onTap,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        item.icon,
                        size: 18,
                        color: const Color(0xFF062056),
                      ),
                    ),
                    title: Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B1E28),
                      ),
                    ),
                    subtitle: Text(
                      item.subtitle,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    trailing: item.trailingText != null
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.trailingText!,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: Colors.grey,
                          ),
                  ),
                  if (i < items.length - 1)
                    const Divider(height: 1, indent: 56),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailingText;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailingText,
    required this.onTap,
  });
}
