import 'package:flutter/material.dart';

import '../models/day_phase.dart';
import '../theme/app_theme.dart';

/// ============================================================================
/// HEADER ILLUSTRATIONS
/// ============================================================================
/// Drawn with CustomPainter rather than shipped as images, so they recolour
/// with the theme and add nothing to the bundle.
/// ============================================================================

/// One phase's lighting: where the light sits, its colour, how it falls on the
/// tree, and which way it throws the shadow.
@immutable
class _SkyLight {
  const _SkyLight({
    required this.x,
    required this.y,
    required this.core,
    required this.halo,
    required this.radius,
    required this.shadowDir,
    required this.shadowLength,
    required this.shadowAlpha,
    this.skyWash,
    this.foliage,
    this.trunk,
    this.rim,
    this.stars = false,
    this.crescent = false,
    this.onHorizon = false,
  });

  /// Position of the sun or moon, as a fraction of the scene.
  final double x;
  final double y;
  final Color core;
  final Color halo;
  final double radius;

  /// -1 throws the shadow left, +1 right — always away from the light.
  final double shadowDir;

  /// Multiplier on the shadow's length. Low light means a long shadow.
  final double shadowLength;
  final double shadowAlpha;

  /// A wash over the upper sky, for dusk and night.
  final Color? skyWash;

  /// Overrides for the tree, so it is not painted the same green at midnight
  /// as at noon.
  final Color? foliage;
  final Color? trunk;

  /// A bright edge on the side of the canopy facing the light.
  final Color? rim;

  final bool stars;
  final bool crescent;

  /// Clips the light to the sky, so the ground cuts the disc into a
  /// half-risen sun instead of a ball resting on the grass.
  final bool onHorizon;

  static const Map<DayPhase, _SkyLight> _all = {
    // Just clearing the horizon on the left, soft rather than fierce, with a
    // long shadow thrown east. The ground is painted after it, so the disc
    // sits half-risen.
    DayPhase.earlyMorning: _SkyLight(
      x: 0.22,
      y: 0.755,
      core: Color(0xFFFFA85F),
      halo: Color(0xFFFFD3A2),
      radius: 0.19,
      onHorizon: true,
      shadowDir: 1,
      shadowLength: 2.7,
      shadowAlpha: 0.18,
      rim: Color(0x66FFD79A),
    ),
    // Overhead and pale; the shadow collapses to a pool underfoot.
    //
    // Well right of centre. Nearer the middle it sat behind the quote, whose
    // block runs to 56% of the header — a bright disc directly under three
    // lines of text, which made both hard to read.
    DayPhase.day: _SkyLight(
      x: 0.70,
      y: 0.08,
      core: Color(0xFFFFD34E),
      halo: Color(0xFFFFEDBA),
      radius: 0.14,
      shadowDir: 0.2,
      shadowLength: 0.7,
      shadowAlpha: 0.24,
      rim: Color(0x55FFF0C0),
    ),
    // Moonlight: the tree drops to a cool near-silhouette with a silver edge
    // on the moon side, over a deep blue sky.
    // Higher than a moon strictly needs to be. The character's speech bubble
    // passes under it, and at its old height the two met.
    DayPhase.night: _SkyLight(
      x: 0.55,
      y: 0.13,
      core: Color(0xFFEFF4FB),
      halo: Color(0xFFAFC4E4),
      radius: 0.11,
      shadowDir: 0.85,
      shadowLength: 1.9,
      shadowAlpha: 0.16,
      skyWash: Color(0x552A3C6B),
      foliage: Color(0xFF27453F),
      trunk: Color(0xFF3A3630),
      rim: Color(0x88C9DBF2),
      stars: true,
      crescent: true,
    ),
  };

  static _SkyLight of(DayPhase phase) => _all[phase]!;
}

/// Soft sunrise-over-mountains scene used on Calendar, Progress and Profile.
class MountainScene extends StatelessWidget {
  const MountainScene({super.key, this.height = 110});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      // Fades out at the bottom so the scene has no hard horizontal edge.
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Colors.white, Colors.transparent],
          stops: [0, 0.66, 1],
        ).createShader(rect),
        child: CustomPaint(
          painter: _MountainPainter(
            context.k.colors,
            // The palette already carries the time of day, so the scene can
            // read it off the theme rather than being told.
            context.k.brightness == Brightness.dark,
          ),
        ),
      ),
    );
  }
}

/// The tree-on-a-hill scene on the Home header, lit by the time of day.
///
/// [treeX] slides the tree sideways (0 = left edge, 1 = right edge) to leave
/// room for the quote.
class TreeScene extends StatelessWidget {
  const TreeScene({
    super.key,
    this.height = 150,
    this.treeX = 0.5,
    this.phase,
    this.showTree = true,
  });

  final double height;
  final double treeX;

  /// Overrides the time of day. Null follows the clock.
  final DayPhase? phase;

  /// Draw the tree itself. Off leaves the sky, the light and the ground —
  /// everything the time of day is carried by — so something else can stand
  /// in the spot the tree had.
  final bool showTree;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      // The fade starts low so the ground — and the shadow lying on it — stay
      // visible; it only softens the very bottom edge into the page.
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Colors.white, Colors.transparent],
          stops: [0, 0.88, 1],
        ).createShader(rect),
        child: CustomPaint(
          painter: _TreePainter(
            context.k.colors,
            treeX,
            phase ??
                (kLiveDayTheme ? DayPhase.of(DateTime.now()) : kStaticPhase),
            showTree,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _MountainPainter extends CustomPainter {
  _MountainPainter(this.colors, this.night);

  final RewireMindColors colors;
  final bool night;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // After dark the hills drop back to a deep, desaturated green so they
    // read as land under moonlight rather than as daytime foliage.
    final green = night ? const Color(0xFF2C4C46) : colors.accent;
    final deep = night ? const Color(0xFF203B39) : colors.primary;

    if (night) {
      paintStarField(canvas, size, const Color(0xFFAFC4E4));
      paintCrescent(
        canvas,
        Offset(w * 0.80, h * 0.30),
        h * 0.17,
        const Color(0xFFEFF4FB),
        const Color(0xFFAFC4E4),
      );
    } else {
      // Sun with a soft halo, right of centre so it balances the page title.
      final sun = Offset(w * 0.78, h * 0.36);
      canvas.drawCircle(
        sun,
        h * 0.52,
        Paint()
          ..color = colors.star.withValues(alpha: 0.14)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      );
      canvas.drawCircle(
        sun,
        h * 0.32,
        Paint()
          ..color = colors.star.withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    canvas.drawPath(
      Path()
        ..moveTo(0, h)
        ..lineTo(0, h * 0.74)
        ..quadraticBezierTo(w * 0.14, h * 0.40, w * 0.28, h * 0.68)
        ..quadraticBezierTo(w * 0.40, h * 0.86, w * 0.52, h * 0.52)
        ..quadraticBezierTo(w * 0.66, h * 0.18, w * 0.80, h * 0.62)
        ..quadraticBezierTo(w * 0.91, h * 0.90, w, h * 0.66)
        ..lineTo(w, h)
        ..close(),
      Paint()..color = green.withValues(alpha: 0.20),
    );

    canvas.drawPath(
      Path()
        ..moveTo(0, h)
        ..lineTo(0, h * 0.88)
        ..quadraticBezierTo(w * 0.18, h * 0.62, w * 0.34, h * 0.84)
        ..quadraticBezierTo(w * 0.48, h * 0.99, w * 0.63, h * 0.74)
        ..quadraticBezierTo(w * 0.80, h * 0.50, w, h * 0.86)
        ..lineTo(w, h)
        ..close(),
      Paint()..color = green.withValues(alpha: 0.34),
    );

    final treePaint = Paint()..color = deep.withValues(alpha: 0.30);
    void conifer(double cx, double baseY, double treeH) {
      final half = treeH * 0.32;
      canvas.drawPath(
        Path()
          ..moveTo(cx, baseY - treeH)
          ..lineTo(cx + half, baseY)
          ..lineTo(cx - half, baseY)
          ..close(),
        treePaint,
      );
    }

    conifer(w * 0.10, h, h * 0.30);
    conifer(w * 0.19, h, h * 0.42);
    conifer(w * 0.28, h, h * 0.26);
    conifer(w * 0.83, h, h * 0.34);
    conifer(w * 0.92, h, h * 0.24);
  }

  @override
  bool shouldRepaint(_MountainPainter oldDelegate) =>
      oldDelegate.colors != colors || oldDelegate.night != night;
}

// ---------------------------------------------------------------------------

class _TreePainter extends CustomPainter {
  _TreePainter(this.colors, this.treeX, this.phase, [this.showTree = true]);

  final RewireMindColors colors;
  final double treeX;
  final DayPhase phase;
  final bool showTree;

  /// The ground line. Everything below it is open ground, which is what gives
  /// the shadow somewhere to fall — the tree used to sit almost on the bottom
  /// edge, leaving no room for one.
  static const double _horizon = 0.74;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final sky = _SkyLight.of(phase);

    final foliage = sky.foliage ?? colors.accent;
    final deepFoliage = sky.foliage == null
        ? colors.primary
        : Color.lerp(sky.foliage!, Colors.black, 0.22)!;
    final trunkColor = sky.trunk ?? const Color(0xFF8D6E52);

    // Canopy radius drives the scale of the whole tree.
    final r = h * 0.155;
    final cx = w * treeX;
    final groundY = h * _horizon;
    final light = Offset(w * sky.x, h * sky.y);

    Paint soft(Color color, double alpha, double sigma) => Paint()
      ..color = color.withValues(alpha: alpha)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma);

    final ground = Path()
      ..moveTo(0, h)
      ..lineTo(0, groundY + h * 0.06)
      ..quadraticBezierTo(w * 0.26, groundY - h * 0.05, w * 0.55, groundY)
      ..quadraticBezierTo(w * 0.80, groundY + h * 0.05, w, groundY - h * 0.02)
      ..lineTo(w, h)
      ..close();

    // ---- sky -------------------------------------------------------------
    if (sky.skyWash != null) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w, groundY),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [sky.skyWash!, sky.skyWash!.withValues(alpha: 0)],
          ).createShader(Rect.fromLTWH(0, 0, w, groundY)),
      );
    }

    if (sky.stars) paintStarField(canvas, size, sky.halo);

    // ---- sun or moon -----------------------------------------------------
    if (sky.crescent) {
      paintCrescent(canvas, light, h * sky.radius, sky.core, sky.halo);
    } else {
      final radius = h * sky.radius;

      // A sun sitting on the horizon is masked to the sky, so the land cuts
      // it cleanly. Without this it reads as a ball lying on the grass.
      if (sky.onHorizon) {
        canvas.save();
        canvas.clipPath(
          Path.combine(
            PathOperation.difference,
            Path()..addRect(Rect.fromLTWH(0, 0, w, h)),
            ground,
          ),
        );
        // First light spilling sideways along the horizon.
        canvas.drawOval(
          Rect.fromCenter(
            center: light,
            width: radius * 9,
            height: radius * 2.4,
          ),
          soft(sky.halo, 0.34, 18),
        );
      }

      canvas.drawCircle(light, radius * 2.6, soft(sky.halo, 0.38, 15));
      // Solid, barely blurred: a low sun has to read as a disc against a
      // sky of almost its own colour, not as another wash.
      canvas.drawCircle(light, radius, soft(sky.core, 0.94, 1.5));

      if (sky.onHorizon) canvas.restore();
    }

    // ---- ground ----------------------------------------------------------
    canvas.drawPath(ground, soft(foliage, 0.20, 2));

    if (!showTree) return;

    // ---- the shadow, before the tree so the trunk sits on top of it -------
    final reach = r * 2.2 * sky.shadowLength;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx + sky.shadowDir * reach * 0.45, groundY + r * 0.30),
        width: r * 1.7 + reach,
        height: r * 0.62,
      ),
      soft(deepFoliage, sky.shadowAlpha, 6),
    );

    // ---- trunk -----------------------------------------------------------
    canvas.drawPath(
      Path()
        ..moveTo(cx - r * 0.22, groundY + r * 0.18)
        ..lineTo(cx - r * 0.11, h * 0.40)
        ..lineTo(cx + r * 0.11, h * 0.40)
        ..lineTo(cx + r * 0.22, groundY + r * 0.18)
        ..close(),
      Paint()..color = trunkColor,
    );

    final branch = Paint()
      ..color = trunkColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.11
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx, h * 0.54),
      Offset(cx - r * 0.62, h * 0.42),
      branch,
    );
    canvas.drawLine(
      Offset(cx + r * 0.04, h * 0.50),
      Offset(cx + r * 0.66, h * 0.40),
      branch,
    );

    // ---- canopy ----------------------------------------------------------
    void blob(double dx, double cy, double radius, double alpha, Color color) {
      canvas.drawCircle(
        Offset(cx + dx, h * cy),
        radius,
        soft(color, alpha, 1.6),
      );
    }

    blob(-r * 0.80, 0.30, r * 0.92, 0.55, foliage);
    blob(r * 0.80, 0.30, r * 0.92, 0.55, foliage);
    blob(0, 0.15, r * 1.05, 0.72, foliage);
    blob(-r * 0.48, 0.23, r * 1.00, 0.86, deepFoliage);
    blob(r * 0.48, 0.23, r * 1.00, 0.86, deepFoliage);
    blob(0, 0.27, r * 1.05, 0.95, foliage);

    // A lit edge on the side facing the sun or moon, which is what actually
    // sells the light as coming from somewhere.
    if (sky.rim != null) {
      final towardLight = (light.dx - cx).sign;
      canvas.saveLayer(null, Paint());
      canvas.drawCircle(
        Offset(cx + towardLight * r * 0.55, h * 0.24),
        r * 1.12,
        Paint()..color = sky.rim!,
      );
      canvas.drawCircle(
        Offset(cx + towardLight * r * 0.22, h * 0.27),
        r * 1.12,
        Paint()..blendMode = BlendMode.clear,
      );
      canvas.restore();
    }

    // ---- drifting leaves --------------------------------------------------
    void drift(double dx, double cy, double radius) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx + dx, h * cy),
          width: radius * 1.7,
          height: radius,
        ),
        soft(foliage, 0.62, 1),
      );
    }

    drift(r * 1.62, 0.22, h * 0.042);
    drift(r * 2.00, 0.38, h * 0.034);
    drift(r * 1.40, 0.52, h * 0.028);
    drift(-r * 1.75, 0.46, h * 0.030);
  }

  /// A fixed scatter of stars at mixed sizes, the brightest carrying a small
  /// cross-flare so the sky reads as glittering rather than dotted.
  @override
  bool shouldRepaint(_TreePainter oldDelegate) =>
      oldDelegate.colors != colors ||
      oldDelegate.treeX != treeX ||
      oldDelegate.phase != phase ||
      oldDelegate.showTree != showTree;
}

// ---------------------------------------------------------------------------
// Night sky, shared by both scenes
// ---------------------------------------------------------------------------

/// A fixed field of stars. Fixed rather than random so the sky does not
/// reshuffle itself on every repaint.
void paintStarField(Canvas canvas, Size size, Color halo) {
  final w = size.width;
  final h = size.height;

  // x, y, size factor, brightness.
  const seeds = <List<double>>[
    [0.04, 0.15, 1.0, 1.0],
    [0.09, 0.38, 0.6, 0.75],
    [0.13, 0.62, 0.5, 0.6],
    [0.17, 0.09, 0.8, 0.85],
    [0.22, 0.29, 1.2, 1.0],
    [0.27, 0.50, 0.6, 0.7],
    [0.31, 0.13, 0.7, 0.8],
    [0.36, 0.36, 0.5, 0.65],
    [0.40, 0.58, 0.9, 0.9],
    [0.44, 0.07, 0.6, 0.7],
    [0.49, 0.26, 0.8, 0.85],
    [0.53, 0.47, 0.5, 0.6],
    [0.58, 0.11, 1.1, 1.0],
    [0.63, 0.33, 0.6, 0.7],
    [0.67, 0.56, 0.7, 0.75],
    [0.71, 0.18, 0.9, 0.9],
    [0.76, 0.42, 0.5, 0.6],
    [0.80, 0.08, 0.7, 0.8],
    [0.84, 0.31, 1.0, 0.95],
    [0.88, 0.53, 0.6, 0.7],
    [0.92, 0.16, 0.8, 0.85],
    [0.96, 0.40, 1.1, 1.0],
    [0.99, 0.24, 0.5, 0.65],
  ];

  Paint soft(Color color, double alpha, double sigma) => Paint()
    ..color = color.withValues(alpha: alpha.clamp(0.0, 1.0))
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma);

  for (final seed in seeds) {
    final at = Offset(w * seed[0], h * seed[1]);
    final radius = h * 0.012 * seed[2];
    final glow = seed[3];

    canvas.drawCircle(at, radius * 3.4, soft(halo, glow * 0.34, 3));
    canvas.drawCircle(at, radius, soft(const Color(0xFFFFFFFF), glow, 0.3));

    // Only the larger ones get flares, or the sky turns into a snowstorm.
    if (seed[2] >= 0.9) {
      final flare = Paint()
        ..color = Colors.white.withValues(alpha: glow * 0.6)
        ..strokeWidth = radius * 0.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        at.translate(-radius * 3.2, 0),
        at.translate(radius * 3.2, 0),
        flare,
      );
      canvas.drawLine(
        at.translate(0, -radius * 3.2),
        at.translate(0, radius * 3.2),
        flare,
      );
    }
  }
}

/// A crescent moon: a disc with a second disc cut out of it.
void paintCrescent(
  Canvas canvas,
  Offset at,
  double radius,
  Color core,
  Color halo,
) {
  canvas.drawCircle(
    at,
    radius * 2.6,
    Paint()
      ..color = halo.withValues(alpha: 0.38)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15),
  );
  canvas.saveLayer(null, Paint());
  canvas.drawCircle(at, radius, Paint()..color = core);
  canvas.drawCircle(
    at.translate(radius * 0.62, -radius * 0.34),
    radius * 0.95,
    Paint()..blendMode = BlendMode.clear,
  );
  canvas.restore();
}
