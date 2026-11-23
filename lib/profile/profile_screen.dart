import 'package:flutter/material.dart';
import '../config/app_env.dart';
import '../login/login_screen.dart';
import '../models/tracking_models.dart';
import '../notifications/notifications_screen.dart';
import '../services/indonesia_time_service.dart';
import '../services/session_service.dart';
import '../services/supabase_service.dart';
import '../services/train_tracking_service.dart';
import '../services/user_db_service.dart';
import '../tracking/favorites_screen.dart';
import '../tracking/widgets/tracking_status_badge.dart';
import 'edit_profile_screen.dart';
import 'security_screen.dart';

/// H. User Profile Screen
/// Menyediakan:
/// - Profile information
/// - Notification preferences (Brevo Email & per-event toggles)
/// - Favorite trains shortcut
/// - Application settings (Zona Waktu Indonesia WIB/WITA/WIT, Auto-Follow, Map/Brevo status)
/// - Logout
class ProfileScreen extends StatefulWidget {
  final bool embedded;
  final VoidCallback? onOpenOrders;
  final VoidCallback? onOpenFavorites;
  final void Function(String tripId)? onTrackTrainOnMap;
  final void Function(String stationCode)? onFocusStationOnMap;

  const ProfileScreen({
    super.key,
    this.embedded = false,
    this.onOpenOrders,
    this.onOpenFavorites,
    this.onTrackTrainOnMap,
    this.onFocusStationOnMap,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _name = 'Pengguna TKA';
  String _email = '';
  String _phone = '';
  int _points = 0;
  int _completedTrips = 0;

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
    final completed =
        await UserDatabaseService.getBookings(statusFilter: 'Selesai');
    await TrainTrackingService.loadPreferences();

    if (mounted) {
      setState(() {
        if (savedName.isNotEmpty) _name = savedName;
        if (savedEmail != null && savedEmail.isNotEmpty) _email = savedEmail;
        if (savedPhone.isNotEmpty) _phone = savedPhone;
        _points = points;
        _completedTrips = completed.length;
      });
    }
  }

  Future<void> _openEditProfile() async {
    final updated = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          currentName: _name,
          currentEmail: _email,
          currentPhone: _phone,
        ),
      ),
    );
    if (updated != null && updated.isNotEmpty && mounted) {
      setState(() => _name = updated);
      await SessionService.saveUserSession(name: _name, emailOrPhone: _email);
    }
  }

  void _openSecurity() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SecurityScreen()),
    );
  }

  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }

  void _openFavorites() {
    if (widget.onOpenFavorites != null) {
      widget.onOpenFavorites!();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FavoritesScreen(
          onTrackTrainOnMap: widget.onTrackTrainOnMap,
          onFocusStationOnMap: widget.onFocusStationOnMap,
        ),
      ),
    );
  }

  Future<void> _updatePref(UserNotificationPreferences updated) async {
    await TrainTrackingService.savePreferences(updated);
  }

  Future<void> _handleLogout() async {
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
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Keluar',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        if (SupabaseService.isInitialized) {
          await SupabaseService.client.auth.signOut();
        }
      } catch (_) {}
      await SessionService.clearSession();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
            builder: (_) => const LoginScreen(alreadyAnimated: true)),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF062056),
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: !widget.embedded,
        title: const Text(
          'Profil & Pengaturan',
          style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Pusat Notifikasi',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: _openNotifications,
          ),
        ],
      ),
      body: ValueListenableBuilder<UserNotificationPreferences>(
        valueListenable: TrainTrackingService.preferencesNotifier,
        builder: (context, prefs, _) {
          return ValueListenableBuilder<List<FavoriteTrainModel>>(
            valueListenable: TrainTrackingService.favoritesNotifier,
            builder: (context, favorites, _) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ================= 1. INFORMASI PROFIL =================
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: const Color(0xFF062056),
                            child: Text(
                              _name.isNotEmpty
                                  ? _name
                                      .trim()
                                      .split(' ')
                                      .where((w) => w.isNotEmpty)
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
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF062056),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Edit Profil',
                                      onPressed: _openEditProfile,
                                      icon: const Icon(Icons.edit_outlined,
                                          size: 18, color: Color(0xFF062056)),
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(4),
                                    ),
                                  ],
                                ),
                                if (_email.isNotEmpty)
                                  Text(
                                    _email,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade700),
                                  ),
                                if (_phone.isNotEmpty)
                                  Text(
                                    _phone,
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        color: Colors.grey.shade600),
                                  ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    _miniStatPill(
                                        Icons.stars_rounded, '$_points Poin'),
                                    _miniStatPill(Icons.favorite_rounded,
                                        '${favorites.length} Favorit'),
                                    _miniStatPill(Icons.train_rounded,
                                        '$_completedTrips Selesai'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ================= 2. KERETA FAVORIT =================
                    _sectionTitle('KERETA FAVORIT'),
                    _cardContainer(
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.favorite_rounded,
                              color: Color(0xFFF26716), size: 20),
                        ),
                        title: const Text(
                          'Daftar Kereta & Rute Favorit',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF062056),
                          ),
                        ),
                        subtitle: Text(
                          favorites.isEmpty
                              ? 'Belum ada kereta favorit tersimpan'
                              : '${favorites.length} kereta dipantau & siap menerima notifikasi',
                          style: const TextStyle(fontSize: 11.5),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: _openFavorites,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ================= 3. PREFERENSI NOTIFIKASI (BREVO) =================
                    _sectionTitle('PREFERENSI NOTIFIKASI (BREVO & IN-APP)'),
                    _cardContainer(
                      child: Column(
                        children: [
                          SwitchListTile(
                            dense: true,
                            activeThumbColor: const Color(0xFFF26716),
                            title: const Text('Notifikasi Email via Brevo',
                                style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              AppEnv.hasBrevoConfig
                                  ? 'Brevo API aktif • Pengirim: ${AppEnv.brevoSenderEmail}'
                                  : 'BREVO_API_KEY belum terkonfigurasi di .env',
                              style: const TextStyle(fontSize: 11),
                            ),
                            value: prefs.emailNotificationsEnabled,
                            onChanged: (v) => _updatePref(
                                prefs.copyWith(emailNotificationsEnabled: v)),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            dense: true,
                            activeThumbColor: const Color(0xFFF26716),
                            title: const Text('Keterlambatan Kereta (Train Delay)',
                                style: TextStyle(fontSize: 12.5)),
                            value: prefs.notifyDelay,
                            onChanged: (v) =>
                                _updatePref(prefs.copyWith(notifyDelay: v)),
                          ),
                          SwitchListTile(
                            dense: true,
                            activeThumbColor: const Color(0xFFF26716),
                            title: const Text('Perubahan Jadwal (Schedule Change)',
                                style: TextStyle(fontSize: 12.5)),
                            value: prefs.notifyScheduleChange,
                            onChanged: (v) => _updatePref(
                                prefs.copyWith(notifyScheduleChange: v)),
                          ),
                          SwitchListTile(
                            dense: true,
                            activeThumbColor: const Color(0xFFF26716),
                            title: const Text(
                                'Gangguan Layanan (Service Disruption)',
                                style: TextStyle(fontSize: 12.5)),
                            value: prefs.notifyServiceDisruption,
                            onChanged: (v) => _updatePref(
                                prefs.copyWith(notifyServiceDisruption: v)),
                          ),
                          SwitchListTile(
                            dense: true,
                            activeThumbColor: const Color(0xFFF26716),
                            title: const Text('Informasi Kedatangan (Arrival Info)',
                                style: TextStyle(fontSize: 12.5)),
                            value: prefs.notifyArrivalInfo,
                            onChanged: (v) => _updatePref(
                                prefs.copyWith(notifyArrivalInfo: v)),
                          ),
                          SwitchListTile(
                            dense: true,
                            activeThumbColor: const Color(0xFFF26716),
                            title: const Text(
                                'Perubahan Status Perjalanan',
                                style: TextStyle(fontSize: 12.5)),
                            value: prefs.notifyStatusChange,
                            onChanged: (v) => _updatePref(
                                prefs.copyWith(notifyStatusChange: v)),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            dense: true,
                            leading: const Icon(
                                Icons.notifications_active_outlined,
                                size: 19,
                                color: Color(0xFF062056)),
                            title: const Text(
                              'Buka Riwayat & Uji Notifikasi Brevo',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF062056)),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: _openNotifications,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ================= 4. PENGATURAN APLIKASI (ZONA WAKTU INDONESIA & PETA) =================
                    _sectionTitle('PENGATURAN APLIKASI'),
                    _cardContainer(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Zona Waktu Indonesia',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF062056),
                                      ),
                                    ),
                                    const IndonesiaClockPill(),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: IndonesiaTimezone.values.map((tz) {
                                    final sel =
                                        prefs.preferredTimezone == tz.code;
                                    return Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 3),
                                        child: ChoiceChip(
                                          label: Center(
                                            child: Text(
                                              '${tz.code} (+${tz.utcOffsetHours})',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: sel
                                                    ? Colors.white
                                                    : const Color(0xFF062056),
                                              ),
                                            ),
                                          ),
                                          selected: sel,
                                          selectedColor:
                                              const Color(0xFF062056),
                                          backgroundColor:
                                              const Color(0xFFF1F5F9),
                                          side: BorderSide.none,
                                          onSelected: (_) => _updatePref(
                                            prefs.copyWith(
                                                preferredTimezone: tz.code),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            dense: true,
                            activeThumbColor: const Color(0xFFF26716),
                            title: const Text(
                              'Auto-Follow Kereta Terpilih di Peta',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            subtitle: const Text(
                              'Kamera peta otomatis mengikuti pergerakan kereta yang sedang dipilih',
                              style: TextStyle(fontSize: 11),
                            ),
                            value: prefs.autoFollowTrain,
                            onChanged: (v) => _updatePref(
                                prefs.copyWith(autoFollowTrain: v)),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.security_rounded,
                                size: 19, color: Color(0xFF062056)),
                            title: const Text(
                              'Keamanan Akun & Ubah Kata Sandi',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: _openSecurity,
                          ),
                          const Divider(height: 1),
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.map_outlined,
                                size: 19, color: Color(0xFF062056)),
                            title: const Text(
                              'Integrasi MapLibre + MapTiler & Supabase',
                              style: TextStyle(
                                  fontSize: 12.5, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              'MapTiler: ${AppEnv.hasMapTilerConfig ? "Terkonfigurasi (.env)" : "Belum diatur"} • Supabase: ${SupabaseService.isInitialized ? "Terhubung" : "Offline"}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ================= 5. MASUK / LOGOUT =================
                    if (_email.isEmpty) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF062056),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const LoginScreen(alreadyAnimated: true),
                              ),
                            );
                          },
                          icon: const Icon(Icons.login_rounded, size: 18),
                          label: const Text(
                            'Masuk / Daftar Akun TKA',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: Color(0xFFFECACA), width: 1.5),
                          backgroundColor: const Color(0xFFFEF2F2),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _handleLogout,
                        icon: const Icon(Icons.logout_rounded,
                            color: Color(0xFFDC2626), size: 18),
                        label: const Text(
                          'Keluar dari Akun (Logout)',
                          style: TextStyle(
                            color: Color(0xFFDC2626),
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Color(0xFF64748B),
          letterSpacing: 0.7,
        ),
      ),
    );
  }

  Widget _cardContainer({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: child,
    );
  }

  Widget _miniStatPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFFF26716)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF062056),
            ),
          ),
        ],
      ),
    );
  }
}
