import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../content/app_content.dart';

import 'dart:async';

import '../notifications/path_sound.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import '../widgets/completion_effects.dart';
import 'challenge_rules_screen.dart';

/// ============================================================================
/// THE 21-DAY PATH
/// ============================================================================
/// A trail climbing a hillside, one stop for each perfect day, and a brain
/// wiring itself further at the seventh, fourteenth and twenty-first.
///
/// A run, not a tally: a missed day puts it back to nothing. That is the
/// harder of the two readings and it is deliberate — twenty-one *consecutive*
/// days is the claim the challenge makes, and a count that survived gaps would
/// be a different and much easier claim. It is also the reason the rules get a
/// screen of their own on the way in; see `challenge_rules_screen.dart`.
/// ============================================================================

/// Stops on the path.
const int kPathLength = kChallengeLength;

/// Where a milestone stands.
const List<int> kMilestones = [7, 14, 21];

/// What the end of each week is worth: bronze, silver, gold.
///
/// The same seven days' work every time, so the metal is the only thing that
/// says which week you are finishing — and it is the third one that finishes
/// the habit, which is why the last is the one worth having.
///
/// Silver is a deeper steel than it looks like it should be. Struck at the
/// pale grey a silver medal actually is, next to a locked stop it read as
/// greyed out rather than as metal — the contrast between face and rim is
/// what says metal here, not the lightness of the face.
const List<Color> kMedalFace = [
  Color(0xFFE8A76B),
  Color(0xFFBFCAD8),
  Color(0xFFF6CE55),
];
const List<Color> kMedalEdge = [
  Color(0xFFB9743C),
  Color(0xFF74839A),
  Color(0xFFD4A017),
];

/// The ribbon it hangs from. Deliberately not the accent: the path is accent
/// green and runs straight through the stop, so a green ribbon vanished into
/// it and left the medal looking like a coin someone had dropped there.
const List<Color> kMedalRibbon = [
  Color(0xFF8C5A2B),
  Color(0xFF5E6B7C),
  Color(0xFFA9761B),
];

/// One milestone's worth of path is what a screen holds, so arriving at a
/// marker is a whole page rather than a thing you scroll past.
const int kStopsPerScreen = 7;

/// The character, at the six days it turns up on.
///
/// The moods climb: it takes real attention at first, earns its first week,
/// starts making it look easy, finds its rhythm, stops noticing, and finally
/// goes up. Six of the same face would be wallpaper — the point is that the
/// effort visibly drains out of it as the days add up.
const Map<int, String> kMoods = {
  4: 'day03', // focused — this still takes attention
  7: 'day07', // happy — the first week is yours
  11: 'day10', // cool — you are making it look easy
  14: 'day14', // confident — it is clicking
  18: 'day17', // calm — it costs nothing now
  21: 'day21', // jumping — done
};

/// The one who is already there, at the foot of the path.
///
/// Always in colour and never locked: the start is somewhere you have by
/// definition reached, and a greyed-out figure at day one would be telling
/// you that you have not begun the thing you are looking at.
const String kStartAsset = 'assets/anim/start.webp';

/// A day you have reached moves; a day ahead of you is a frozen frame of the
/// same character. A greyed-out character still bobbing away reads as broken
/// rather than dormant — and on a fresh install this leaves one animation
/// decoding instead of six.
String moodAsset(int day, {required bool reached}) =>
    'assets/anim/${kMoods[day]}${reached ? '' : '_still'}.webp';

/// Extra room at each week boundary, on top of the usual gap between days.
///
/// Without it the week banner lands mid-way between day seven and day eight —
/// which is right on top of the milestone, since that stop is 34 across with
/// a halo round it. The weeks also just read better with air between them.
const double kWeekGap = 74;

/// Where stop [i] sits on a canvas of [size].
///
/// Lives outside the painter because the character is an animated image, and
/// an image is a widget: it has to be positioned in the same coordinate space
/// the painter draws in, so both read their geometry from here.
Offset pathStop(int i, Size size, double stopGap, double bottomPad) {
  // Side to side, day by day. A drift of a few percent read as a straight
  // line with a wobble; this actually leaves the middle of the page.
  //
  // The swing has a limit, though: the characters stand on fixed marks at
  // 16% and 84% of the width rather than dodging the route, so the route has
  // to stay out of the columns they occupy. Their boxes reach in to about
  // 30%, which is what caps the amplitude below.
  //
  // A milestone is not swung at all. It is 34 across with a halo round it and
  // a ribbon on top, and centring it both keeps it clear of the characters
  // and makes the end of a week land square in the middle of the page.
  // The phase of the alternation is not free. The characters turn up on days
  // 4, 11 and 18 standing on the right, and on 7, 14 and 21 standing on the
  // left — and 4, 11 and 18 all fall on the same rung of the week. Starting
  // the zigzag to the right is what sends those three stops left, away from
  // the character beside them; the other way round and all three crowd it.
  final onWeek = i % kDaysPerWeek;
  final swing = onWeek == kDaysPerWeek - 1
      ? 0.0
      : (onWeek.isEven ? 1 : -1) * (0.125 + 0.03 * math.sin(i * 1.31));

  return Offset(
    size.width * (0.5 + swing),
    size.height - bottomPad - i * stopGap - (i ~/ kDaysPerWeek) * kWeekGap,
  );
}

/// The road ahead: a dotted line in neutral stone, a route that exists but
/// has not carried anything yet.
const Color kTrackFace = Color(0xFFB3A78F);

/// The track once it has been walked: green, and green for good.
///
/// Three tones because it is drawn as a tube — the face, the shadow side and
/// the lit edge. It was stone for a while, on the theory that a green strip
/// would fight the coloured beads; but a stretch you have covered is
/// a pathway that has fired, and it stays lit — the green is the achievement,
/// so it should not drain back to grey the moment the animation that earned it
/// is over. The same family as the impulse that travels it, so when the
/// once-a-day signal lands its glow settles into this rather than being
/// replaced by something else.
const Color kFiredFace = Color(0xFF2FBF6A);
const Color kFiredEdge = Color(0xFF1B8747);
const Color kFiredLit = Color(0xFFB4F2CD);

/// A colour for each of the six days that lead up to a medal.
///
/// One flat green dot per day made the walked half of the path read as a
/// tally rather than as somewhere you had been. The hues run in the order the
/// glyphs do, so a day is recognisable by its colour before you have looked
/// at what is drawn on it.
const List<Color> kBeatColours = [
  Color(0xFFF5A623), // spark
  Color(0xFF1FB3A4), // link
  Color(0xFF8B6BE8), // circuit
  Color(0xFF3D8BF2), // mesh
  Color(0xFFFF7043), // bolt
  Color(0xFFEC5F8C), // star
];

/// Days in a week of the path. Seven days, three weeks, twenty-one days.
const int kDaysPerWeek = 7;
const int kWeeks = kPathLength ~/ kDaysPerWeek;

class RoadmapScreen extends StatefulWidget {
  const RoadmapScreen({super.key, this.walkFrom});

  /// The stop to walk up from, or null to open the path already drawn.
  ///
  /// Set only by the once-a-day arrival: the trail starts the length it was
  /// yesterday and grows to the stop that has been earned since. Everywhere
  /// else opens the path as it stands, because a screen that re-enacts your
  /// progress every time you visit is a screen you stop visiting.
  final int? walkFrom;

  static Future<void> open(BuildContext context, {int? walkFrom}) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RoadmapScreen(walkFrom: walkFrom)),
    );
  }

  @override
  State<RoadmapScreen> createState() => _RoadmapScreenState();
}

class _RoadmapScreenState extends State<RoadmapScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  /// Draws the trail in and pops the stops, once, on arrival.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  /// Never stops: drifting leaves, the ring around today, the trees swaying.
  /// This is what keeps the screen from looking like a diagram.
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );

  /// The impulse travelling from yesterday's stop to today's.
  ///
  /// Two seconds, because that is how long the chime that carries it rings:
  /// the signal reaches the far stop on the same beat the sound finishes, and
  /// the arrival click lands there. Any faster and it is over before anybody
  /// has looked up; any slower and the sound runs out halfway up the fibre.
  late final AnimationController _walk = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  );

  /// The stop that received the signal, waking up. Runs once, on arrival.
  late final AnimationController _energise = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  /// True from the moment the walk arrives. Holds the arrival on screen — the
  /// stop keeps its glow and the button appears — until the screen is left.
  bool _arrived = false;

  /// True once the camera has found the stop the signal leaves from. Nothing
  /// fires before then: an impulse that sets off while the page is still
  /// sliding is an impulse nobody sees start.
  bool _aimed = false;

  final ScrollController _scroll = ScrollController();

  // Margins above the top stop and below the bottom one. Everything between
  // is divided so that a screen holds exactly one milestone's worth of path.
  static const double _topPad = 74;
  static const double _bottomPad = 74;

  /// Set during layout, and read by the opening scroll.
  double _stopGap = 96;

  /// The canvas the stops are laid out on, set during layout.
  Size _canvas = Size.zero;

  /// The scroll offset that puts stop [day] at [fraction] of the way down the
  /// screen, clamped to what the page can actually scroll to.
  ///
  /// Read from [pathStop] rather than worked out from the gap, so the week
  /// breaks — which add height between days seven and eight — are counted.
  double _offsetFor(double day, {double fraction = 0.6}) {
    final position = _scroll.position;
    final i = (day - 1).clamp(0.0, kPathLength - 1.0);
    final lower = pathStop(i.floor(), _canvas, _stopGap, _bottomPad).dy;
    final upper = pathStop(i.ceil(), _canvas, _stopGap, _bottomPad).dy;
    final y = lower + (upper - lower) * (i - i.floor());
    return (y - position.viewportDimension * fraction).clamp(
      0.0,
      position.maxScrollExtent,
    );
  }

  double _gapFor(double viewport) =>
      ((viewport - _topPad - _bottomPad) / (kStopsPerScreen - 1)).clamp(
        62.0,
        132.0,
      );

  bool _started = false;

  /// The locked day currently being held down, if any.
  ///
  /// Press and hold one of the days ahead of you and it wakes up for as long
  /// as your finger is on it — a look at what is coming, which costs nothing
  /// and gives the greyed-out half of the path something to do.
  int? _peeking;

  /// How far the trail runs: the stop you are standing on.
  ///
  /// Keeping a day earns the next stop, so an unbroken run puts you at today's
  /// — and a missed day drops both the run and the trail back to nothing,
  /// because the challenge is twenty-one *consecutive* days and a path that
  /// kept its progress through a gap would be counting something else.
  int _done(AppState state) => state.challengeStop.clamp(0, kPathLength);

  /// The trail's length right now, as a fraction of a stop.
  ///
  /// A whole number except during the walk, which is the point: the painter
  /// takes a double so the green can stop halfway between two days.
  double _drawn(AppState state) {
    final to = _done(state).toDouble();
    final from = widget.walkFrom?.toDouble();
    if (from == null) return to;
    return from + (to - from) * Curves.easeInOutCubic.transform(_walk.value);
  }

  /// The stop marked "you are here".
  ///
  /// The day the challenge is on, not the one after the last day finished.
  /// Before it has been started there is no such day, so the ring sits on the
  /// first stop — which is where somebody reading the rules is about to be.
  int _here(AppState state) =>
      state.challengeLive ? state.challengeElapsed.clamp(1, kPathLength) : 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (context.read<AppState>().challengeMusicOn) {
      unawaited(ChallengeMusic.start());
    }

    // Open on the stop you are actually standing at, not at day one.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      // The stop you are standing on, sitting a little below the middle of
      // the screen — where you are, with the road ahead above it. Anchored on
      // that rather than on days finished, or the first morning of the
      // challenge opens above day one with nothing under it.
      //
      // On the once-a-day walk it opens a screen higher than that instead, so
      // that finding the stop the signal leaves from is a movement you watch
      // — see [_aim].
      final from = widget.walkFrom;
      if (from != null && !reduceMotion(context)) {
        final aim = _offsetFor(_walkMidpoint(from));
        _scroll.jumpTo(
          (aim - _scroll.position.viewportDimension * 0.8).clamp(
            0.0,
            _scroll.position.maxScrollExtent,
          ),
        );
        return;
      }
      final here = _here(context.read<AppState>());
      _scroll.jumpTo(
        _offsetFor(
          (from != null ? _walkMidpoint(from) : here.toDouble()),
          fraction: 0.55,
        ),
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery is only readable from here down, and the trail should only
    // ever draw itself in once.
    if (_started) return;
    _started = true;
    if (reduceMotion(context)) {
      _intro.value = 1;
    } else {
      _intro.forward();
      _ambient.repeat();
    }
    _startWalk();
  }

  /// Halfway between the stop the signal leaves and the one it reaches: where
  /// the camera sits, so both ends of the journey are on screen at once.
  double _walkMidpoint(int from) =>
      (from + _done(context.read<AppState>())) / 2;

  /// Finds the cell, fires, conducts, and wakes the next one.
  ///
  /// Somebody who has asked the system for reduced motion gets the arrival
  /// without the journey — the stop still wakes, both sounds still play, the
  /// camera just does not travel and nothing streaks up the page.
  Future<void> _startWalk() async {
    final from = widget.walkFrom;
    if (from == null) return;

    if (reduceMotion(context)) {
      setState(() => _aimed = true);
      unawaited(PathSound.travel());
      // The music steps back while the signal travels.
      unawaited(ChallengeMusic.duck(const Duration(milliseconds: 2400)));
      _walk.value = 1;
      _land();
      return;
    }

    // Let the page lay out and the trail start drawing before the camera
    // moves, then find the stop.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    await _aim(from);
    if (!mounted) return;

    // A breath on the stop before it fires — long enough to see which one it
    // is, short enough that nobody wonders whether something is wrong.
    setState(() => _aimed = true);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;

    unawaited(PathSound.travel());
    // The music steps back while the signal travels.
    unawaited(ChallengeMusic.duck(const Duration(milliseconds: 2400)));
    await _walk.forward();
    if (!mounted) return;
    _land();
  }

  /// The glide down to the stop the signal leaves from.
  Future<void> _aim(int from) async {
    if (!_scroll.hasClients) return;
    final target = _offsetFor(_walkMidpoint(from));
    if ((target - _scroll.offset).abs() < 1) return;
    await _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeInOutCubic,
    );
  }

  /// The signal has arrived: a buzz, and the stop wakes.
  ///
  /// No sound of its own. The chime that carried the signal ends on this
  /// beat, and a click on top of it was one sound too many.
  void _land() {
    setState(() => _arrived = true);
    HapticFeedback.mediumImpact();
    if (reduceMotion(context)) {
      _energise.value = 1;
    } else {
      _energise.forward();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _ambient.dispose();
    _walk.dispose();
    _energise.dispose();
    _scroll.dispose();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(ChallengeMusic.stop());
    unawaited(PathSound.release());
    super.dispose();
  }

  /// Quiet while the app is in the background, back when it returns.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed) {
      unawaited(ChallengeMusic.resume());
    } else if (lifecycle == AppLifecycleState.paused ||
        lifecycle == AppLifecycleState.inactive) {
      unawaited(ChallengeMusic.pause());
    }
  }

  Future<void> _toggleMusic(AppState state) async {
    final on = !state.challengeMusicOn;
    await state.setChallengeMusicOn(on);
    on ? await ChallengeMusic.start() : await ChallengeMusic.stop();
  }

  /// The one waiting at the foot of the path, on the left.
  ///
  /// A still rather than a clip, so it gets its life from a slow rise and
  /// fall instead — enough to stop it looking like a sticker pinned to the
  /// page, and it costs nothing to decode.
  Widget _startMarker(Size canvas) {
    const w = 96.0;
    const h = 88.0;
    const box = 110.0;

    final at = pathStop(0, canvas, _stopGap, _bottomPad);

    return Positioned(
      left: canvas.width * 0.16 - box / 2,
      // Lifted clear of day one, or its label lands on the week-one banner,
      // which sits just below the first stop.
      top: at.dy - h / 2 - 30,
      child: SizedBox(
        width: box,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              kStartAsset,
              width: w,
              height: h,
              fit: BoxFit.contain,
              alignment: Alignment.bottomCenter,
              filterQuality: FilterQuality.medium,
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.fromLTRB(11, 5, 11, 6),
              decoration: BoxDecoration(
                color: context.k.colors.surface,
                borderRadius: BorderRadius.circular(
                  context.k.geometry.pillRadius,
                ),
                border: Border.all(
                  color: context.k.colors.accent.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                AppContent.pathStart,
                textAlign: TextAlign.center,
                style: context.k.text.captionStrong.copyWith(
                  fontSize: 11.5,
                  height: 1.2,
                  color: context.k.colors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The character for [day], beside the path.
  ///
  /// It stands on whichever side the path is not on at that moment, so it
  /// never has to be squeezed against a margin or drawn over the route.
  /// A day you have not reached shows the same character drained of colour
  /// and standing still: waiting for you, rather than absent. Hold it and it
  /// starts moving until you let go — still grey, because the colour is what
  /// arriving there is worth.
  Widget _mood(int day, Size canvas, int done) {
    const w = 96.0;
    const h = 88.0;
    // A little wider than the character, so the label underneath has room.
    const box = 110.0;

    final at = pathStop(day - 1, canvas, _stopGap, _bottomPad);
    // Left, right, left — the one at the foot of the path is the first and
    // stands left, so the first mood along it stands right. A steady rhythm
    // reads better than picking whichever side happens to be roomier, which
    // made the placement look accidental.
    final rank = kMoods.keys.toList().indexOf(day) + 1;
    final x = rank.isOdd ? canvas.width * 0.84 : canvas.width * 0.16;
    final reached = done >= day;
    final peeking = _peeking == day;

    Widget brain = Image.asset(
      // A day under your finger plays, the same as one you have earned.
      moodAsset(day, reached: reached || peeking),
      width: w,
      height: h,
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
      filterQuality: FilterQuality.medium,
    );

    if (!reached) {
      // Held, it moves — but it stays grey. The colour is what you get for
      // arriving; all a peek buys you is the sight of it stirring.
      brain = Opacity(
        opacity: 0.4,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            0.2126, 0.7152, 0.0722, 0, 0, //
            0.2126, 0.7152, 0.0722, 0, 0, //
            0.2126, 0.7152, 0.0722, 0, 0, //
            0, 0, 0, 1, 0, //
          ]),
          child: brain,
        ),
      );
    }

    return Positioned(
      left: x - box / 2,
      top: at.dy - h / 2,
      child: Listener(
        // Raw pointer events rather than a tap: the wake-up has to last
        // exactly as long as the finger is down, and a tap gesture only
        // reports itself once it is over.
        onPointerDown: reached ? null : (_) => setState(() => _peeking = day),
        onPointerUp: reached ? null : (_) => setState(() => _peeking = null),
        onPointerCancel: reached
            ? null
            : (_) => setState(() => _peeking = null),
        child: SizedBox(
          width: box,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: w, height: h, child: brain),
              if (reached) ...[
                const SizedBox(height: 2),
                // On a plate, the way the mood sheet labels its own drawings.
                // Bare text at this size disappeared into the background.
                Container(
                  padding: const EdgeInsets.fromLTRB(11, 5, 11, 6),
                  decoration: BoxDecoration(
                    color: context.k.colors.surface,
                    borderRadius: BorderRadius.circular(
                      context.k.geometry.pillRadius,
                    ),
                    border: Border.all(
                      color: context.k.colors.accent.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    AppContent.pathLine(day),
                    textAlign: TextAlign.center,
                    style: context.k.text.captionStrong.copyWith(
                      fontSize: 11.5,
                      height: 1.2,
                      color: context.k.colors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Ends the challenge, after asking.
  ///
  /// It stops counting and it comes off Home; nothing that was logged is
  /// touched, because those days happened whether or not the challenge is
  /// still running. Starting again is the same two taps it was the first
  /// time, and day one is that day.
  Future<void> _confirmGiveUp(BuildContext context) async {
    final k = context.k;
    final state = context.read<AppState>();

    final go = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: k.colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(k.geometry.cardRadius),
        ),
        title: Text(AppContent.challengeGiveUpTitle, style: k.text.cardTitle),
        content: Text(AppContent.challengeGiveUpBody, style: k.text.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              AppContent.challengeKeepGoing,
              style: k.text.captionStrong.copyWith(color: k.colors.primary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              AppContent.challengeGiveUpConfirm,
              style: k.text.captionStrong.copyWith(color: k.colors.danger),
            ),
          ),
        ],
      ),
    );

    if (go != true) return;
    await state.leaveChallenge();
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final state = context.watch<AppState>();
    final done = _done(state);
    final here = _here(state);
    final walking = widget.walkFrom != null;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: k.colors.primary),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            AppContent.pathTitle,
            style: k.text.sectionTitle.copyWith(fontSize: 17),
          ),
          actions: [
            // The music, on or off — remembered for next time.
            IconButton(
              icon: Icon(
                state.challengeMusicOn
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                color: k.colors.primary,
              ),
              tooltip: state.challengeMusicOn
                  ? AppContent.musicOff
                  : AppContent.musicOn,
              onPressed: () => _toggleMusic(state),
            ),
            // The terms stay reachable. They are agreed to once, but the one
            // that costs something is worth being able to check.
            IconButton(
              icon: Icon(Icons.info_outline, color: k.colors.primary),
              tooltip: AppContent.rulesTitle,
              onPressed: () =>
                  ChallengeRulesScreen.open(context, startsChallenge: false),
            ),
            // The way out. Twenty-one consecutive days is a commitment, and a
            // commitment nobody can withdraw from is a trap — it would sit on
            // Home saying "live" for as long as the app is installed.
            if (state.challengeLive)
              IconButton(
                icon: Icon(Icons.flag_outlined, color: k.colors.primary),
                tooltip: AppContent.challengeGiveUpTitle,
                onPressed: () => _confirmGiveUp(context),
              ),
          ],
        ),
        body: Column(
          children: [
            // Days *kept*, as the header says — not the stop you are standing
            // on, which is one further along every morning of an unbroken run.
            // The trail below shows where you are; this counts what you did.
            _PathHeader(done: state.challengeDay.clamp(0, kPathLength)),
            // Shown only on the once-a-day walk, and only once it lands. A
            // "back to Home" on every visit would be a second back button.
            //
            // Its room is held from the start and the bar fades into it.
            // Inserted at the moment of arrival it pushed the whole path down
            // by its own height, so the stop that had just woken jumped away
            // from under the burst.
            if (walking)
              IgnorePointer(
                ignoring: !_arrived,
                child: AnimatedOpacity(
                  opacity: _arrived ? 1 : 0,
                  duration: const Duration(milliseconds: 400),
                  child: _ArrivalBar(stop: done),
                ),
              ),
            Expanded(
              // The spacing between stops is whatever makes seven of them fit
              // the screen exactly. A milestone is then a page, not something
              // you scroll past halfway.
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _stopGap = _gapFor(constraints.maxHeight);
                  final height =
                      _topPad +
                      _bottomPad +
                      (kPathLength - 1) * _stopGap +
                      (kWeeks - 1) * kWeekGap;

                  final canvas = Size(constraints.maxWidth, height);
                  _canvas = canvas;

                  return SingleChildScrollView(
                    controller: _scroll,
                    child: SizedBox(
                      height: height,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: AnimatedBuilder(
                              animation: Listenable.merge([
                                _intro,
                                _ambient,
                                _walk,
                                _energise,
                              ]),
                              builder: (context, _) => CustomPaint(
                                painter: _PathPainter(
                                  colors: k.colors,
                                  done: _drawn(state),
                                  here: here,
                                  // The whole once-a-day sequence: which
                                  // stop fires, which receives, and how far
                                  // through each beat it is. All null on an
                                  // ordinary visit.
                                  firedFrom: walking ? widget.walkFrom : null,
                                  target: walking ? _done(state) : null,
                                  signal: walking && _aimed && !_arrived
                                      ? _walk.value
                                      : null,
                                  energise: walking && _arrived
                                      ? _energise.value
                                      : null,
                                  intro: Curves.easeOutCubic.transform(
                                    _intro.value,
                                  ),
                                  ambient: _ambient.value,
                                  stopGap: _stopGap,
                                  topPad: _topPad,
                                  bottomPad: _bottomPad,
                                ),
                                size: Size.infinite,
                              ),
                            ),
                          ),
                          _startMarker(canvas),
                          for (final day in kMoods.keys)
                            _mood(day, canvas, _drawn(state).floor()),
                        ],
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
}

// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------

/// What the walk was for, and the way out.
///
/// Appears only when the once-a-day climb lands, and only then: the path is
/// somewhere you can wander into any time, and a "back to Home" pinned under
/// the header on every visit would be a second back button.
///
/// It says which stop, because the number is the reward. "Day 6" after six
/// days of not missing is a different sentence from "well done".
class _ArrivalBar extends StatelessWidget {
  const _ArrivalBar({required this.stop});

  final int stop;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        k.geometry.screenPadding,
        0,
        k.geometry.screenPadding,
        10,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppContent.pathArrivedTitle(stop, kPathLength),
                  style: k.text.cardTitle.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  AppContent.pathArrivedBody(kPathLength - stop),
                  style: k.text.caption.copyWith(fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: k.colors.primary,
            borderRadius: BorderRadius.circular(k.geometry.pillRadius),
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(k.geometry.pillRadius),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 11,
                ),
                child: Text(
                  AppContent.pathArrivedButton,
                  style: k.text.captionStrong.copyWith(
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Where you are, in words, above the trail.
class _PathHeader extends StatelessWidget {
  const _PathHeader({required this.done});

  final int done;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final complete = done >= kPathLength;
    final next = kMilestones.firstWhere(
      (m) => m > done,
      orElse: () => kPathLength,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        k.geometry.screenPadding,
        2,
        k.geometry.screenPadding,
        10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('$done', style: k.text.statValue.copyWith(fontSize: 30)),
              const SizedBox(width: 5),
              Text(
                AppContent.pathOf(kPathLength),
                style: k.text.caption.copyWith(fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 1),
          Text(
            AppContent.pathTagline,
            style: k.text.caption.copyWith(fontSize: 11.5),
          ),
          const SizedBox(height: 1),
          Text(
            complete
                ? AppContent.pathFinished
                : AppContent.pathNextMilestone(next - done),
            style: k.text.caption.copyWith(
              fontSize: 11.5,
              color: k.colors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// The hillside, the trail, the stops and everything drifting across them.
class _PathPainter extends CustomPainter {
  _PathPainter({
    required this.colors,
    required this.done,
    required this.here,
    this.firedFrom,
    this.target,
    this.signal,
    this.energise,
    required this.intro,
    required this.ambient,
    required this.stopGap,
    required this.topPad,
    required this.bottomPad,
  });

  final RewireMindColors colors;

  /// How far the trail runs, in stops.
  ///
  /// A double rather than a count so that the once-a-day climb can leave it
  /// halfway between two days. Everything that asks "is this day walked" asks
  /// it as `done >= day`, which reads the same either way.
  final double done;

  /// The stop to mark as "you are here": the day the challenge is on.
  final int here;

  /// The stop the once-a-day signal fires from. Null on an ordinary visit.
  final int? firedFrom;

  /// The stop it is heading for. Null on an ordinary visit.
  final int? target;

  /// How far the impulse has travelled, 0 to 1, while it is travelling.
  final double? signal;

  /// How far the receiving stop has woken, 0 to 1, once it has arrived.
  final double? energise;

  /// 0 to 1, once, as the screen arrives.
  final double intro;

  /// 0 to 1, on a loop, forever.
  final double ambient;

  final double stopGap;
  final double topPad;
  final double bottomPad;

  /// Where stop [i] sits. Day one is at the bottom: the path is climbed.
  ///
  /// Nearly vertical, with a long slow drift across the page. It used to
  /// switchback hard from edge to edge, which made a nerve fibre look like a
  /// mountain road and left the middle of every screen empty.
  Offset _stop(int i, Size size) => pathStop(i, size, stopGap, bottomPad);

  @override
  void paint(Canvas canvas, Size size) {
    final stops = [for (var i = 0; i < kPathLength; i++) _stop(i, size)];

    _paintNeuralField(canvas, size);
    _paintPathway(canvas, size, stops);

    for (var i = 0; i < kPathLength; i++) {
      _paintStop(canvas, i, stops[i], size);
    }

    // Over the stops, so none of it is half-hidden behind the stop it is
    // happening to.
    final from = firedFrom;
    final to = target;
    if (from != null && to != null && to >= 1 && to <= kPathLength) {
      final origin = stops[(from - 1).clamp(0, kPathLength - 1)];
      final dest = stops[to - 1];
      final travel = signal;
      final wake = energise;
      if (travel != null) {
        _paintFiring(canvas, origin, from, travel);
        _paintExpecting(canvas, dest, to, travel);
      }
      if (wake != null) _paintWaking(canvas, dest, to, wake);
    }

    _paintWeekBanners(canvas, size, stops);
  }

  // ---- the three weeks ----------------------------------------------------

  /// The line where one week ends and the next begins, and its name.
  void _paintWeekBanners(Canvas canvas, Size size, List<Offset> stops) {
    for (var w = 1; w <= kWeeks; w++) {
      // Centred in the gap between the weeks, so it is clear of the milestone
      // below it and the first day above it.
      final first = stops[(w - 1) * kDaysPerWeek];
      final y = w == 1
          ? first.dy + 52
          : (first.dy + stops[(w - 1) * kDaysPerWeek - 1].dy) / 2;
      final reached = done >= (w - 1) * kDaysPerWeek + 1;

      // A hairline across the page, broken where the label sits.
      final label = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(
              text: '${AppContent.weekLabel(w).toUpperCase()}  ',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.7,
                color: reached ? colors.primary : colors.textSecondary,
              ),
            ),
            TextSpan(
              text: AppContent.weekName(w).toUpperCase(),
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.7,
                color: reached ? colors.accent : colors.textMuted,
              ),
            ),
          ],
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final gap = label.width / 2 + 16;
      final rule = Paint()
        ..color = reached
            ? Color.lerp(colors.accentTrack, colors.accent, 0.45)!
            : colors.accentTrack
        ..strokeWidth = 1.4;
      for (var x = 16.0; x < size.width - 16; x += 8) {
        if ((x - size.width / 2).abs() < gap) continue;
        canvas.drawLine(Offset(x, y), Offset(x + 4, y), rule);
      }

      // The label sits on the page rather than on the rule, so the dashes
      // never run through the words.
      final plate = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width / 2, y),
          width: label.width + 22,
          height: label.height + 12,
        ),
        const Radius.circular(20),
      );
      canvas.drawRRect(
        plate,
        Paint()..color = colors.surface.withValues(alpha: 0.92),
      );
      canvas.drawRRect(
        plate,
        Paint()
          ..color = reached
              ? colors.accent.withValues(alpha: 0.5)
              : colors.accentTrack
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );

      label.paint(
        canvas,
        Offset((size.width - label.width) / 2, y - label.height / 2),
      );
    }
  }

  // ---- the field it runs through -----------------------------------------

  /// A loose mesh of dim neurons behind everything, drifting.
  ///
  /// This used to be a hillside with leaves blowing over it, which was
  /// pleasant and had nothing to do with the idea. What the screen is about is
  /// a pathway in a brain getting easier to fire, so the background is the
  /// tissue that pathway runs through.
  void _paintNeuralField(Canvas canvas, Size size) {
    const cols = 8;
    final rows = (size.height / 78).ceil();
    final cellW = size.width / cols;
    final cellH = size.height / rows;

    // How far this node sits from its cell centre, breathing in and out.
    //
    // The phase runs with position rather than being shared, so the expansion
    // crosses the mesh as a slow wave instead of the whole field pulsing at
    // once — which would read as a flicker rather than as something alive.
    double reach(int c, int r) =>
        1 + 0.42 * math.sin(ambient * math.pi * 2 - (c * 0.55 + r * 0.3));

    // A jittered grid: the jitter stops it reading as graph paper, the grid
    // keeps the links between neighbours short without measuring distances.
    Offset node(int c, int r) {
      final seed = c * 3.7 + r * 1.9;
      final drift = ambient * math.pi * 2 + seed;
      final out = reach(c, r);
      return Offset(
        cellW * (c + 0.5 + 0.3 * math.sin(seed * 2.1) * out) +
            math.sin(drift) * 3,
        cellH * (r + 0.5 + 0.3 * math.cos(seed * 1.7) * out) +
            math.cos(drift * 0.8) * 2.5,
      );
    }

    final wire = Paint()
      ..color = colors.accent.withValues(alpha: 0.20)
      ..strokeWidth = 1.2;
    final cell = Paint()..color = colors.accent.withValues(alpha: 0.34);

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final here = node(c, r);

        // Only right and down, so every link is drawn exactly once.
        if (c < cols - 1) canvas.drawLine(here, node(c + 1, r), wire);
        if (r < rows - 1) canvas.drawLine(here, node(c, r + 1), wire);
        // One diagonal in four, so the mesh is not a lattice.
        if (c < cols - 1 && r < rows - 1 && (c + r).isEven) {
          canvas.drawLine(here, node(c + 1, r + 1), wire);
        }

        // The nodes swell with the same breath, so the whole field reads as
        // one thing rather than dots on moving strings.
        final swell = 2.1 + 0.8 * (reach(c, r) - 1);
        canvas.drawCircle(
          here,
          swell + 2.4,
          Paint()..color = colors.accent.withValues(alpha: 0.09),
        );
        canvas.drawCircle(here, swell, cell);

        // Every so often one of them fires down a link — the background is
        // never still, but never busy enough to compete with the path.
        if ((c * 3 + r) % 7 == 0 && r < rows - 1) {
          final t = (ambient * 2 + (c * 0.31 + r * 0.17)) % 1.0;
          canvas.drawCircle(
            Offset.lerp(here, node(c, r + 1), t)!,
            1.6,
            Paint()..color = colors.accent.withValues(alpha: 0.4),
          );
        }
      }
    }
  }

  /// The green the neuron glows, brighter than the accent: this is the one
  /// moment on the page that is meant to look electric.
  static const Color _charge = Color(0xFF3DDC84);

  double _radiusOf(int day) => kMilestones.contains(day) ? 34.0 : 20.0;

  /// The stop the signal leaves from, discharging.
  ///
  /// A flash at the moment it fires that drains away over the first part of
  /// the journey — the cell giving up its charge to the fibre.
  void _paintFiring(Canvas canvas, Offset at, int day, double travel) {
    final left = (1 - travel / 0.35).clamp(0.0, 1.0);
    if (left <= 0) return;
    final r = _radiusOf(day);
    canvas.drawCircle(
      at,
      r + 14 * left,
      Paint()
        ..color = _charge.withValues(alpha: 0.45 * left)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawCircle(
      at,
      r + 3,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = _charge.withValues(alpha: 0.9 * left),
    );
  }

  /// The stop the signal is heading for, waiting to receive it.
  ///
  /// Quiet on purpose: a single faint ring that tightens as the impulse gets
  /// closer. The loud part is saved for when it lands.
  void _paintExpecting(Canvas canvas, Offset at, int day, double travel) {
    final r = _radiusOf(day);
    final near = Curves.easeIn.transform(travel);
    canvas.drawCircle(
      at,
      r + 18 - 12 * near,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 + 1.3 * near
        ..color = _charge.withValues(alpha: 0.18 + 0.5 * near),
    );
  }

  /// The stop that received the signal, depolarising.
  ///
  /// A burst of green behind the stop, three rings going out a beat apart,
  /// and eight short sparks along its dendrites — then all of it fading, and
  /// the stop is just a stop you have reached. The flash is front-loaded so
  /// it lands on the same beat as the click; the rings are what linger.
  void _paintWaking(Canvas canvas, Offset at, int day, double wake) {
    final r = _radiusOf(day);

    // The flash.
    final flash = math.pow(1 - wake, 2).toDouble();
    if (flash > 0.01) {
      canvas.drawCircle(
        at,
        r + 26 * flash + 8,
        Paint()
          ..color = _charge.withValues(alpha: 0.55 * flash)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
      );
      canvas.drawCircle(
        at,
        r * 0.6,
        Paint()..color = Colors.white.withValues(alpha: 0.7 * flash),
      );
    }

    // The rings, going out one after another.
    for (var i = 0; i < 3; i++) {
      final t = ((wake - i * 0.14) / 0.72).clamp(0.0, 1.0);
      if (t <= 0 || t >= 1) continue;
      final eased = Curves.easeOutCubic.transform(t);
      canvas.drawCircle(
        at,
        r + 4 + eased * 58,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2 * (1 - eased) + 0.5
          ..color = _charge.withValues(alpha: 0.8 * (1 - eased)),
      );
    }

    // The dendrites: short sparks thrown out from the rim and fading.
    final spark = (wake / 0.55).clamp(0.0, 1.0);
    if (spark < 1) {
      final reach = Curves.easeOutCubic.transform(spark);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.2
        ..color = _charge.withValues(alpha: 0.9 * (1 - spark));
      for (var k = 0; k < 8; k++) {
        // Staggered off the compass points, so it reads as branching rather
        // than as a sun.
        final angle = k * math.pi / 4 + 0.35;
        final dir = Offset(math.cos(angle), math.sin(angle));
        final inner = r + 6 + 20 * reach;
        final outer = inner + 10 * (1 - spark) + 4;
        canvas.drawLine(at + dir * inner, at + dir * outer, paint);
      }
    }

    // And a rim that stays a little longer than the rest, so the stop is
    // still visibly the one that just woke when the burst has gone.
    final rim = (1 - wake).clamp(0.0, 1.0);
    canvas.drawCircle(
      at,
      r + 3,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = _charge.withValues(alpha: 0.9 * rim),
    );
  }

  /// The link from day [i] to the next, as its own curve: through both
  /// stops exactly, leaving and arriving along the line of their neighbours
  /// so that, link after link, the route still flows as one.
  ///
  /// The route used to be one long curve that used each stop as a pull
  /// rather than passing through it, and the arrows drawn along it landed
  /// beside the days they were meant to point at.
  ui.PathMetric _link(List<Offset> stops, int i) {
    Offset bend(int j) {
      final prev = stops[math.max(0, j - 1)];
      final next = stops[math.min(stops.length - 1, j + 1)];
      return (next - prev) / 2;
    }

    final p0 = stops[i];
    final p3 = stops[i + 1];
    final c1 = p0 + bend(i) / 3;
    final c2 = p3 - bend(i + 1) / 3;
    return (Path()
          ..moveTo(p0.dx, p0.dy)
          ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p3.dx, p3.dy))
        .computeMetrics()
        .first;
  }

  /// Room left round a stop by an arrow leaving it, and by one arriving.
  /// A milestone is bigger, glows, and wears its ribbon on top — and the
  /// route climbs, so the arrow leaving one sets off from under that ribbon.
  double _leave(int i) => kMilestones.contains(i + 1) ? 50.0 : 26.0;
  double _arrive(int i) => kMilestones.contains(i + 1) ? 44.0 : 25.0;

  /// The fibre conducting: the stretch the signal has covered, lit green, and
  /// the impulse itself at the leading edge.
  ///
  /// Drawn over the arrows rather than instead of them. The bright glow is
  /// the signal passing; what it leaves behind is the pathway — green for
  /// good — so once the far stop has woken the glow fades into the green
  /// arrow under it rather than into anything else.
  void _paintConduction(Canvas canvas, List<ui.PathMetric> links) {
    final from = firedFrom;
    final to = target;
    if (from == null || to == null || to <= from) return;

    // Full strength while it travels, fading through the wake.
    final wake = energise;
    final strength = wake == null ? 1.0 : (1 - wake).clamp(0.0, 1.0);
    if (strength <= 0) return;

    // How far along, in stops, from the stop it fired from.
    final along = ((done - 1) - (from - 1)).clamp(0.0, (to - from).toDouble());
    if (along <= 0) return;

    Offset? head;
    for (var i = from - 1; i < to - 1 && i < links.length; i++) {
      final covered = (along - (i - (from - 1))).clamp(0.0, 1.0);
      if (covered <= 0) break;
      final link = links[i];
      final lit = link.extractPath(0, link.length * covered);
      canvas.drawPath(
        lit,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 16
          ..color = _charge.withValues(alpha: 0.35 * strength)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawPath(
        lit,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 5
          ..color = _charge.withValues(alpha: 0.95 * strength),
      );
      head = link.getTangentForOffset(link.length * covered)?.position;
      // A short tail of sparks behind the leading edge, so it reads as
      // moving even in a still.
      if (signal != null && covered < 1) {
        for (var k = 1; k <= 4; k++) {
          final back = link.getTangentForOffset(
            math.max(0, link.length * covered - k * 9),
          );
          if (back == null) continue;
          canvas.drawCircle(
            back.position,
            4.5 - k * 0.8,
            Paint()..color = Colors.white.withValues(alpha: 0.5 - k * 0.1),
          );
        }
      }
    }

    // The impulse: only while it is on its way.
    final at = head;
    if (signal == null || at == null) return;
    canvas.drawCircle(
      at,
      18,
      Paint()
        ..color = _charge.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawCircle(at, 6.5, Paint()..color = Colors.white);
    canvas.drawCircle(
      at,
      6.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _charge,
    );
  }

  // ---- the pathway --------------------------------------------------------

  /// The route, as a nerve fibre: one arrow per day, node to node.
  ///
  /// Every link is a whole arrow — a shaft from the edge of one day to the
  /// edge of the next, and a head pointing into it. Walked links are the
  /// sheathed green tube with a solid head, thickening the further you have
  /// come, because that is what repetition does to a pathway. Links ahead
  /// are an even dashed shaft with an open head, and the one leading on from
  /// where you stand flows towards the day ahead. Signals run up the walked
  /// part continuously: the habit firing on its own.
  void _paintPathway(Canvas canvas, Size size, List<Offset> stops) {
    final links = [for (var i = 0; i < kPathLength - 1; i++) _link(stops, i)];

    // How far the tube has got, in links, drawn in on arrival.
    final walked = (done - 1).clamp(0.0, kPathLength - 1.0) * intro;
    final show = intro.clamp(0.0, 1.0);

    for (var i = 0; i < links.length; i++) {
      final link = links[i];
      final from = _leave(i);
      final to = link.length - _arrive(i + 1);
      if (to - from < 18) continue;
      final width = 6 + 6 * i / (kPathLength - 1);

      if (walked >= i + 1) {
        _walkedArrow(canvas, link, from, to, width);
      } else if (walked > i) {
        // Partway, while the once-a-day climb is running: the tube as far as
        // it has got, and the rest of the link still dashed ahead of it.
        final reach = from + (to - from) * (walked - i);
        if (reach - from > 2) {
          _tube(canvas, link.extractPath(from, reach), width);
        }
        if (to - reach > 18) {
          _aheadArrow(canvas, link, reach, to, flowing: true, fade: show);
        }
      } else {
        _aheadArrow(canvas, link, from, to, flowing: i == here - 1, fade: show);
      }
    }

    // ---- the once-a-day impulse, conducting -------------------------------
    _paintConduction(canvas, links);

    // ---- the signal, hopping stop to stop ---------------------------------
    //
    // It jumps from day to day rather than sliding along, which is both what
    // a myelinated fibre actually does and far more legible than a smooth
    // comet: you see it arrive at each day. Whole stops only — a signal runs
    // between days, and half a hop is not a destination.
    final hops = (done - 1).clamp(0.0, kPathLength - 1.0).floor();
    if (hops <= 0) return;

    for (var p = 0; p < 2; p++) {
      final phase = (ambient * 2.4 + p * 0.5) % 1.0;
      final pos = phase * hops;
      final k = pos.floor().clamp(0, hops - 1);
      final f = Curves.easeInOutCubic.transform((pos - k).clamp(0.0, 1.0));

      final link = links[k];
      final at = link.getTangentForOffset(link.length * f)?.position;
      if (at == null) continue;

      // Brightest mid-hop, fading as it settles into the next stop.
      final travelling = math.sin(f * math.pi);
      canvas.drawCircle(
        at,
        8,
        Paint()..color = Colors.white.withValues(alpha: 0.20 * travelling),
      );
      canvas.drawCircle(
        at,
        3.2,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.55 + 0.45 * travelling),
      );
    }
  }

  /// A stretch of the sheathed tube: shadow, the shaded side, the face, and a
  /// thin lit edge. The route runs mostly up the page, so the light comes
  /// from the side — a highlight offset upwards would only show at the ends.
  void _tube(Canvas canvas, Path piece, double width) {
    Paint pen(Color c, double w) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(
      piece.shift(const Offset(1, 3)),
      pen(Colors.black.withValues(alpha: 0.10), width)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(piece.shift(const Offset(2.2, 0)), pen(kFiredEdge, width));
    canvas.drawPath(piece, pen(kFiredFace, width));
    canvas.drawPath(
      piece.shift(Offset(-width * 0.2, 0)),
      pen(kFiredLit.withValues(alpha: 0.7), width * 0.3),
    );
  }

  /// A walked link: the tube, and a solid head pointing into the next day.
  void _walkedArrow(
    Canvas canvas,
    ui.PathMetric metric,
    double from,
    double to,
    double width,
  ) {
    final head = 11 + width * 0.6;
    _tube(canvas, metric.extractPath(from, to - head * 0.75), width);

    final tip = metric.getTangentForOffset(to);
    if (tip == null) return;
    final dir = tip.vector;
    final side = Offset(-dir.dy, dir.dx);
    final base = tip.position - dir * head;
    final spread = width * 0.55 + 5;
    final arrow = Path()
      ..moveTo(tip.position.dx, tip.position.dy)
      ..lineTo((base + side * spread).dx, (base + side * spread).dy)
      ..quadraticBezierTo(
        (base + dir * (head * 0.22)).dx,
        (base + dir * (head * 0.22)).dy,
        (base - side * spread).dx,
        (base - side * spread).dy,
      )
      ..close();

    canvas.drawPath(
      arrow.shift(const Offset(1, 3)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(
      arrow.shift(const Offset(1.6, 0)),
      Paint()..color = kFiredEdge,
    );
    canvas.drawPath(arrow, Paint()..color = kFiredFace);
    canvas.drawPath(
      arrow,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeJoin = StrokeJoin.round
        ..color = kFiredLit.withValues(alpha: 0.55),
    );
  }

  /// A link still ahead: an even dashed shaft and an open head. [flowing]
  /// runs the dashes towards the next day, for the link you are about to
  /// walk.
  void _aheadArrow(
    Canvas canvas,
    ui.PathMetric metric,
    double from,
    double to, {
    required bool flowing,
    required double fade,
  }) {
    const dash = 7.0;
    const gap = 6.0;
    const head = 10.0;
    final colour = flowing
        ? kFiredFace.withValues(alpha: 0.9 * fade)
        : kTrackFace.withValues(alpha: 0.55 * fade);
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = flowing ? 3.4 : 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = colour;

    // Spread evenly over this link's own length, so no link has a stub of a
    // dash at one end and a gap at the other.
    final shaftEnd = to - head * 0.5;
    final room = shaftEnd - from;
    if (room > dash) {
      final count = math.max(1, ((room + gap) / (dash + gap)).floor());
      final step = (room + gap) / count;
      final length = step - gap;
      // About one step every 0.8s, towards the day ahead.
      final shift = flowing ? ((ambient * 15) % 1.0) * step : 0.0;
      for (var k = -1; k < count; k++) {
        final start = from + k * step + shift;
        final a = math.max(start, from);
        final b = math.min(start + length, shaftEnd);
        if (b - a < 1) continue;
        canvas.drawPath(metric.extractPath(a, b), pen);
      }
    }

    // The head: an open chevron on the line's own direction.
    final tip = metric.getTangentForOffset(to);
    if (tip == null) return;
    final angle = math.atan2(tip.vector.dy, tip.vector.dx);
    Offset wing(double turn) =>
        tip.position -
        Offset(math.cos(angle + turn), math.sin(angle + turn)) * head;
    canvas.drawPath(
      Path()
        ..moveTo(wing(0.6).dx, wing(0.6).dy)
        ..lineTo(tip.position.dx, tip.position.dy)
        ..lineTo(wing(-0.6).dx, wing(-0.6).dy),
      pen,
    );
  }

  // ---- the stops ---------------------------------------------------------

  void _paintStop(Canvas canvas, int i, Offset at, Size size) {
    final day = i + 1;
    final walked = day <= done;
    // The stop you are standing on, which is the day the challenge is on —
    // not the one after the last you finished. Those are the same number for
    // most of the challenge and differ on exactly the day somebody is most
    // likely to be looking: the first, where nothing is done yet and marking
    // day two as "here" reads as having skipped the start.
    final isNext = day == here;
    final milestone = kMilestones.contains(day);

    // Popped in from the bottom up, staggered, as the trail draws.
    final appear = ((intro - i / kPathLength * 0.55) / 0.45).clamp(0.0, 1.0);
    if (appear <= 0) return;

    // A milestone stop is half again as big: the end of a week should be
    // visibly a bigger thing than the days that led to it.
    final radius = (milestone ? 34.0 : 20.0) * appear;

    if (milestone) {
      // A halo, so it reads as an arrival rather than a large dot.
      canvas.drawCircle(
        at,
        radius + 9,
        Paint()..color = colors.accent.withValues(alpha: walked ? 0.16 : 0.07),
      );
    }

    // The ring around the stop you are heading for, breathing.
    if (isNext) {
      final pulse = 0.5 + 0.5 * math.sin(ambient * math.pi * 6);
      canvas.drawCircle(
        at,
        radius + 8 + 5 * pulse,
        Paint()
          ..color = colors.accent.withValues(alpha: 0.30 * (1 - pulse * 0.5))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4,
      );
    }

    // The end of a week is a medal rather than a stop, earned or not: a reward
    // you cannot see is not one anybody is working towards.
    if (milestone) {
      _paintMedal(canvas, at, day, radius, walked);
      return;
    }

    if (walked) {
      // Its own colour, in the order the glyphs run.
      final hue = kBeatColours[(day - 1) % kDaysPerWeek];
      _paintDisc(canvas, at, radius, hue, Color.lerp(hue, Colors.black, 0.38)!);
      // Cast down a little before it is drawn in white: a flat white glyph on
      // a saturated face reads as a sticker, and this is what gives it edges.
      _paintGlyph(
        canvas,
        at.translate(0, radius * 0.07),
        day,
        radius,
        Colors.black.withValues(alpha: 0.17),
      );
      _paintGlyph(canvas, at, day, radius, Colors.white);
    } else {
      _paintDisc(
        canvas,
        at,
        radius,
        colors.surface,
        isNext ? colors.accent : colors.accentTrack,
        lit: false,
      );
      _paintNumber(canvas, at, '$day', isNext, radius);
    }
  }

  /// A disc with some thickness to it.
  ///
  /// A dark seat showing as a crescent along the bottom, a face lit from the
  /// top left, and one streak across it. The same treatment for a day and for
  /// a medal, so the path reads as one set of objects rather than two kinds of
  /// drawing — and so a flat green dot is no longer what a kept day looks
  /// like.
  void _paintDisc(
    Canvas canvas,
    Offset at,
    double r,
    Color face,
    Color edge, {
    bool lit = true,
  }) {
    canvas.drawCircle(
      at.translate(0, r * 0.2),
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: lit ? 0.15 : 0.07)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5),
    );

    // The seat. Same disc, edge colour, nudged down — which is the whole
    // trick: the face then looks like a cap on top of something rather than
    // a circle printed on the page.
    canvas.drawCircle(at.translate(0, r * 0.13), r, Paint()..color = edge);

    canvas.drawCircle(
      at,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          at.translate(-r * 0.36, -r * 0.42),
          r * 1.6,
          [
            Color.lerp(face, Colors.white, lit ? 0.5 : 0.2)!,
            face,
            Color.lerp(face, edge, 0.55)!,
          ],
          [0.0, 0.46, 1.0],
        ),
    );

    if (!lit) return;

    // Hard-edged on purpose. A soft gradient here just looked like fog.
    canvas.save();
    canvas.translate(at.dx - r * 0.3, at.dy - r * 0.48);
    canvas.rotate(-0.55);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: r * 0.9, height: r * 0.32),
      Paint()..color = Colors.white.withValues(alpha: 0.4),
    );
    canvas.restore();
  }

  /// What a kept day is worth, at the days that are not a milestone.
  ///
  /// A tick on all eighteen of them said the same thing eighteen times over.
  /// These say something a little further along each day and then begin again
  /// the next week: one cell fires, two find each other, three make a circuit,
  /// the mesh holds itself up, it goes off without being asked, and the day
  /// before the medal is a star.
  void _paintGlyph(
    Canvas canvas,
    Offset at,
    int day,
    double radius,
    Color ink,
  ) {
    final s = radius * 0.54;
    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.17
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final solid = Paint()..color = ink;

    Offset polar(double turns, double r) {
      final a = -math.pi / 2 + turns * math.pi * 2;
      return at + Offset(math.cos(a), math.sin(a)) * (s * r);
    }

    Offset at_(double dx, double dy) => at + Offset(dx * s, dy * s);

    switch ((day - 1) % kDaysPerWeek + 1) {
      // One cell, firing for the first time. Eight rays rather than four:
      // four alone made a cross, which reads as a plus sign.
      case 1:
        canvas.drawCircle(at, s * 0.3, solid);
        for (var i = 0; i < 8; i++) {
          final long = i.isEven;
          canvas.drawLine(
            polar(i / 8, 0.55),
            polar(i / 8, long ? 1.05 : 0.82),
            line,
          );
        }

      // Two, wired together.
      case 2:
        final a = at_(-0.62, 0.46);
        final b = at_(0.62, -0.46);
        canvas.drawLine(a, b, line);
        canvas.drawCircle(a, s * 0.30, solid);
        canvas.drawCircle(b, s * 0.30, solid);

      // Three, and it is a circuit rather than a wire.
      case 3:
        final pts = [for (var i = 0; i < 3; i++) polar(i / 3, 0.82)];
        for (var i = 0; i < 3; i++) {
          canvas.drawLine(pts[i], pts[(i + 1) % 3], line);
        }
        for (final p in pts) {
          canvas.drawCircle(p, s * 0.26, solid);
        }

      // Four, and the loop closes: it holds itself up now. No brace across
      // the middle — at this size it only made the shape harder to read.
      case 4:
        final pts = [for (var i = 0; i < 4; i++) polar(i / 4, 0.92)];
        for (var i = 0; i < 4; i++) {
          canvas.drawLine(pts[i], pts[(i + 1) % 4], line);
        }
        for (final p in pts) {
          canvas.drawCircle(p, s * 0.24, solid);
        }

      // It goes off without being asked.
      case 5:
        canvas.drawPath(
          Path()
            ..moveTo(at_(0.16, -1.0).dx, at_(0.16, -1.0).dy)
            ..lineTo(at_(-0.56, 0.12).dx, at_(-0.56, 0.12).dy)
            ..lineTo(at_(-0.06, 0.12).dx, at_(-0.06, 0.12).dy)
            ..lineTo(at_(-0.2, 1.0).dx, at_(-0.2, 1.0).dy)
            ..lineTo(at_(0.56, -0.16).dx, at_(0.56, -0.16).dy)
            ..lineTo(at_(0.06, -0.16).dx, at_(0.06, -0.16).dy)
            ..close(),
          solid,
        );

      // The day before the medal.
      default:
        final star = Path();
        for (var i = 0; i < 10; i++) {
          final p = polar(i / 10, i.isEven ? 1.0 : 0.45);
          if (i == 0) {
            star.moveTo(p.dx, p.dy);
          } else {
            star.lineTo(p.dx, p.dy);
          }
        }
        canvas.drawPath(star..close(), solid);
    }
  }

  /// The medal at the end of a week, on its ribbon.
  ///
  /// Drawn locked as well as earned, with the day engraved on the face — so
  /// the stop still says which day it is, and the ones ahead of you still say
  /// what they are worth.
  void _paintMedal(
    Canvas canvas,
    Offset at,
    int day,
    double radius,
    bool earned,
  ) {
    final week = day ~/ kDaysPerWeek - 1;

    // Locked is a washed-out version of the real thing rather than a blank
    // disc — the same treatment the characters beside the path get. A medal
    // you cannot make out is not a medal you are working towards, and left
    // plain it was indistinguishable from an ordinary day that happened to
    // be drawn a bit larger.
    Color ghost(Color c, double amount) =>
        earned ? c : Color.lerp(c, colors.surface, amount)!;

    final face = ghost(kMedalFace[week], 0.72);
    final edge = ghost(kMedalEdge[week], 0.5);

    final discR = radius * 0.68;
    final centre = at + Offset(0, radius * 0.26);
    final top = at.dy - radius * 0.98;

    // Two bands crossing behind the disc, which is all of a ribbon that shows.
    final ribbon = Paint()..color = ghost(kMedalRibbon[week], 0.62);
    for (final dir in [-1.0, 1.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(at.dx + dir * radius * 0.58, top)
          ..lineTo(at.dx + dir * radius * 0.22, top)
          ..lineTo(centre.dx - dir * radius * 0.16, centre.dy)
          ..lineTo(centre.dx - dir * radius * 0.46, centre.dy)
          ..close(),
        ribbon,
      );
    }

    _paintDisc(canvas, centre, discR, face, edge, lit: earned);

    canvas.drawCircle(
      centre,
      discR,
      Paint()
        ..color = edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.085,
    );
    // An inner ring, the way a struck medal has a raised border.
    canvas.drawCircle(
      centre,
      discR * 0.78,
      Paint()
        ..color = edge.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.05,
    );

    final engraved = TextPainter(
      text: TextSpan(
        text: '$day',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: discR * 0.76,
          fontWeight: FontWeight.w700,
          color: earned
              ? Color.lerp(kMedalEdge[week], Colors.black, 0.42)!
              : colors.textMuted,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    engraved.paint(
      canvas,
      centre - Offset(engraved.width / 2, engraved.height / 2),
    );
  }

  void _paintNumber(
    Canvas canvas,
    Offset at,
    String text,
    bool isNext,
    double radius,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: radius * 0.78,
          fontWeight: FontWeight.w600,
          color: isNext ? colors.primary : colors.textMuted,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(_PathPainter old) =>
      old.signal != signal ||
      old.energise != energise ||
      old.target != target ||
      old.here != here ||
      old.done != done ||
      old.intro != intro ||
      old.ambient != ambient;
}
