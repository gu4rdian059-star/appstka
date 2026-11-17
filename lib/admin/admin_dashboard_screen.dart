import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../login/login_screen.dart';
import '../services/admin_service.dart';
import '../services/session_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  final String adminEmail;
  final String adminName;

  const AdminDashboardScreen({
    super.key,
    this.adminEmail = 'admin@tka.id',
    this.adminName = 'Bambang Sudiro, M.T.',
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with TickerProviderStateMixin {
  late final AnimationController _animController;
  late final AnimationController _trainTrackController;

  int _activeTabIndex = 0; // 0: Ringkasan, 1: Jadwal Kereta, 2: Transaksi, 3: Kelola Admin

  // Unified Request Pattern States (supabase-patterns/SKILL.md)
  bool _isLoading = true;
  String? _errorMessage;

  // Domain Data State
  AdminOverviewMetrics? _metrics;
  List<TrainScheduleItem> _schedules = [];
  List<BookingTransactionItem> _bookings = [];
  List<AdminAccountItem> _admins = [];

  // Filter & Search States
  String _scheduleFilter = 'Semua';
  String _bookingFilter = 'Semua';
  final TextEditingController _bookingSearchController = TextEditingController();

  // Supabase live status
  bool _isSupabaseConnected = true;
  bool _isRefreshing = false;

  // ============================================================================
  // INTERACTIVE GRAPHICS & ANIMATION STATES
  // ============================================================================
  int _chartMode = 0; // 0: Pendapatan (Rp), 1: Volume Tiket (Pcs)
  int _selectedChartDay = 4; // 0: Sen .. 4: Jum .. 6: Min
  int _selectedHourlyIndex = 1; // 08:00 WIB
  int _selectedClassIndex = 0; // 0: Eksekutif

  // Weekly Trend Data for Interactive Spline Chart
  final List<Map<String, dynamic>> _weeklyData = const [
    {'day': 'Sen', 'fullDay': 'Senin, 11 Nov', 'revenue': 38500000.0, 'tickets': 1120, 'growth': '+8.4%'},
    {'day': 'Sel', 'fullDay': 'Selasa, 12 Nov', 'revenue': 41200000.0, 'tickets': 1210, 'growth': '+11.2%'},
    {'day': 'Rab', 'fullDay': 'Rabu, 13 Nov', 'revenue': 39800000.0, 'tickets': 1180, 'growth': '+6.5%'},
    {'day': 'Kam', 'fullDay': 'Kamis, 14 Nov', 'revenue': 45600000.0, 'tickets': 1340, 'growth': '+14.1%'},
    {'day': 'Jum', 'fullDay': 'Jumat, 15 Nov', 'revenue': 54800000.0, 'tickets': 1620, 'growth': '+21.5%'},
    {'day': 'Sab', 'fullDay': 'Sabtu, 16 Nov', 'revenue': 58200000.0, 'tickets': 1740, 'growth': '+24.8%'},
    {'day': 'Min', 'fullDay': 'Minggu, 17 Nov', 'revenue': 51000000.0, 'tickets': 1530, 'growth': '+16.7%'},
  ];

  // Ticket Class Distribution Data for Donut Chart
  final List<Map<String, dynamic>> _ticketClassData = const [
    {'name': 'Eksekutif', 'pct': 0.45, 'tickets': 642, 'revenue': 'Rp 24.2 Jt', 'color': Color(0xFF062056)},
    {'name': 'Kereta Cepat', 'pct': 0.30, 'tickets': 428, 'revenue': 'Rp 16.5 Jt', 'color': Color(0xFFF26716)},
    {'name': 'Luxury Sleeper', 'pct': 0.15, 'tickets': 214, 'revenue': 'Rp 8.1 Jt', 'color': Color(0xFFF59E0B)},
    {'name': 'Bisnis & Lainnya', 'pct': 0.10, 'tickets': 144, 'revenue': 'Rp 4.9 Jt', 'color': Color(0xFF10B981)},
  ];

  // Hourly Departure Load for Bar Chart
  final List<Map<String, dynamic>> _hourlyLoad = const [
    {'time': '06:00', 'load': 0.65, 'passengers': 364, 'note': 'Awal Dinas Pagi'},
    {'time': '08:00', 'load': 0.95, 'passengers': 532, 'note': 'Jam Sibuk Pagi (Puncak)'},
    {'time': '10:00', 'load': 0.70, 'passengers': 392, 'note': 'Perjalanan Bisnis'},
    {'time': '12:00', 'load': 0.55, 'passengers': 308, 'note': 'Reguler Siang'},
    {'time': '14:00', 'load': 0.60, 'passengers': 336, 'note': 'Reguler Siang'},
    {'time': '16:00', 'load': 0.88, 'passengers': 492, 'note': 'Arus Balik Sore'},
    {'time': '18:00', 'load': 0.92, 'passengers': 515, 'note': 'Jam Sibuk Sore (Puncak)'},
    {'time': '20:00', 'load': 0.78, 'passengers': 436, 'note': 'Perjalanan Malam'},
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    // Continuous Live Railway Track Simulator Loop (6 seconds per cycle)
    _trainTrackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..repeat();

    _bookingSearchController.addListener(_onSearchChanged);
    _loadAllData();
  }

  @override
  void dispose() {
    _animController.dispose();
    _trainTrackController.dispose();
    _bookingSearchController.removeListener(_onSearchChanged);
    _bookingSearchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _fetchBookings();
  }

  Future<void> _loadAllData({bool showIndicator = true}) async {
    if (showIndicator) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final conn = await AdminService.checkSupabaseStatus();
      final metrics = await AdminService.getOverviewMetrics();
      final schedules = await AdminService.getTrainSchedules(statusFilter: _scheduleFilter);
      final bookings = await AdminService.getBookings(
        searchQuery: _bookingSearchController.text,
        statusFilter: _bookingFilter,
      );
      final admins = await AdminService.getAdminAccounts();

      if (mounted) {
        setState(() {
          _isSupabaseConnected = conn;
          _metrics = metrics;
          _schedules = schedules;
          _bookings = bookings;
          _admins = admins;
          _isLoading = false;
          _isRefreshing = false;
        });
        _animController.forward(from: 0.0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat data operasional: $e';
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _fetchBookings() async {
    final bookings = await AdminService.getBookings(
      searchQuery: _bookingSearchController.text,
      statusFilter: _bookingFilter,
    );
    if (mounted) {
      setState(() {
        _bookings = bookings;
      });
    }
  }

  Future<void> _fetchSchedules() async {
    final schedules = await AdminService.getTrainSchedules(statusFilter: _scheduleFilter);
    if (mounted) {
      setState(() {
        _schedules = schedules;
      });
    }
  }

  void _showNotification(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFE53935) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ============================================================================
  // DIALOGS & MODAL SHEETS
  // ============================================================================

  void _showLogoutDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 28),
            ),
            const SizedBox(height: 16),
            const Text(
              'Keluar dari Portal Admin?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sesi otentikasi admin Anda akan diakhiri. Anda perlu login kembali untuk mengakses panel kontrol.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Batal',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await SessionService.clearSession();
                      if (!mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen(alreadyAnimated: true)),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Ya, Keluar',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showAddAdminModal() {
    final formKey = GlobalKey<FormState>();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    String selectedRole = 'Super Admin';
    bool obscurePass = true;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF26716).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.admin_panel_settings_rounded,
                              color: Color(0xFFF26716),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Daftarkan Akun Admin Baru',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF10B981),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    const Text(
                                      'Tersinkronisasi ke Supabase Cloud Auth',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF10B981),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(height: 1),
                      const SizedBox(height: 20),

                      // Field 1: Nama Lengkap
                      const Text(
                        'Nama Lengkap Petugas',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          hintText: 'Contoh: Dimas Prasetyo, S.Kom',
                          prefixIcon: const Icon(Icons.person_outline, size: 20),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().length < 3) {
                            return 'Nama minimal 3 karakter';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 14),

                      // Field 2: Email Admin
                      const Text(
                        'Email Akun Admin (Supabase Auth)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'nama.admin@tka.id',
                          prefixIcon: const Icon(Icons.email_outlined, size: 20),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || !v.contains('@') || !v.contains('.')) {
                            return 'Masukkan email valid (@tka.id)';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 14),

                      // Field 3: Kata Sandi
                      const Text(
                        'Kata Sandi Sementara',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: passCtrl,
                        obscureText: obscurePass,
                        decoration: InputDecoration(
                          hintText: 'Minimal 8 karakter',
                          prefixIcon: const Icon(Icons.lock_outline, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              size: 20,
                            ),
                            onPressed: () => setModalState(() => obscurePass = !obscurePass),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.length < 8) {
                            return 'Kata sandi minimal 8 karakter';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 14),

                      // Field 4: Role / Peran
                      const Text(
                        'Peran & Hak Akses',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedRole,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(value: 'Super Admin', child: Text('Super Admin (Akses Penuh)')),
                              DropdownMenuItem(value: 'Operator Perjalanan', child: Text('Operator Perjalanan (Armada & Jadwal)')),
                              DropdownMenuItem(value: 'Petugas Stasiun', child: Text('Petugas Stasiun (Check-in & Tiket)')),
                              DropdownMenuItem(value: 'Finance & Audit', child: Text('Finance & Audit (Transaksi & Laporan)')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() => selectedRole = val);
                              }
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setModalState(() => isSubmitting = true);

                                  final res = await AdminService.createAdminAccount(
                                    email: emailCtrl.text,
                                    password: passCtrl.text,
                                    fullName: nameCtrl.text,
                                    role: selectedRole,
                                  );

                                  setModalState(() => isSubmitting = false);
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                  }

                                  if (res.success) {
                                    _showNotification(res.message);
                                    _loadAllData(showIndicator: false);
                                  } else {
                                    _showNotification(res.message, isError: true);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF062056),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.cloud_upload_outlined, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Simpan & Daftarkan ke Supabase',
                                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showBookingDetailModal(BookingTransactionItem booking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.bookingId,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF062056),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Dibuat pada: ${_formatDateTime(booking.createdAt)}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                _buildStatusPill(booking.status),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Passenger Info Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _buildDetailRow(Icons.person_outline, 'Nama Penumpang', booking.passengerName),
                  const SizedBox(height: 10),
                  _buildDetailRow(Icons.email_outlined, 'Email', booking.passengerEmail),
                  const SizedBox(height: 10),
                  _buildDetailRow(Icons.phone_outlined, 'No. Handphone', booking.passengerPhone),
                  const SizedBox(height: 10),
                  _buildDetailRow(Icons.train_outlined, 'Kereta & Rute', '${booking.trainName} (${booking.route})'),
                  const SizedBox(height: 10),
                  _buildDetailRow(Icons.airline_seat_recline_extra_outlined, 'Tempat Duduk', '${booking.seatNumber} • ${booking.wagonClass}'),
                  const SizedBox(height: 10),
                  _buildDetailRow(Icons.payment_outlined, 'Metode Bayar', booking.paymentMethod),
                  const SizedBox(height: 10),
                  _buildDetailRow(Icons.monetization_on_outlined, 'Total Tarif', 'Rp ${_formatCurrency(booking.amount)}', isBold: true),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Actions: Refund or Verify Boarding
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: booking.status == 'Refund'
                        ? null
                        : () async {
                            Navigator.pop(ctx);
                            await AdminService.updateBookingStatus(
                              bookingId: booking.bookingId,
                              newStatus: 'Refund',
                            );
                            _showNotification('Tiket ${booking.bookingId} berhasil diproses Refund.');
                            _fetchBookings();
                          },
                    icon: const Icon(Icons.currency_exchange_rounded, size: 18, color: Color(0xFFEF4444)),
                    label: const Text(
                      'Proses Refund',
                      style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFEF4444)),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: booking.status == 'Lunas'
                        ? null
                        : () async {
                            Navigator.pop(ctx);
                            await AdminService.updateBookingStatus(
                              bookingId: booking.bookingId,
                              newStatus: 'Lunas',
                            );
                            _showNotification('Pembayaran tiket ${booking.bookingId} telah diverifikasi Lunas.');
                            _fetchBookings();
                          },
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text(
                      'Tandai Lunas',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // MAIN BUILD
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9), // Slate 100
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                // 1. Sleek Command Center Header with KPIs
                _buildAdminHeader(),

                // 2. Custom Segmented Navigation Bar
                _buildSegmentedNav(),

                // 3. Tab Contents with Pull-to-Refresh
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: Color(0xFF062056)),
                        )
                      : _errorMessage != null
                          ? _buildErrorView()
                          : RefreshIndicator(
                              onRefresh: () => _loadAllData(showIndicator: false),
                              color: const Color(0xFFF26716),
                              child: _buildActiveTabContent(),
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // HEADER COMPONENT (Deep Navy Command Center)
  // ============================================================================

  Widget _buildAdminHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 20,
        right: 20,
        bottom: 18,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF041433),
            Color(0xFF062056),
            Color(0xFF092C78),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Bar: Admin Info + Cloud Status + Actions
          Row(
            children: [
              // Avatar with Initials
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF26716), Color(0xFFFF944D)],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF26716).withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Text(
                  'BS',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Title and Role
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'PORTAL ADMIN TKA',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFF26716),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (_isSupabaseConnected ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: (_isSupabaseConnected ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.6),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: _isSupabaseConnected ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _isSupabaseConnected ? 'Supabase Live' : 'Offline Cache',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: _isSupabaseConnected ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.adminName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // Action Buttons: Refresh & Logout
              IconButton(
                onPressed: _isRefreshing
                    ? null
                    : () {
                        setState(() => _isRefreshing = true);
                        _loadAllData(showIndicator: false);
                      },
                tooltip: 'Sinkronisasi Data',
                icon: _isRefreshing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded, color: Colors.white, size: 22),
              ),
              IconButton(
                onPressed: _showLogoutDialog,
                tooltip: 'Keluar',
                icon: const Icon(Icons.logout_rounded, color: Color(0xFFFF8585), size: 22),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Horizontal KPI Quick Metrics Strip
          if (_metrics != null) _buildKpiRow(_metrics!),
        ],
      ),
    );
  }

  Widget _buildKpiRow(AdminOverviewMetrics m) {
    return SizedBox(
      height: 72,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          _buildKpiCard(
            title: 'Pendapatan Tiket',
            value: 'Rp ${_formatCompactCurrency(m.totalRevenue)}',
            trend: '+${m.revenueGrowth}%',
            icon: Icons.payments_rounded,
            iconColor: const Color(0xFF10B981),
          ),
          const SizedBox(width: 10),
          _buildKpiCard(
            title: 'Tiket Terjual',
            value: '${m.ticketsSold} Tiket',
            trend: '${m.occupancyRate}% Okupansi',
            icon: Icons.confirmation_number_rounded,
            iconColor: const Color(0xFFF26716),
          ),
          const SizedBox(width: 10),
          _buildKpiCard(
            title: 'Armada Aktif',
            value: '${m.activeTrains} Kereta',
            trend: '100% Siap',
            icon: Icons.train_rounded,
            iconColor: const Color(0xFF38BDF8),
          ),
          const SizedBox(width: 10),
          _buildKpiCard(
            title: 'Database User',
            value: '${m.registeredUsers} User',
            trend: 'Supabase Sync',
            icon: Icons.group_rounded,
            iconColor: const Color(0xFFA855F7),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String trend,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      width: 146,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  trend,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: iconColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // SEGMENTED TAB BAR
  // ============================================================================

  Widget _buildSegmentedNav() {
    final tabs = [
      {'label': 'Ringkasan', 'icon': Icons.dashboard_outlined},
      {'label': 'Jadwal KA', 'icon': Icons.train_outlined},
      {'label': 'Transaksi', 'icon': Icons.receipt_long_outlined},
      {'label': 'Akun Admin', 'icon': Icons.manage_accounts_outlined},
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = _activeTabIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _activeTabIndex = index);
                _animController.forward(from: 0.0);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF062056) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tabs[index]['icon'] as IconData,
                      size: 18,
                      color: isSelected ? const Color(0xFFF26716) : const Color(0xFF64748B),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tabs[index]['label'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ============================================================================
  // TAB 1: RINGKASAN (OVERVIEW WITH ANIMATIONS & CHARTS)
  // ============================================================================

  Widget _buildActiveTabContent() {
    switch (_activeTabIndex) {
      case 0:
        return _buildOverviewTab();
      case 1:
        return _buildSchedulesTab();
      case 2:
        return _buildBookingsTab();
      case 3:
        return _buildAdminManagementTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Supabase Cloud Status Card
          _buildSupabaseStatusBanner(),

          const SizedBox(height: 16),

          // 2. GRAFIK UTAMA 1: Interactive Animated Revenue & Ticket Spline Chart
          _buildInteractiveRevenueChartCard(),

          const SizedBox(height: 16),

          // 3. ANIMASI UTAMA: Live GPS Railway Track & Bullet Train Simulator
          _buildLiveTrainTrackRadarCard(),

          const SizedBox(height: 16),

          // 4. GRAFIK UTAMA 2: Animated Donut Chart for Ticket Class Distribution
          _buildAnimatedDonutDistributionCard(),

          const SizedBox(height: 16),

          // 5. GRAFIK UTAMA 3: Animated Hourly Departure Traffic Bars
          _buildTrafficChartCard(),

          const SizedBox(height: 16),

          // 6. Operational Quick Action Shortcuts
          _buildQuickActionCards(),

          const SizedBox(height: 16),

          // 7. Live Activity Stream
          _buildRecentActivitySection(),
        ],
      ),
    );
  }

  Widget _buildSupabaseStatusBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.cloud_done_rounded,
              color: Color(0xFF10B981),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Supabase Postgres Cluster',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '99.98% SLA',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF10B981)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                const Text(
                  'Project ID: lbjpvbwmctzuhkqdidpt • RLS Security Active',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // GRAFIK 1: INTERACTIVE ANIMATED REVENUE & VOLUME SPLINE CHART
  // ============================================================================

  Widget _buildInteractiveRevenueChartCard() {
    final curDay = _weeklyData[_selectedChartDay];
    final isRevenue = _chartMode == 0;
    final valStr = isRevenue
        ? 'Rp ${_formatCurrency(curDay['revenue'] as double)}'
        : '${curDay['tickets']} Tiket';

    // Normalize weekly values between 0.0 and 1.0 for the curve
    final values = _weeklyData.map((d) {
      if (isRevenue) {
        final r = d['revenue'] as double;
        return (r - 35000000.0) / 25000000.0; // 35Jt to 60Jt
      } else {
        final t = d['tickets'] as int;
        return (t - 1000.0) / 800.0;
      }
    }).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Title and Mode Switcher
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.show_chart_rounded, size: 18, color: Color(0xFF062056)),
                      SizedBox(width: 6),
                      Text(
                        'Tren Analisis & Pendapatan',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Performa 7 hari terakhir (Real-time DB)',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              // Segmented Toggle
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    _buildChartModeBtn('Rp', 0),
                    _buildChartModeBtn('Tiket', 1),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Interactive Callout Banner (Values of the selected day)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF062056).withValues(alpha: 0.05),
                  const Color(0xFFF26716).withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF062056).withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      curDay['fullDay'] as String,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      valStr,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF062056),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.trending_up_rounded, size: 14, color: Color(0xFF10B981)),
                      const SizedBox(width: 4),
                      Text(
                        curDay['growth'] as String,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF10B981)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Custom Animated Spline Area Chart
          SizedBox(
            height: 150,
            width: double.infinity,
            child: AnimatedBuilder(
              animation: _animController,
              builder: (ctx, _) {
                return CustomPaint(
                  painter: _RevenueCurvePainter(
                    values: values,
                    progress: _animController.value,
                    selectedIndex: _selectedChartDay,
                    primaryColor: const Color(0xFF062056),
                    accentColor: const Color(0xFFF26716),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 10),

          // Day Selection Buttons Row (Tap to inspect specific day)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_weeklyData.length, (idx) {
              final isSel = idx == _selectedChartDay;
              final dayLabel = _weeklyData[idx]['day'] as String;

              return InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedChartDay = idx);
                },
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSel ? const Color(0xFF062056) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    dayLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                      color: isSel ? Colors.white : const Color(0xFF64748B),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildChartModeBtn(String label, int mode) {
    final isSelected = _chartMode == mode;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _chartMode = mode);
        _animController.forward(from: 0.0);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF062056) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // ANIMASI: LIVE GPS RAILWAY RADAR & SPEEDOMETER
  // ============================================================================

  Widget _buildLiveTrainTrackRadarCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF061A40),
            Color(0xFF0A2558),
            Color(0xFF041433),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 14, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Live Pulse Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.radar_rounded, size: 18, color: Color(0xFFF26716)),
                  SizedBox(width: 8),
                  Text(
                    'Radar Armada Kereta Cepat (Live GPS)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.7), width: 0.8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.fiber_manual_record_rounded, size: 8, color: Color(0xFFEF4444)),
                    SizedBox(width: 4),
                    Text(
                      '350 KM/JAM',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFFFF6B6B)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Custom Animated Railway Painter with moving train
          SizedBox(
            height: 90,
            width: double.infinity,
            child: AnimatedBuilder(
              animation: _trainTrackController,
              builder: (ctx, _) {
                return CustomPaint(
                  painter: _LiveRailwayTrackPainter(
                    progress: _trainTrackController.value,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // Active Train Telemetry Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: const Row(
              children: [
                Icon(Icons.speed_rounded, size: 16, color: Color(0xFFF26716)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'KA-1024 Argo Parahyangan • Karawang ➔ Padalarang • Tepat Waktu (ETA: 11m)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // GRAFIK 2: ANIMATED DONUT CHART (DISTRIBUSI KELAS TIKET)
  // ============================================================================

  Widget _buildAnimatedDonutDistributionCard() {
    final portions = _ticketClassData.map((d) => d['pct'] as double).toList();
    final colors = _ticketClassData.map((d) => d['color'] as Color).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pie_chart_outline_rounded, size: 18, color: Color(0xFF062056)),
              SizedBox(width: 6),
              Text(
                'Distribusi Okupansi per Kelas',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            'Proporsi tiket terjual berdasarkan varian layanan',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 18),

          Row(
            children: [
              // Animated Donut Widget
              SizedBox(
                width: 125,
                height: 125,
                child: AnimatedBuilder(
                  animation: _animController,
                  builder: (ctx, _) {
                    return CustomPaint(
                      painter: _DonutChartPainter(
                        portions: portions,
                        colors: colors,
                        progress: _animController.value,
                        selectedIndex: _selectedClassIndex,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Total',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                            ),
                            Text(
                              '${_metrics?.ticketsSold ?? 1428}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF062056),
                              ),
                            ),
                            const Text(
                              'Tiket',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(width: 16),

              // Legend and Breakdown List
              Expanded(
                child: Column(
                  children: List.generate(_ticketClassData.length, (idx) {
                    final item = _ticketClassData[idx];
                    final isSel = idx == _selectedClassIndex;
                    final col = item['color'] as Color;

                    return InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedClassIndex = idx);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSel ? col.withValues(alpha: 0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: col,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item['name'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            Text(
                              '${((item['pct'] as double) * 100).toInt()}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: col,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // GRAFIK 3: ANIMATED HOURLY DEPARTURE TRAFFIC BARS
  // ============================================================================

  Widget _buildTrafficChartCard() {
    final curHour = _hourlyLoad[_selectedHourlyIndex];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.bar_chart_rounded, size: 18, color: Color(0xFF062056)),
                  SizedBox(width: 6),
                  Text(
                    'Trafik Penumpang per Jam',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Ketuk Batang',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Keterisian kursi tertinggi di jam 08:00 & 18:00 WIB',
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),

          // Detail Callout for Selected Hour
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFFF26716)),
                    const SizedBox(width: 6),
                    Text(
                      'Pukul ${curHour['time']} WIB',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF062056)),
                    ),
                  ],
                ),
                Text(
                  '${curHour['passengers']} Penumpang (${((curHour['load'] as double) * 100).toInt()}% Okupansi)',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF10B981)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Animated Bar Visualizer
          SizedBox(
            height: 120,
            child: AnimatedBuilder(
              animation: _animController,
              builder: (ctx, _) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(_hourlyLoad.length, (idx) {
                    final h = _hourlyLoad[idx];
                    final load = h['load'] as double;
                    final isPeak = load >= 0.90;
                    final isSel = idx == _selectedHourlyIndex;
                    final fullHeight = (load * 85).clamp(20.0, 85.0);
                    final animatedHeight = fullHeight * _animController.value;

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedHourlyIndex = idx);
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '${(load * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: isSel
                                  ? const Color(0xFFF26716)
                                  : (isPeak ? const Color(0xFFF26716) : const Color(0xFF94A3B8)),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 24,
                            height: animatedHeight,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: isSel
                                    ? [const Color(0xFFF26716), const Color(0xFFFF944D)]
                                    : (isPeak
                                        ? [const Color(0xFFF26716), const Color(0xFFFF8A3D)]
                                        : [const Color(0xFF062056), const Color(0xFF1E3A8A)]),
                              ),
                              borderRadius: BorderRadius.circular(6),
                              border: isSel
                                  ? Border.all(color: const Color(0xFF062056), width: 2)
                                  : null,
                              boxShadow: isSel
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFFF26716).withValues(alpha: 0.4),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            h['time'] as String,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSel ? FontWeight.w900 : (isPeak ? FontWeight.w800 : FontWeight.w600),
                              color: isSel ? const Color(0xFFF26716) : (isPeak ? const Color(0xFF0F172A) : const Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCards() {
    return Row(
      children: [
        Expanded(
          child: _buildActionTile(
            title: 'Daftar Admin',
            subtitle: 'Supabase Auth',
            icon: Icons.person_add_alt_1_rounded,
            color: const Color(0xFF062056),
            onTap: _showAddAdminModal,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionTile(
            title: 'Audit Tiket',
            subtitle: '${_bookings.length} Transaksi',
            icon: Icons.qr_code_scanner_rounded,
            color: const Color(0xFFF26716),
            onTap: () => setState(() => _activeTabIndex = 2),
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivitySection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Log Aktivitas Operasional',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                'Real-time',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildActivityItem(
            icon: Icons.check_circle_rounded,
            iconColor: const Color(0xFF10B981),
            title: 'Pembayaran Tiket Lunas',
            desc: 'Arya Pratama - KA-1024 Halim ke Tegalluar (Rp 250.000)',
            time: '18 menit lalu',
          ),
          const Divider(height: 18),
          _buildActivityItem(
            icon: Icons.cloud_sync_rounded,
            iconColor: const Color(0xFF062056),
            title: 'Sinkronisasi Jadwal Supabase',
            desc: 'KA-1028 Nusantara Ekspres status diubah menjadi: Boarding',
            time: '42 menit lalu',
          ),
          const Divider(height: 18),
          _buildActivityItem(
            icon: Icons.shield_rounded,
            iconColor: const Color(0xFFF26716),
            title: 'Sesi Admin Diotorisasi',
            desc: 'Bambang Sudiro, M.T. (admin@tka.id) berhasil masuk via Supabase Auth',
            time: 'Hari ini, 08:15 WIB',
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String desc,
    required String time,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          time,
          style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
        ),
      ],
    );
  }

  // ============================================================================
  // TAB 2: JADWAL KERETA (SCHEDULES & FLEET)
  // ============================================================================

  Widget _buildSchedulesTab() {
    final filterOptions = ['Semua', 'Tepat Waktu', 'Boarding', 'Terlambat'];

    return Column(
      children: [
        // Filter Chips Bar
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: filterOptions.map((f) {
              final isSelected = _scheduleFilter == f;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(f),
                  selected: isSelected,
                  onSelected: (val) {
                    setState(() => _scheduleFilter = f);
                    _fetchSchedules();
                  },
                  backgroundColor: Colors.white,
                  selectedColor: const Color(0xFF062056),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                  ),
                  side: BorderSide(
                    color: isSelected ? const Color(0xFF062056) : const Color(0xFFCBD5E1),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            }).toList(),
          ),
        ),

        // List of Trains
        Expanded(
          child: _schedules.isEmpty
              ? _buildEmptyState(
                  title: 'Tidak Ada Jadwal Kereta',
                  desc: 'Tidak ada perjalanan kereta yang cocok dengan filter "$_scheduleFilter".',
                  onReset: () {
                    setState(() => _scheduleFilter = 'Semua');
                    _fetchSchedules();
                  },
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  physics: const BouncingScrollPhysics(),
                  itemCount: _schedules.length,
                  itemBuilder: (ctx, index) {
                    final item = _schedules[index];
                    return _buildTrainScheduleCard(item);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTrainScheduleCard(TrainScheduleItem item) {
    final occupancyPct = (item.bookedSeats / item.capacity).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Code + Category + Status Dropdown
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF062056),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.trainNumber,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.trainName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              // Status Badge with Tap Menu
              PopupMenuButton<String>(
                onSelected: (newStatus) async {
                  await AdminService.updateScheduleStatus(id: item.id, newStatus: newStatus);
                  _showNotification('Status ${item.trainNumber} diubah ke $newStatus');
                  _fetchSchedules();
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'Tepat Waktu', child: Text('🟢 Tepat Waktu')),
                  const PopupMenuItem(value: 'Boarding', child: Text('🟡 Boarding')),
                  const PopupMenuItem(value: 'Terlambat 15m', child: Text('🔴 Terlambat 15m')),
                  const PopupMenuItem(value: 'Tiba', child: Text('⚪ Tiba di Tujuan')),
                ],
                child: _buildStatusPill(item.status, isInteractive: true),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Route & Time Row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.origin,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                    ),
                    Text(
                      item.departureTime,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFF26716)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: Color(0xFF94A3B8), size: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      item.destination,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                    ),
                    Text(
                      item.arrivalTime,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Occupancy & Fare Progress Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Okupansi: ${item.bookedSeats}/${item.capacity} Kursi (${(occupancyPct * 100).toInt()}%)',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
              ),
              Text(
                'Rp ${_formatCurrency(item.fare)}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF062056)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: occupancyPct,
              minHeight: 6,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                occupancyPct > 0.9 ? const Color(0xFFF26716) : const Color(0xFF10B981),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 3: TRANSAKSI & TIKET (BOOKINGS)
  // ============================================================================

  Widget _buildBookingsTab() {
    return Column(
      children: [
        // Search & Filter Box
        Container(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          color: const Color(0xFFF1F5F9),
          child: Column(
            children: [
              // Search Input
              TextField(
                controller: _bookingSearchController,
                decoration: InputDecoration(
                  hintText: 'Cari nama penumpang, kode booking, rute...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                  suffixIcon: _bookingSearchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _bookingSearchController.clear();
                            _fetchBookings();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Filter Status Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: ['Semua', 'Lunas', 'Menunggu', 'Refund'].map((f) {
                    final isSelected = _bookingFilter == f;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(f),
                        selected: isSelected,
                        onSelected: (val) {
                          setState(() => _bookingFilter = f);
                          _fetchBookings();
                        },
                        selectedColor: const Color(0xFF062056),
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF475569),
                        ),
                        side: BorderSide(
                          color: isSelected ? const Color(0xFF062056) : const Color(0xFFCBD5E1),
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        // Booking List
        Expanded(
          child: _bookings.isEmpty
              ? _buildEmptyState(
                  title: 'Tidak Ada Transaksi',
                  desc: 'Tidak ada data pemesanan yang sesuai dengan pencarian atau filter Anda.',
                  onReset: () {
                    _bookingSearchController.clear();
                    setState(() => _bookingFilter = 'Semua');
                    _fetchBookings();
                  },
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  physics: const BouncingScrollPhysics(),
                  itemCount: _bookings.length,
                  itemBuilder: (ctx, index) {
                    final booking = _bookings[index];
                    return _buildBookingCard(booking);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBookingCard(BookingTransactionItem booking) {
    return InkWell(
      onTap: () => _showBookingDetailModal(booking),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF062056).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.confirmation_number_outlined, size: 16, color: Color(0xFF062056)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      booking.bookingId,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF062056),
                      ),
                    ),
                  ],
                ),
                _buildStatusPill(booking.status),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.passengerName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${booking.trainNumber} • ${booking.route}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      Text(
                        '${booking.travelDate} • ${booking.departureTime}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Rp ${_formatCurrency(booking.amount)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFF26716),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      booking.seatNumber,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // TAB 4: KELOLA AKUN & SUPABASE AUTH
  // ============================================================================

  Widget _buildAdminManagementTab() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Tambah Admin Baru ke Supabase
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF062056), Color(0xFF1E3A8A)],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF062056).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF26716),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Manajemen Kredensial Supabase',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Setiap akun admin tersimpan langsung di Supabase Auth & Tabel admin_users dengan kebijakan Role-Based Access Control (RBAC).',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: _showAddAdminModal,
                    icon: const Icon(Icons.person_add_rounded, size: 18),
                    label: const Text(
                      'Daftarkan Akun Admin Baru',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF26716),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Header List
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daftar Petugas & Admin (${_admins.length})',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF10B981)),
                    SizedBox(width: 4),
                    Text(
                      'Semua Terverifikasi',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF10B981)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Admin Cards
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _admins.length,
            itemBuilder: (ctx, index) {
              final admin = _admins[index];
              return _buildAdminAccountCard(admin);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAdminAccountCard(AdminAccountItem admin) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          // Role Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF062056).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              admin.role == 'Super Admin'
                  ? Icons.security_rounded
                  : admin.role == 'Finance & Audit'
                      ? Icons.account_balance_rounded
                      : Icons.badge_rounded,
              color: const Color(0xFF062056),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),

          // Name and Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        admin.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF26716).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        admin.role,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFF26716),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  admin.email,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.cloud_done_rounded, size: 12, color: Color(0xFF10B981)),
                    const SizedBox(width: 4),
                    const Text(
                      'Terkoneksi Supabase',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
                    ),
                    const Spacer(),
                    Text(
                      'Status: ${admin.status}',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // SHARED UTILITY WIDGETS
  // ============================================================================

  Widget _buildStatusPill(String status, {bool isInteractive = false}) {
    Color bg;
    Color text;

    switch (status.toLowerCase()) {
      case 'lunas':
      case 'tepat waktu':
      case 'aktif':
        bg = const Color(0xFF10B981).withValues(alpha: 0.12);
        text = const Color(0xFF059669);
        break;
      case 'boarding':
      case 'menunggu':
      case 'menunggu pembayaran':
        bg = const Color(0xFFF59E0B).withValues(alpha: 0.12);
        text = const Color(0xFFD97706);
        break;
      case 'refund':
      case 'terlambat':
      case 'dibatalkan':
        bg = const Color(0xFFEF4444).withValues(alpha: 0.12);
        text = const Color(0xFFDC2626);
        break;
      default:
        if (status.toLowerCase().contains('terlambat')) {
          bg = const Color(0xFFEF4444).withValues(alpha: 0.12);
          text = const Color(0xFFDC2626);
        } else {
          bg = const Color(0xFF64748B).withValues(alpha: 0.12);
          text = const Color(0xFF475569);
        }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            status,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: text,
            ),
          ),
          if (isInteractive) ...[
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 14, color: text),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {bool isBold = false}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
            color: isBold ? const Color(0xFFF26716) : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required String title,
    required String desc,
    VoidCallback? onReset,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF062056).withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 36,
                color: Color(0xFF062056),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
            ),
            if (onReset != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Reset Filter', style: TextStyle(fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF062056)),
                  foregroundColor: const Color(0xFF062056),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: Color(0xFFEF4444)),
            const SizedBox(height: 14),
            const Text(
              'Gagal Menghubungkan Supabase',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage ?? 'Terjadi kendala pada jaringan server.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () => _loadAllData(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF062056),
                foregroundColor: Colors.white,
              ),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    final str = amount.toInt().toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i != 0) {
        buffer.write('.');
      }
    }
    return buffer.toString().split('').reversed.join('');
  }

  String _formatCompactCurrency(double amount) {
    if (amount >= 1000000) {
      final millions = (amount / 1000000).toStringAsFixed(1);
      return '$millions Jt';
    }
    return _formatCurrency(amount);
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day} Nov ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} WIB';
  }
}

// ============================================================================
// CUSTOM PAINTER: INTERACTIVE ANIMATED SPLINE REVENUE CURVE
// ============================================================================

class _RevenueCurvePainter extends CustomPainter {
  final List<double> values;
  final double progress;
  final int selectedIndex;
  final Color primaryColor;
  final Color accentColor;

  _RevenueCurvePainter({
    required this.values,
    required this.progress,
    required this.selectedIndex,
    required this.primaryColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final n = values.length;
    final dx = size.width / (n - 1);
    final h = size.height;

    // 1. Draw horizontal background grid lines (25%, 50%, 75%)
    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 1; i <= 3; i++) {
      final y = h * (i * 0.25);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Convert values to screen points
    final points = <Offset>[];
    for (int i = 0; i < n; i++) {
      final x = i * dx;
      // Invert Y and apply curve progress
      final normalizedY = (1.0 - (values[i].clamp(0.0, 1.0))) * (h * 0.75) + (h * 0.12);
      final animatedY = h - (h - normalizedY) * progress;
      points.add(Offset(x, animatedY));
    }

    // 2. Build Smooth Cubic Spline Path
    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 0; i < n - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final cx = (p0.dx + p1.dx) / 2;
      path.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
    }

    // 3. Draw Gradient Area Fill below Curve
    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, h)
      ..lineTo(points.first.dx, h)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accentColor.withValues(alpha: 0.22 * progress),
          primaryColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, h))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // 4. Draw Spline Line with Gradient
    final strokePaint = Paint()
      ..shader = LinearGradient(
        colors: [primaryColor, accentColor],
      ).createShader(Rect.fromLTWH(0, 0, size.width, h))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, strokePaint);

    // 5. Draw Selected Node Guide Line and Dots
    for (int i = 0; i < n; i++) {
      final pt = points[i];
      final isSel = i == selectedIndex;

      if (isSel) {
        // Vertical guideline to x-axis
        final guidePaint = Paint()
          ..color = accentColor.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;

        canvas.drawLine(Offset(pt.dx, pt.dy), Offset(pt.dx, h), guidePaint);

        // Halo outer circle
        final haloPaint = Paint()
          ..color = accentColor.withValues(alpha: 0.25)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pt, 12.0, haloPaint);

        // Core selected circle
        final corePaint = Paint()
          ..color = accentColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pt, 5.5, corePaint);

        final whiteDot = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pt, 2.5, whiteDot);
      } else {
        // Normal node dot
        final dotBg = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pt, 4.0, dotBg);

        final dotBorder = Paint()
          ..color = primaryColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawCircle(pt, 4.0, dotBorder);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RevenueCurvePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.values != values;
  }
}

// ============================================================================
// CUSTOM PAINTER: ANIMATED DONUT CHART
// ============================================================================

class _DonutChartPainter extends CustomPainter {
  final List<double> portions;
  final List<Color> colors;
  final double progress;
  final int selectedIndex;

  _DonutChartPainter({
    required this.portions,
    required this.colors,
    required this.progress,
    required this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 10;
    const strokeW = 14.0;

    double startAngle = -math.pi / 2;

    for (int i = 0; i < portions.length; i++) {
      final sweepAngle = portions[i] * 2 * math.pi * progress;
      final isSel = i == selectedIndex;

      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSel ? strokeW + 4.0 : strokeW
        ..strokeCap = StrokeCap.round;

      final drawRadius = isSel ? radius + 2.0 : radius;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: drawRadius),
        startAngle + 0.04, // slight spacing between arcs
        (sweepAngle - 0.08).clamp(0.0, 2 * math.pi),
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.selectedIndex != selectedIndex;
  }
}

// ============================================================================
// CUSTOM PAINTER: LIVE HIGH-SPEED RAILWAY RADAR SIMULATOR
// ============================================================================

class _LiveRailwayTrackPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0 (from repeating animation controller)

  _LiveRailwayTrackPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final centerY = h * 0.45;

    // 1. Draw Base Track Curve
    final trackPath = Path()
      ..moveTo(24, centerY)
      ..cubicTo(w * 0.35, centerY - 18, w * 0.65, centerY + 18, w - 24, centerY);

    // Track Rail (Glow line)
    final railBg = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(trackPath, railBg);

    // 2. Active traveled path in Orange
    final pathMetrics = trackPath.computeMetrics().toList();
    if (pathMetrics.isNotEmpty) {
      final metric = pathMetrics.first;
      final currentDistance = metric.length * progress;
      final activeSubpath = metric.extractPath(0, currentDistance);

      final activeRail = Paint()
        ..color = const Color(0xFFF26716)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(activeSubpath, activeRail);

      // 3. Draw 4 Fixed Stations along the track
      final stations = [
        {'name': 'Halim', 'pct': 0.05},
        {'name': 'Karawang', 'pct': 0.35},
        {'name': 'Padalarang', 'pct': 0.70},
        {'name': 'Tegalluar', 'pct': 0.95},
      ];

      for (final st in stations) {
        final pct = st['pct'] as double;
        final pos = metric.getTangentForOffset(metric.length * pct);
        if (pos != null) {
          final isPassed = progress >= pct;

          // Station dot
          final dotPaint = Paint()
            ..color = isPassed ? const Color(0xFFF26716) : Colors.white.withValues(alpha: 0.5)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(pos.position, 4.5, dotPaint);

          final ringPaint = Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5;
          canvas.drawCircle(pos.position, 4.5, ringPaint);

          // Station name text
          final tp = TextPainter(
            text: TextSpan(
              text: st['name'] as String,
              style: TextStyle(
                color: isPassed ? Colors.white : Colors.white.withValues(alpha: 0.6),
                fontSize: 10,
                fontWeight: isPassed ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, Offset(pos.position.dx - (tp.width / 2), pos.position.dy + 12));
        }
      }

      // 4. Moving Bullet Train Indicator with GPS Pulse
      final trainTangent = metric.getTangentForOffset(currentDistance);
      if (trainTangent != null) {
        final tPos = trainTangent.position;

        // Radar expanding pulse ring
        final pulseFraction = (progress * 5.0) % 1.0;
        final pulseRadius = 8.0 + (pulseFraction * 16.0);
        final pulseAlpha = (1.0 - pulseFraction) * 0.6;

        final pulsePaint = Paint()
          ..color = const Color(0xFFF26716).withValues(alpha: pulseAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawCircle(tPos, pulseRadius, pulsePaint);

        // Train Core Body
        final corePaint = Paint()
          ..color = const Color(0xFFF26716)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(tPos, 7.5, corePaint);

        // Headlight glow beam
        final headBeam = Paint()
          ..color = const Color(0xFFFFD54F)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(tPos, 3.5, headBeam);

        // Train Label pill above
        final trainPill = TextPainter(
          text: const TextSpan(
            text: 'KA-1024 ⚡',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final pillRect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(tPos.dx, tPos.dy - 16),
            width: trainPill.width + 10,
            height: trainPill.height + 4,
          ),
          const Radius.circular(6),
        );

        final pillBg = Paint()..color = const Color(0xFFF26716);
        canvas.drawRRect(pillRect, pillBg);
        trainPill.paint(canvas, Offset(tPos.dx - (trainPill.width / 2), tPos.dy - 16 - (trainPill.height / 2)));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LiveRailwayTrackPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
