import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'completion_effects.dart';
import 'k_card.dart';

/// What the empty section will look like, drawn faintly behind the message.
enum GhostKind {
  /// Habit rows: a circle, a name, a count.
  rows,

  /// A bar chart, a week of it.
  bars,

  /// The board's tiles.
  grid,
}

/// A section with nothing in it yet, made to look like a promise rather than
/// a gap.
///
/// A faint picture of what will be there — rows, bars or tiles — sits behind
/// a small lit badge, a title and one line. An empty table with its headings
/// showing, or a big card with one sentence in it, reads as something broken;
/// a preview of the thing reads as the thing, waiting.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.ghost = GhostKind.rows,
    this.height = 196,
    this.card = true,
  });

  final IconData icon;
  final String title;
  final String body;
  final GhostKind ghost;
  final double height;

  /// Drawn in its own card, or straight into a card it already sits in.
  final bool card;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final compact = height < 150;
    // Every place this sits is a card, so the clear patch is card-coloured.
    final ground = k.colors.surface;

    final content = SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _Ghost(kind: ghost),
          // A clear patch in the middle for the words to sit on, fading out
          // into the preview round it.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 0.75,
                colors: [
                  ground,
                  ground.withValues(alpha: 0.9),
                  ground.withValues(alpha: 0),
                ],
                stops: const [0, 0.45, 1],
              ),
            ),
          ),
          // Shrunk to fit rather than spilling over, wherever the section
          // turns out shorter than asked for.
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Badge(icon: icon, size: compact ? 40 : 54),
                    SizedBox(height: compact ? 8 : 12),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: k.text.cardTitle.copyWith(
                        fontSize: compact ? 14 : 15.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      textAlign: TextAlign.center,
                      style: k.text.caption.copyWith(
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (!card) return content;
    return KCard(padding: const EdgeInsets.all(14), child: content);
  }
}

/// A small disc, lit in the accent, with the section's icon on it. Rises in
/// once when the section first appears.
class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.size});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduceMotion(context) ? 1 : 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Transform.scale(
        scale: 0.7 + 0.3 * t,
        child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
      ),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [k.colors.accentSoft, k.colors.primarySoft],
          ),
          border: Border.all(color: k.colors.accent.withValues(alpha: 0.28)),
          boxShadow: [
            BoxShadow(
              color: k.colors.accent.withValues(alpha: 0.22),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, size: size * 0.46, color: k.colors.accent),
      ),
    );
  }
}

/// The faint preview itself.
class _Ghost extends StatelessWidget {
  const _Ghost({required this.kind});

  final GhostKind kind;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return CustomPaint(
      painter: _GhostPainter(
        kind: kind,
        ink: k.colors.textPrimary.withValues(alpha: 0.06),
        tint: k.colors.accent,
      ),
    );
  }
}

class _GhostPainter extends CustomPainter {
  _GhostPainter({required this.kind, required this.ink, required this.tint});

  final GhostKind kind;
  final Color ink;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = ink;
    switch (kind) {
      case GhostKind.rows:
        const widths = [0.46, 0.34, 0.52, 0.28];
        final rowH = size.height / widths.length;
        for (var i = 0; i < widths.length; i++) {
          final cy = rowH * (i + 0.5);
          canvas.drawCircle(Offset(14, cy), 10, paint);
          canvas.drawRRect(
            RRect.fromLTRBR(
              34,
              cy - 5,
              34 + size.width * widths[i],
              cy + 5,
              const Radius.circular(5),
            ),
            paint,
          );
          canvas.drawRRect(
            RRect.fromLTRBR(
              size.width - 44,
              cy - 5,
              size.width - 4,
              cy + 5,
              const Radius.circular(5),
            ),
            paint,
          );
        }
      case GhostKind.bars:
        const heights = [0.35, 0.6, 0.45, 0.82, 0.55, 0.7, 0.4];
        final slot = size.width / heights.length;
        final bar = Paint()..color = tint.withValues(alpha: 0.10);
        for (var i = 0; i < heights.length; i++) {
          final h = (size.height - 12) * heights[i];
          canvas.drawRRect(
            RRect.fromLTRBAndCorners(
              slot * i + slot * 0.24,
              size.height - h,
              slot * (i + 1) - slot * 0.24,
              size.height,
              topLeft: const Radius.circular(6),
              topRight: const Radius.circular(6),
            ),
            bar,
          );
        }
      case GhostKind.grid:
        const cols = 10;
        const rows = 5;
        final cell = math.min(size.width / cols, size.height / rows);
        final left = (size.width - cell * cols) / 2;
        final top = (size.height - cell * rows) / 2;
        // A pattern rather than noise: a board somebody is getting into.
        for (var r = 0; r < rows; r++) {
          for (var c = 0; c < cols; c++) {
            final shade = ((c * 7 + r * 3) % 5) / 5;
            final tile = Paint()
              ..color = tint.withValues(
                alpha: 0.04 + 0.12 * shade * (c / cols),
              );
            canvas.drawRRect(
              RRect.fromLTRBR(
                left + c * cell + 2,
                top + r * cell + 2,
                left + (c + 1) * cell - 2,
                top + (r + 1) * cell - 2,
                const Radius.circular(5),
              ),
              tile,
            );
          }
        }
    }
  }

  @override
  bool shouldRepaint(_GhostPainter old) =>
      old.kind != kind || old.ink != ink || old.tint != tint;
}
