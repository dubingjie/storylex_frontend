import 'package:flutter/material.dart';

/// Small line drawings transcribed from the original HTML artwork.
class JournalBookArt extends StatelessWidget {
  const JournalBookArt({super.key, this.cover = false});
  final bool cover;
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: cover ? const Size(68, 94) : const Size(95, 76),
    painter: _BookPainter(cover),
  );
}

class _BookPainter extends CustomPainter {
  const _BookPainter(this.cover);
  final bool cover;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(
      size.width / (cover ? 68 : 100),
      size.height / (cover ? 94 : 80),
    );
    if (cover) {
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 68, 94),
        Paint()..color = const Color(0xFFD5DFC5),
      );
      final stroke = Paint()
        ..color = const Color(0xFFADB99A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7;
      canvas.drawRect(const Rect.fromLTWH(5, 5, 58, 84), stroke);
      final arch = Path()
        ..moveTo(17, 61)
        ..lineTo(17, 32)
        ..arcToPoint(const Offset(51, 32), radius: const Radius.circular(17))
        ..lineTo(51, 61)
        ..close();
      canvas.drawPath(arch, Paint()..color = const Color(0xFFF6EDCC));
      canvas.drawCircle(
        const Offset(42, 29),
        7,
        Paint()..color = const Color(0xFFE6D299),
      );
      canvas.drawPath(
        Path()
          ..moveTo(17, 55)
          ..quadraticBezierTo(33, 34, 51, 50)
          ..lineTo(51, 62)
          ..lineTo(17, 62)
          ..close(),
        Paint()..color = const Color(0xFFB9C9A3),
      );
      stroke
        ..color = const Color(0xFFA1B18C)
        ..strokeWidth = 1.8;
      canvas.drawLine(const Offset(34, 16), const Offset(34, 61), stroke);
      canvas.drawLine(const Offset(17, 39), const Offset(51, 39), stroke);
      stroke
        ..color = const Color(0xFFB4BF9E)
        ..strokeWidth = 1.3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(14, 76), const Offset(54, 76), stroke);
      canvas.drawLine(const Offset(23, 81), const Offset(45, 81), stroke);
    } else {
      final pen = Paint()
        ..color = const Color(0xFFE1D7AF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final book = Path()
        ..moveTo(11, 31)
        ..quadraticBezierTo(31, 24, 50, 36)
        ..quadraticBezierTo(69, 24, 89, 31)
        ..lineTo(91, 62)
        ..quadraticBezierTo(69, 57, 50, 67)
        ..quadraticBezierTo(31, 57, 9, 62)
        ..close();
      canvas.drawPath(book, pen);
      canvas.drawLine(const Offset(50, 36), const Offset(50, 67), pen);
      for (final y in [36.0, 43.0, 50.0]) {
        canvas.drawPath(
          Path()
            ..moveTo(17, y)
            ..quadraticBezierTo(32, y - 3, 43, y + 4),
          pen,
        );
        canvas.drawPath(
          Path()
            ..moveTo(58, y + 4)
            ..quadraticBezierTo(69, y - 3, 83, y),
          pen,
        );
      }
      canvas.drawPath(
        Path()
          ..moveTo(51, 30)
          ..quadraticBezierTo(50, 18, 58, 7),
        pen,
      );
      canvas.drawPath(
        Path()
          ..moveTo(54, 21)
          ..quadraticBezierTo(41, 20, 41, 9)
          ..quadraticBezierTo(53, 9, 54, 21)
          ..close(),
        pen,
      );
      canvas.drawPath(
        Path()
          ..moveTo(56, 15)
          ..quadraticBezierTo(56, 4, 68, 3)
          ..quadraticBezierTo(67, 14, 56, 15)
          ..close(),
        pen,
      );
      for (final mark in [const Offset(22, 16), const Offset(81, 20)]) {
        canvas.drawLine(
          mark - const Offset(0, 3),
          mark + const Offset(0, 3),
          pen,
        );
        canvas.drawLine(
          mark - const Offset(3, 0),
          mark + const Offset(3, 0),
          pen,
        );
      }
      canvas.drawPath(
        Path()
          ..moveTo(36, 67)
          ..lineTo(35, 75)
          ..lineTo(40, 72)
          ..lineTo(44, 76)
          ..lineTo(45, 69),
        pen,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BookPainter oldDelegate) => cover != oldDelegate.cover;
}
