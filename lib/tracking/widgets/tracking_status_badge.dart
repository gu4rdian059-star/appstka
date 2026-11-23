import 'package:flutter/material.dart';
import '../../models/tracking_models.dart';
import '../../services/indonesia_time_service.dart';

/// Badge visual status data kereta yang tegas & jujur:
/// LIVE | DELAYED | SCHEDULED | DEMO | UNAVAILABLE
class TrainStatusBadge extends StatelessWidget {
  final TrainDataStatus status;
  final int delayMinutes;
  final bool compact;

  const TrainStatusBadge({
    super.key,
    required this.status,
    this.delayMinutes = 0,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = status == TrainDataStatus.delayed && delayMinutes > 0
        ? (compact ? 'DELAY +${delayMinutes}m' : 'TERLAMBAT +$delayMinutes MNT')
        : (compact ? status.code : status.label);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: status.color.withValues(alpha: 0.45),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            status.icon,
            size: compact ? 11 : 13,
            color: status.color,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: compact ? 9.5 : 10.5,
              fontWeight: FontWeight.w800,
              color: status.color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Banner peringatan jujur ketika data yang ditampilkan adalah simulasi/demo.
class DemoDataDisclaimerBanner extends StatelessWidget {
  final String? customMessage;
  final VoidCallback? onRetryLive;

  const DemoDataDisclaimerBanner({
    super.key,
    this.customMessage,
    this.onRetryLive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E8FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC4B5FD)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.science_rounded,
            size: 16,
            color: Color(0xFF6D28D9),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              customMessage ??
                  'Data Simulasi / Demo ditampilkan — bukan posisi GPS real-time.',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5B21B6),
                height: 1.3,
              ),
            ),
          ),
          if (onRetryLive != null) ...[
            const SizedBox(width: 6),
            TextButton(
              onPressed: onRetryLive,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Refresh',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5B21B6),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Widget jam digital real-time zona waktu Indonesia (WIB / WITA / WIT).
class IndonesiaClockPill extends StatelessWidget {
  final bool darkStyle;

  const IndonesiaClockPill({super.key, this.darkStyle = false});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<IndonesiaTimezone>(
      valueListenable: IndonesiaTimeService.currentTimezone,
      builder: (context, tz, _) {
        return StreamBuilder<DateTime>(
          stream: IndonesiaTimeService.clockStream(tz),
          initialData: IndonesiaTimeService.now(tz),
          builder: (context, snapshot) {
            final dt = snapshot.data ?? IndonesiaTimeService.now(tz);
            final text = IndonesiaTimeService.formatWallClock(
              dt,
              withSeconds: true,
              zone: tz,
            );
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: darkStyle
                    ? Colors.white.withValues(alpha: 0.16)
                    : const Color(0xFF062056),
                borderRadius: BorderRadius.circular(20),
                border: darkStyle
                    ? Border.all(color: Colors.white.withValues(alpha: 0.25))
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.access_time_filled_rounded,
                    size: 13,
                    color: Color(0xFFF26716),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

