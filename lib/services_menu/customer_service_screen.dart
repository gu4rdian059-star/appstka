import 'package:flutter/material.dart';

class CustomerServiceScreen extends StatefulWidget {
  const CustomerServiceScreen({super.key});

  @override
  State<CustomerServiceScreen> createState() => _CustomerServiceScreenState();
}

class _CustomerServiceScreenState extends State<CustomerServiceScreen> {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _messages = [
    {
      'isBot': true,
      'time': '09:00',
      'text': 'Halo! Selamat datang di Pusat Bantuan Pelanggan TKA Mobile 24/7.\nAda yang bisa kami bantu seputar tiket atau perjalanan Anda hari ini?',
    },
  ];

  final List<Map<String, String>> _faqs = [
    {
      'q': 'Bagaimana cara membatalkan tiket (Refund)?',
      'a': 'Pembatalan tiket dapat dilakukan melalui menu Tiket Saya maksimal 2 jam sebelum keberangkatan kereta. Dana refund akan ditransfer ke rekening bank / saldo TKAPay Anda dalam 1-3 hari kerja dengan potongan bea 25% sesuai regulasi PT KAI/TKA.',
    },
    {
      'q': 'Bagaimana cara mengubah jadwal (Reschedule)?',
      'a': 'Perubahan jadwal dapat dilakukan via menu Tiket Saya > Ubah Jadwal minimal 2 jam sebelum keberangkatan, selama kursi kereta yang dituju masih tersedia.',
    },
    {
      'q': 'Berapa batas berat bagasi cuma-cuma penumpang?',
      'a': 'Setiap penumpang berhak membawa bagasi maksimal 20 kg atau volume 100 dm³ (dimensi maksimal 70x48x30 cm) tanpa dikenakan biaya tambahan.',
    },
    {
      'q': 'Apakah anak usia di bawah 3 tahun wajib beli tiket?',
      'a': 'Anak di bawah usia 3 tahun (infant) gratis selama tidak mengambil kursi sendiri dan dipangku oleh pendamping dewasa. Maksimal 1 infant per 1 dewasa.',
    },
    {
      'q': 'Bagaimana jika saya tertinggal kereta api?',
      'a': 'Tiket yang tertinggal kereta api dianggap hangus dan tidak dapat dibatalkan atau dijadwalkan ulang. Kami menyarankan tiba di stasiun 30-45 menit sebelum keberangkatan.',
    },
  ];

  int? _expandedFaqIndex;

  @override
  void dispose() {
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage([String? quickText]) {
    final text = quickText ?? _chatController.text.trim();
    if (text.isEmpty) return;

    final now = TimeOfDay.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    setState(() {
      _messages.add({'isBot': false, 'time': timeStr, 'text': text});
      if (quickText == null) _chatController.clear();
    });

    _scrollDown();

    // Simulasi bot respons
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      String reply =
          'Terima kasih telah menghubungi Customer Care TKA. Pertanyaan Anda mengenai "$text" sedang diteruskan ke petugas layanan kami. Anda juga dapat menghubungi Call Center 121 untuk bantuan darurat instan.';
      if (text.toLowerCase().contains('batal') ||
          text.toLowerCase().contains('refund')) {
        reply = 'Untuk pembatalan tiket (Refund), silakan buka menu "Tiket Saya" di navigasi bawah, pilih tiket aktif Anda, lalu klik tombol "Batalkan Tiket". Dana akan dikembalikan sesuai ketentuan.';
      } else if (text.toLowerCase().contains('jadwal') ||
          text.toLowerCase().contains('reschedule')) {
        reply = 'Untuk reschedule, pastikan minimal 2 jam sebelum jam keberangkatan pada tiket Anda. Pilih tiket di menu "Tiket Saya" lalu pilih opsi "Ubah Jadwal".';
      } else if (text.toLowerCase().contains('bagasi')) {
        reply = 'Batas bagasi bebas biaya adalah 20 kg per penumpang dewasa. Kelebihan bagasi dikenakan bea saat proses boarding di stasiun.';
      }

      setState(() {
        _messages.add({'isBot': true, 'time': timeStr, 'text': reply});
      });
      _scrollDown();
    });
  }

  void _scrollDown() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showCallCenterDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F1FC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.phone_in_talk_rounded,
                color: Color(0xFF0256B8),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Call Center 121',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF062056),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Layanan telepon resmi PT Kereta Api Indonesia / TKA beroperasi 24 jam setiap hari.',
              style: TextStyle(fontSize: 12.5, color: Colors.black87),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    children: const [
                      Icon(Icons.call, size: 16, color: Color(0xFF10B981)),
                      SizedBox(width: 8),
                      Text(
                        '121 / (021) 121',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF062056),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: const [
                      Icon(Icons.email, size: 16, color: Color(0xFFF26716)),
                      SizedBox(width: 8),
                      Text(
                        'cs@tka-rail.id',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF062056),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0256B8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Menghubungkan ke Call Center 121...'),
                  backgroundColor: Color(0xFF0256B8),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.phone, size: 16, color: Colors.white),
            label: const Text(
              'Panggil 121',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showWhatsAppConfirm() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Membuka WhatsApp Official TKA Care (+62 811-121-121)...',
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

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
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.support_agent_rounded,
                color: Color(0xFF10B981),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bantuan & Layanan CS',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'Online 24 Jam • Respon Cepat',
                      style: TextStyle(fontSize: 10, color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Banner Kanal Cepat
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            decoration: const BoxDecoration(
              color: Color(0xFF062056),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _showCallCenterDialog,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.phone_in_talk_rounded,
                            color: Color(0xFFFFB74D),
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Call Center 121',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: _showWhatsAppConfirm,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.chat_bubble_rounded,
                            color: Color(0xFF6EE7B7),
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'WhatsApp TKA',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Chips Pertanyaan Cepat
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildQuickPill('Cara Batalkan Tiket'),
                  const SizedBox(width: 8),
                  _buildQuickPill('Reschedule Jadwal'),
                  const SizedBox(width: 8),
                  _buildQuickPill('Aturan Bagasi'),
                  const SizedBox(width: 8),
                  _buildQuickPill('Tiket Anak & Bayi'),
                  const SizedBox(width: 8),
                  _buildQuickPill('Kereta Terlambat'),
                ],
              ),
            ),
          ),

          // Area Chat & Accordion FAQ
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                // Chat bubble list
                ..._messages.map((m) => _buildMessageBubble(m)),

                const SizedBox(height: 16),

                // FAQ Section
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(
                            Icons.help_outline_rounded,
                            color: Color(0xFF0256B8),
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Pertanyaan yang Sering Diajukan (FAQ)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF062056),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...List.generate(_faqs.length, (index) {
                        final faq = _faqs[index];
                        final isExpanded = _expandedFaqIndex == index;
                        return Column(
                          children: [
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _expandedFaqIndex = isExpanded ? null : index;
                                });
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 4,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        faq['q']!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isExpanded
                                              ? const Color(0xFF0256B8)
                                              : const Color(0xFF1E293B),
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      isExpanded
                                          ? Icons.keyboard_arrow_up_rounded
                                          : Icons.keyboard_arrow_down_rounded,
                                      size: 18,
                                      color: Colors.grey.shade500,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (isExpanded)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                margin: const EdgeInsets.only(
                                  bottom: 8,
                                  top: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.blue.shade50,
                                  ),
                                ),
                                child: Text(
                                  faq['a']!,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Colors.grey.shade800,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            if (index < _faqs.length - 1)
                              Divider(color: Colors.grey.shade100, height: 1),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Input Bar di Bawah
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _chatController,
                        onSubmitted: (_) => _sendMessage(),
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: 'Tulis pesan atau pertanyaan Anda...',
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _sendMessage(),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0256B8),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPill(String title) {
    return InkWell(
      onTap: () => _sendMessage(title),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xFF062056),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final isBot = msg['isBot'] as bool;
    final text = msg['text'] as String;
    final time = msg['time'] as String;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isBot
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isBot) ...[
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFF0256B8),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.support_agent_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isBot ? Colors.white : const Color(0xFF0256B8),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: isBot
                      ? const Radius.circular(2)
                      : const Radius.circular(14),
                  bottomRight: isBot
                      ? const Radius.circular(14)
                      : const Radius.circular(2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: isBot
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.end,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isBot ? const Color(0xFF062056) : Colors.white,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 9.5,
                      color: isBot ? Colors.grey.shade400 : Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!isBot) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFFF26716),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
