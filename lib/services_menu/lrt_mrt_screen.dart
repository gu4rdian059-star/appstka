import 'package:flutter/material.dart';

class LrtMrtScreen extends StatefulWidget {
  const LrtMrtScreen({super.key});

  @override
  State<LrtMrtScreen> createState() => _LrtMrtScreenState();
}

class _LrtMrtScreenState extends State<LrtMrtScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
        title: const Text(
          'LRT & MRT Metro Jakarta',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF062056),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF062056),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF0256B8),
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'MRT Jakarta (Fase 1)'),
            Tab(text: 'LRT Jabodebek'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildMrtTab(), _buildLrtTab()],
      ),
    );
  }

  Widget _buildMrtTab() {
    final mrtStations = [
      {
        'name': 'Lebak Bulus Grab',
        'type': 'Elevated',
        'transit': 'Transjakarta',
      },
      {'name': 'Fatmawati Indomaret', 'type': 'Elevated', 'transit': '-'},
      {'name': 'Cipete Raya', 'type': 'Elevated', 'transit': '-'},
      {'name': 'Blok M BCA', 'type': 'Elevated', 'transit': 'Integrasi CSW'},
      {
        'name': 'Senayan Mastercard',
        'type': 'Underground',
        'transit': 'GBK Shuttle',
      },
      {
        'name': 'Dukuh Atas BNI',
        'type': 'Underground',
        'transit': 'KRL, LRT, Kereta Bandara',
      },
      {
        'name': 'Bundaran HI Bank DKI',
        'type': 'Underground',
        'transit': 'Transjakarta Koridor 1',
      },
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Card Info MRT
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.electric_bolt_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MRT JAKARTA NORTH - SOUTH',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Waktu tunggu antarkereta (headway) 5 menit pada jam sibuk.',
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
          'Daftar Stasiun MRT (Lebak Bulus - Bundaran HI)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 10),

        ...mrtStations.map(
          (st) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.radio_button_checked_rounded,
                  color: Color(0xFF2563EB),
                  size: 16,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        st['name']!,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        '${st['type']} • Transit: ${st['transit']}',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLrtTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF062056),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            children: [
              Icon(Icons.train_rounded, color: Color(0xFF38BDF8), size: 30),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LRT JABODEBEK (Driverless GoA3)',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Melayani Lintas Cibubur Line & Bekasi Line berteknologi otomatis.',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildLrtLineCard(
          'Cibubur Line',
          'Dukuh Atas ➔ Cawang ➔ Ciracas ➔ Harjamukti',
          const Color(0xFF16A34A),
          'Rp3.000 - Rp20.000',
        ),
        const SizedBox(height: 10),
        _buildLrtLineCard(
          'Bekasi Line',
          'Dukuh Atas ➔ Halim (KCIC) ➔ Cikunir ➔ Jati Mulya',
          const Color(0xFF2563EB),
          'Rp3.000 - Rp20.000',
        ),
      ],
    );
  }

  Widget _buildLrtLineCard(
    String title,
    String route,
    Color color,
    String fare,
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
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const Spacer(),
              Text(
                fare,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11.5,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            route,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}
