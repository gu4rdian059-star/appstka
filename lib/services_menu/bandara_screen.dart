import 'package:flutter/material.dart';

class BandaraScreen extends StatelessWidget {
  const BandaraScreen({super.key});

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
        title: const Text(
          'Kereta Bandara (Airport Railink)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF062056),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner Railink
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D9488), Color(0xFF115E59)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.flight_takeoff_rounded,
                  color: Colors.white,
                  size: 36,
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'KA BANDARA SOEKARNO-HATTA & KUALANAMU',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Bebas macet, terhubung langsung ke Skytrain terminal bandara.',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),
          const Text(
            'Pilihan Rute Kereta Bandara',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),

          _buildAirportCard(
            context,
            'Basoetta Airport Express',
            'Manggarai (MRI) ➔ BNI City ➔ Duri ➔ Batu Ceper ➔ Bandara Soetta (BST)',
            'Waktu tempuh 42 menit • Keberangkatan tiap 30 menit',
            'Rp70.000',
            const Color(0xFF0D9488),
          ),
          const SizedBox(height: 12),
          _buildAirportCard(
            context,
            'Kualanamu Railink Medan',
            'Medan (MDN) ➔ Bandar Khalipah ➔ Kualanamu (KNM)',
            'Waktu tempuh 28 menit • Non-stop Express',
            'Rp50.000',
            const Color(0xFF0256B8),
          ),
          const SizedBox(height: 12),
          _buildAirportCard(
            context,
            'YIA Airport Express (Yogyakarta)',
            'Yogyakarta (YK) ➔ Wates ➔ Yogyakarta Int. Airport (YIA)',
            'Waktu tempuh 39 menit • Kereta Baru 2026',
            'Rp20.000 - Rp50.000',
            const Color(0xFFD97706),
          ),
        ],
      ),
    );
  }

  Widget _buildAirportCard(
    BuildContext context,
    String title,
    String route,
    String desc,
    String price,
    Color color,
  ) {
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
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: color,
                ),
              ),
              Text(
                price,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: Color(0xFF062056),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            route,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: color),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Jadwal $title siap dipesan.'),
                    backgroundColor: color,
                  ),
                );
              },
              child: Text(
                'Pilih Jadwal Bandara',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
