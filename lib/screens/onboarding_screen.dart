import 'package:flutter/material.dart';

import '../content/app_content.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import '../widgets/completion_effects.dart';
import 'home_shell.dart';

/// How it works: the app in five slides.
///
/// Shown on the first launch and kept on Profile. Each slide is one idea: a
/// small drawing of it, a two-line headline and one line under it. Swipe or
/// tap Next; Skip leaves from any slide. It replaced a page of nine cards of
/// sentences, which is a lot to ask of somebody in their first minute.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.offerTour = true});

  /// Whether the last slide offers the walkthrough of Home. Not on the first
  /// launch, where the walkthrough follows on by itself.
  final bool offerTour;

  static Future<void> open(BuildContext context, {bool offerTour = true}) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, _, _) => OnboardingScreen(offerTour: offerTour),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pager = PageController();
  int _at = 0;

  static const _slides = AppContent.howSlides;

  bool get _last => _at == _slides.length - 1;

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  void _next() {
    if (_last) {
      Navigator.of(context).pop();
      return;
    }
    _pager.nextPage(
      duration: reduceMotion(context)
          ? Duration.zero
          : const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final colour = Color(_slides[_at].colour);
    final calm = reduceMotion(context);

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // The slide's own light, behind the character. It crossfades from
            // one colour to the next as you move, which is most of what makes
            // the change of slide feel like a change of scene.
            Positioned.fill(
              child: TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: colour),
                duration: Duration(milliseconds: calm ? 0 : 500),
                builder: (context, c, _) => DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.28),
                      radius: 0.85,
                      colors: [
                        (c ?? colour).withValues(alpha: 0.30),
                        (c ?? colour).withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 10, 8, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: _Progress(at: _at, of: _slides.length),
                        ),
                        const SizedBox(width: 6),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: k.colors.textSecondary,
                          ),
                          child: Text(AppContent.howSkip),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pager,
                      itemCount: _slides.length,
                      onPageChanged: (i) => setState(() => _at = i),
                      itemBuilder: (context, i) =>
                          _Slide(slide: _slides[i], showing: i == _at),
                    ),
                  ),
                  // The walkthrough of Home, offered once the story is told.
                  // Always laid out, so the button under it does not move.
                  if (widget.offerTour)
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: _last ? 1 : 0,
                      child: IgnorePointer(
                        ignoring: !_last,
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            homeTourRequests.value++;
                          },
                          icon: const Icon(Icons.touch_app_outlined, size: 18),
                          label: Text(AppContent.howTour),
                          style: TextButton.styleFrom(
                            foregroundColor: k.colors.primary,
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 22),
                    child: _Button(
                      colour: colour,
                      label: _last ? AppContent.howStart : AppContent.howNext,
                      wide: _last,
                      onTap: _next,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One slide: the drawing on a glass disc, then the words.
class _Slide extends StatelessWidget {
  const _Slide({required this.slide, required this.showing});

  final HowSlide slide;

  /// Whether this is the slide on screen. The words rise into place when it
  /// arrives, so each slide lands rather than merely sliding past.
  final bool showing;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final colour = Color(slide.colour);
    final motion = reduceMotion(context)
        ? Duration.zero
        : const Duration(milliseconds: 520);

    return LayoutBuilder(
      builder: (context, box) {
        final disc = (box.maxHeight * 0.46).clamp(180.0, 270.0);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: showing ? 1 : 0.88,
                duration: motion,
                curve: Curves.easeOutBack,
                child: _Stage(
                  art: slide.art,
                  colour: colour,
                  size: disc,
                  showing: showing,
                ),
              ),
              SizedBox(height: disc * 0.14),
              AnimatedSlide(
                offset: showing ? Offset.zero : const Offset(0, 0.25),
                duration: motion,
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: showing ? 1 : 0,
                  duration: motion,
                  child: Column(
                    children: [
                      Text(
                        slide.title,
                        textAlign: TextAlign.center,
                        style: k.text.pageTitle.copyWith(
                          fontSize: 32,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.6,
                          color: k.colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        slide.line,
                        textAlign: TextAlign.center,
                        style: k.text.body.copyWith(
                          fontSize: 15,
                          height: 1.4,
                          color: k.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A frosted disc lit in the slide's colour, with the slide's drawing on it.
class _Stage extends StatelessWidget {
  const _Stage({
    required this.art,
    required this.colour,
    required this.size,
    required this.showing,
  });

  final String art;
  final Color colour;
  final double size;

  /// The drawing plays each time its slide comes into view.
  final bool showing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 0.92,
            height: size * 0.92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.62),
                  Colors.white.withValues(alpha: 0.18),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.7),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: colour.withValues(alpha: 0.22),
                  blurRadius: 56,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
          ),
          SizedBox(
            width: size * 0.6,
            height: size * 0.6,
            child: TweenAnimationBuilder<double>(
              key: ValueKey(showing),
              tween: Tween(
                begin: showing && !reduceMotion(context) ? 0 : 1,
                end: 1,
              ),
              duration: const Duration(milliseconds: 1100),
              curve: Curves.easeOutCubic,
              builder: (context, t, _) => _Art(art: art, colour: colour, t: t),
            ),
          ),
        ],
      ),
    );
  }
}

/// The five drawings, each at [t] of the way through its entrance.
class _Art extends StatelessWidget {
  const _Art({required this.art, required this.colour, required this.t});

  final String art;
  final Color colour;
  final double t;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final s = box.maxWidth;
        return switch (art) {
          'tick' => _tick(context, s),
          'flame' => _flame(context, s),
          'grid' => _grid(s),
          'ring' => _ring(context, s),
          _ => _sprout(s),
        };
      },
    );
  }

  /// Something the colour of the slide, lit from the top left.
  Shader _lit(Rect r) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color.lerp(colour, Colors.white, 0.35)!, colour],
  ).createShader(r);

  Widget _glyph(IconData icon, double size) => ShaderMask(
    shaderCallback: _lit,
    blendMode: BlendMode.srcIn,
    child: Icon(icon, size: size, color: Colors.white),
  );

  /// Tiny habits: a sprout coming up, with a few specks rising round it.
  Widget _sprout(double s) {
    final grow = Curves.easeOutBack.transform(t.clamp(0.0, 1.0));
    return Stack(
      alignment: Alignment.center,
      children: [
        for (final (dx, dy, r) in const [
          (-0.34, 0.1, 5.0),
          (0.36, -0.05, 4.0),
          (0.26, -0.38, 3.0),
          (-0.22, -0.34, 3.5),
        ])
          Align(
            alignment: Alignment(dx, dy - 0.25 * t),
            child: Opacity(
              opacity: (t * 1.4).clamp(0.0, 1.0) * 0.55,
              child: Container(
                width: r * 2,
                height: r * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colour,
                ),
              ),
            ),
          ),
        Transform.scale(
          scale: 0.4 + 0.6 * grow,
          alignment: Alignment.bottomCenter,
          child: _glyph(Icons.spa_rounded, s * 0.7),
        ),
      ],
    );
  }

  /// Tap it, done: a habit card, and its circle filling with a tick.
  Widget _tick(BuildContext context, double s) {
    final fill = ((t - 0.35) / 0.4).clamp(0.0, 1.0);
    return Center(
      child: Container(
        width: s,
        padding: EdgeInsets.all(s * 0.08),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(s * 0.12),
          boxShadow: [
            BoxShadow(
              color: colour.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: s * 0.2,
              height: s * 0.2,
              decoration: BoxDecoration(
                color: colour.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(s * 0.06),
              ),
            ),
            SizedBox(width: s * 0.07),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bar(s * 0.36, s * 0.05, 0.22),
                  SizedBox(height: s * 0.04),
                  _bar(s * 0.22, s * 0.04, 0.12),
                ],
              ),
            ),
            Container(
              width: s * 0.2,
              height: s * 0.2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color.lerp(Colors.transparent, colour, fill),
                border: Border.all(
                  color: Color.lerp(
                    colour.withValues(alpha: 0.35),
                    colour,
                    fill,
                  )!,
                  width: 2,
                ),
              ),
              child: Transform.scale(
                scale: Curves.easeOutBack.transform(fill),
                child: Icon(
                  Icons.check_rounded,
                  size: s * 0.14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bar(double w, double h, double alpha) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: colour.withValues(alpha: alpha),
      borderRadius: BorderRadius.circular(h),
    ),
  );

  /// Streaks that glow: a flame, and the days counting up under it.
  Widget _flame(BuildContext context, double s) {
    final k = context.k;
    final days = (12 * t).round();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: colour.withValues(alpha: 0.35 * t),
                blurRadius: 36,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Transform.scale(
            scale: 0.8 + 0.2 * Curves.easeOutBack.transform(t),
            child: _glyph(Icons.local_fire_department_rounded, s * 0.58),
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: s * 0.08,
            vertical: s * 0.025,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(s),
          ),
          child: Text(
            '$days day streak',
            style: k.text.captionStrong.copyWith(
              fontSize: s * 0.085,
              color: colour,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }

  /// Your story, in colour: a board of tiles, filling in left to right.
  Widget _grid(double s) {
    const cols = 6;
    const rows = 5;
    final cell = s / cols;
    return Center(
      child: SizedBox(
        width: s,
        height: cell * rows,
        child: Stack(
          children: [
            for (var r = 0; r < rows; r++)
              for (var c = 0; c < cols; c++)
                Positioned(
                  left: c * cell,
                  top: r * cell,
                  width: cell,
                  height: cell,
                  child: Builder(
                    builder: (context) {
                      final at = (c + r * 0.4) / (cols + rows * 0.4);
                      final on = ((t - at * 0.7) / 0.3).clamp(0.0, 1.0);
                      final depth = 0.25 + 0.75 * (((c * 5 + r * 3) % 4) / 3);
                      return Padding(
                        padding: EdgeInsets.all(cell * 0.09),
                        child: Transform.scale(
                          scale: 0.6 + 0.4 * on,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(cell * 0.22),
                              color: colour.withValues(alpha: depth * on),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
          ],
        ),
      ),
    );
  }

  /// 21 days to rewire: the number, and a ring closing round it.
  Widget _ring(BuildContext context, double s) {
    final k = context.k;
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: s * 0.9,
          height: s * 0.9,
          child: CircularProgressIndicator(
            value: t,
            strokeWidth: s * 0.06,
            strokeCap: StrokeCap.round,
            backgroundColor: colour.withValues(alpha: 0.14),
            valueColor: AlwaysStoppedAnimation(colour),
          ),
        ),
        ShaderMask(
          shaderCallback: _lit,
          blendMode: BlendMode.srcIn,
          child: Text(
            '21',
            style: k.text.pageTitle.copyWith(
              fontSize: s * 0.36,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}

/// Story-style bars along the top: one per slide, filled up to this one.
class _Progress extends StatelessWidget {
  const _Progress({required this.at, required this.of});

  final int at;
  final int of;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Row(
      children: [
        for (var i = 0; i < of; i++) ...[
          if (i > 0) const SizedBox(width: 5),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 3.5,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: i <= at
                    ? k.colors.textPrimary.withValues(alpha: 0.8)
                    : k.colors.textPrimary.withValues(alpha: 0.14),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Next, in the slide's colour; full width on the last slide, as Let's go.
class _Button extends StatelessWidget {
  const _Button({
    required this.colour,
    required this.label,
    required this.wide,
    required this.onTap,
  });

  final Color colour;
  final String label;
  final bool wide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return LayoutBuilder(
      builder: (context, box) => Align(
        alignment: Alignment.centerRight,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
          width: wide ? box.maxWidth : 148,
          height: 56,
          decoration: BoxDecoration(
            color: colour,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: colour.withValues(alpha: 0.38),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: onTap,
              // Scaled rather than cut while the button widens into Let's go,
              // and under a large system font.
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: k.text.bodyStrong.copyWith(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
