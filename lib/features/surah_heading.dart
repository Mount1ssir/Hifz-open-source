import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

class SurahHeading extends StatelessWidget {
  const SurahHeading({super.key, required this.name, required this.fontSize});
  final String name;
  final double fontSize;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: const _SurahFrame(),
    child: Center(
      child: Text(
        'سُورَة $name',
        textDirection: TextDirection.rtl,
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: const Color(0xff204f40),
        ),
      ),
    ),
  );
}

/// Ruled cartouche with an eight-point rosette at each end.
class _SurahFrame extends CustomPainter {
  const _SurahFrame();
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final h = size.height, w = size.width, tip = math.min(h * .45, w * .12);
    Path border(double inset) => Path()
      ..moveTo(inset, h / 2)
      ..lineTo(tip + inset, inset)
      ..lineTo(w - tip - inset, inset)
      ..lineTo(w - inset, h / 2)
      ..lineTo(w - tip - inset, h - inset)
      ..lineTo(tip + inset, h - inset)
      ..close();
    canvas.drawPath(border(1), Paint()..color = const Color(0xffeaf1e6));
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .9
      ..color = const Color(0xff6c8971);
    canvas.drawPath(border(1), ink);
    canvas.drawPath(
      border(h * .12),
      ink
        ..color = const Color(0xffb5a373)
        ..strokeWidth = .7,
    );
    for (final cx in [tip * 1.8, w - tip * 1.8]) {
      final flower = Path();
      for (var i = 0; i < 16; i++) {
        final angle = i * math.pi / 8, r = h * (i.isEven ? 0.24 : 0.15);
        final x = cx + math.cos(angle) * r, y = h / 2 + math.sin(angle) * r;
        if (i == 0) {
          flower.moveTo(x, y);
        } else {
          flower.lineTo(x, y);
        }
      }
      canvas.drawPath(
        flower..close(),
        Paint()..color = const Color(0xff648470),
      );
      canvas.drawCircle(
        Offset(cx, h / 2),
        h * .07,
        Paint()..color = const Color(0xffe8d29a),
      );
    }
  }

  @override
  bool shouldRepaint(_SurahFrame oldDelegate) => false;
}
