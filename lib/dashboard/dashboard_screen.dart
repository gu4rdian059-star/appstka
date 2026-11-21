import 'package:flutter/material.dart';

import '../services/session_service.dart';
import '../services/user_db_service.dart';
import '../intercity/antar_kota_screen.dart';
import '../orders/orders_screen.dart';
import '../orders/order_detail_screen.dart';
import '../tickets/my_tickets_screen.dart';
import '../profile/profile_screen.dart';
import '../notifications/notifications_screen.dart';
import '../tracking/live_tracking_screen.dart';
import '../services_menu/lokal_screen.dart';
import '../services_menu/komuter_screen.dart';
import '../services_menu/lrt_mrt_screen.dart';
import '../services_menu/bandara_screen.dart';
import '../services_menu/katalog_ka_screen.dart';
import '../services_menu/customer_service_screen.dart';
import '../services_menu/lainnya_screen.dart';
import '../wallet/scan_qr_screen.dart';
import '../wallet/top_up_screen.dart';
import '../wallet/top_up_history_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String? userName;
  final int initialTabIndex;

  const DashboardScreen({super.key, this.userName, this.initialTabIndex = 0});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  String _currentUserName = 'Arya Pratama';
  int _userBalance = 0;
  int _userPoints = 0;
  String _userTier = 'Member Baru';
  List<BookingModel> _activeBookings = [];
  bool _isLoadingBookings = true;

  int _activeNavIndex = 0; // 0: Beranda, 1: Pesanan, 2: Tiket Saya, 3: Akun
  int _selectedTripType = 0; // 0: Sekali Jalan, 1: Pulang Pergi
  String _selectedClassFilter = 'Semua';
  bool _returnTripChecked = false;
  DateTime _departureDate = DateTime.now().add(const Duration(days: 1));
  DateTime? _returnDate;

  // Rute Kereta Default
  String _originStation = 'Gambir (GMR)';
  String _originCity = 'Jakarta Pusat';
  String _destStation = 'Pasar Turi (SBI)';
  String _destCity = 'Surabaya';

  void _pickDashboardDate(bool isReturn) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime firstDate = isReturn ? _departureDate : today;
    if (firstDate.isBefore(today)) firstDate = today;

    DateTime initialDate = isReturn
        ? (_returnDate ?? _departureDate.add(const Duration(days: 2)))
        : _departureDate;
    if (initialDate.isBefore(firstDate)) initialDate = firstDate;

    final lastDate = today.add(const Duration(days: 180));
    if (initialDate.isAfter(lastDate)) initialDate = lastDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: isReturn
          ? 'PILIH TANGGAL PULANG'
          : 'PILIH TANGGAL KEBERANGKATAN',
      cancelText: 'BATAL',
      confirmText: 'PILIH',
    );

    if (picked != null && mounted) {
      setState(() {
        if (isReturn) {
          _returnDate = picked;
          _returnTripChecked = true;
        } else {
          _departureDate = picked;
          if (_returnDate != null && _returnDate!.isBefore(_departureDate)) {
            _returnDate = _departureDate.add(const Duration(days: 2));
          }
        }
      });
    }
  }

  String _formatDashboardDate(DateTime d) {
    const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final dayName = days[d.weekday - 1];
    final monthName = months[d.month - 1];
    return '$dayName, ${d.day} $monthName ${d.year}';
  }

  final List<String> _classFilters = [
    'Semua',
    'Eksekutif',
    'Bisnis',
    'Ekonomi',
    'Luxury',
  ];

  @override
  void initState() {
    super.initState();
    _activeNavIndex = widget.initialTabIndex;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _loadUserData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _animController.forward(from: 0.0);
      }
    });
  }

  Future<void> _loadUserData() async {
    final savedName = widget.userName?.trim().isNotEmpty == true
        ? widget.userName!.trim()
        : await SessionService.getUserName();
    final balance = await SessionService.getUserBalance();
    final points = await SessionService.getUserPoints();
    final tier = await SessionService.getUserTier();
    final bookings = await UserDatabaseService.getBookings(
      statusFilter: 'Sudah Dibayar',
    );

    if (mounted) {
      setState(() {
        _currentUserName = savedName;
        _userBalance = balance;
        _userPoints = points;
        _userTier = tier;
        _activeBookings = bookings;
        _isLoadingBookings = false;
      });
    }
  }

  String _formatNumber(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _swapStations() {
    setState(() {
      final tempStation = _originStation;
      final tempCity = _originCity;
      _originStation = _destStation;
      _originCity = _destCity;
      _destStation = tempStation;
      _destCity = tempCity;
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat Pagi,';
    if (hour < 15) return 'Selamat Siang,';
    if (hour < 18) return 'Selamat Sore,';
    return 'Selamat Malam,';
  }

  @override
  Widget build(BuildContext context) {
    // Staggered Animations
    final headerAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
    );

    final walletAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.15, 0.60, curve: Curves.easeOutBack),
    );

    final menuAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.25, 0.70, curve: Curves.easeOutCubic),
    );

    final searchCardAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.35, 0.80, curve: Curves.easeOutCubic),
    );

    final ticketAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.45, 0.90, curve: Curves.easeOutCubic),
    );

    final promoAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.55, 1.0, curve: Curves.easeOutCubic),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            children: [
              // Konten Tab Utama
              Expanded(
                child: _buildCurrentTab(
                  context,
                  headerAnim: headerAnim,
                  walletAnim: walletAnim,
                  menuAnim: menuAnim,
                  searchCardAnim: searchCardAnim,
                  ticketAnim: ticketAnim,
                  promoAnim: promoAnim,
                ),
              ),

              // ==================== 8. BOTTOM NAVIGATION BAR ====================
              _buildBottomNavigationBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTab(
    BuildContext context, {
    required Animation<double> headerAnim,
    required Animation<double> walletAnim,
    required Animation<double> menuAnim,
    required Animation<double> searchCardAnim,
    required Animation<double> ticketAnim,
    required Animation<double> promoAnim,
  }) {
    switch (_activeNavIndex) {
      case 1:
        return OrdersScreen(
          embedded: true,
          onNavigateToTickets: () => setState(() => _activeNavIndex = 2),
        );
      case 2:
        return const MyTicketsScreen(embedded: true);
      case 3:
        return ProfileScreen(
          embedded: true,
          onOpenOrders: () => setState(() => _activeNavIndex = 1),
        );
      default:
        return _buildHomeScrollView(
          context,
          headerAnim: headerAnim,
          walletAnim: walletAnim,
          menuAnim: menuAnim,
          searchCardAnim: searchCardAnim,
          ticketAnim: ticketAnim,
          promoAnim: promoAnim,
        );
    }
  }

  Widget _buildHomeScrollView(
    BuildContext context, {
    required Animation<double> headerAnim,
    required Animation<double> walletAnim,
    required Animation<double> menuAnim,
    required Animation<double> searchCardAnim,
    required Animation<double> ticketAnim,
    required Animation<double> promoAnim,
  }) {
    return RefreshIndicator(
      onRefresh: _loadUserData,
      color: const Color(0xFFF26716),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        child: Column(
          children: [
            // ==================== 1. HEADER BIRU NAVY ====================
            SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -0.4),
                end: Offset.zero,
              ).animate(headerAnim),
              child: FadeTransition(
                opacity: headerAnim,
                child: _buildNavyHeader(context),
              ),
            ),

            // ==================== 2. KARTU TKAPay MELAYANG ====================
            Transform.translate(
              offset: const Offset(0, -42),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: ScaleTransition(
                  scale: walletAnim,
                  child: _buildWalletCard(),
                ),
              ),
            ),

            // Geser ke atas agar tidak ada gap besar akibat translate kartu
            Transform.translate(
              offset: const Offset(0, -30),
              child: Column(
                children: [
                  // ==================== 3. GRID 8 MENU LAYANAN ====================
                  FadeTransition(
                    opacity: menuAnim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.15),
                        end: Offset.zero,
                      ).animate(menuAnim),
                      child: _buildServiceMenuGrid(),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ==================== 4. FORM PEMESANAN TIKET ====================
                  FadeTransition(
                    opacity: searchCardAnim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.18),
                        end: Offset.zero,
                      ).animate(searchCardAnim),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: _buildSearchTicketCard(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ==================== 5. PERJALANAN MENDATANG ====================
                  FadeTransition(
                    opacity: ticketAnim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.20),
                        end: Offset.zero,
                      ).animate(ticketAnim),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: _buildUpcomingJourneySection(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ==================== 6. BANNER LIVE TRACKING ====================
                  FadeTransition(
                    opacity: promoAnim,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: _buildLiveTrackingBanner(),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ==================== 7. PROMO MENARIK ====================
                  FadeTransition(
                    opacity: promoAnim,
                    child: _buildPromosSection(),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // 1. HEADER BIRU NAVY (LOGO, GREETING, NOTIFIKASI, BENDERA ID)
  // ==========================================================================
  Widget _buildNavyHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        18,
        MediaQuery.paddingOf(context).top + 10,
        18,
        58,
      ),
      decoration: const BoxDecoration(color: Color(0xFF062056)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo TKA + Greeting User
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/logo_tka_full.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _getGreeting(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00E676),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _currentUserName,
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Tombol Notifikasi, Tiket/Chat & Bendera ID
          Row(
            children: [
              // Bell Notification
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => NotificationsScreen(
                        onOpenTickets: () =>
                            setState(() => _activeNavIndex = 2),
                        onOpenOrders: () => setState(() => _activeNavIndex = 1),
                      ),
                    ),
                  );
                },
                child: Stack(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF26716),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Chat / Receipt Icon
              GestureDetector(
                onTap: () => setState(() => _activeNavIndex = 1),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.receipt_long_outlined,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Bendera Indonesia + ID
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Container(
                        width: 14,
                        height: 10,
                        color: const Color(0xFFE53935),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(height: 5, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'ID',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // 2. KARTU TKAPay (SALDO, SCAN, TOP UP, RIWAYAT & MEMBER GOLD)
  // ==========================================================================
  Widget _buildWalletCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF062056).withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Baris Atas: Saldo & Tombol Aksi (Scan, Top Up, Riwayat)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Saldo TKAPay
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF062056)
                              .withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'TK',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF062056),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'TKAPay',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF062056),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        'Rp ',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        _formatNumber(_userBalance),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1B1E28),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Aksi: Scan, Top Up, Riwayat
              Row(
                children: [
                  _buildWalletAction(
                    icon: Icons.qr_code_scanner_rounded,
                    label: 'Scan',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ScanQrScreen()),
                      );
                    },
                  ),
                  const SizedBox(width: 14),
                  _buildWalletAction(
                    icon: Icons.add_circle_outline_rounded,
                    label: 'Top Up',
                    onTap: () async {
                      final refreshed = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(builder: (_) => const TopUpScreen()),
                      );
                      if (refreshed == true || mounted) {
                        _loadUserData();
                      }
                    },
                  ),
                  const SizedBox(width: 14),
                  _buildWalletAction(
                    icon: Icons.history_rounded,
                    label: 'Riwayat',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const TopUpHistoryScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),
          Divider(color: Colors.grey.shade200, height: 1),
          const SizedBox(height: 10),

          // Baris Bawah: TKA Poin & Member Tier
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF26716),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.monetization_on_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatNumber(_userPoints),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF062056),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'TKA Poin',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              // Badge Member Tier
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _userTier.contains('Gold')
                      ? const Color(0xFFFFF3E0)
                      : const Color(0xFFE8F1FC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _userTier.contains('Gold')
                        ? const Color(0xFFFFB74D).withValues(alpha: 0.5)
                        : const Color(0xFF90CAF9).withValues(alpha: 0.5),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 7,
                      color: _userTier.contains('Gold')
                          ? const Color(0xFFE65100)
                          : const Color(0xFF1565C0),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _userTier,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _userTier.contains('Gold')
                            ? const Color(0xFFE65100)
                            : const Color(0xFF1565C0),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 15,
                      color: _userTier.contains('Gold')
                          ? const Color(0xFFE65100)
                          : const Color(0xFF1565C0),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWalletAction({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6FA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF062056), size: 19),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // 3. GRID MENU LAYANAN (BARIS 1: 5 MENU, BARIS 2: 4 MENU)
  // ==========================================================================
  Widget _buildServiceMenuGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          // Baris 1: Antar Kota, Lokal, Komuter, LRT/MRT, Bandara
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildServiceItem(
                title: 'Antar Kota',
                icon: Icons.train_rounded,
                bgColor: const Color(0xFF062056),
                iconColor: Colors.white,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AntarKotaScreen(
                        initialOrigin: _originStation,
                        initialDestination: _destStation,
                        initialDate: _departureDate,
                      ),
                    ),
                  );
                },
              ),
              _buildServiceItem(
                title: 'Lokal',
                icon: Icons.subway_rounded,
                bgColor: const Color(0xFFF26716),
                iconColor: Colors.white,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LokalScreen()),
                  );
                },
              ),
              _buildServiceItem(
                title: 'Komuter',
                icon: Icons.tram_rounded,
                bgColor: const Color(0xFFEB4D4B),
                iconColor: Colors.white,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const KomuterScreen()),
                  );
                },
              ),
              _buildServiceItem(
                title: 'LRT/MRT',
                icon: Icons.electric_bolt_rounded,
                bgColor: const Color(0xFF686DE0),
                iconColor: Colors.white,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LrtMrtScreen()),
                  );
                },
              ),
              _buildServiceItem(
                title: 'Bandara',
                icon: Icons.flight_takeoff_rounded,
                bgColor: const Color(0xFF22A6B3),
                iconColor: Colors.white,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BandaraScreen()),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Baris 2: Live Tracking, Katalog KA, Bantuan CS, Lainnya
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildServiceItem(
                title: 'Live Tracking',
                icon: Icons.map_outlined,
                bgColor: const Color(0xFFE8F1FC),
                iconColor: const Color(0xFF1976D2),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const LiveTrackingScreen(),
                    ),
                  );
                },
              ),
              _buildServiceItem(
                title: 'Katalog KA',
                icon: Icons.shopping_bag_outlined,
                bgColor: const Color(0xFFFFF3E0),
                iconColor: const Color(0xFFE65100),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const KatalogKaScreen()),
                  );
                },
              ),
              _buildServiceItem(
                title: 'Bantuan CS',
                icon: Icons.support_agent_rounded,
                bgColor: const Color(0xFFE8F5E9),
                iconColor: const Color(0xFF2E7D32),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CustomerServiceScreen(),
                    ),
                  );
                },
              ),
              _buildServiceItem(
                title: 'Lainnya',
                icon: Icons.grid_view_rounded,
                bgColor: const Color(0xFFECEFF1),
                iconColor: const Color(0xFF546E7A),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LainnyaScreen()),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServiceItem({
    required String title,
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: bgColor.withValues(alpha: 0.22),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF062056),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // 4. KARTU PENCARIAN TIKET KERETA API (SEKALI JALAN / PULANG PERGI)
  // ==========================================================================
  Widget _buildSearchTicketCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF062056).withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Segment Tab: Sekali Jalan vs Pulang Pergi
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F4F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTripType = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: _selectedTripType == 0
                            ? Colors.white
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _selectedTripType == 0
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        'Sekali Jalan',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: _selectedTripType == 0
                              ? const Color(0xFF062056)
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTripType = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: _selectedTripType == 1
                            ? Colors.white
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _selectedTripType == 1
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        'Pulang Pergi',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: _selectedTripType == 1
                              ? const Color(0xFF062056)
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Stasiun Asal & Stasiun Tujuan dengan Tombol Tukar
          Stack(
            alignment: Alignment.centerRight,
            children: [
              Column(
                children: [
                  // Stasiun Asal
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 10, 50, 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'STASIUN ASAL',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade500,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _originStation,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF062056),
                              ),
                            ),
                            Text(
                              _originCity,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Stasiun Tujuan
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 10, 50, 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'STASIUN TUJUAN',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade500,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _destStation,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF062056),
                              ),
                            ),
                            Text(
                              _destCity,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Tombol Tukar Stasiun (Swap Button)
              Positioned(
                right: 12,
                child: GestureDetector(
                  onTap: _swapStations,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF26716),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF26716)
                              .withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.swap_vert_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Baris Tanggal Berangkat & Pulang
          Row(
            children: [
              // Tanggal Berangkat
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _pickDashboardDate(false),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tanggal Berangkat',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDashboardDate(_departureDate),
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF062056),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F1FC),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Pilih Kalender',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1976D2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Pulang (Opsional)
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _pickDashboardDate(true),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _returnTripChecked
                            ? const Color(0xFFFFF7ED)
                            : Colors.white,
                        border: Border.all(
                          color: _returnTripChecked
                              ? const Color(0xFFFDBA74)
                              : Colors.grey.shade200,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Pulang (Opsional)',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: Checkbox(
                                  value: _returnTripChecked,
                                  activeColor: const Color(0xFFF26716),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  onChanged: (v) {
                                    setState(() {
                                      _returnTripChecked = v ?? false;
                                      if (_returnTripChecked &&
                                          _returnDate == null) {
                                        _returnDate = _departureDate.add(
                                          const Duration(days: 2),
                                        );
                                      }
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _returnTripChecked && _returnDate != null
                                ? _formatDashboardDate(_returnDate!)
                                : 'Tambah PP',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: _returnTripChecked
                                  ? const Color(0xFFC2410C)
                                  : Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Baris Penumpang & Kelas
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PENUMPANG',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        '1 Dewasa, 0 Bayi',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF062056),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 28, color: Colors.grey.shade200),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'KELAS',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Semua Kelas',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF062056),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Pilihan Filter Kelas (Semua, Eksekutif, Bisnis, Ekonomi, Luxury)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _classFilters.map((cf) {
                final isSelected = _selectedClassFilter == cf;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedClassFilter = cf),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF062056)
                            : const Color(0xFFF1F4F9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        cf,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),

          // Tombol Cari Kereta Api
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AntarKotaScreen(
                      initialOrigin: _originStation,
                      initialDestination: _destStation,
                      initialDate: _departureDate,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF062056),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_rounded, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Cari Kereta Api',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Riwayat Terakhir Dicari
          Row(
            children: [
              Text(
                'Terakhir dicari: ',
                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
              ),
              _buildHistoryPill('GMR ➔ BD'),
              const SizedBox(width: 6),
              _buildHistoryPill('GMR ➔ YK'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryPill(String route) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        route,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  // ==========================================================================
  // 5. PERJALANAN MENDATANG (DINAMIS BERDASARKAN TIKET AKTIF USER)
  // ==========================================================================
  Widget _buildUpcomingJourneySection() {
    if (_isLoadingBookings) {
      return const SizedBox.shrink();
    }

    if (_activeBookings.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF062056).withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF062056).withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.confirmation_number_outlined,
                color: Color(0xFF062056),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Belum Ada Perjalanan Aktif',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF062056),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Pesan tiket kereta sekarang untuk mulai perjalanan Anda.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () {
                Navigator.of(context)
                    .push(
                      MaterialPageRoute(
                        builder: (_) => const AntarKotaScreen(),
                      ),
                    )
                    .then((_) => _loadUserData());
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF26716),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Cari Tiket',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final ticket = _activeBookings.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'PERJALANAN MENDATANG',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF062056),
                letterSpacing: 0.3,
              ),
            ),
            Text(
              '${_activeBookings.length} Tiket Aktif',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFFF26716),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Kartu Tiket Aktif Pengguna
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF062056).withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Kartu: Nama KA & Badge Tanggal
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.circle,
                          size: 8,
                          color: Color(0xFF2E7D32),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            ticket.trainName,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF062056),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      ticket.travelDate,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1976D2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${ticket.trainClass} • Kursi ${ticket.seatNumber}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 14),

              // Rute & Jam Keberangkatan / Kedatangan
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Asal
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ticket.departureTime.replaceAll(' WIB', ''),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF062056),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        ticket.originCode,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF062056),
                        ),
                      ),
                      Text(
                        ticket.originCity,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),

                  // Garis Tengah (Durasi & Ikon Kereta)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Column(
                        children: [
                          Text(
                            'Langsung',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              CustomPaint(
                                size: const Size(double.infinity, 2),
                                painter: _DottedLinePainter(),
                              ),
                              Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF26716),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 13,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Tujuan
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        ticket.arrivalTime.replaceAll(' WIB', ''),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF062056),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        ticket.destCode,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF062056),
                        ),
                      ),
                      Text(
                        ticket.destCity,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 14),
              Divider(color: Colors.grey.shade200, height: 1),
              const SizedBox(height: 10),

              // Baris Bawah: Kode Booking & Tombol Lihat E-Tiket
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Kode: ',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        ticket.bookingId,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace',
                          color: Color(0xFF062056),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  LiveTrackingScreen(booking: ticket),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.my_location_rounded,
                                size: 13,
                                color: Color(0xFF0256B8),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Lacak',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0256B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          Navigator.of(context)
                              .push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      OrderDetailScreen.fromBooking(ticket),
                                ),
                              )
                              .then((_) => _loadUserData());
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF26716),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Lihat E-Tiket',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // 6. BANNER LIVE TRACKING (GRADASI UNGU DENGAN IKON PETIR)
  // ==========================================================================
  Widget _buildLiveTrackingBanner() {
    return InkWell(
      onTap: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const LiveTrackingScreen()));
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C5CE7), Color(0xFF4834D4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C5CE7).withValues(alpha: 0.30),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Live Tracking',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD54F),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'BARU',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF062056),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pantau posisi dan kecepatan waktu perjalanan kereta secara real-time.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.white.withValues(alpha: 0.85),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Buka Live Tracking',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF062056),
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: Color(0xFF062056),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Ikon Petir Glowing
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.electric_bolt_rounded,
                color: Colors.white,
                size: 34,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // 7. PROMO MENARIK (CAROUSEL PROMO)
  // ==========================================================================
  Widget _buildPromosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'PROMO MENARIK',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF062056),
                  letterSpacing: 0.3,
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: const Text(
                  'Lihat Semua',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF26716),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              // Promo 1: Diskon 20%
              _buildPromoCard(
                badge: 'DISKON 20%',
                title: 'Spesial Rute Eksekutif',
                subtitle: 'Gunakan kode: TKA-EKSEKUTIF',
                validDate: 'Berlaku s/d 31 Okt',
                actionLabel: 'Klaim Promo',
                gradientColors: const [Color(0xFF062056), Color(0xFF1E3C72)],
              ),
              const SizedBox(width: 14),

              // Promo 2: Cashback 50%
              _buildPromoCard(
                badge: 'CASHBACK 50%',
                title: 'Top Up Saldo TKAPay',
                subtitle: 'Bebas biaya admin s/d Rp 25rb',
                validDate: 'Khusus Pengguna Baru',
                actionLabel: 'Top Up Sekarang',
                gradientColors: const [Color(0xFFF26716), Color(0xFFFF8E53)],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPromoCard({
    required String badge,
    required String title,
    required String subtitle,
    required String validDate,
    required String actionLabel,
    required List<Color> gradientColors,
  }) {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Atas Gradasi
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD54F),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF062056),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),

          // Info Bawah & Tombol Klaim
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  validDate,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
                Text(
                  actionLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF26716),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // 8. BOTTOM NAVIGATION BAR (BERANDA, PESANAN, TIKET SAYA, AKUN)
  // ==========================================================================
  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.home_rounded,
                label: 'Beranda',
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.receipt_long_rounded,
                label: 'Pesanan',
              ),
              _buildNavItem(
                index: 2,
                icon: Icons.confirmation_number_rounded,
                label: 'Tiket Saya',
                hasBadge: true,
              ),
              _buildNavItem(
                index: 3,
                icon: Icons.person_rounded,
                label: 'Akun',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    bool hasBadge = false,
  }) {
    final isActive = _activeNavIndex == index;
    final color = isActive ? const Color(0xFFF26716) : const Color(0xFF8E95A5);

    return GestureDetector(
      onTap: () => setState(() => _activeNavIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Icon(icon, color: color, size: 24),
              if (hasBadge)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF26716),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Painter garis putus-putus untuk rute kereta api
class _DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB0BEC5)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    const dashWidth = 4.0;
    const dashSpace = 3.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(startX + dashWidth, size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
