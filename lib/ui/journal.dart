import 'dart:math' as math;

import 'package:flutter/material.dart';

abstract final class Journal {
  static const cream = Color(0xFFFCF8ED), paper = Color(0xFFFFFEFA);
  static const ink = Color(0xFF53443B), muted = Color(0xFFA19480);
  static const line = Color(0xFFEEE7D7), yellow = Color(0xFFFFF9DE);
  static const sage = Color(0xFFEEF3E5), pink = Color(0xFFFFF3F4);
  static const green = Color(0xFF708157);
  static TextStyle hand(double size) => TextStyle(
    fontFamily: 'JournalHand',
    fontFamilyFallback: const [
      'JournalHandFull',
      'JournalSans',
      'JournalSansFull',
    ],
    fontWeight: FontWeight.w400,
    fontSize: size,
    height: 1.5,
    color: ink,
  );
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    fontFamily: 'JournalSans',
    fontFamilyFallback: const ['JournalSansFull'],
    scaffoldBackgroundColor: cream,
    colorScheme: const ColorScheme.light(
      primary: green,
      secondary: Color(0xFFB7985F),
      surface: paper,
      onSurface: ink,
      error: Color(0xFFA74F43),
      surfaceTint: Colors.transparent,
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 14, height: 1.6, color: ink),
      bodySmall: TextStyle(fontSize: 12, height: 1.6, color: muted),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: paper,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: green, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFDCE8CA),
        foregroundColor: const Color(0xFF617148),
        minimumSize: const Size(44, 48),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ink,
        minimumSize: const Size(44, 46),
        side: const BorderSide(color: line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: green,
        minimumSize: const Size(44, 44),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Color(0xFF79684F),
      behavior: SnackBarBehavior.floating,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: green,
      linearTrackColor: Color(0xFFE5E3D4),
    ),
    dividerColor: line,
    dividerTheme: const DividerThemeData(color: line, thickness: 1),
  );
}

class Paper extends StatelessWidget {
  const Paper({
    super.key,
    required this.child,
    this.color = Journal.paper,
    this.padding = const EdgeInsets.all(26),
    this.tape = true,
  });
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  final bool tape;
  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(9),
            bottomLeft: Radius.circular(10),
            bottomRight: Radius.circular(7),
          ),
          border: Border.all(color: Journal.line),
          boxShadow: color != Journal.paper
              ? const [
                  BoxShadow(color: Color(0x60E3DEC7), offset: Offset(0, 3)),
                ]
              : const [
                  BoxShadow(color: Color(0xFFF8EFCE), offset: Offset(8, 10)),
                  BoxShadow(color: Color(0xFFF4E8DF), offset: Offset(4, 5)),
                  BoxShadow(
                    color: Color(0x0CC0AF8A),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
        ),
        child: child,
      ),
      if (tape && color != Journal.paper)
        Positioned(
          top: -8,
          left: 0,
          right: 0,
          child: Center(
            child: Transform.rotate(
              angle: color == Journal.sage ? .087 : -.07,
              child: Container(
                width: 62,
                height: 19,
                color: color == Journal.sage
                    ? const Color(0x94CEDEC4)
                    : const Color(0x91F2DFAA),
              ),
            ),
          ),
        ),
      if (tape && color == Journal.paper)
        Positioned(
          top: -8,
          left: JournalLayout.of(context).mobile ? -8 : -11,
          child: Transform.rotate(
            angle: -math.pi / 10,
            child: Container(
              width: JournalLayout.of(context).mobile ? 67 : 93,
              height: JournalLayout.of(context).mobile ? 21 : 29,
              color: const Color(0x80C9DEC9),
            ),
          ),
        ),
      if (tape && color == Journal.paper)
        Positioned(
          top: 1,
          right: JournalLayout.of(context).mobile ? -8 : -13,
          child: Transform.rotate(
            angle: 28 * math.pi / 180,
            child: Container(
              width: JournalLayout.of(context).mobile ? 64 : 93,
              height: JournalLayout.of(context).mobile ? 21 : 29,
              color: const Color(0x7DEFD2D7),
            ),
          ),
        ),
    ],
  );
}

/// Breakpoints and dimensions from the reference HTML's final CSS rules.
class JournalLayout {
  const JournalLayout(this.width);
  factory JournalLayout.of(BuildContext context) =>
      JournalLayout(MediaQuery.sizeOf(context).width);
  final double width;
  bool get mobile => width <= 650;
  bool get tiny => width <= 370;
  bool get tablet => width <= 850;
  bool get medium => width <= 1100;
  bool get large => width >= 1450;
  double get sidebar => large ? 225 : (tablet ? 155 : (medium ? 180 : 210));
  double get sidebarX => large ? 25 : (tablet ? 12 : (medium ? 17 : 22));
  double get sidebarY => large ? 35 : (tablet ? 27 : (medium ? 29 : 31));
  double get navSize => tablet ? 13 : (medium ? 14 : 16);
  double get navX => tablet ? 12 : (medium ? 14 : 17);
  double get navY => tablet ? 12 : (medium ? 13 : 14);
  double get navGap => tablet ? 10 : (medium ? 12 : 14);
  EdgeInsets get sheetPadding => mobile
      ? EdgeInsets.fromLTRB(tiny ? 13 : 17, 16, tiny ? 13 : 17, 21)
      : large
      ? const EdgeInsets.symmetric(horizontal: 40, vertical: 29)
      : tablet
      ? const EdgeInsets.symmetric(horizontal: 20, vertical: 22)
      : medium
      ? const EdgeInsets.all(24)
      : const EdgeInsets.fromLTRB(32, 25, 32, 26);
  EdgeInsets get framePadding => mobile
      ? EdgeInsets.fromLTRB(tiny ? 13 : 17, 17, tiny ? 13 : 17, 35)
      : EdgeInsets.fromLTRB(
          large ? 38 : (tablet ? 20 : (medium ? 23 : 26)),
          25,
          large ? 38 : (tablet ? 20 : (medium ? 23 : 30)),
          35,
        );
}

class PageFrame extends StatelessWidget {
  const PageFrame({super.key, required this.child, this.width = 1180});
  final Widget child;
  final double width;
  @override
  Widget build(BuildContext context) {
    final layout = JournalLayout.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: layout.mobile ? 540 : width),
        child: Padding(padding: layout.framePadding, child: child),
      ),
    );
  }
}

class ErrorNote extends StatelessWidget {
  const ErrorNote(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF7E8E2),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Color(0xFF994F43), fontSize: 13),
      ),
    ),
  );
}

class WaitButton extends StatelessWidget {
  const WaitButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.busy = false,
  });
  final String text;
  final VoidCallback? onPressed;
  final bool busy;
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy ? null : onPressed,
    child: busy
        ? const SizedBox(
            width: 21,
            height: 21,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(text),
  );
}

void showNote(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
