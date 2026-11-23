import 'dart:async';

import 'package:flutter/material.dart';

import '../services/session_service.dart';
import '../services/user_db_service.dart';
import '../transitions/page_transitions.dart';
import 'seat_selection_screen.dart';

class PassengerFormScreen extends StatefulWidget {
  final TrainScheduleModel train;
  final StationModel origin;
  final StationModel dest;
  final DateTime travelDate;
  final int adultCount;
  final int infantCount;
  final TrainScheduleModel? returnTrain;
  final DateTime? returnDate;

  const PassengerFormScreen({
    super.key,
    required this.train,
    required this.origin,
    required this.dest,
    required this.travelDate,
    this.adultCount = 1,
    this.infantCount = 0,
    this.returnTrain,
    this.returnDate,
  });

  @override
  State<PassengerFormScreen> createState() => _PassengerFormScreenState();
}

class _PassengerData {
  String category = 'Dewasa'; // 'Dewasa' or 'Bayi'
  String idType = 'NIK / KTP'; // 'NIK / KTP', 'Paspor', 'KIA'
  TextEditingController idController;
  TextEditingController nameController;

  _PassengerData({String id = '', String name = ''})
    : idController = TextEditingController(text: id),
      nameController = TextEditingController(text: name);

  void dispose() {
    idController.dispose();
    nameController.dispose();
  }
}

class _PassengerFormScreenState extends State<PassengerFormScreen> {
  // Pemesan Controllers
  final _bookerNameController = TextEditingController();
  final _bookerPhoneController = TextEditingController();
  final _bookerEmailController = TextEditingController();

  bool _copyBookerToPassenger1 = true;
  final List<_PassengerData> _passengers = [];

  // Countdown Timer (14 menit 47 detik = 887 detik)
  late int _remainingSeconds;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = 887;
    _startTimer();
    _initPassengerList();
    _loadUserProfile();
  }

  void _startTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  String get _timerFormatted {
    final m = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _initPassengerList() {
    final total = widget.adultCount.clamp(1, 4);
    for (int i = 0; i < total; i++) {
      _passengers.add(_PassengerData());
    }

    _bookerNameController.addListener(_syncBookerToPassenger1);
    _bookerPhoneController.addListener(_syncBookerToPassenger1);
  }

  void _syncBookerToPassenger1() {
    if (_copyBookerToPassenger1 && _passengers.isNotEmpty) {
      final name = _bookerNameController.text;
      if (_passengers[0].nameController.text != name) {
        _passengers[0].nameController.text = name;
      }
    }
  }

  Future<void> _loadUserProfile() async {
    final name = await SessionService.getUserName();
    final email = await SessionService.getUserEmail() ?? '';
    final phone = await SessionService.getUserPhone();
    final nik = await SessionService.getUserNik();

    if (mounted) {
      setState(() {
        _bookerNameController.text = name.isNotEmpty
            ? name
            : 'M. Safid Maulana';
        _bookerEmailController.text = email.isNotEmpty
            ? email
            : 'safid.m@tka-rail.id';
        _bookerPhoneController.text = phone.isNotEmpty ? phone : '081234567890';

        if (_passengers.isNotEmpty) {
          _passengers[0].nameController.text = _bookerNameController.text;
          _passengers[0].idController.text = nik.isNotEmpty
              ? nik
              : '3514062607090001';
        }
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _bookerNameController.dispose();
    _bookerPhoneController.dispose();
    _bookerEmailController.dispose();
    for (final p in _passengers) {
      p.dispose();
    }
    super.dispose();
  }

  int get _totalAmount {
    // Bayi gratis (Rp0), hanya dewasa yang membayar
    int payable = 0;
    final singlePersonFare =
        widget.train.baseFare + (widget.returnTrain?.baseFare ?? 0);
    for (final p in _passengers) {
      if (p.category == 'Dewasa') {
        payable += singlePersonFare;
      }
    }
    return payable > 0 ? payable : singlePersonFare;
  }

  void _validateAndProceed() {
    // Validasi Pemesan
    final bookerName = _bookerNameController.text.trim();
    final bookerPhone = _bookerPhoneController.text.trim();
    final bookerEmail = _bookerEmailController.text.trim();

    if (bookerName.isEmpty) {
      _showWarning('Nama lengkap pemesan wajib diisi!');
      return;
    }
    if (bookerPhone.length < 8) {
      _showWarning('Nomor WhatsApp / HP tidak valid!');
      return;
    }
    if (!bookerEmail.contains('@') || !bookerEmail.contains('.')) {
      _showWarning('Alamat email tidak valid!');
      return;
    }

    // Validasi Setiap Penumpang
    for (int i = 0; i < _passengers.length; i++) {
      final p = _passengers[i];
      final pName = p.nameController.text.trim();
      final pId = p.idController.text.trim();

      if (pName.isEmpty) {
        _showWarning(
          'Nama penumpang ${i + 1} wajib diisi sesuai KTP/tanda pengenal!',
        );
        return;
      }
      if (p.idType == 'NIK / KTP' && pId.length < 16) {
        _showWarning('NIK Penumpang ${i + 1} harus 16 digit angka!');
        return;
      }
      if (pId.isEmpty) {
        _showWarning('Nomor identitas penumpang ${i + 1} wajib diisi!');
        return;
      }
    }

    // Kumpulkan seluruh data penumpang
    final passengersList = _passengers
        .map(
          (p) => {
            'name': p.nameController.text.trim(),
            'nik': p.idController.text.trim(),
            'category': p.category,
            'idType': p.idType,
          },
        )
        .toList();

    // Lanjut ke Pilih Kursi dengan animasi mulus
    AppPageRoute.push(
      context,
      SeatSelectionScreen(
        train: widget.train,
        origin: widget.origin,
        dest: widget.dest,
        travelDate: widget.travelDate,
        bookerName: bookerName,
        bookerEmail: bookerEmail,
        bookerPhone: bookerPhone,
        passengerName: _passengers[0].nameController.text.trim(),
        passengerNik: _passengers[0].idController.text.trim(),
        passengers: passengersList,
        totalAmount: _totalAmount,
        returnTrain: widget.returnTrain,
        returnDate: widget.returnDate,
      ),
    );
  }

  void _showWarning(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatCurrency(int amount) {
    return 'Rp${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  String _formatDate(DateTime d) {
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
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF062056)),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Data Penumpang',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF062056),
              ),
            ),
            Text(
              'Langkah 1 dari 3: Isi Formulir',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  size: 14,
                  color: Color(0xFF1D4ED8),
                ),
                const SizedBox(width: 4),
                Text(
                  _timerFormatted,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Info Ringkas Kereta (Card Atas)
                  _buildTrainSummaryCard(),

                  const SizedBox(height: 16),

                  // 2. Data Kontak Pemesan
                  _buildContactCard(),

                  const SizedBox(height: 16),

                  // 3. Data Penumpang (Daftar Penumpang)
                  ..._passengers.asMap().entries.map((entry) {
                    final index = entry.key;
                    final p = entry.value;
                    return _buildPassengerCard(index, p);
                  }),

                  const SizedBox(height: 12),

                  // Tombol Tambah Penumpang Lain
                  _buildAddPassengerButton(),

                  const SizedBox(height: 16),

                  // Callout Informasi Keamanan Data
                  _buildSecurityNotice(),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Sticky Bottom Bar
          _buildStickyBottomBar(),
        ],
      ),
    );
  }

  // ===========================================================================
  // SUB WIDGETS (PERSIS GAMBAR 2)
  // ===========================================================================

  Widget _buildTrainSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
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
                  const Icon(
                    Icons.train_rounded,
                    color: Color(0xFF0256B8),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.train.name,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Text(
                _formatDate(widget.travelDate),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Text(
              '${widget.train.availableClasses.first} • Gerbong 1',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.train.departureTime,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    '${widget.origin.name} (${widget.origin.code})',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
              Column(
                children: [
                  Text(
                    '${widget.train.duration} Langsung',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  SizedBox(
                    width: 70,
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade400,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: Colors.grey.shade300,
                            thickness: 1,
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 12,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    widget.train.arrivalTime,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    '${widget.dest.name} (${widget.dest.code})',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),

          // Jika Pulang-Pergi: Tampilkan Rincian Kereta Pulang
          if (widget.returnTrain != null) ...[
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.sync_alt_rounded,
                      color: Color(0xFFEA580C),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.returnTrain!.name,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'PULANG',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEA580C),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  widget.returnDate != null
                      ? _formatDate(widget.returnDate!)
                      : _formatDate(widget.travelDate),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(
                '${widget.returnTrain!.availableClasses.first} • Gerbong 1',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.returnTrain!.departureTime,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      '${widget.dest.name} (${widget.dest.code})',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      '${widget.returnTrain!.duration} Langsung',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    SizedBox(
                      width: 70,
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade400,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: Colors.grey.shade300,
                              thickness: 1,
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 12,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      widget.returnTrain!.arrivalTime,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      '${widget.origin.name} (${widget.origin.code})',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContactCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.contact_mail_outlined,
                    size: 18,
                    color: Color(0xFF0256B8),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Data Kontak Pemesan',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: _loadUserProfile,
                child: const Row(
                  children: [
                    Icon(
                      Icons.person_pin_rounded,
                      size: 15,
                      color: Color(0xFF0256B8),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Isi Profil Saya',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0256B8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'E-tiket dan notifikasi perjalanan akan dikirimkan ke kontak di bawah ini.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 14),

          // Nama Lengkap Pemesan
          const Text(
            'Nama Lengkap Pemesan',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 6),
          _buildTextField(
            controller: _bookerNameController,
            hint: 'M. Safid Maulana',
            icon: Icons.person_outline_rounded,
          ),

          const SizedBox(height: 12),

          // WhatsApp & Alamat Email (Side by Side)
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'WhatsApp / No. HP',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildTextField(
                      controller: _bookerPhoneController,
                      hint: '081234567890',
                      icon: Icons.phone_android_rounded,
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Alamat Email',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildTextField(
                      controller: _bookerEmailController,
                      hint: 'safid.m@tka-rail.id',
                      icon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Switch Box "Tambahkan sebagai Penumpang 1"
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.person_add_alt_1_rounded,
                  size: 20,
                  color: Color(0xFF0256B8),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tambahkan sebagai Penumpang 1',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Salin data pemesan otomatis ke formulir penumpang',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _copyBookerToPassenger1,
                  activeThumbColor: const Color(0xFF0256B8),
                  activeTrackColor: const Color(0xFF93C5FD),
                  onChanged: (val) {
                    setState(() {
                      _copyBookerToPassenger1 = val;
                      if (val) _syncBookerToPassenger1();
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassengerCard(int index, _PassengerData p) {
    final isInfant = p.category == 'Bayi';
    final badgeLabel = isInfant ? 'Bayi (<3 thn)' : 'Dewasa (≥3 thn)';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card Penumpang
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.badge_outlined,
                    size: 18,
                    color: Color(0xFF0256B8),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Data Penumpang ${index + 1}',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badgeLabel,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                  ),
                  if (index > 0) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _passengers[index].dispose();
                          _passengers.removeAt(index);
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Penumpang ${index + 1} berhasil dihapus/dibatalkan.',
                                ),
                              ],
                            ),
                            backgroundColor: const Color(0xFF0256B8),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.close_rounded,
                              size: 13,
                              color: Color(0xFFDC2626),
                            ),
                            SizedBox(width: 3),
                            Text(
                              'Batal',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Kategori Penumpang (Dewasa vs Bayi - Persis Gambar 2)
          const Text(
            'Kategori Penumpang',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _buildSegmentButton(
                  label: 'Dewasa (> 3 tahun)',
                  isSelected: p.category == 'Dewasa',
                  onTap: () => setState(() => p.category = 'Dewasa'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSegmentButton(
                  label: 'Bayi (< 3 tahun)',
                  isSelected: p.category == 'Bayi',
                  onTap: () => setState(() => p.category = 'Bayi'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Tipe Identitas (NIK / KTP, Paspor, KIA - Persis Gambar 2)
          const Text(
            'Tipe Identitas',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _buildSegmentButton(
                  label: 'NIK / KTP',
                  isSelected: p.idType == 'NIK / KTP',
                  onTap: () => setState(() => p.idType = 'NIK / KTP'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildSegmentButton(
                  label: 'Paspor',
                  isSelected: p.idType == 'Paspor',
                  onTap: () => setState(() => p.idType = 'Paspor'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildSegmentButton(
                  label: 'KIA',
                  isSelected: p.idType == 'KIA',
                  onTap: () => setState(() => p.idType = 'KIA'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Nomor Identitas (Dengan checkmark live validation)
          const Text(
            'Nomor Identitas',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 6),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: p.idController,
            builder: (context, value, _) {
              final isValid = value.text.trim().length >= 16;
              return TextField(
                controller: p.idController,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  hintText: '3514062607090001',
                  hintStyle: TextStyle(
                    fontSize: 12.5,
                    color: Colors.grey.shade400,
                  ),
                  suffixIcon: isValid
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF16A34A),
                          size: 18,
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF0256B8)),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          // Nama Lengkap Sesuai Identitas Resmi
          const Text(
            'Nama Lengkap (Sesuai Identitas Resmi)',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: p.nameController,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              hintText: 'M. SAFID MAULANA',
              hintStyle: TextStyle(fontSize: 12.5, color: Colors.grey.shade400),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF0256B8)),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pastikan nama dan nomor identitas persis sesuai tanda pengenal saat boarding.',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF062056) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: Color(0xFF0F172A),
      ),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade500),
        hintText: hint,
        hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF0256B8)),
        ),
      ),
    );
  }

  Widget _buildAddPassengerButton() {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF0256B8),
        side: const BorderSide(
          color: Color(0xFF93C5FD),
          style: BorderStyle.solid,
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.white,
      ),
      onPressed: () {
        if (_passengers.length >= 4) {
          _showWarning('Maksimal pemesanan 4 penumpang dalam satu transaksi.');
          return;
        }
        setState(() {
          _passengers.add(_PassengerData());
        });
      },
      icon: const Icon(Icons.add_rounded, size: 18),
      label: const Text(
        'Tambah Penumpang Lain',
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSecurityNotice() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: Color(0xFF64748B),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Data tiket akan tersimpan aman. Pemesanan kursi Anda ditahan selama sesi formulir berlangsung.',
              style: TextStyle(
                fontSize: 10.5,
                color: Colors.grey.shade700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'TOTAL PEMBAYARAN (${_passengers.length} PENUMPANG)',
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 12,
                      color: Color(0xFF64748B),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _formatCurrency(_totalAmount),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF062056),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _validateAndProceed,
              child: const Row(
                children: [
                  Text(
                    'Lanjut: Pilih Kursi',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
