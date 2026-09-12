import 'dart:async';

import 'package:flutter/material.dart';

import '../models/day_phase.dart';
import '../content/app_content.dart';
import '../theme/app_theme.dart';

/// Set false in tests.
///
/// A repeating timer schedules frames forever, so `pumpAndSettle` would never
/// settle and every widget test would time out. Tests disable it in
/// `test/helpers.dart`; production always leaves it on.
bool quoteAutoAdvance = true;

/// The day's quotes, sliding gently from one to the next.
///
/// Swipeable as well as automatic — the timer restarts after a manual swipe so
/// it never yanks the page out from under a finger.
class QuoteCarousel extends StatefulWidget {
  const QuoteCarousel({
    super.key,
    this.interval = const Duration(seconds: 7),
    this.phase,
  });

  final Duration interval;

  /// Overrides the time of day, so the ink follows a previewed scene
  /// rather than the clock. Null follows the clock.
  final DayPhase? phase;

  @override
  State<QuoteCarousel> createState() => _QuoteCarouselState();
}

class _QuoteCarouselState extends State<QuoteCarousel> {
  /// The pool for the time of day being shown.
  ///
  /// Read once, in initState, and fixed for the life of the widget: the page
  /// controller is built around how many quotes there are, so a pool that
  /// changed underneath it would leave the controller pointing past the end.
  /// Home gives this a key on the phase, so crossing into the evening builds a
  /// fresh carousel rather than mutating this one.
  late final List<String> _quotes = AppContent.homeQuotesFor(
    widget.phase ?? DayPhase.of(DateTime.now()),
  );

  late final PageController _controller;
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Start on the quote of the day, then move on from there.
    _index = DateTime.now().day % _quotes.length;
    _controller = PageController(initialPage: _index);
    _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    if (!quoteAutoAdvance || _quotes.length < 2) return;
    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted || !_controller.hasClients) return;
      _controller.animateToPage(
        (_index + 1) % _quotes.length,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    // The night sky darkens the ground under this text, so the ink flips to
    // light. Dark-on-dark was the weakest contrast in the whole app.
    final isNight =
        (widget.phase ?? DayPhase.of(DateTime.now())) == DayPhase.night;
    final ink = isNight
        ? Colors.white.withValues(alpha: 0.94)
        : k.colors.textPrimary.withValues(alpha: 0.88);
    final markColor = isNight
        ? Colors.white.withValues(alpha: 0.55)
        : k.colors.accent.withValues(alpha: 0.6);
    final dotColor = isNight ? Colors.white : k.colors.accent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.format_quote, size: 19, color: markColor),
        const SizedBox(height: 2),
        SizedBox(
          height: 62,
          child: PageView.builder(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            itemCount: _quotes.length,
            onPageChanged: (i) {
              setState(() => _index = i);
              _restartTimer();
            },
            itemBuilder: (context, i) {
              final text = Align(
                alignment: Alignment.topLeft,
                child: Text(
                  _quotes[i],
                  style: k.text.body.copyWith(
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: ink,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              );

              // Sliding sideways puts the outgoing and incoming quote in view
              // at once, and in a narrow column that reads as clipped
              // half-words. Fading each page by its distance from centre turns
              // the hand-off into a soft cross-dissolve.
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  var distance = 0.0;
                  if (_controller.hasClients &&
                      _controller.position.haveDimensions) {
                    distance = (_controller.page ?? _index.toDouble()) - i;
                  }
                  return Opacity(
                    opacity: (1 - distance.abs() * 1.6).clamp(0.0, 1.0),
                    child: child,
                  );
                },
                child: text,
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < _quotes.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.only(right: 4),
                width: i == _index ? 12 : 5,
                height: 5,
                decoration: BoxDecoration(
                  color: i == _index
                      ? dotColor
                      : dotColor.withValues(alpha: 0.32),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
