import 'package:flutter/material.dart';

/// Indikator 3 tahap alur Reset Kata Sandi:
/// 1. Email Terdaftar -> 2. Verifikasi OTP -> 3. Sandi Baru
class ResetPasswordStepper extends StatelessWidget {
  /// 0 = Email, 1 = Verifikasi OTP, 2 = Ubah Kata Sandi, 3 = Semua Selesai
  final int currentStep;

  const ResetPasswordStepper({super.key, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          _buildStepItem(index: 0, label: 'Email'),
          _buildConnector(isActive: currentStep > 0),
          _buildStepItem(index: 1, label: 'Kode OTP'),
          _buildConnector(isActive: currentStep > 1),
          _buildStepItem(index: 2, label: 'Sandi Baru'),
        ],
      ),
    );
  }

  Widget _buildStepItem({required int index, required String label}) {
    final isCompleted = currentStep > index;
    final isCurrent = currentStep == index;

    final Color circleBg = isCompleted
        ? const Color(0xFF16A34A)
        : isCurrent
            ? const Color(0xFF062056)
            : const Color(0xFFE2E8F0);

    final Color textColor = isCompleted
        ? const Color(0xFF15803D)
        : isCurrent
            ? const Color(0xFF062056)
            : const Color(0xFF94A3B8);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: circleBg,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: isCompleted
              ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
              : Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isCurrent ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isCurrent || isCompleted ? FontWeight.bold : FontWeight.w500,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildConnector({required bool isActive}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18, left: 6, right: 6),
        child: Container(
          height: 2.5,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

/// Banner peringatan error inline yang jelas agar user langsung tahu penyebab validasi gagal
class ResetErrorBanner extends StatelessWidget {
  final String message;

  const ResetErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: Color(0xFFDC2626),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFFB91C1C),
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ResetDottedDividerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF062056).withValues(alpha: 0.2)
      ..strokeWidth = 1.5;

    for (double x = 0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, 1), Offset(x + 4, 1), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

