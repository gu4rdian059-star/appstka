import 'package:flutter/material.dart';

class LainnyaScreen extends StatelessWidget {
  const LainnyaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF062056),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Layanan Tambahan & Fasilitas',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF062056), Color(0xFF0256B8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.apps_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Ekosistem Perjalanan TKA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Nikmati berbagai layanan pendukung mulai dari logistik kilat hingga kenyamanan di atas kereta api.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11.5,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Kategori 1: Onboard & Kenyamanan
          _buildCategoryHeader(
            'Kenyamanan Di Kereta (Onboard)',
            Icons.restaurant_rounded,
          ),
          const SizedBox(height: 10),
          _buildServiceCard(
            context: context,
            title: 'Rail Food & Beverage',
            subtitle: 'Pesan menu kuliner khas nusantara resto kereta langsung diantar ke kursi Anda.',
            icon: Icons.lunch_dining_rounded,
            iconBg: const Color(0xFFFFF3E0),
            iconColor: const Color(0xFFF26716),
            badge: 'Populer',
            onTap: () => _showServiceDetail(
              context,
              'Rail Food & Beverage',
              'Menu Pilihan di Perjalanan',
              'Nikmati Nasi Goreng Parahyangan, Selat Solo, Bistik Sapi, dan Kopi Khas Nusantara. Makanan disajikan hangat langsung ke kursi Anda oleh prami/prama kereta.',
              [
                'Nasi Rames Nusantara - Rp40.000',
                'Nasi Goreng Legend - Rp35.000',
                'Kopi Robusta Tubruk - Rp15.000',
                'Snack Pack & Jus Segar - Rp20.000',
              ],
              Icons.restaurant_menu_rounded,
            ),
          ),
          _buildServiceCard(
            context: context,
            title: 'Bantal & Selimut Steril',
            subtitle: 'Sewa tambahan perlengkapan tidur higienis bersegel untuk kelas Ekonomi & Bisnis.',
            icon: Icons.bed_rounded,
            iconBg: const Color(0xFFE8F1FC),
            iconColor: const Color(0xFF0256B8),
            onTap: () => _showServiceDetail(
              context,
              'Bantal & Selimut Higienis',
              'Tidur Nyenyak di Setiap Perjalanan',
              'Setiap set bantal dan selimut telah dicuci dengan standar sanitasi tinggi dan dibungkus plastik vakum sekali pakai.',
              [
                'Sewa Bantal Empuk - Rp10.000',
                'Sewa Selimut Hangat - Rp15.000',
                'Paket Bundle Tidur - Rp20.000',
              ],
              Icons.bed_rounded,
            ),
          ),

          const SizedBox(height: 20),

          // Kategori 2: Logistik & Kargo
          _buildCategoryHeader(
            'Logistik & Ekspedisi',
            Icons.local_shipping_rounded,
          ),
          const SizedBox(height: 10),
          _buildServiceCard(
            context: context,
            title: 'Rail Express (Stasiun ke Stasiun)',
            subtitle: 'Kirim paket dokumen, oleh-oleh, atau barang berharga via kereta api tiba dalam 1 hari.',
            icon: Icons.markunread_mailbox_rounded,
            iconBg: const Color(0xFFE8F5E9),
            iconColor: const Color(0xFF10B981),
            badge: '24 Jam Tiba',
            onTap: () => _showServiceDetail(
              context,
              'Rail Express TKA',
              'Kargo Kilat Bergaransi',
              'Kirim barang antar kota jalur Jawa-Sumatera dengan kepastian waktu jadwal kereta api tanpa macet di jalan tol.',
              [
                'Paket Dokumen (< 5 kg) - Mulai Rp25.000',
                'Paket Barang General (< 10 kg) - Mulai Rp45.000',
                'Paket Sepeda Motor Bebek/Matic - Mulai Rp350.000',
                'Paket Sepeda Motor Sport - Mulai Rp500.000',
              ],
              Icons.local_shipping_rounded,
            ),
          ),

          const SizedBox(height: 20),

          // Kategori 3: Wisata & Charter
          _buildCategoryHeader('Pariwisata & Charter', Icons.star_rounded),
          const SizedBox(height: 10),
          _buildServiceCard(
            context: context,
            title: 'Sewa Gerbong Kereta Wisata',
            subtitle: 'Charter gerbong Suite, Imperial, Bali, atau Nusantara untuk acara keluarga & kantor.',
            icon: Icons.stars_rounded,
            iconBg: const Color(0xFFF3E5F5),
            iconColor: const Color(0xFF8E24AA),
            badge: 'Eksklusif',
            onTap: () => _showServiceDetail(
              context,
              'Kereta Wisata Tematik',
              'Kemewahan Perjalanan Pribadi',
              'Sewa 1 gerbong penuh dengan kapasitas 20-28 penumpang dilengkapi karaoke lounge, mini bar, toilet mewah, dan butler service khusus.',
              [
                'Tipe Nusantara (Lounge & Dining) - Hubungi CS',
                'Tipe Imperial (Reclining Reversible) - Hubungi CS',
                'Tipe Priority & Retro - Hubungi CS',
              ],
              Icons.stars_rounded,
            ),
          ),

          const SizedBox(height: 20),

          // Kategori 4: Fasilitas Stasiun
          _buildCategoryHeader('Fasilitas Stasiun', Icons.storefront_rounded),
          const SizedBox(height: 10),
          _buildServiceCard(
            context: context,
            title: 'Porter Resmi Stasiun',
            subtitle: 'Bantuan angkut bagasi di stasiun dengan tarif transparan dan petugas berseragam resmi.',
            icon: Icons.luggage_rounded,
            iconBg: const Color(0xFFFFF8E1),
            iconColor: const Color(0xFFFFA000),
            onTap: () => _showServiceDetail(
              context,
              'Layanan Porter Resmi',
              'Mudah & Bebas Repot Bawa Barang',
              'Gunakan layanan porter berlisensi di stasiun keberangkatan dan kedatangan untuk membawa koper, kardus, atau stroller Anda.',
              [
                'Tarif Sukarela Standar Asosiasi (disarankan Rp15.000 - Rp25.000/koli)',
                'Tersedia di semua stasiun besar pulau Jawa & Sumatera',
                'Dapat dipesan di loket info stasiun',
              ],
              Icons.luggage_rounded,
            ),
          ),
          _buildServiceCard(
            context: context,
            title: 'Asuransi Perjalanan TKA Protect',
            subtitle: 'Perlindungan komprehensif keterlambatan, pembatalan darurat, dan kecelakaan diri.',
            icon: Icons.shield_rounded,
            iconBg: const Color(0xFFE0F2FE),
            iconColor: const Color(0xFF0284C7),
            onTap: () => _showServiceDetail(
              context,
              'TKA Protect Travel Care',
              'Perjalanan Nyaman Tanpa Khawatir',
              'Kompensasi otomatis jika terjadi keterlambatan kereta lebih dari 60 menit, santunan medis kecelakaan, dan penggantian barang hilang.',
              [
                'Premi Hanya Rp5.000 per tiket',
                'Klaim instan 100% via aplikasi',
                'Didukung Jasa Raharja & Jasindo',
              ],
              Icons.security_rounded,
            ),
          ),

          const SizedBox(height: 25),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF0256B8)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF062056),
          ),
        ),
      ],
    );
  }

  Widget _buildServiceCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    String? badge,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF062056),
                              ),
                            ),
                          ),
                          if (badge != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF26716)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                badge,
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFF26716),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showServiceDetail(
    BuildContext context,
    String title,
    String tagLine,
    String desc,
    List<String> items,
    IconData icon,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F1FC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: const Color(0xFF0256B8), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF062056),
                        ),
                      ),
                      Text(
                        tagLine,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFFF26716),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              desc,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Daftar Tarif & Estimasi:',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF062056),
              ),
            ),
            const SizedBox(height: 8),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: Color(0xFF10B981),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0256B8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Layanan "$title" siap diproses.'),
                      backgroundColor: const Color(0xFF062056),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: const Text(
                  'Gunakan Layanan Ini',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
