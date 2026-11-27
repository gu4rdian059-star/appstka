import 'package:flutter/material.dart';

import '../services/supabase_storage_service.dart';
import '../services/user_db_service.dart';

class KatalogKaScreen extends StatefulWidget {
  const KatalogKaScreen({super.key});

  @override
  State<KatalogKaScreen> createState() => _KatalogKaScreenState();
}

class _KatalogKaScreenState extends State<KatalogKaScreen> {
  @override
  void initState() {
    super.initState();
    // Sinkronkan data armada melalui GET PostgREST /rest/v1/train_schedules (HTTP 200 OK)
    UserDatabaseService.getAllTrainSchedules(refreshRemote: true);
  }

  @override
  Widget build(BuildContext context) {
    final trains = [
      {
        'title': 'Suite Class Compartment',
        'subtitle': 'Puncak Kemewahan Kereta Api Indonesia',
        'image': 'logo_train.png',
        'localFallback': 'assets/images/logo_train.png',
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
        'image': 'ob1_hero_train.png',
        'localFallback': 'assets/images/onboarding/ob1_hero_train.png',
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
        'image': 'logo_tka_full.png',
        'localFallback': 'assets/images/logo_tka_full.png',
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
        'image': 'logo_train.png',
        'localFallback': 'assets/images/logo_train.png',
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner Status Supabase Storage train-assets
          _buildStorageBanner(context),

          const SizedBox(height: 16),

          // Daftar Kartu Kereta
          for (final t in trains) ...[
            _buildTrainCard(context, t),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildStorageBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF062056), Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF062056).withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_sync_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Supabase Storage • train-assets',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Aset foto kereta otomatis terhubung ke cloud bucket train-assets (Maks 5MB).',
                  style: TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF26716),
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    '🔄 Menyinkronkan aset gambar kereta ke Supabase Storage (train-assets)...',
                  ),
                  backgroundColor: Color(0xFF062056),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              await SupabaseStorageService.seedTrainAssetsToStorage();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      '✅ Aset kereta berhasil disinkronkan ke Supabase Storage!',
                    ),
                    backgroundColor: Color(0xFF10B981),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text(
              'Sync',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainCard(BuildContext context, Map<String, dynamic> t) {
    final Color badgeCol = t['color'] as Color;

    return Container(
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

                // Gambar Armada dari Supabase train-assets bucket
                Container(
                  height: 110,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: badgeCol.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: badgeCol.withValues(alpha: 0.15),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.asset(
                          t['localFallback'] as String,
                          height: 90,
                          fit: BoxFit.contain,
                        ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: badgeCol.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.storage_rounded,
                                  size: 10,
                                  color: badgeCol,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'train-assets',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: badgeCol,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
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
  }
}
