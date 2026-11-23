import 'package:flutter/material.dart';
import '../../services/turnstile_service.dart';

/// Widget Verifikasi Keamanan Cloudflare Turnstile untuk Form Login TKA.
class CloudflareTurnstileBox extends StatefulWidget {
  final bool isVerified;
  final String? errorText;
  final ValueChanged<String?> onVerifiedChanged;

  const CloudflareTurnstileBox({
    super.key,
    required this.isVerified,
    this.errorText,
    required this.onVerifiedChanged,
  });

  @override
  State<CloudflareTurnstileBox> createState() => _CloudflareTurnstileBoxState();
}

class _CloudflareTurnstileBoxState extends State<CloudflareTurnstileBox> {
  bool _isVerifying = false;
  String? _statusMessage;

  Future<void> _runVerification() async {
    if (_isVerifying) return;

    // Jika sudah terverifikasi dan ditekan ulang, reset atau verifikasi ulang
    if (widget.isVerified) {
      widget.onVerifiedChanged(null);
      setState(() => _statusMessage = null);
      return;
    }

    setState(() {
      _isVerifying = true;
      _statusMessage = 'Memverifikasi keamanan Cloudflare...';
    });

    final result = await TurnstileService.verifyChallenge();
    if (!mounted) return;

    setState(() {
      _isVerifying = false;
      _statusMessage = result.message;
    });

    if (result.verified) {
      widget.onVerifiedChanged(result.token);
    } else {
      widget.onVerifiedChanged(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!TurnstileService.isEnabled) {
      return const SizedBox.shrink();
    }

    final hasError = widget.errorText != null && !widget.isVerified;
    final siteKey = TurnstileService.siteKey;
    final maskedSiteKey = siteKey.length > 12
        ? '${siteKey.substring(0, 6)}...${siteKey.substring(siteKey.length - 4)}'
        : siteKey;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _runVerification,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: widget.isVerified
                  ? const Color(0xFFF0FDF4)
                  : hasError
                      ? const Color(0xFFFEF2F2)
                      : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.isVerified
                    ? const Color(0xFF22C55E)
                    : hasError
                        ? const Color(0xFFEF4444)
                        : const Color(0xFFCBD5E1),
                width: widget.isVerified || hasError ? 1.4 : 1.1,
              ),
            ),
            child: Row(
              children: [
                // Kotak Checkbox / Spinner / Checkmark
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: widget.isVerified
                        ? const Color(0xFF16A34A)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: widget.isVerified
                          ? const Color(0xFF16A34A)
                          : hasError
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF94A3B8),
                      width: 1.8,
                    ),
                  ),
                  child: Center(
                    child: _isVerifying
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Color(0xFFF26716),
                            ),
                          )
                        : widget.isVerified
                            ? const Icon(
                                Icons.check_rounded,
                                size: 18,
                                color: Colors.white,
                              )
                            : null,
                  ),
                ),
                const SizedBox(width: 12),

                // Label Status Verifikasi
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isVerifying
                            ? 'Memverifikasi...'
                            : widget.isVerified
                                ? 'Verifikasi Keamanan Berhasil'
                                : 'Verifikasi bahwa Anda manusia',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: widget.isVerified
                              ? const Color(0xFF15803D)
                              : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Site Key: $maskedSiteKey',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),

                // Badge Branding Cloudflare Turnstile
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_done_rounded,
                          size: 16,
                          color: Color(0xFFF48120),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'CLOUDFLARE',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      'Turnstile • Privacy',
                      style: TextStyle(
                        fontSize: 8.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 13,
                color: Color(0xFFE53935),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  widget.errorText!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFE53935),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ] else if (_statusMessage != null && widget.isVerified) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.verified_user_rounded,
                size: 12,
                color: Color(0xFF16A34A),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _statusMessage!,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF15803D),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

