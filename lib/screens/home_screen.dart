import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../content/app_content.dart';
import '../models/day_phase.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';
import '../models/progress_range.dart';
import '../notifications/path_sound.dart';
import '../state/app_state.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/completion_effects.dart';
import '../widgets/day_complete_overlay.dart';
import '../widgets/script_note.dart';
import '../widgets/habit_row.dart';
import '../widgets/empty_state.dart';
import '../widgets/illustrations.dart';
import '../widgets/k_card.dart';
import '../widgets/quote_carousel.dart';
import 'habit_actions_sheet.dart';
import 'habit_detail_screen.dart';
import 'challenge_rules_screen.dart';
import 'roadmap_screen.dart';
import 'journal_editor_screen.dart';
import 'journal_screen.dart';
import '../widgets/journal_widgets.dart';
import '../widgets/premium_gate.dart';
import '../content/premium_content.dart';

/// Opens the challenge, by way of its rules the first time.
///
/// The rules matter here in a way they usually do not: the run resets to
/// nothing on a missed day, and somebody who found that out by having it
/// happen would reasonably feel the app had moved the goalposts. Once read,
/// the path opens directly and the rules stay reachable from its app bar.
Future<void> openChallenge(BuildContext context) {
  // Paid for, so the door is here rather than inside the path: the rules
  // screen and the walk both open from more than one place.
  return ifPremium(context, PremiumContent.lockedChallenge, () {
    if (context.read<AppState>().needsChallengeRules) {
      return ChallengeRulesScreen.open(context);
    }
    return RoadmapScreen.open(context);
  });
}

/// Stand the animated brain next to the tree on the Home header.
///
/// Set to false and it is just the tree again, with nothing else to undo.
const bool kBrainHero = true;

/// How long one clip runs, in milliseconds.
///
/// Every one of them was cut at the same frame rate and the same length, which
/// is what lets a scene be held for exactly one play of itself. The number
/// matters: hold a 5.9-second clip for seven seconds and the last second of
/// the scene is the first second of it over again.
const int kClipMillis = 5900;

/// How far the character's feet sit above the bottom of the header.
///
/// Low. It used to stand higher, which put the bubble over its head straight
/// through the sun — the sun's disc reaches about a third of the way down the
/// header, and the character plus its bubble is most of the height. Dropping
/// the whole figure is what buys the bubble clear sky.
const double kHeroFoot = 13;

/// The fade from one scene to the next.
const Duration kSceneFade = Duration(milliseconds: 420);

/// How far ahead the next clip is decoded, so the fade has something to
/// fade to rather than a hole.
const int kWarmupMillis = 700;

/// One beat of the header: the character somewhere, doing one thing.
class HeroScene {
  const HeroScene(
    this.label,
    this.asset, {
    required this.says,
    this.left,
    this.crosses = false,
    this.millis = kClipMillis,
    this.frame = 1.0,
  });

  /// Names the scene. Not shown anywhere — it is what the cross-fade keys
  /// off, and what makes this list readable.
  final String label;

  /// The clip — the right-facing one, where the scene crosses the ground.
  final String asset;

  /// The return leg, where a second clip was drawn for it. Without one the
  /// way back is [asset] mirrored, which is why the jogger needed only a
  /// single clip and the stroll needed two.
  final String? left;

  /// What it says while it is on, one line picked each time the scene comes
  /// round. Several per scene rather than one: the run loops, and a character
  /// that says the same word every three minutes stops being a character.
  ///
  /// Short. The bubble sits in the gap between the quote and the tree, and
  /// anything longer than about five words wraps into the tree.
  final List<String> says;

  /// Walks the strip of ground rather than standing on it.
  final bool crosses;

  /// How long the beat lasts: exactly one play of [asset], so nothing in a
  /// scene is ever shown twice. A crossing scene walks one length of the
  /// strip per clip, so its beat is two of them — out and back.
  final int millis;

  /// How tall the clip is against the character in it. 1 for a clip that is
  /// all character; the towel clip has the shower above him and is a third
  /// taller again, and is drawn that much bigger so he is not smaller.
  final double frame;
}

/// The day as three short runs of scenes rather than a clock.
///
/// An earlier version hung one scene on each hour, which meant that at any
/// moment you saw exactly one of them and the rest of the morning was
/// something you had to take on trust. These play in order instead: every
/// scene of the phase you are actually in, one after the next, on a loop.
const Map<DayPhase, List<HeroScene>> kHeroScenes = {
  DayPhase.earlyMorning: [
    HeroScene(
      'Waking up',
      'assets/anim/wake.webp',
      says: ['Rise and rewire!', 'New day, new reps.', 'Up. Let\'s go.'],
    ),
    HeroScene(
      'Toothbrush',
      'assets/anim/brush.webp',
      says: ['Tiny habit, daily.', 'Two minutes counts.', 'Small wins, early.'],
    ),
    HeroScene(
      'Towel',
      'assets/anim/towel.webp',
      says: ['Fresh start!', 'Clean slate today.', 'Ready for habits.'],
      frame: 1.325,
    ),
    // Machine then cup, in one clip: split in two it stood at the machine
    // for an hour before anybody drank anything. Two clips joined, so it
    // runs for two clips' worth.
    HeroScene(
      'Coffee',
      'assets/anim/coffee.webp',
      says: ['Sip, then tick.', 'Fuelled for habits.', 'First habit next?'],
      millis: kClipMillis * 2,
    ),
  ],
  DayPhase.day: [
    // The day opens in a good mood, which is rather the point of the app.
    HeroScene(
      'Feeling it',
      'assets/anim/heart.webp',
      says: ['Proud of you!', 'Keep it glowing.', 'We\'ve got this.'],
    ),
    HeroScene(
      'Lunch',
      'assets/anim/lunch.webp',
      says: ['Refuel, then repeat.', 'Recharging…', 'Break, then back.'],
    ),
    // The afternoon: head down. Also the one scene that says anything about
    // the work the habits are being built for.
    HeroScene(
      'Focused',
      'assets/anim/focus.webp',
      says: ['Focus is a habit.', 'One page at a time.', 'Deep work mode.'],
    ),
    HeroScene(
      'Jogging',
      'assets/anim/jog.webp',
      says: ['Every step counts!', 'Keep moving!', 'Rewiring on the run.'],
      crosses: true,
      millis: kClipMillis * 2,
    ),
  ],
  DayPhase.night: [
    // The same meal clip stands in for both sittings: one arrived twice.
    HeroScene(
      'Dinner',
      'assets/anim/lunch.webp',
      says: ['Eat well, rest well.', 'Refuelled!', 'Good food, good day.'],
    ),
    // A walk after dinner, which is where a stroll belongs — in the middle of
    // the afternoon it was just something to fill the gap between meals.
    HeroScene(
      'Walking',
      'assets/anim/hero_walk_right.webp',
      says: ['A walk counts too.', 'Evening lap!', 'Clearing my head.'],
      left: 'assets/anim/hero_walk_left.webp',
      crosses: true,
      millis: kClipMillis * 2,
    ),
    HeroScene(
      'Yawning',
      'assets/anim/hero_night.webp',
      says: ['Any ticks left?', 'Close the day strong.', 'Winding down…'],
    ),
    HeroScene(
      'Asleep',
      'assets/anim/sleep.webp',
      says: ['Rest rewires too.', 'Zzz… growing.', 'Same again tomorrow.'],
    ),
  ],
};

/// The scenes never stop, which means `pumpAndSettle` never settles. Widget
/// tests turn them off, the same way they do the quote carousel's timer.
bool heroWalks = true;

/// Home keeps the greeting, stats and week strip pinned, and scrolls only the
/// habit list. Scrolling the whole page made the header slide away on every
/// small interaction, which read as the app "jumping".
/// What the Home tour points at. Owned by the shell, which runs the tour and
/// also owns the + button and the tabs.
class HomeTourKeys {
  final hero = GlobalKey(debugLabel: 'tour-hero');
  final stats = GlobalKey(debugLabel: 'tour-stats');
  final week = GlobalKey(debugLabel: 'tour-week');
  final habits = GlobalKey(debugLabel: 'tour-habits');
  final journal = GlobalKey(debugLabel: 'tour-journal');
  final add = GlobalKey(debugLabel: 'tour-add');
  final tabs = GlobalKey(debugLabel: 'tour-tabs');
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onOpenCalendar, this.tourKeys});

  /// Where the Home tour finds the parts it explains. Null outside the shell.
  final HomeTourKeys? tourKeys;

  /// Switches to the Calendar tab. The date header is the natural way
  /// into a fuller view of the month, so it opens one.
  final VoidCallback? onOpenCalendar;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// Puts Home's list into arrange mode: drag handles on every row, and the
/// order saved as each one is dropped. Set from a habit's long-press menu.
final ValueNotifier<bool> homeArrangeMode = ValueNotifier<bool>(false);

class _HomeScreenState extends State<HomeScreen> {
  /// The day whose habits are listed. Null means today, and keeps following
  /// today as the date rolls over.
  // The selected day lives on AppState: the add button in the shell below
  // needs it too, so that adding a habit while looking at last Tuesday can
  // say so.

  /// Which of the two lists is showing. Not persisted: building is the one
  /// almost everybody opens the app for, so that is where it starts every
  /// time rather than wherever it was left.
  HabitKind _kind = HabitKind.build;

  /// The day already celebrated, read from the device on first use.
  ///
  /// Held here as well as stored so the common case — rebuilding a finished
  /// day over and over — costs nothing, and read through [_alreadyClosed] so
  /// the first check of a fresh launch consults what was actually saved.
  String? _closedDay;
  bool _closedDayRead = false;

  /// Held so the list can be scrolled to the end when the day closes —
  /// the note lives at the bottom, and it is no use if you are looking at
  /// the top of the list when it appears.
  final ScrollController _listScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    homeArrangeMode.addListener(_onArrange);
  }

  void _onArrange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    homeArrangeMode.removeListener(_onArrange);
    _listScroll.dispose();
    super.dispose();
  }

  /// Moves one habit within the list on screen, and writes the result into
  /// the order of every habit.
  ///
  /// What is on screen is a subset — today's habits, of one kind — so the
  /// moved ones go back into the slots that subset already held in the full
  /// order. Everything off screen keeps its place.
  Future<void> _reorder(List<Habit> shown, int from, int to) async {
    final state = context.read<AppState>();
    // `onReorderItem` gives the final index, after the removal.
    final moved = shown.toList();
    moved.insert(to, moved.removeAt(from));
    final all = state.habits.toList();
    final ids = {for (final h in shown) h.id};
    final slots = [
      for (var i = 0; i < all.length; i++)
        if (ids.contains(all[i].id)) i,
    ];
    for (var i = 0; i < slots.length && i < moved.length; i++) {
      all[slots[i]] = moved[i];
    }
    await state.reorderHabits(all);
  }

  /// Watches the day's completion and reports the moment it becomes whole.
  void _notedCompletion({required bool allDone, required DateTime day}) {
    final key = dayKey(day);
    final state = context.read<AppState>();

    // What the device remembers, on the first check of this launch. Without
    // it a day finished last night is finished-and-unannounced again this
    // morning, and the whole screen is taken over by a party for something
    // that already happened.
    if (!_closedDayRead) {
      _closedDayRead = true;
      _closedDay = state.celebratedDay;
    }

    if (!allDone) {
      // Re-armed as soon as the day is no longer whole, so finishing it again
      // plays again. A moment you cannot re-watch is a moment you cannot
      // check, and toggling the last habit is a rare thing to do anyway.
      if (_closedDay == key) {
        _closedDay = null;
        unawaited(state.setCelebratedDay(null));
      }
      return;
    }
    if (_closedDay == key) return;

    _closedDay = key;
    unawaited(state.setCelebratedDay(key));
    HapticFeedback.mediumImpact();
    _revealDayClosed();

    // The celebration takes over the whole screen, bottom bar included, so it
    // goes through the app's overlay rather than into this page's own stack.
    //
    // The ordinary day streak, which is the number the flame on this very
    // screen shows. The 21-day count belongs to the challenge and stays there.
    showDayComplete(context, streak: state.currentStreak);
    // And a sound to go with it — once a day. Closing the day again after
    // un-ticking something still says "Day closed", but quietly: the check is
    // for finishing the day, not for every time the last box is ticked.
    if (!state.closeSoundPlayedOn(key)) {
      unawaited(state.markCloseSoundPlayed(key));
      unawaited(PathSound.closeDay());
    }
  }

  /// Brings the end of the list into view so the closing note is actually
  /// seen rather than sitting below the fold.
  void _revealDayClosed() {
    // The note is appended by the same rebuild that closed the day, so the
    // extent it adds does not exist until the next layout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_listScroll.hasClients) return;

      final target = _listScroll.position.maxScrollExtent;
      if (target <= _listScroll.offset) return; // already at the end

      if (reduceMotion(context)) {
        _listScroll.jumpTo(target);
      } else {
        _listScroll.animateTo(
          target,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final k = context.k;
    final today = state.today;
    final selected = state.viewedDay;
    final isToday = selected == today;
    final isFuture = selected.isAfter(today);

    final scheduled = state.scheduledOn(selected);
    final done = state.completedCountOn(selected);

    // Checked after the frame so the burst starts once the tick that caused
    // it has been drawn, and only for today — closing out a backfilled
    // Tuesday is not a moment.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notedCompletion(
        allDone: isToday && scheduled.isNotEmpty && done == scheduled.length,
        day: selected,
      );
    });

    final build = scheduled.where((h) => h.kind == HabitKind.build).toList();
    final quit = scheduled.where((h) => h.kind == HabitKind.quit).toList();

    // The switch only appears when there is something on both sides. One tab
    // is not a choice, and a tab bar over a single list is furniture.
    final split = build.isNotEmpty && quit.isNotEmpty;
    final kind = split ? _kind : HabitKind.build;
    final shown = !split ? scheduled : (kind == HabitKind.build ? build : quit);

    // Counted over what is on screen. "3 of 8" across both lists was adding
    // up two different questions — how many things you got to, and how many
    // you stayed under — and the answer meant neither.
    final shownDone = shown.where((h) => state.isComplete(h, selected)).length;
    final arranging = homeArrangeMode.value && shown.length > 1;

    Widget row(Habit habit) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: HabitCheckRow(
        habit: habit,
        day: selected,
        enabled: !isFuture,
        onTap: () =>
            HabitDetailScreen.open(context, habitId: habit.id, day: selected),
        onLongPress: () =>
            HabitActionsSheet.show(context, habit: habit, day: selected),
      ),
    );

    return Column(
      children: [
        // ---- pinned ----
        SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              k.geometry.screenPadding,
              6,
              k.geometry.screenPadding,
              0,
            ),
            child: Column(
              children: [
                KeyedSubtree(key: widget.tourKeys?.hero, child: const _Hero()),
                const SizedBox(height: 10),
                KeyedSubtree(
                  key: widget.tourKeys?.stats,
                  child: _StatLine(state: state),
                ),
                const SizedBox(height: 14),
                _DateHeader(
                  day: selected,
                  isToday: isToday,
                  onTap: widget.onOpenCalendar,
                ),
                const SizedBox(height: 8),
                KeyedSubtree(
                  key: widget.tourKeys?.week,
                  child: _WeekStrip(
                    selected: selected,
                    onSelect: (day) => state.viewDay(day),
                  ),
                ),
                const SizedBox(height: 12),
                // The board used to be a second view here; it lives on the
                // Calendar tab now, and Home is just what is due today.
                if (arranging)
                  _ArrangeBar(onDone: () => homeArrangeMode.value = false)
                else
                  KeyedSubtree(
                    // The tour's "tap the circle" step points at the first
                    // habit when there is one, and at this header otherwise.
                    key: shown.isEmpty ? widget.tourKeys?.habits : null,
                    child: _HabitsHeader(
                      isToday: isToday,
                      done: shownDone,
                      total: shown.length,
                    ),
                  ),
                if (split) ...[
                  const SizedBox(height: 10),
                  _KindSwitch(
                    kind: kind,
                    buildCount: build.length,
                    quitCount: quit.length,
                    onSelect: (k) => setState(() => _kind = k),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        // ---- scrolls ----
        // A fixed gutter between the pinned header and the scrolling
        // list. It used to be the list's own top padding, which scrolls
        // away with the content — leaving the first card flush against
        // the header the moment you moved it.
        SizedBox(height: 8),
        if (arranging)
          Expanded(
            child: ReorderableListView.builder(
              scrollController: _listScroll,
              padding: EdgeInsets.fromLTRB(
                k.geometry.screenPadding,
                0,
                k.geometry.screenPadding,
                16,
              ),
              buildDefaultDragHandles: false,
              itemCount: shown.length,
              onReorderItem: (from, to) {
                if (from != to) _reorder(shown, from, to);
              },
              proxyDecorator: (child, _, animation) => AnimatedBuilder(
                animation: animation,
                builder: (context, _) => Transform.scale(
                  scale: 1 + 0.03 * animation.value,
                  child: Material(
                    color: Colors.transparent,
                    elevation: 10 * animation.value,
                    borderRadius: BorderRadius.circular(k.geometry.cardRadius),
                    shadowColor: Colors.black.withValues(alpha: 0.3),
                    child: child,
                  ),
                ),
              ),
              itemBuilder: (context, i) => Padding(
                key: ValueKey(shown[i].id),
                padding: const EdgeInsets.only(bottom: 10),
                child: _ArrangeRow(habit: shown[i], index: i),
              ),
            ),
          )
        else
          Expanded(
            // The list ends against the check-in strip, so it fades out over
            // the last few pixels rather than stopping mid-card.
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (rect) => LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: const [Color(0x00000000), Color(0xFF000000)],
                stops: [0, 14 / rect.height],
              ).createShader(rect),
              child: ListView(
                controller: _listScroll,
                padding: EdgeInsets.fromLTRB(
                  k.geometry.screenPadding,
                  0,
                  k.geometry.screenPadding,
                  16,
                ),
                children: [
                  if (scheduled.isEmpty)
                    _EmptyDay(isToday: isToday)
                  else ...[
                    KeyedSubtree(
                      key: widget.tourKeys?.habits,
                      child: row(shown.first),
                    ),
                    ...shown.skip(1).map(row),
                  ],
                  // Stays for as long as the day is finished, rather than
                  // vanishing with the leaves — the burst is the moment, this
                  // is the receipt.
                  if (isToday &&
                      scheduled.isNotEmpty &&
                      done == scheduled.length)
                    const _DayClosedNote(),
                ],
              ),
            ),
          ),
        // ---- pinned ----
        // How the day felt, next to what was done in it: one tap on a face is
        // a journal entry. Under the list rather than in it, so it holds its
        // place instead of trailing whichever list is on screen.
        if (!isFuture &&
            !arranging &&
            state.isPremium &&
            state.everyHabit.isNotEmpty)
          Padding(
            // Clear of the add button, which is docked 20 above the bar.
            padding: EdgeInsets.fromLTRB(
              k.geometry.screenPadding,
              2,
              k.geometry.screenPadding,
              24,
            ),
            child: KeyedSubtree(
              key: widget.tourKeys?.journal,
              child: JournalCheckInBar(
                day: selected,
                onOpenJournal: () => JournalScreen.open(context),
                onWrite: (entry) => JournalEditorScreen.open(
                  context,
                  entry: entry,
                  day: selected,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Hero — greeting, quote of the day, tree illustration
// ---------------------------------------------------------------------------

/// Home's header: the day's quotes, sliding, with the tree beside them.
///
/// Nothing sits on top of the scene any more — the bell moved to the tab bar
/// and the avatar went with it — so the tree gets the height back.
class _Hero extends StatefulWidget {
  const _Hero();

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> with SingleTickerProviderStateMixin {
  /// One length of the strip. Rewound at the start of every crossing scene,
  /// so the walk begins at the left end rather than wherever the last one
  /// happened to leave it.
  late final AnimationController _walk = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: kClipMillis),
  );

  /// Which scene of the current phase is on. Held here rather than in
  /// AppState: it is the header's own business and nothing else reads it.
  int _beat = 0;

  /// The run this is partway through. A new phase is a new run, started at
  /// its first scene rather than wherever the last one had got to.
  DayPhase? _phase;

  Timer? _next;
  Timer? _warm;

  /// What it is saying, and whether the bubble is up.
  ///
  /// Chosen once when the scene starts rather than read on every rebuild —
  /// a line that changed as the walker moved would be a flicker, not a
  /// thought.
  final math.Random _tongue = math.Random();
  String? _saying;
  bool _speaking = false;
  Timer? _sayIn;
  Timer? _sayOut;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final phase = context.read<AppState>().activePhase;
    if (phase == _phase) return;
    _phase = phase;
    _beat = 0;
    _enter();
  }

  @override
  void dispose() {
    _next?.cancel();
    _warm?.cancel();
    _sayIn?.cancel();
    _sayOut?.cancel();
    _walk.dispose();
    super.dispose();
  }

  /// Puts a line up a moment after the scene starts and takes it down before
  /// the scene changes, so the bubble never outlives the character saying it.
  void _speak(HeroScene scene, int hold) {
    _sayIn?.cancel();
    _sayOut?.cancel();
    _speaking = false;

    if (scene.says.isEmpty) return;
    // Half the time, a word about the scene; the other half, a word about
    // your day — what is left, the streak, a finished day. A character that
    // only ever talks about its own breakfast is scenery.
    final state = context.read<AppState>();
    final scheduled = state.scheduledOn(state.today);
    final yours = AppContent.heroAboutYou(
      done: scheduled.where((h) => state.isComplete(h, state.today)).length,
      total: scheduled.length,
      streak: state.perfectStreak,
      hasHabits: state.everyHabit.isNotEmpty,
    );
    final pool = yours.isNotEmpty && _tongue.nextBool() ? yours : scene.says;
    _saying = pool[_tongue.nextInt(pool.length)];

    // Not on the first frame: the character should look like it is doing the
    // thing before it comments on it.
    _sayIn = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _speaking = true);
    });
    _sayOut = Timer(Duration(milliseconds: math.max(1200, hold - 700)), () {
      if (mounted) setState(() => _speaking = false);
    });
  }

  List<HeroScene> _playlist() =>
      kHeroScenes[context.read<AppState>().activePhase] ??
      kHeroScenes[DayPhase.day]!;

  /// Starts the scene the beat is on.
  ///
  /// Holds it for exactly one play of its clip, warms the next one up before
  /// the fade, and drops this one from the image cache on the way out.
  void _enter() {
    _next?.cancel();
    _warm?.cancel();

    final list = _playlist();
    final scene = list[_beat % list.length];
    final moving = heroWalks && !reduceMotion(context);

    if (scene.crosses && moving) {
      // One length per play of the walk clip, and always from the left end.
      _walk.duration = Duration(milliseconds: scene.millis ~/ 2);
      _walk.value = 0;
      _walk.repeat(reverse: true);
    } else {
      _walk.stop();
    }

    if (!moving) {
      _speaking = false;
      return;
    }

    // The fade is spent on the tail of this clip rather than added after it.
    // Run the full length and the outgoing clip loops back to its opening
    // while it dissolves — which is the repeat you notice, a second or so of
    // the coffee machine turning up again behind the cup. Handing the fade
    // the last of the clip instead means the next scene opens on its first
    // frame exactly as this one plays its last.
    final hold = math.max(0, scene.millis - kSceneFade.inMilliseconds);

    _speak(scene, hold);

    final next = list[(_beat + 1) % list.length];
    _warm = Timer(
      Duration(milliseconds: math.max(0, hold - kWarmupMillis)),
      () {
        if (!mounted) return;
        // Decoded, but not shown and so not yet playing: the clip is sitting
        // on its first frame by the time the fade reaches it.
        for (final asset in [next.asset, if (next.left != null) next.left!]) {
          unawaited(precacheImage(AssetImage(asset), context));
        }
      },
    );

    _next = Timer(Duration(milliseconds: hold), () {
      if (!mounted) return;
      _release(scene);
      setState(() => _beat++);
      _enter();
    });
  }

  /// Drops a scene's clips from the image cache as it leaves the screen.
  ///
  /// An animated image keeps its playhead in that cache, so a scene coming
  /// round a second time picked up wherever it had stopped — halfway down the
  /// cup, and then round again to the machine that poured it. Evicting is
  /// what makes every scene start on its first frame. The copy still fading
  /// out holds its own listener, so this never blanks the outgoing frame.
  void _release(HeroScene scene) {
    final config = createLocalImageConfiguration(context);
    for (final asset in [scene.asset, if (scene.left != null) scene.left!]) {
      unawaited(AssetImage(asset).evict(configuration: config));
    }
  }

  /// The character standing on the ground clear of the tree.
  ///
  /// The horizon sits at 74% of the scene's height, which is what puts the
  /// feet on that line. A fixed box rather than a fixed width: these scenes
  /// come with furniture — a bed, a coffee machine — so they are all
  /// different shapes, and only their height and their footing should agree.
  Widget _stander(double width, HeroScene spec) {
    return Positioned(
      left: width * 0.68 - 48,
      bottom: kHeroFoot,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Bubble(text: _saying, showing: _speaking),
          SizedBox(
            width: 96,
            height: 58 * spec.frame,
            child: Image.asset(
              spec.asset,
              fit: BoxFit.contain,
              alignment: Alignment.bottomCenter,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ],
      ),
    );
  }

  /// The character crossing the ground between the quote and the tree.
  Widget _walker(double width, HeroScene spec) {
    const height = 42.0;
    // The strip it has to itself. The left end clears the quote even on its
    // longest three-line day; the right end stops short of the canopy.
    final from = width * 0.57;
    final to = width * 0.72;

    return AnimatedBuilder(
      animation: _walk,
      builder: (context, _) {
        // Linear on purpose. Easing into the turns made it slow to a halt at
        // each end while the cycle kept playing, so it looked like it was
        // running on the spot. A constant pace matches a constant stride, and
        // the turn then reads as a turn.
        final goingRight = _walk.status != AnimationStatus.reverse;
        Widget frame = Image.asset(
          goingRight ? spec.asset : (spec.left ?? spec.asset),
          height: height,
          fit: BoxFit.contain,
          alignment: Alignment.bottomCenter,
          filterQuality: FilterQuality.medium,
        );

        // With only one clip, the way back is the same clip flipped.
        if (!goingRight && spec.left == null) {
          frame = Transform.flip(flipX: true, child: frame);
        }

        return Positioned(
          left: from + (to - from) * _walk.value,
          // No bounce added here: the clip already has its own, and stacking
          // a second one on top gives it a limp.
          bottom: kHeroFoot,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Travels with it. Pinned to the header instead, it read as a
              // caption on the page the moment the character walked out from
              // under it.
              _Bubble(text: _saying, showing: _speaking),
              frame,
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final phase = context.select<AppState, DayPhase>((s) => s.activePhase);

    // Wherever this phase's run has got to. The beat counts on past the end
    // of the list and wraps here, so changing phase mid-run is always in
    // range — the new phase simply picks up at its own scene.
    final list = kHeroScenes[phase] ?? kHeroScenes[DayPhase.day]!;
    final scene = kBrainHero ? list[_beat % list.length] : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SizedBox(
          height: 132,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: -k.geometry.screenPadding,
                right: -k.geometry.screenPadding,
                bottom: 0,
                // Pushed to the right to open a patch of ground between the
                // quote and the trunk for the character to stand on.
                child: TreeScene(height: 128, treeX: 0.90, phase: phase),
              ),
              // The character gets a layer to itself so that one scene can
              // dissolve into the next. Cutting between them was the one place
              // the header ever looked like a slideshow — and standing and
              // crossing scenes have to fade into each other too, which is why
              // they share this layer rather than sitting side by side in the
              // Stack.
              if (scene != null)
                Positioned.fill(
                  child: AnimatedSwitcher(
                    duration: reduceMotion(context)
                        ? Duration.zero
                        : kSceneFade,
                    child: Stack(
                      key: ValueKey(scene.label),
                      clipBehavior: Clip.none,
                      children: [
                        if (scene.crosses)
                          _walker(width, scene)
                        else
                          _stander(width, scene),
                      ],
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                top: 4,
                width: width * 0.56,
                // Keyed on the phase: the carousel takes the pool for the
                // hour once, so crossing into the evening has to build a new
                // one rather than leave the old one pointing at morning.
                child: QuoteCarousel(key: ValueKey(phase), phase: phase),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// What the character is thinking, over its head.
///
/// Always laid out, even with nothing to say, so the figure does not hop up
/// and down the page as lines come and go — only the bubble's opacity changes.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.showing});

  final String? text;
  final bool showing;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    // No width of its own in the layout. Given one, a bubble wider than the
    // character would widen the column it shares with it and shunt the
    // character sideways — visibly, since the bubble comes and goes.
    return SizedBox(
      height: 28,
      width: 0,
      child: OverflowBox(
        minWidth: 0,
        // Narrow on purpose: this has to pass under the sun on one side and
        // the moon on the other, and every point of width is a point closer
        // to one of them.
        maxWidth: 104,
        alignment: Alignment.bottomCenter,
        child: AnimatedOpacity(
          opacity: showing && text != null ? 1 : 0,
          duration: const Duration(milliseconds: 260),
          child: Container(
            padding: const EdgeInsets.fromLTRB(9, 4, 9, 5),
            margin: const EdgeInsets.only(bottom: 3),
            decoration: BoxDecoration(
              // Opaque, and outlined. Drawn in the surface tint at a low
              // border weight it disappeared into the morning sky, which is
              // very nearly the same colour.
              color: k.colors.surface,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: k.colors.accent.withValues(alpha: 0.55),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: k.colors.textPrimary.withValues(alpha: 0.16),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              text ?? '',
              maxLines: 1,
              // Never dots. Every line it can say is short enough to fit the
              // 132 points this is allowed, so an ellipsis here would only
              // ever be the sign of a line that should have been rewritten.
              overflow: TextOverflow.clip,
              textAlign: TextAlign.center,
              style: k.text.captionStrong.copyWith(
                fontSize: 10.5,
                height: 1.1,
                color: k.colors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stat strip
// ---------------------------------------------------------------------------

/// Where you are, as a single line of text.
///
/// Deliberately not cards: the boxed version read as a row of white buttons
/// and people tried to tap it. Plain text with hairline separators reads as
/// information, and costs a fifth of the height.
///
/// Two figures, not four. It used to carry a completion rate labelled only
/// "so far" and a week-on-week delta beside it, and neither said which window
/// it covered — the rate in particular counts a habit only on days its target
/// was met, so a fortnight of part-days reads 0% here and as a field of
/// mid-tone colour on the board directly underneath. Both were right; side by
/// side they read as a contradiction. Rates live on Progress now, next to the
/// range picker that says what period they cover.
class _StatLine extends StatelessWidget {
  const _StatLine({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final week = state.statsFor(ProgressRange.week);

    return CustomPaint(
      painter: _SunlitBandPainter(
        base: k.colors.statBand,
        glow: k.colors.star,
        radius: k.geometry.innerRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Row(
          children: [
            _Stat(
              icon: Icons.local_fire_department,
              iconColor: k.colors.flame,
              value: '${state.currentStreak}',
              label: AppContent.statStreak,
            ),
            _Sep(),
            _Stat(
              icon: Icons.workspace_premium,
              iconColor: k.colors.star,
              value: '${week.perfectDays}',
              label: AppContent.statPerfectThisWeek,
            ),

            // Only while the challenge is actually running, and drawn as a
            // badge rather than a third statistic: it is the one thing on this
            // strip that is a *state* — something is running — where the other
            // two are numbers. As a third number with a hairline beside it, it
            // read as another tally and the row's spacing came out lopsided,
            // because two of the three entries were text and one was a claim.
            if (state.challengeLive) ...[
              const SizedBox(width: 8),
              _LiveChallenge(
                day: state.challengeDay,
                onTap: () => openChallenge(context),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Paints the stats band as a lit surface rather than a flat swatch.
///
/// The Home header has a sun above and to the left of the tree, so the
/// band beneath gets warm light pooling from that direction and the tree's
/// shadow falling just to its right. Both are very low contrast — the point
/// is that the panel feels lit, not that anyone notices a gradient.
class _SunlitBandPainter extends CustomPainter {
  const _SunlitBandPainter({
    required this.base,
    required this.glow,
    required this.radius,
  });

  final Color base;
  final Color glow;
  final double radius;

  /// Where the sun sits horizontally in the header above, as a fraction
  /// of the band's width. Keep in step with TreeScene's sun or the light
  /// will fall from the wrong place.
  static const double _sunX = 0.58;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(rect, Paint()..color = base);

    // Light spilling down from the sun.
    final sun = Offset(size.width * _sunX, -size.height * 0.55);
    canvas.drawCircle(
      sun,
      size.width * 0.62,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.34),
            glow.withValues(alpha: 0.10),
            glow.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: sun, radius: size.width * 0.62)),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_SunlitBandPainter old) =>
      old.base != base || old.glow != glow;
}

class _Sep extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Container(
      width: 1,
      height: 16,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      color: k.colors.statBandLabel.withValues(alpha: 0.22),
    );
  }
}

/// The challenge, while it is running: a pulse, the day, and a way in.
///
/// A filled badge on a strip of plain text, because "this is live" is not the
/// same kind of fact as "nine days" and dressing it as one made it invisible.
/// The dot breathes for the same reason a recording light does.
class _LiveChallenge extends StatefulWidget {
  const _LiveChallenge({required this.day, required this.onTap});

  final int day;
  final VoidCallback onTap;

  @override
  State<_LiveChallenge> createState() => _LiveChallengeState();
}

class _LiveChallengeState extends State<_LiveChallenge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    // The same seam the walking mascot uses: a repeating animation means
    // `pumpAndSettle` never settles, so under test it simply holds still.
    if (heroWalks) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return Material(
      color: k.colors.primary,
      borderRadius: BorderRadius.circular(k.geometry.pillRadius),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(k.geometry.pillRadius),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(9, 5, 10, 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _c,
                builder: (context, _) => Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(
                      alpha: 0.45 + 0.55 * _c.value,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Text(
                AppContent.challengeBadge(widget.day, kPathLength),
                style: k.text.captionStrong.copyWith(
                  fontSize: 11.5,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_right,
                size: 15,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;

  /// Icons keep their own semantic colour — flame, green, gold — while the
  /// numbers and labels take the band's ink, so the row still reads as one
  /// unit rather than four unrelated badges.
  final Color iconColor;

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Expanded(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 4),
            Text(
              value,
              style: k.text.captionStrong.copyWith(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: k.colors.statBandText,
              ),
            ),
            const SizedBox(width: 3),
            Text(
              label,
              style: k.text.caption.copyWith(
                fontSize: 11,
                color: k.colors.statBandLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Date header + week strip
// ---------------------------------------------------------------------------

/// Just the date. Returning to today is done by tapping today's cell in
/// the week strip below — it carries an accent ring and is always on
/// screen, so a button that appeared and vanished was only shifting the
/// layout for something already one tap away.
class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.day, required this.isToday, this.onTap});

  final DateTime day;
  final bool isToday;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    final label = Text(
      isToday
          ? 'Today, ${DateFormat('d MMM').format(day)}'
          : DateFormat('EEE, d MMM').format(day),
      style: k.text.sectionTitle.copyWith(fontSize: 16),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    if (onTap == null) {
      return Row(children: [Expanded(child: label)]);
    }

    // Carries a chevron so it reads as a way through to the month rather than
    // a heading that happens to respond to taps.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(k.geometry.chipRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Flexible(child: label),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 19, color: k.colors.textMuted),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.selected, required this.onSelect});

  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final start = startOfWeek(selected);
    final earliest = state.firstTrackedDay;

    final days = <DateTime>[
      for (var i = 0; i < 7; i++)
        if (!start.add(Duration(days: i)).isBefore(earliest))
          start.add(Duration(days: i)),
    ];

    return Row(
      children: [
        for (var i = 0; i < days.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == days.length - 1 ? 0 : 5),
              child: _WeekDayCell(
                day: days[i],
                selected: selected,
                onTap: onSelect,
              ),
            ),
          ),
      ],
    );
  }
}

class _WeekDayCell extends StatelessWidget {
  const _WeekDayCell({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final DateTime day;
  final DateTime selected;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final k = context.k;
    final isSelected = day == selected;
    final isToday = day == state.today;

    // The cell's own outline carries the day's completion instead of a dot
    // underneath it — same information, a whole row of height cheaper.
    final scheduled = state.scheduledOn(day);
    final done = scheduled.where((h) => state.isComplete(h, day)).length;
    final fraction = scheduled.isEmpty ? 0.0 : done / scheduled.length;
    final radius = k.geometry.innerRadius;

    return GestureDetector(
      onTap: () => onTap(day),
      behavior: HitTestBehavior.opaque,
      child: CustomPaint(
        foregroundPainter: _DayProgressRing(
          fraction: day.isAfter(state.today) ? 0 : fraction,
          radius: radius,
          fill: isSelected ? Colors.white : k.colors.accent,
          track: isSelected
              ? Colors.white.withValues(alpha: 0.25)
              : (isToday ? k.colors.accentTrack : k.colors.outline),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? k.colors.primary : k.colors.surface,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: isSelected ? null : k.cardShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormat('EEE').format(day),
                style: k.text.caption.copyWith(
                  fontSize: 9.5,
                  color: isSelected ? Colors.white70 : k.colors.textSecondary,
                ),
              ),
              Text(
                '${day.day}',
                style: k.text.cardTitle.copyWith(
                  fontSize: 15,
                  color: isSelected ? Colors.white : k.colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Traces the cell's rounded outline, filling the accent colour clockwise in
/// proportion to the day's completed habits.
class _DayProgressRing extends CustomPainter {
  const _DayProgressRing({
    required this.fraction,
    required this.radius,
    required this.fill,
    required this.track,
  });

  final double fraction;
  final double radius;
  final Color fill;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(rect.deflate(0.75), Radius.circular(radius)),
      );

    canvas.drawPath(
      outline,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    if (fraction <= 0) return;

    final metric = outline.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * fraction.clamp(0.0, 1.0)),
      Paint()
        ..color = fill
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_DayProgressRing old) =>
      old.fraction != fraction || old.fill != fill || old.track != track;
}

// ---------------------------------------------------------------------------
// Habit list
// ---------------------------------------------------------------------------

/// Building, or cutting back.
///
/// Two lists rather than two sections of one, because they are not the same
/// task: building asks "did I get to it", cutting back asks "did I stay under
/// it". Stacked, the second read as an afterthought to the first and the count
/// above them was adding up two questions nobody adds up.
///
/// Shown only when there is something on both sides.
class _KindSwitch extends StatelessWidget {
  const _KindSwitch({
    required this.kind,
    required this.buildCount,
    required this.quitCount,
    required this.onSelect,
  });

  final HabitKind kind;
  final int buildCount;
  final int quitCount;
  final ValueChanged<HabitKind> onSelect;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: k.colors.surfaceSoft,
        borderRadius: BorderRadius.circular(k.geometry.pillRadius),
        border: Border.all(color: k.colors.outline),
      ),
      child: Row(
        children: [
          _KindTab(
            label: AppContent.sectionBuild,
            icon: Icons.trending_up,
            count: buildCount,
            selected: kind == HabitKind.build,
            onTap: () => onSelect(HabitKind.build),
          ),
          _KindTab(
            label: AppContent.sectionQuit,
            icon: Icons.block,
            count: quitCount,
            selected: kind == HabitKind.quit,
            onTap: () => onSelect(HabitKind.quit),
          ),
        ],
      ),
    );
  }
}

class _KindTab extends StatelessWidget {
  const _KindTab({
    required this.label,
    required this.icon,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final ink = selected ? Colors.white : k.colors.textSecondary;

    return Expanded(
      child: Material(
        color: selected ? k.colors.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(k.geometry.pillRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(k.geometry.pillRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 15, color: ink),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: k.text.captionStrong.copyWith(
                    fontSize: 12.5,
                    color: ink,
                  ),
                ),
                const SizedBox(width: 5),
                // The count belongs on the tab you are not looking at as much
                // as on the one you are: it is how you know there is anything
                // over there worth pressing.
                Text(
                  '$count',
                  style: k.text.caption.copyWith(
                    fontSize: 11.5,
                    color: selected
                        ? Colors.white.withValues(alpha: 0.8)
                        : k.colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HabitsHeader extends StatelessWidget {
  const _HabitsHeader({
    required this.isToday,
    required this.done,
    required this.total,
  });

  final bool isToday;
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final fraction = total == 0 ? 0.0 : done / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                AppContent.homeTodaySection,
                style: k.text.sectionTitle.copyWith(fontSize: 16),
              ),
            ),
            // The board's legend used to sit here, squeezed to 9.5pt against
            // the right edge over two lines. It is the one sentence that
            // explains the whole view, so it moved inside the board itself,
            // at a size somebody can read.
            ...[
              // Flexible, and a little smaller than it was: the view switch
              // beside it carries a word now, and "10 of 12 completed" at the
              // old size put this row 3px over the edge.
              Flexible(
                child: Text(
                  AppContent.completedOf(done, total),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: k.text.caption.copyWith(fontSize: 10.5),
                ),
              ),
              const SizedBox(width: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  width: 42,
                  height: 6,
                  // Tweened rather than set: it used to jump straight to its
                  // new width, which is why nobody ever noticed it move.
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: fraction),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      backgroundColor: k.colors.accentTrack,
                      valueColor: AlwaysStoppedAnimation(k.colors.accent),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay({required this.isToday});

  final bool isToday;

  @override
  Widget build(BuildContext context) {
    // No habits at all is a start; habits but none on this day is a day off.
    final none = context.select<AppState, bool>((s) => s.everyHabit.isEmpty);
    return EmptyState(
      icon: none ? Icons.add_task_rounded : Icons.wb_sunny_outlined,
      title: none ? AppContent.emptyDayTitle : AppContent.freeDayTitle,
      body: none
          ? AppContent.emptyDayBody
          : (isToday ? AppContent.freeDayBody : AppContent.freeDayPastBody),
      height: 200,
    );
  }
}

// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------

/// Shown under the list once every habit for today is logged.
///
/// Two words and nothing else. The streak and the look-ahead belong to the
/// celebration that has just played across the whole screen; repeating them
/// here turned a full stop into a summary.
class _DayClosedNote extends StatelessWidget {
  const _DayClosedNote();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 14, bottom: 4),
      child: ScriptNote(
        text: AppContent.homeDayClosed,
        align: TextAlign.center,
        fontSize: 21,
        underline: false,
      ),
    );
  }
}

/// Above the list while arranging: what to do, and the way out.
class _ArrangeBar extends StatelessWidget {
  const _ArrangeBar({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: k.colors.primarySoft,
        borderRadius: BorderRadius.circular(k.geometry.innerRadius),
      ),
      child: Row(
        children: [
          Icon(Icons.swap_vert_rounded, size: 20, color: k.colors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppContent.arrangeHint,
              style: k.text.captionStrong.copyWith(
                fontSize: 13.5,
                color: k.colors.primary,
              ),
            ),
          ),
          FilledButton(
            onPressed: onDone,
            style: FilledButton.styleFrom(
              backgroundColor: k.colors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(72, 36),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: Text(AppContent.arrangeDone),
          ),
        ],
      ),
    );
  }
}

/// A habit while arranging: its icon and name, and a handle to drag it by.
/// Holding anywhere on the row drags it too.
class _ArrangeRow extends StatelessWidget {
  const _ArrangeRow({required this.habit, required this.index});

  final Habit habit;
  final int index;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return ReorderableDelayedDragStartListener(
      index: index,
      child: KCard(
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        child: Row(
          children: [
            IconChip(
              iconKey: habit.iconKey,
              icon: AppIcons.forKey(habit.iconKey),
              size: 36,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                habit.name,
                style: k.text.cardTitle.copyWith(fontSize: 14.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.drag_indicator_rounded,
                  size: 22,
                  color: k.colors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
