import 'package:material_ui/material_ui.dart';

/// App logo (same drawing as the web app's Logo SVG): rounded square, three lines, green dot.
class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(size: Size.square(size), painter: _LogoPainter(scheme.onSurface, scheme.surface));
  }
}

class _LogoPainter extends CustomPainter {
  final Color fg, bg;
  _LogoPainter(this.fg, this.bg);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24; // the SVG uses a 24×24 viewBox
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(2 * s, 2 * s, 20 * s, 20 * s), Radius.circular(5 * s)),
      Paint()..color = fg,
    );
    final line = Paint()
      ..color = bg
      ..strokeWidth = 2 * s
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(7 * s, 8.5 * s), Offset(17 * s, 8.5 * s), line);
    canvas.drawLine(Offset(7 * s, 12 * s), Offset(14 * s, 12 * s), line);
    canvas.drawLine(Offset(7 * s, 15.5 * s), Offset(11 * s, 15.5 * s), line);
    canvas.drawCircle(Offset(16.5 * s, 15.5 * s), 2 * s, Paint()..color = const Color(0xFF3FB950));
  }

  @override
  bool shouldRepaint(covariant _LogoPainter old) => old.fg != fg || old.bg != bg;
}
