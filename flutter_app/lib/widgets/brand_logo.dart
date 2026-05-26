import 'package:flutter/material.dart';

/// Exact Flutter replica of the website's BrandLogo component.
///
/// The wordmark reads  MatchI[♥↗]Minutes  where the "n" in "In" is
/// replaced by the cupid-heart-arrow glyph — same SVG paths as
/// BrandLogo.jsx / favicon.svg.
class BrandLogo extends StatelessWidget {
  final BrandLogoSize size;
  final BrandLogoTone tone;

  const BrandLogo({
    super.key,
    this.size = BrandLogoSize.md,
    this.tone = BrandLogoTone.light,
  });

  @override
  Widget build(BuildContext context) {
    final cfg = _cfg(size);
    final isDark = tone == BrandLogoTone.dark;
    final textColor = isDark ? const Color(0xFF111827) : Colors.white;
    // On dark tone: pink accent; on light (gradient) tone: white so it stays readable
    final accentColor = isDark ? const Color(0xFFEC4899) : Colors.white;
    final glyphColor = isDark ? const Color(0xFFEC4899) : Colors.white70;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Icon badge ─────────────────────────────────────────────
        _BadgeIcon(size: cfg.badge),
        SizedBox(width: cfg.gap),
        // ── Wordmark ───────────────────────────────────────────────
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: cfg.fontSize,
              letterSpacing: -0.5,
              color: textColor,
              height: 1,
            ),
            children: [
              const TextSpan(text: 'Match'),
              // The heart-n glyph replaces the "n" in "In"
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: cfg.glyphPad),
                  child: _HeartArrowGlyph(
                    size: cfg.glyph,
                    color: glyphColor,
                  ),
                ),
              ),
              TextSpan(
                text: 'nMinutes',
                style: TextStyle(color: accentColor),
              ),
            ],
          ),
        ),
      ],
    );
  }

  _LogoCfg _cfg(BrandLogoSize s) => switch (s) {
        BrandLogoSize.sm => _LogoCfg(badge: 24, fontSize: 14, glyph: 10, gap: 6, glyphPad: 0),
        BrandLogoSize.md => _LogoCfg(badge: 32, fontSize: 18, glyph: 13, gap: 8, glyphPad: 0.5),
        BrandLogoSize.lg => _LogoCfg(badge: 40, fontSize: 22, glyph: 16, gap: 10, glyphPad: 1),
        BrandLogoSize.xl => _LogoCfg(badge: 56, fontSize: 32, glyph: 24, gap: 12, glyphPad: 1),
      };
}

enum BrandLogoSize { sm, md, lg, xl }
enum BrandLogoTone { light, dark }

class _LogoCfg {
  final double badge, fontSize, glyph, gap, glyphPad;
  const _LogoCfg({
    required this.badge,
    required this.fontSize,
    required this.glyph,
    required this.gap,
    required this.glyphPad,
  });
}

// ── Icon badge: icon.png inside a white circle with pink glow ──────────────

class _BadgeIcon extends StatelessWidget {
  final double size;
  const _BadgeIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEC4899).withOpacity(0.45),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(size * 0.09),
        child: Image.asset(
          'assets/images/icon.png',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            Icons.favorite,
            color: const Color(0xFFEC4899),
            size: size * 0.6,
          ),
        ),
      ),
    );
  }
}

// ── Heart-n glyph: exact same SVG paths as BrandLogo.jsx / favicon.svg ─────

class _HeartArrowGlyph extends StatelessWidget {
  final double size;
  final Color color;
  const _HeartArrowGlyph({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _HeartArrowPainter(color: color),
    );
  }
}

class _HeartArrowPainter extends CustomPainter {
  final Color color;
  const _HeartArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 32;
    final sy = size.height / 32;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Heart body (same control points as HeartNGlyph in BrandLogo.jsx)
    final heart = Path();
    heart.moveTo(16 * sx, 28.5 * sy);
    heart.cubicTo(16 * sx, 28.5 * sy, 3.5 * sx, 20 * sy, 3.5 * sx, 11.8 * sy);
    heart.cubicTo(3.5 * sx, 7.4 * sy, 7 * sx, 4 * sy, 11.2 * sx, 4 * sy);
    heart.cubicTo(13.4 * sx, 4 * sy, 15.2 * sx, 5.2 * sy, 16 * sx, 6.8 * sy);
    heart.cubicTo(16.8 * sx, 5.2 * sy, 18.6 * sx, 4 * sy, 20.8 * sx, 4 * sy);
    heart.cubicTo(25 * sx, 4 * sy, 28.5 * sx, 7.4 * sy, 28.5 * sx, 11.8 * sy);
    heart.cubicTo(28.5 * sx, 20 * sy, 16 * sx, 28.5 * sy, 16 * sx, 28.5 * sy);
    heart.close();
    canvas.drawPath(heart, paint);

    // Arrow shaft
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4 * sx
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(3 * sx, 25 * sy), Offset(29 * sx, 3 * sy), linePaint);

    // Arrowhead (top-right)
    final arrowHead = Path();
    arrowHead.moveTo(29 * sx, 3 * sy);
    arrowHead.lineTo(22.5 * sx, 4.2 * sy);
    arrowHead.lineTo(27.8 * sx, 9.5 * sy);
    arrowHead.close();
    canvas.drawPath(arrowHead, paint);

    // Feathers (bottom-left)
    final feather1 = Path();
    feather1.moveTo(3 * sx, 25 * sy);
    feather1.lineTo(7 * sx, 21 * sy);
    feather1.lineTo(5.5 * sx, 26.5 * sy);
    feather1.close();
    canvas.drawPath(feather1, paint..color = color.withAlpha(217));

    final feather2 = Path();
    feather2.moveTo(3 * sx, 25 * sy);
    feather2.lineTo(8.5 * sx, 24 * sy);
    feather2.lineTo(5.5 * sx, 27.5 * sy);
    feather2.close();
    canvas.drawPath(feather2, paint..color = color.withAlpha(179));
  }

  @override
  bool shouldRepaint(_HeartArrowPainter old) => old.color != color;
}
