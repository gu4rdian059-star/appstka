import 'package:flutter/material.dart';

class KatalogKaScreen extends StatelessWidget {
  const KatalogKaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final trains = [
      {
        'title': 'Suite Class Compartment',
        'subtitle': 'Puncak Kemewahan Kereta Api Indonesia',
        'features': [
          'Kabin Privat Pintu Geser Otomatis',
          'Kursi Pijat 180° Flat-Bed',
          'AVOD Monitor 14 Inci',
          'Sajian Hidangan Khusus & Minuman Mewah',
        ],
        'trains': 'KA Bima & KA Argo Semeru',
        'badge': 'ULTRA LUXURY',
        'color': const Color(0xFF7C3AED),
      },
      {
        'title': 'Panoramic Glass Train',
        'subtitle': 'Pemandangan Panorama Indah Jalur Selatan',
        'features': [
          'Kaca Kubah Luas Anti Radiasi UV',
          'Tirai Otomatis Sensor Remote',
          'Kursi Putar Reclining 140°',
          'Layanan Minibar & Snack Gratis',
        ],
        'trains': 'KA Argo Parahyangan & KA Turangga',
        'badge': 'PANORAMIC',
        'color': const Color(0xFF0256B8),
      },
      {
        'title': 'Luxury Sleeper Generasi 3',
        'subtitle': 'Kenyamanan Tidur Nyenyak Lintas Malam',
        'features': [
          'Reclining Seat 140° Ergonomis',
          'Stop Kontak & USB Fast Charging',
          'Lampu Baca LED Personal',
          'Bantal & Selimut Premium',
        ],
        'trains': 'KA Argo Bromo Anggrek, Gajayana, Taksaka',
        'badge': 'LUXURY SLEEPER',
        'color': const Color(0xFFD97706),
      },
      {
        'title': 'Eksekutif Stainless Steel New Gen',
        'subtitle': 'Kecepatan, Kesenyapan & Stabilitas Bogie K9',
        'features': [
          'Bogie K9 Halus Tanpa Guncangan',
          'Footrest Lipat & Meja Pribadi',
          'Pintu Antarkereta Sensor Sentuh',
          'Display Informasi Digital PIDS',
        ],
        'trains': 'KA Argo Wilis, Lodaya, Argo Dwipangga',
        'badge': 'NEW GENERATION',
        'color': const Color(0xFF0D9488),
      },
    ];

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
          'Katalog Armada Kereta Api',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF062056),
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: trains.length,
        itemBuilder: (context, idx) {
          final t = trains[idx];
          final Color badgeCol = t['color'] as Color;

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Armada
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: badgeCol.withValues(alpha: 0.08),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: badgeCol,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          t['badge'] as String,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        'Armada Resmi TKA',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t['title'] as String,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        t['subtitle'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Fasilitas Unggulan:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...(t['features'] as List<String>).map(
                        (f) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.5),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 14,
                                color: badgeCol,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  f,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.directions_railway_rounded,
                              size: 16,
                              color: Color(0xFF062056),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Tersedia pada: ${t['trains']}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF062056),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
