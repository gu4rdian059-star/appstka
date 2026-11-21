import 'package:flutter/material.dart';

class KomuterScreen extends StatefulWidget {
  const KomuterScreen({super.key});

  @override
  State<KomuterScreen> createState() => _KomuterScreenState();
}

class _KomuterScreenState extends State<KomuterScreen> {
  String _selectedLine = 'Bogor Line';

  final List<Map<String, dynamic>> _lines = [
    {
      'name': 'Bogor Line',
      'color': const Color(0xFFDC2626),
      'route': 'Jakarta Kota ➔ Manggarai ➔ Depok ➔ Bogor',
      'headway': '3-5 Menit',
    },
    {
      'name': 'Cikarang Line',
      'color': const Color(0xFF2563EB),
      'route': 'Kampung Bandan ➔ Pasar Senen ➔ Bekasi ➔ Cikarang',
      'headway': '5-8 Menit',
    },
    {
      'name': 'Rangkasbitung Line',
      'color': const Color(0xFF16A34A),
      'route': 'Tanah Abang ➔ Serpong ➔ Parung Panjang ➔ Rangkasbitung',
      'headway': '5-10 Menit',
    },
    {
      'name': 'Yogyakarta - Solo',
      'color': const Color(0xFFD97706),
      'route': 'Yogyakarta ➔ Klaten ➔ Purwosari ➔ Solo Balapan ➔ Palur',
      'headway': '15-20 Menit',
    },
  ];

  final List<Map<String, String>> _liveArrivals = [
    {
      'trainId': 'KA 1120B',
      'dest': 'Tujuan Bogor',
      'platform': 'Peron 2',
      'eta': '2 Menit lagi',
      'status': 'Masuk Stasiun',
    },
    {
      'trainId': 'KA 1124A',
      'dest': 'Tujuan Nambo',
      'platform': 'Peron 1',
      'eta': '7 Menit lagi',
      'status': 'Menuju Stasiun',
    },
    {
      'trainId': 'KA 1128C',
      'dest': 'Tujuan Depok',
      'platform': 'Peron 2',
      'eta': '12 Menit lagi',
      'status': 'Tepat Waktu',
    },
  ];

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
              'KRL Commuter Line',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF062056),
              ),
            ),
            Text(
              'Info Jalur, Posisi Kereta & Tiket Multi-Trip',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kartu Saldo Tiket Tap-In KRL
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
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
                          Icon(
                            Icons.nfc_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'KARTU MULTI TRIP (KMT) DIGITAL',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'AKTIF',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Saldo KMT Terhubung',
                    style: TextStyle(color: Colors.white70, fontSize: 11.5),
                  ),
                  const Text(
                    'Rp45.000',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFDC2626),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Tunjukkan QR KRL ke sensor gate stasiun.',
                            ),
                            backgroundColor: Color(0xFFDC2626),
                          ),
                        );
                      },
                      icon: const Icon(Icons.qr_code_rounded, size: 18),
                      label: const Text(
                        'Buka Barcode Tap-In Gate',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Pilihan Jalur KRL
            const Text(
              'Pilih Koridor Jalur',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _lines.map((line) {
                  final isSelected = _selectedLine == line['name'];
                  final Color c = line['color'] as Color;
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _selectedLine = line['name'] as String),
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? c : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? c : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : c,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            line['name'] as String,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 20),

            // Live Jadwal Kedatangan di Stasiun Terdekat (Manggarai)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Live Kedatangan (Stasiun Manggarai)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.sensors_rounded,
                        size: 12,
                        color: Color(0xFF16A34A),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Live',
                        style: TextStyle(
                          color: Color(0xFF16A34A),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Card Kedatangan Real-Time
            ..._liveArrivals.map(
              (arr) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.tram_rounded,
                        color: Color(0xFF0256B8),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            arr['dest']!,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${arr['trainId']} • ${arr['platform']}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          arr['eta']!,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFDC2626),
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          arr['status']!,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF16A34A),
                            fontWeight: FontWeight.bold,
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
      ),
    );
  }
}
