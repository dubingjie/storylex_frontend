import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'journal.dart';

/// A paper tab: its small tilt and loose stitched edge match the HTML reference.
class JournalNav extends StatefulWidget {
  const JournalNav({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });
  final String label;
  final IconData icon;
  final bool selected, compact;
  final VoidCallback onTap;
  @override
  State<JournalNav> createState() => _JournalNavState();
}

class _JournalNavState extends State<JournalNav>
    with SingleTickerProviderStateMixin {
  late final _tapAnimation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  bool _hovered = false, _focused = false;
  @override
  void dispose() {
    _tapAnimation.dispose();
    super.dispose();
  }

  void _tap() {
    if (!MediaQuery.disableAnimationsOf(context))
      _tapAnimation.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final duration = reduce ? Duration.zero : const Duration(milliseconds: 240);
    final foreground = widget.selected
        ? const Color(0xFF705B3D)
        : const Color(0xFF968D7C);
    return Semantics(
      label: widget.label,
      button: true,
      selected: widget.selected,
      onTap: _tap,
      child: ExcludeSemantics(
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: AnimatedBuilder(
            animation: _tapAnimation,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, math.sin(_tapAnimation.value * math.pi) * -3),
              child: child,
            ),
            child: TweenAnimationBuilder<double>(
              tween: Tween(
                end: widget.selected ? -.024 : (_hovered ? .012 : 0),
              ),
              duration: duration,
              curve: Curves.easeOutCubic,
              builder: (context, angle, child) =>
                  Transform.rotate(angle: angle, child: child),
              child: AnimatedContainer(
                duration: duration,
                transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
                decoration: BoxDecoration(
                  color: widget.selected
                      ? const Color(0xFFFCF1C8)
                      : (_hovered
                            ? const Color(0xFFFAF3E2)
                            : const Color(0x00FCF1C8)),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(13),
                    topRight: Radius.circular(17),
                    bottomLeft: Radius.circular(15),
                    bottomRight: Radius.circular(14),
                  ),
                  border: _focused
                      ? Border.all(color: const Color(0xFFC7AE74))
                      : null,
                  // Keep the same pale RGB when alpha fades, avoiding a dark flash.
                  boxShadow: [
                    BoxShadow(
                      color: widget.selected
                          ? const Color(0x70DED2AF)
                          : const Color(0x00DED2AF),
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (widget.selected)
                      const Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(painter: _Stitches()),
                        ),
                      ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _tap,
                        onFocusChange: (value) =>
                            setState(() => _focused = value),
                        borderRadius: BorderRadius.circular(14),
                        overlayColor: const WidgetStatePropertyAll(
                          Colors.transparent,
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: widget.compact
                                ? 8
                                : JournalLayout.of(context).navX,
                            vertical: widget.compact
                                ? 7
                                : JournalLayout.of(context).navY,
                          ),
                          child: widget.compact
                              ? Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      widget.icon,
                                      size: 21,
                                      color: foreground,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      widget.label,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: foreground,
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    Icon(
                                      widget.icon,
                                      size: JournalLayout.of(context).tablet
                                          ? 18
                                          : 22,
                                      color: widget.selected
                                          ? const Color(0xFFBC9861)
                                          : const Color(0xFFAD9E87),
                                    ),
                                    SizedBox(
                                      width: JournalLayout.of(context).navGap,
                                    ),
                                    Text(
                                      widget.label,
                                      style: TextStyle(
                                        fontSize: JournalLayout.of(context)
                                            .navSize,
                                        height: 1.6,
                                        color: foreground,
                                        fontWeight: widget.selected
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: widget.compact ? -3 : -11,
                      bottom: widget.compact ? -3 : -6,
                      child: IgnorePointer(
                        child: AnimatedScale(
                          scale: widget.selected ? 1 : 0,
                          duration: duration,
                          curve: Curves.easeOutBack,
                          child: CustomPaint(
                            size: Size.square(widget.compact ? 19 : 29),
                            painter: const _PaperStar(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Stitches extends CustomPainter {
  const _Stitches();
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(5),
          const Radius.circular(10),
        ),
      );
    final paint = Paint()
      ..color = const Color(0xFFE6D7A4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in path.computeMetrics()) {
      for (double distance = 0; distance < metric.length; distance += 7) {
        canvas.drawPath(
          metric.extractPath(distance, math.min(distance + 3, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_Stitches oldDelegate) => false;
}

class _PaperStar extends CustomPainter {
  const _PaperStar();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(.21);
    final points = [
      const Offset(.5, 0),
      const Offset(.64, .32),
      const Offset(1, .37),
      const Offset(.74, .61),
      const Offset(.81, .98),
      const Offset(.49, .80),
      const Offset(.16, .98),
      const Offset(.23, .61),
      const Offset(0, .37),
      const Offset(.36, .32),
    ];
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final point = Offset(
        (points[i].dx - .5) * size.width,
        (points[i].dy - .5) * size.height,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(
      path.shift(const Offset(1, 1.5)),
      Paint()..color = const Color(0x88C9B985),
    );
    canvas.drawPath(path, Paint()..color = const Color(0xFFF2E6A8));
  }

  @override
  bool shouldRepaint(_PaperStar oldDelegate) => false;
}
