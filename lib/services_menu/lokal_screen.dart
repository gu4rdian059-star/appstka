import 'package:flutter/material.dart';

import '../services/user_db_service.dart';
import '../booking/passenger_form_screen.dart';

class LokalScreen extends StatefulWidget {
  const LokalScreen({super.key});

  @override
  State<LokalScreen> createState() => _LokalScreenState();
}

class _LokalScreenState extends State<LokalScreen> {
  String _selectedRegion =
      'Jawa Timur'; // Jabodetabek, Jawa Barat, Jawa Tengah, Jawa Timur

  final Map<String, List<Map<String, dynamic>>> _regionalTrains = {
    'Jawa Timur': [
      {
        'name': 'KA Dhoho (351)',
        'route': 'Surabaya Kota ➔ Blitar via Kertosono',
        'dep': '05:00',
        'arr': '10:15',
        'duration': '5j 15m',
        'fare': 12000,
        'seats': 86,
        'tag': 'Lokal AC',
      },
      {
        'name': 'KA Penataran (367)',
        'route': 'Surabaya Kota ➔ Blitar via Malang',
        'dep': '07:15',
        'arr': '12:40',
        'duration': '5j 25m',
        'fare': 15000,
        'seats': 42,
        'tag': 'Lokal AC',
      },
      {
        'name': 'KA Commuter Line Sindro (382)',
        'route': 'Sidoarjo ➔ Indro (Gresik)',
        'dep': '10:00',
        'arr': '11:45',
        'duration': '1j 45m',
        'fare': 5000,
        'seats': 120,
        'tag': 'Komuter Regional',
      },
    ],
    'Jawa Tengah': [
      {
        'name': 'KA Prameks (Prambanan Ekspres)',
        'route': 'Yogyakarta ➔ Kutoarjo (PP)',
        'dep': '06:37',
        'arr': '07:55',
        'duration': '1j 18m',
        'fare': 8000,
        'seats': 65,
        'tag': 'Lokal Unggulan',
      },
      {
        'name': 'KA Batara Kresna',
        'route': 'Purwosari ➔ Wonogiri',
        'dep': '06:00',
        'arr': '07:45',
        'duration': '1j 45m',
        'fare': 4000,
        'seats': 30,
        'tag': 'Railbus',
      },
      {
        'name': 'KA Kedung Sepur',
        'route': 'Semarang Poncol ➔ Ngrombo',
        'dep': '06:20',
        'arr': '07:35',
        'duration': '1j 15m',
        'fare': 10000,
        'seats': 55,
        'tag': 'Lokal Komuter',
      },
    ],
    'Jawa Barat': [
      {
        'name': 'KA Lokal Merak (421)',
        'route': 'Rangkasbitung ➔ Merak',
        'dep': '07:30',
        'arr': '09:24',
        'duration': '1j 54m',
        'fare': 3000,
        'seats': 78,
        'tag': 'Tarif Subsidi',
      },
      {
        'name': 'KA Commuter Line Garut',
        'route': 'Purwakarta ➔ Garut via Bandung',
        'dep': '05:35',
        'arr': '10:25',
        'duration': '4j 50m',
        'fare': 14000,
        'seats': 90,
        'tag': 'Lokal AC',
      },
      {
        'name': 'KA Walahar Ekspres',
        'route': 'Cikarang ➔ Purwakarta',
        'dep': '08:50',
        'arr': '10:35',
        'duration': '1j 45m',
        'fare': 4000,
        'seats': 45,
        'tag': 'Komuter Cikarang',
      },
    ],
  };

  String _formatCurrency(int amount) {
    return 'Rp${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  @override
  Widget build(BuildContext context) {
    final trains = _regionalTrains[_selectedRegion] ?? [];

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
              'Kereta Api Lokal',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF062056),
              ),
            ),
            Text(
              'Layanan KA Komuter & Daerah Bersubsidi',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Banner Info Tarif Subsidi
          Container(
            color: const Color(0xFFFFF7ED),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.savings_outlined,
                  color: Color(0xFFEA580C),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tiket KA Lokal bersubsidi PSO. Pemesanan dibuka H-7 sebelum keberangkatan.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.amber.shade900,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Horizontal Filter Wilayah
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: ['Jawa Timur', 'Jawa Tengah', 'Jawa Barat'].map((r) {
                  final isSelected = _selectedRegion == r;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(r),
                      selected: isSelected,
                      onSelected: (val) {
                        if (val) setState(() => _selectedRegion = r);
                      },
                      selectedColor: const Color(0xFF0256B8),
                      backgroundColor: const Color(0xFFEFF6FF),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF1E40AF),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      side: BorderSide.none,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const Divider(height: 1),

          // Daftar KA Lokal
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: trains.length,
              itemBuilder: (context, idx) {
                final item = trains[idx];
                return _buildLokalCard(item);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLokalCard(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFDBA74)),
                  ),
                  child: Text(
                    item['tag'] as String,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFEA580C),
                    ),
                  ),
                ),
                Text(
                  '${item['seats']} Kursi Tersedia',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item['name'] as String,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item['route'] as String,
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item['dep']} ➔ ${item['arr']}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF062056),
                      ),
                    ),
                    Text(
                      'Durasi ${item['duration']}',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatCurrency(item['fare'] as int),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0256B8),
                      ),
                    ),
                    const Text(
                      'per orang',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0256B8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  // Langsung bawa ke pengisian tiket
                  final trainModel = TrainScheduleModel(
                    id: 'LOKAL-${item['name']}',
                    trainNumber: 'LOK',
                    name: item['name'] as String,
                    originCode: 'REG',
                    originName: (item['route'] as String)
                        .split('➔')
                        .first
                        .trim(),
                    originCity: _selectedRegion,
                    destCode: 'REG',
                    destName: (item['route'] as String).split('➔').last.trim(),
                    destCity: _selectedRegion,
                    departureTime: item['dep'] as String,
                    arrivalTime: item['arr'] as String,
                    duration: item['duration'] as String,
                    baseFare: item['fare'] as int,
                    availableClasses: ['Ekonomi'],
                    availableSeats: item['seats'] as int,
                  );

                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PassengerFormScreen(
                        train: trainModel,
                        origin: StationModel(
                          code: 'REG',
                          name: trainModel.originName,
                          city: _selectedRegion,
                          region: _selectedRegion,
                        ),
                        dest: StationModel(
                          code: 'REG',
                          name: trainModel.destName,
                          city: _selectedRegion,
                          region: _selectedRegion,
                        ),
                        travelDate: DateTime.now().add(const Duration(days: 1)),
                      ),
                    ),
                  );
                },
                child: const Text(
                  'Pesan Tiket Lokal',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
