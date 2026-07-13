import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _detected = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_detected) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;
    _detected = true;
    Navigator.pop(context, raw);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Camera ──────────────────────────────────────────────────────────
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            // Le widget d'erreur par défaut de mobile_scanner masque le vrai
            // code d'erreur hors kDebugMode (toujours "An unexpected error
            // occurred" en release) — on l'affiche nous-mêmes pour pouvoir
            // diagnostiquer (permission refusée, pas de caméra, etc.).
            errorBuilder: (context, error, child) =>
                _ScannerError(error: error, onRetry: () => _controller.start()),
          ),

          // ── Dark overlay with cut-out ────────────────────────────────────────
          const _ScanOverlay(),

          // ── Top bar ─────────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  ),
                  const Spacer(),
                  // Torch toggle
                  ValueListenableBuilder(
                    valueListenable: _controller,
                    builder: (_, state, __) {
                      final torchOn =
                          state.torchState == TorchState.on;
                      return IconButton(
                        onPressed: _controller.toggleTorch,
                        icon: Icon(
                          torchOn ? Icons.flash_on : Icons.flash_off,
                          color: torchOn
                              ? AppTheme.secondaryPurple
                              : Colors.white54,
                          size: 26,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // ── Label ─────────────────────────────────────────────────────────
          Align(
            alignment: const Alignment(0, 0.55),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.qr_code_scanner,
                    color: Colors.white54, size: 20),
                const SizedBox(height: 10),
                Text(
                  AppLocalizations.of(context)!.scanQrHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                    height: 1.5,
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

// ─────────────────────────────────────────────────────────────────────────────
// Camera error state (permission refusée, pas de caméra, etc.)
// ─────────────────────────────────────────────────────────────────────────────

class _ScannerError extends StatelessWidget {
  final MobileScannerException error;
  final VoidCallback onRetry;

  const _ScannerError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.white54, size: 40),
              const SizedBox(height: 16),
              Text(
                '${error.errorCode} — ${error.errorDetails?.message ?? error.errorCode.message}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Scan frame overlay (dark surround + purple corner brackets)
// ─────────────────────────────────────────────────────────────────────────────

class _ScanOverlay extends StatelessWidget {
  const _ScanOverlay();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OverlayPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  static const _side = 240.0;
  static const _corner = 28.0;
  static const _stroke = 3.5;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 - 30; // slightly above centre
    final left = cx - _side / 2;
    final top = cy - _side / 2;
    final rect = Rect.fromLTWH(left, top, _side, _side);

    // Dark surround
    final dark = Paint()..color = Colors.black.withValues(alpha: 0.62);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, dark);

    // Purple corner brackets
    final pen = Paint()
      ..color = AppTheme.primaryPurple
      ..strokeWidth = _stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    void bracket(double x, double y, double dx, double dy) {
      canvas.drawLine(Offset(x, y + dy), Offset(x, y), pen);
      canvas.drawLine(Offset(x, y), Offset(x + dx, y), pen);
    }

    bracket(left, top, _corner, _corner);                        // TL
    bracket(left + _side, top, -_corner, _corner);               // TR
    bracket(left, top + _side, _corner, -_corner);               // BL
    bracket(left + _side, top + _side, -_corner, -_corner);      // BR
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
