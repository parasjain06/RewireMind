import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A handwritten Caveat annotation with the small underline swoosh used in
/// the mockups.
class ScriptNote extends StatelessWidget {
  const ScriptNote({
    super.key,
    required this.text,
    this.align = TextAlign.center,
    this.underline = true,
    this.fontSize,
    this.color,
  });

  final String text;
  final TextAlign align;
  final bool underline;
  final double? fontSize;

  /// Overrides the theme's script ink — for the celebration, which is
  /// white on green rather than green on white.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    var style = k.text.script;
    if (fontSize != null) style = style.copyWith(fontSize: fontSize);
    if (color != null) style = style.copyWith(color: color);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: switch (align) {
        TextAlign.left || TextAlign.start => CrossAxisAlignment.start,
        TextAlign.right || TextAlign.end => CrossAxisAlignment.end,
        _ => CrossAxisAlignment.center,
      },
      children: [
        Text(text, textAlign: align, style: style),
        if (underline) ...[
          const SizedBox(height: 2),
          CustomPaint(
            size: const Size(52, 7),
            painter: _SwooshPainter(color ?? k.colors.script),
          ),
        ],
      ],
    );
  }
}

class _SwooshPainter extends CustomPainter {
  const _SwooshPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(size.width * 0.04, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * 0.45,
        size.height * 1.15,
        size.width * 0.96,
        size.height * 0.18,
      );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SwooshPainter oldDelegate) => oldDelegate.color != color;
}
