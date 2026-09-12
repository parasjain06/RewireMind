import 'package:flutter/material.dart';

import '../models/day_phase.dart';

/// ============================================================================
/// REWIREMIND THEME
/// ============================================================================
/// This is the single source of truth for the app's visual language.
///
/// To add a new theme later:
///   1. Build a new [RewireMindTheme] (copy [RewireMindTheme.forest] and tweak, or
///      use `RewireMindTheme.forest.copyWith(...)` for a small variation).
///   2. Optionally give it a `phases` map so it also follows the clock; leave
///      it null and the theme simply stays the same all day.
///   3. Add it to [RewireMindTheme.presets].
///   4. Switch with `AppState.setTheme(...)` — no widget code needs to change.
///
/// Widgets must never hardcode a Color or TextStyle. Read tokens instead:
///   final k = context.k;                 // the active RewireMindTheme
///   color: k.colors.accent
///   style: k.text.sectionTitle
/// ============================================================================

/// Master switch for the live time-of-day theme.
///
/// `true`  — the page repaints itself morning / afternoon / evening / night.
/// `false` — one static palette and one static daylight scene, exactly as the
///           app looked before day phases existed.
///
/// This single line is the whole revert. Nothing else needs touching: every
/// screen reads the same tokens either way.
const bool kLiveDayTheme = true;

/// The scene and palette used when [kLiveDayTheme] is off.
const DayPhase kStaticPhase = DayPhase.day;

// ---------------------------------------------------------------------------
// Colour tokens
// ---------------------------------------------------------------------------

/// A background/foreground pair used for the round icon chips next to habits
/// and profile menu rows.
@immutable
class AccentPair {
  const AccentPair(this.background, this.foreground);

  final Color background;
  final Color foreground;

  static AccentPair lerp(AccentPair a, AccentPair b, double t) => AccentPair(
    Color.lerp(a.background, b.background, t)!,
    Color.lerp(a.foreground, b.foreground, t)!,
  );
}

@immutable
class RewireMindColors {
  const RewireMindColors({
    required this.background,
    required this.backgroundGradient,
    required this.backgroundStops,
    required this.surface,
    required this.surfaceSoft,
    required this.primary,
    required this.primarySoft,
    required this.accent,
    required this.accentSoft,
    required this.accentTrack,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.outline,
    required this.script,
    required this.flame,
    required this.star,
    required this.danger,
    required this.dangerSoft,
    required this.statBand,
    required this.statBandText,
    required this.statBandLabel,
    required this.navActiveBackground,
    required this.navActive,
    required this.navInactive,
    required this.accents,
  });

  /// Page background (the pale mint wash behind every screen).
  final Color background;

  /// Soft top-to-bottom wash painted behind screen content: green where the
  /// header art sits, fading to near-white where the user reads and taps.
  final List<Color> backgroundGradient;

  /// Positions for [backgroundGradient], same length.
  final List<double> backgroundStops;

  /// Card surface.
  final Color surface;

  /// Tinted card surface (stat strips, quote bars, encouragement banners).
  final Color surfaceSoft;

  /// Deep brand green — wordmark, page titles, selected day pill.
  final Color primary;

  /// Light fill derived from [primary] (selected chips, filter pills).
  final Color primarySoft;

  /// Progress green — filled rings, completed checks, progress bars.
  final Color accent;

  /// Very light green fill behind accent elements.
  final Color accentSoft;

  /// Unfilled portion of progress bars and rings.
  final Color accentTrack;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  /// Hairline dividers and card borders.
  final Color outline;

  /// Colour of the handwritten Caveat annotations.
  final Color script;

  /// Streak flame.
  final Color flame;

  /// Best-streak star.
  final Color star;

  final Color danger;
  final Color dangerSoft;

  /// The Home stats band. Deliberately outside the green family: it sits
  /// between the week strip and the habit list, and a green fill there
  /// dissolved into the page. Change these three to retint it.
  final Color statBand;
  final Color statBandText;
  final Color statBandLabel;

  final Color navActiveBackground;
  final Color navActive;
  final Color navInactive;

  /// Named icon-chip colours. Habits and profile rows look these up by key,
  /// so a new theme can restyle every icon chip without touching widgets.
  /// Keys used by the app: water, book, exercise, meditate, sleep,
  /// account, notifications, appearance, defaults, privacy, help.
  final Map<String, AccentPair> accents;

  /// Icon-chip colours for [key], falling back to the accent green.
  AccentPair accentFor(String key) =>
      accents[key] ?? AccentPair(accentSoft, accent);

  /// Lets a time-of-day palette restate only what it changes.
  RewireMindColors copyWith({
    Color? background,
    List<Color>? backgroundGradient,
    List<double>? backgroundStops,
    Color? surface,
    Color? surfaceSoft,
    Color? primary,
    Color? primarySoft,
    Color? accent,
    Color? accentSoft,
    Color? accentTrack,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? outline,
    Color? script,
    Color? flame,
    Color? star,
    Color? danger,
    Color? dangerSoft,
    Color? statBand,
    Color? statBandText,
    Color? statBandLabel,
    Color? navActiveBackground,
    Color? navActive,
    Color? navInactive,
    Map<String, AccentPair>? accents,
  }) {
    return RewireMindColors(
      background: background ?? this.background,
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
      backgroundStops: backgroundStops ?? this.backgroundStops,
      surface: surface ?? this.surface,
      surfaceSoft: surfaceSoft ?? this.surfaceSoft,
      primary: primary ?? this.primary,
      primarySoft: primarySoft ?? this.primarySoft,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      accentTrack: accentTrack ?? this.accentTrack,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      outline: outline ?? this.outline,
      script: script ?? this.script,
      flame: flame ?? this.flame,
      star: star ?? this.star,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      statBand: statBand ?? this.statBand,
      statBandText: statBandText ?? this.statBandText,
      statBandLabel: statBandLabel ?? this.statBandLabel,
      navActiveBackground: navActiveBackground ?? this.navActiveBackground,
      navActive: navActive ?? this.navActive,
      navInactive: navInactive ?? this.navInactive,
      accents: accents ?? this.accents,
    );
  }

  static RewireMindColors lerp(
    RewireMindColors a,
    RewireMindColors b,
    double t,
  ) {
    return RewireMindColors(
      background: Color.lerp(a.background, b.background, t)!,
      backgroundGradient: [
        for (var i = 0; i < a.backgroundGradient.length; i++)
          Color.lerp(a.backgroundGradient[i], b.backgroundGradient[i], t)!,
      ],
      backgroundStops: [
        for (var i = 0; i < a.backgroundStops.length; i++)
          a.backgroundStops[i] +
              (b.backgroundStops[i] - a.backgroundStops[i]) * t,
      ],
      surface: Color.lerp(a.surface, b.surface, t)!,
      surfaceSoft: Color.lerp(a.surfaceSoft, b.surfaceSoft, t)!,
      primary: Color.lerp(a.primary, b.primary, t)!,
      primarySoft: Color.lerp(a.primarySoft, b.primarySoft, t)!,
      accent: Color.lerp(a.accent, b.accent, t)!,
      accentSoft: Color.lerp(a.accentSoft, b.accentSoft, t)!,
      accentTrack: Color.lerp(a.accentTrack, b.accentTrack, t)!,
      textPrimary: Color.lerp(a.textPrimary, b.textPrimary, t)!,
      textSecondary: Color.lerp(a.textSecondary, b.textSecondary, t)!,
      textMuted: Color.lerp(a.textMuted, b.textMuted, t)!,
      outline: Color.lerp(a.outline, b.outline, t)!,
      script: Color.lerp(a.script, b.script, t)!,
      flame: Color.lerp(a.flame, b.flame, t)!,
      star: Color.lerp(a.star, b.star, t)!,
      danger: Color.lerp(a.danger, b.danger, t)!,
      dangerSoft: Color.lerp(a.dangerSoft, b.dangerSoft, t)!,
      statBand: Color.lerp(a.statBand, b.statBand, t)!,
      statBandText: Color.lerp(a.statBandText, b.statBandText, t)!,
      statBandLabel: Color.lerp(a.statBandLabel, b.statBandLabel, t)!,
      navActiveBackground: Color.lerp(
        a.navActiveBackground,
        b.navActiveBackground,
        t,
      )!,
      navActive: Color.lerp(a.navActive, b.navActive, t)!,
      navInactive: Color.lerp(a.navInactive, b.navInactive, t)!,
      accents: {
        for (final entry in a.accents.entries)
          entry.key: AccentPair.lerp(
            entry.value,
            b.accents[entry.key] ?? entry.value,
            t,
          ),
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Typography tokens
// ---------------------------------------------------------------------------

@immutable
class RewireMindTypography {
  const RewireMindTypography({
    required this.wordmark,
    required this.tagline,
    required this.pageTitle,
    required this.pageSubtitle,
    required this.greeting,
    required this.sectionTitle,
    required this.sectionSubtitle,
    required this.cardTitle,
    required this.body,
    required this.bodyStrong,
    required this.caption,
    required this.captionStrong,
    required this.statValue,
    required this.statLabel,
    required this.script,
  });

  /// "RewireMind" wordmark.
  final TextStyle wordmark;

  /// "Small steps. A better you."
  final TextStyle tagline;

  /// Big screen headings — "Progress", "Calendar".
  final TextStyle pageTitle;

  /// The line under a page title.
  final TextStyle pageSubtitle;

  /// "Good morning, Paras!"
  final TextStyle greeting;

  /// "Today's Habits", "Habit Breakdown".
  final TextStyle sectionTitle;
  final TextStyle sectionSubtitle;

  /// Habit name inside a row/card.
  final TextStyle cardTitle;

  final TextStyle body;
  final TextStyle bodyStrong;
  final TextStyle caption;
  final TextStyle captionStrong;

  /// Large numerals in stat tiles ("12", "78%").
  final TextStyle statValue;

  /// Label under a stat value ("Day Streak").
  final TextStyle statLabel;

  /// Handwritten Caveat annotations.
  final TextStyle script;

  static RewireMindTypography lerp(
    RewireMindTypography a,
    RewireMindTypography b,
    double t,
  ) {
    return RewireMindTypography(
      wordmark: TextStyle.lerp(a.wordmark, b.wordmark, t)!,
      tagline: TextStyle.lerp(a.tagline, b.tagline, t)!,
      pageTitle: TextStyle.lerp(a.pageTitle, b.pageTitle, t)!,
      pageSubtitle: TextStyle.lerp(a.pageSubtitle, b.pageSubtitle, t)!,
      greeting: TextStyle.lerp(a.greeting, b.greeting, t)!,
      sectionTitle: TextStyle.lerp(a.sectionTitle, b.sectionTitle, t)!,
      sectionSubtitle: TextStyle.lerp(a.sectionSubtitle, b.sectionSubtitle, t)!,
      cardTitle: TextStyle.lerp(a.cardTitle, b.cardTitle, t)!,
      body: TextStyle.lerp(a.body, b.body, t)!,
      bodyStrong: TextStyle.lerp(a.bodyStrong, b.bodyStrong, t)!,
      caption: TextStyle.lerp(a.caption, b.caption, t)!,
      captionStrong: TextStyle.lerp(a.captionStrong, b.captionStrong, t)!,
      statValue: TextStyle.lerp(a.statValue, b.statValue, t)!,
      statLabel: TextStyle.lerp(a.statLabel, b.statLabel, t)!,
      script: TextStyle.lerp(a.script, b.script, t)!,
    );
  }
}

// ---------------------------------------------------------------------------
// Geometry tokens
// ---------------------------------------------------------------------------

@immutable
class RewireMindGeometry {
  const RewireMindGeometry({
    this.screenPadding = 16,
    this.cardPadding = 16,
    this.gap = 12,
    this.gapSmall = 8,
    this.gapLarge = 20,
    this.cardRadius = 22,
    this.innerRadius = 16,
    this.chipRadius = 14,
    this.pillRadius = 999,
    this.iconChip = 42,
  });

  /// Horizontal padding applied to screen content.
  final double screenPadding;
  final double cardPadding;
  final double gap;
  final double gapSmall;
  final double gapLarge;
  final double cardRadius;
  final double innerRadius;
  final double chipRadius;
  final double pillRadius;

  /// Diameter of the round icon chips beside habits/menu rows.
  final double iconChip;

  static RewireMindGeometry lerp(
    RewireMindGeometry a,
    RewireMindGeometry b,
    double t,
  ) {
    double l(double x, double y) => x + (y - x) * t;
    return RewireMindGeometry(
      screenPadding: l(a.screenPadding, b.screenPadding),
      cardPadding: l(a.cardPadding, b.cardPadding),
      gap: l(a.gap, b.gap),
      gapSmall: l(a.gapSmall, b.gapSmall),
      gapLarge: l(a.gapLarge, b.gapLarge),
      cardRadius: l(a.cardRadius, b.cardRadius),
      innerRadius: l(a.innerRadius, b.innerRadius),
      chipRadius: l(a.chipRadius, b.chipRadius),
      pillRadius: l(a.pillRadius, b.pillRadius),
      iconChip: l(a.iconChip, b.iconChip),
    );
  }
}

// ---------------------------------------------------------------------------
// The theme itself
// ---------------------------------------------------------------------------

@immutable
class RewireMindTheme extends ThemeExtension<RewireMindTheme> {
  const RewireMindTheme({
    required this.id,
    required this.name,
    required this.brightness,
    required this.colors,
    required this.text,
    this.geometry = const RewireMindGeometry(),
    this.phases,
  });

  /// Stable key persisted in storage.
  final String id;

  /// Human-readable name shown in the (future) appearance picker.
  final String name;

  final Brightness brightness;
  final RewireMindColors colors;
  final RewireMindTypography text;
  final RewireMindGeometry geometry;

  /// This theme's time-of-day palettes, keyed by phase.
  ///
  /// Null — or a missing key — means the theme does not change with the
  /// clock, so a new theme can opt out of day phases by simply not
  /// supplying this.
  final Map<DayPhase, RewireMindColors>? phases;

  /// Soft elevation used by every card in the app.
  List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: colors.textPrimary.withValues(alpha: 0.06),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];

  /// Standard card decoration.
  BoxDecoration get cardDecoration => BoxDecoration(
    color: colors.surface,
    borderRadius: BorderRadius.circular(geometry.cardRadius),
    // A hairline keeps white cards legible against the near-white lower
    // half of the page, where the shadow alone is not enough.
    border: Border.all(color: colors.outline, width: 1),
    boxShadow: cardShadow,
  );

  /// Tinted card (stat strips, banners) — no shadow, soft fill.
  BoxDecoration get softCardDecoration => BoxDecoration(
    color: colors.surfaceSoft,
    borderRadius: BorderRadius.circular(geometry.cardRadius),
  );

  // -- Presets --------------------------------------------------------------

  /// The default theme, matching the approved mockups.
  static final RewireMindTheme forest = _buildForest();

  /// Every selectable theme. Add new presets here.
  static List<RewireMindTheme> get presets => [forest];

  static RewireMindTheme byId(String id) =>
      presets.firstWhere((t) => t.id == id, orElse: () => forest);

  /// The same theme, retinted for the time of day.
  ///
  /// Only the palette changes — every widget keeps reading the same tokens,
  /// so the whole page follows the sun without a single screen knowing what
  /// time it is. Night is a genuine dark palette, not a tinted light one.
  ///
  /// Returns the theme unchanged when [kLiveDayTheme] is off or the theme
  /// defines no palette for this phase.
  RewireMindTheme forPhase(DayPhase phase) {
    if (!kLiveDayTheme) return this;
    final tinted = phases?[phase];
    if (tinted == null) return this;

    return copyWith(
      id: '$id-${phase.name}',
      brightness: phase.isDark ? Brightness.dark : Brightness.light,
      colors: tinted,
      text: _retint(text, tinted),
    );
  }

  /// Text tokens bake in their colours, so they are re-derived whenever the
  /// palette flips — otherwise night would keep the daytime ink.
  static RewireMindTypography _retint(
    RewireMindTypography t,
    RewireMindColors c,
  ) {
    return RewireMindTypography(
      wordmark: t.wordmark.copyWith(color: c.primary),
      tagline: t.tagline.copyWith(color: c.textSecondary),
      pageTitle: t.pageTitle.copyWith(color: c.textPrimary),
      pageSubtitle: t.pageSubtitle.copyWith(color: c.textSecondary),
      greeting: t.greeting.copyWith(color: c.textPrimary),
      sectionTitle: t.sectionTitle.copyWith(color: c.textPrimary),
      sectionSubtitle: t.sectionSubtitle.copyWith(color: c.textSecondary),
      cardTitle: t.cardTitle.copyWith(color: c.textPrimary),
      body: t.body.copyWith(color: c.textSecondary),
      bodyStrong: t.bodyStrong.copyWith(color: c.textPrimary),
      caption: t.caption.copyWith(color: c.textSecondary),
      captionStrong: t.captionStrong.copyWith(color: c.textPrimary),
      statValue: t.statValue.copyWith(color: c.textPrimary),
      statLabel: t.statLabel.copyWith(color: c.textSecondary),
      script: t.script.copyWith(color: c.script),
    );
  }

  // -- ThemeExtension plumbing ---------------------------------------------

  @override
  RewireMindTheme copyWith({
    String? id,
    String? name,
    Brightness? brightness,
    RewireMindColors? colors,
    RewireMindTypography? text,
    RewireMindGeometry? geometry,
    Map<DayPhase, RewireMindColors>? phases,
  }) {
    return RewireMindTheme(
      id: id ?? this.id,
      name: name ?? this.name,
      brightness: brightness ?? this.brightness,
      colors: colors ?? this.colors,
      text: text ?? this.text,
      geometry: geometry ?? this.geometry,
      phases: phases ?? this.phases,
    );
  }

  @override
  RewireMindTheme lerp(ThemeExtension<RewireMindTheme>? other, double t) {
    if (other is! RewireMindTheme) return this;
    return RewireMindTheme(
      id: t < 0.5 ? id : other.id,
      name: t < 0.5 ? name : other.name,
      brightness: t < 0.5 ? brightness : other.brightness,
      colors: RewireMindColors.lerp(colors, other.colors, t),
      text: RewireMindTypography.lerp(text, other.text, t),
      geometry: RewireMindGeometry.lerp(geometry, other.geometry, t),
    );
  }

  /// Builds the Material [ThemeData] that carries this theme.
  ThemeData toThemeData() {
    final scheme = ColorScheme.fromSeed(
      seedColor: colors.primary,
      brightness: brightness,
      primary: colors.primary,
      surface: colors.surface,
      error: colors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.background,
      fontFamily: _fontSans,
      fontFamilyFallback: _emojiFallback,
      splashFactory: InkSparkle.splashFactory,
      textTheme: TextTheme(
        displaySmall: text.pageTitle,
        headlineSmall: text.greeting,
        titleLarge: text.sectionTitle,
        titleMedium: text.cardTitle,
        bodyMedium: text.body,
        bodySmall: text.caption,
        labelSmall: text.statLabel,
      ),
      dividerTheme: DividerThemeData(
        color: colors.outline,
        thickness: 1,
        space: 1,
      ),
      extensions: [this],
    );
  }
}

// ---------------------------------------------------------------------------
// Forest preset — the palette used by the approved mockups
// ---------------------------------------------------------------------------

const String _fontSans = 'Poppins';
const String _fontScript = 'Caveat';

/// Poppins and Caveat carry no emoji glyphs, so the platform emoji font has to
/// be named explicitly or emoji render as tofu boxes (notably on web).
const List<String> _emojiFallback = [
  'Noto Color Emoji',
  'Segoe UI Emoji',
  'Apple Color Emoji',
  'Noto Emoji',
];

/// Icon-chip colour families. Every habit and menu icon points at one of these,
/// so restyling all of them is a nine-line edit rather than a per-icon sweep.
const AccentPair _blue = AccentPair(Color(0xFFE4F1FD), Color(0xFF2F94E8));
const AccentPair _green = AccentPair(Color(0xFFE6F4E9), Color(0xFF43A047));
const AccentPair _coral = AccentPair(Color(0xFFFDE9EA), Color(0xFFE4574F));
const AccentPair _violet = AccentPair(Color(0xFFF1E9FB), Color(0xFF8E5BD0));
const AccentPair _amber = AccentPair(Color(0xFFFDF3DC), Color(0xFFE9A93A));
const AccentPair _teal = AccentPair(Color(0xFFDFF2F0), Color(0xFF2F9E92));
const AccentPair _rose = AccentPair(Color(0xFFFDE6EE), Color(0xFFD9548A));
const AccentPair _indigo = AccentPair(Color(0xFFE8EAFA), Color(0xFF5A63C4));
const AccentPair _slate = AccentPair(Color(0xFFE9EDEA), Color(0xFF62766A));

RewireMindTheme _buildForest() {
  const colors = RewireMindColors(
    background: Color(0xFFF7FBF7),
    backgroundGradient: [
      Color(0xFFDCEDE0),
      Color(0xFFEDF5EE),
      Color(0xFFF9FCF9),
    ],
    backgroundStops: [0.0, 0.22, 0.46],
    surface: Color(0xFFFFFFFF),
    surfaceSoft: Color(0xFFE7F3E8),
    primary: Color(0xFF14532D),
    primarySoft: Color(0xFFDCEEDD),
    accent: Color(0xFF43A047),
    accentSoft: Color(0xFFE6F4E9),
    accentTrack: Color(0xFFE2EAE3),
    textPrimary: Color(0xFF16241B),
    textSecondary: Color(0xFF5F7265),
    textMuted: Color(0xFF93A395),
    outline: Color(0xFFE4EDE5),
    script: Color(0xFF2F7D33),
    flame: Color(0xFFFF6B35),
    star: Color(0xFFF5B826),
    danger: Color(0xFFE23B34),
    dangerSoft: Color(0xFFFDECEC),
    statBand: Color(0xFFFDF8E4),
    statBandText: Color(0xFF412402),
    statBandLabel: Color(0xFF854F0B),
    navActiveBackground: Color(0xFFDDEEDD),
    navActive: Color(0xFF14532D),
    navInactive: Color(0xFF93A395),
    accents: {
      // -- movement -------------------------------------------------------
      'walk': _green,
      'run': _coral,
      'cycle': _blue,
      'swim': _teal,
      'yoga': _violet,
      'stretch': _rose,
      'exercise': _coral,
      'stand': _slate,
      'steps': _green,
      'calories': _coral,
      'sports': _indigo,
      // -- health ---------------------------------------------------------
      'water': _blue,
      'sleep': _amber,
      'vitamins': _rose,
      'vegetables': _green,
      'fruit': _rose,
      'breakfast': _amber,
      'meal': _amber,
      'tea': _teal,
      'weight': _slate,
      // -- mind -----------------------------------------------------------
      'meditate': _violet,
      'breathe': _teal,
      'journal': _indigo,
      'premium': _amber,
      'gratitude': _rose,
      'book': _green,
      'study': _indigo,
      'review': _slate,
      'music': _violet,
      // -- lifestyle ------------------------------------------------------
      'money': _amber,
      'expenses': _slate,
      'tidy': _teal,
      'plan': _indigo,
      'family': _rose,
      'outdoors': _green,
      'selfcare': _rose,
      // -- cutting back ---------------------------------------------------
      'sugar': _rose,
      'caffeine': _amber,
      'alcohol': _coral,
      'smoking': _slate,
      'social': _indigo,
      'tv': _slate,
      'game': _violet,
      'sitting': _slate,
      'spending': _coral,
      'junk': _coral,
      // -- profile menu ---------------------------------------------------
      'account': _blue,
      'notifications': _coral,
      'appearance': _violet,
      'defaults': _green,
      'challenge': _violet,
      'widgets': _blue,
      'privacy': _amber,
      'help': _blue,
      'about': _violet,
      'share_app': _green,
      'feedback': _coral,
      'test_app': _slate,
      'journal_menu': _violet,
    },
  );

  final primary = colors.textPrimary;

  final text = RewireMindTypography(
    wordmark: TextStyle(
      fontFamily: _fontSans,
      fontFamilyFallback: _emojiFallback,
      fontSize: 25,
      fontWeight: FontWeight.w700,
      height: 1.1,
      color: colors.primary,
    ),
    tagline: TextStyle(
      fontFamily: _fontSans,
      fontFamilyFallback: _emojiFallback,
      fontSize: 11.5,
      fontWeight: FontWeight.w400,
      color: colors.textSecondary,
    ),
    pageTitle: TextStyle(
      fontFamily: _fontSans,
      fontFamilyFallback: _emojiFallback,
      fontSize: 32,
      fontWeight: FontWeight.w700,
      height: 1.15,
      color: primary,
    ),
    pageSubtitle: TextStyle(
      fontFamily: _fontSans,
      fontFamilyFallback: _emojiFallback,
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: colors.textSecondary,
    ),
    greeting: TextStyle(
      fontFamily: _fontSans,
      fontFamilyFallback: _emojiFallback,
      fontSize: 25,
      fontWeight: FontWeight.w700,
      height: 1.25,
      color: primary,
    ),
    sectionTitle: TextStyle(
      fontFamily: _fontSans,
      fontFamilyFallback: _emojiFallback,
      fontSize: 19,
      fontWeight: FontWeight.w700,
      color: primary,
    ),
    sectionSubtitle: TextStyle(
      fontFamily: _fontSans,
      fontFamilyFallback: _emojiFallback,
      fontSize: 12.5,
      fontWeight: FontWeight.w400,
      color: colors.textSecondary,
    ),
    cardTitle: TextStyle(
      fontFamily: _fontSans,
      fontFamilyFallback: _emojiFallback,
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: primary,
    ),
    body: TextStyle(
      fontFamily: _fontSans,
      fontFamilyFallback: _emojiFallback,
      fontSize: 13.5,
      fontWeight: FontWeight.w400,
      color: colors.textSecondary,
    ),
    bodyStrong: TextStyle(
      fontFamily: _fontSans,
      fontFamilyFallback: _emojiFallback,
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
      color: primary,
    ),
    caption: TextStyle(
      fontFamily: _fontSans,
      fontFamilyFallback: _emojiFallback,
      fontSize: 11.5,
      fontWeight: FontWeight.w400,
      color: colors.textSecondary,
    ),
    captionStrong: TextStyle(
      fontFamily: _fontSans,
      fontFamilyFallback: _emojiFallback,
      fontSize: 11.5,
      fontWeight: FontWeight.w600,
      color: primary,
    ),
    statValue: TextStyle(
      fontFamily: _fontSans,
      fontFamilyFallback: _emojiFallback,
      fontSize: 24,
      fontWeight: FontWeight.w700,
      height: 1.1,
      color: primary,
    ),
    statLabel: TextStyle(
      fontFamily: _fontSans,
      fontFamilyFallback: _emojiFallback,
      fontSize: 11.5,
      fontWeight: FontWeight.w400,
      color: colors.textSecondary,
    ),
    // Caveat is a variable font, so the weight comes from a FontVariation
    // rather than a separately declared asset.
    script: TextStyle(
      fontFamily: _fontScript,
      fontFamilyFallback: _emojiFallback,
      fontSize: 19,
      fontWeight: FontWeight.w600,
      fontVariations: [FontVariation('wght', 600)],
      height: 1.15,
      color: colors.script,
    ),
  );

  return RewireMindTheme(
    id: 'forest',
    name: 'Forest',
    brightness: Brightness.light,
    colors: colors,
    text: text,
    phases: _forestPhases(colors),
  );
}

/// Forest's four times of day.
///
/// Each one restates only what it changes, so a tweak to the base palette
/// still flows through every phase. Keep every colour decision here — this
/// map is the whole "live" look of the app.
Map<DayPhase, RewireMindColors> _forestPhases(RewireMindColors base) => {
  // Sunrise: a soft warm light, not a blaze — this is the palette a
  // half-awake person reads at six in the morning.
  DayPhase.earlyMorning: base.copyWith(
    background: const Color(0xFFFFF6EE),
    // Barely off-white, warmed toward the sky. Pure white would sit on a
    // peach page as a foreign object — night already tints its cards, and
    // the light phases should too.
    surface: const Color(0xFFFFFBF6),
    backgroundGradient: const [
      Color(0xFFFFD5B4),
      Color(0xFFFFE8D6),
      Color(0xFFFFF6EE),
    ],
    backgroundStops: const [0.0, 0.42, 1.0],
    surfaceSoft: const Color(0xFFFDEEE1),
    outline: const Color(0xFFF3E3D5),
    accentTrack: const Color(0xFFF5E7DA),
    statBand: const Color(0xFFFFEBD3),
    statBandText: const Color(0xFF4A2A0C),
    statBandLabel: const Color(0xFF9A5B1C),
  ),
  // Daylight: bright open sky.
  DayPhase.day: base.copyWith(
    background: const Color(0xFFEAF7FB),
    surface: const Color(0xFFFAFDFE),
    backgroundGradient: const [
      Color(0xFF8ACFEC),
      Color(0xFFC2E6F3),
      Color(0xFFEAF7FB),
    ],
    backgroundStops: const [0.0, 0.42, 1.0],
    surfaceSoft: const Color(0xFFDCEFF3),
    outline: const Color(0xFFD6E8ED),
    accentTrack: const Color(0xFFDCEAEE),
  ),
  // Night inverts the page. Whites that sit on coloured fills — the
  // checkmarks, the add button, selected pills — stay correct because
  // those fills are still coloured.
  // Night's greens are calmer than day's: a jade leaning a little towards
  // teal, so the switches, ticks and selected tabs sit with the navy instead
  // of glaring off it. The saturated day green read as neon after dark.
  DayPhase.night: base.copyWith(
    background: const Color(0xFF16263A),
    backgroundGradient: const [
      Color(0xFF0A1220),
      Color(0xFF13233A),
      Color(0xFF1E3653),
    ],
    backgroundStops: const [0.0, 0.42, 1.0],
    surface: const Color(0xFF1F3149),
    surfaceSoft: const Color(0xFF263C56),
    primary: const Color(0xFF2E7563),
    primarySoft: const Color(0xFF223F3D),
    accent: const Color(0xFF52A08A),
    accentSoft: const Color(0xFF213D3C),
    accentTrack: const Color(0xFF31465E),
    textPrimary: const Color(0xFFE9F0F8),
    textSecondary: const Color(0xFFA9BDD2),
    textMuted: const Color(0xFF7B8FA6),
    outline: const Color(0xFF2E4560),
    script: const Color(0xFF8CC4B0),
    flame: const Color(0xFFFF8A5B),
    star: const Color(0xFFF7CF62),
    danger: const Color(0xFFF1685F),
    dangerSoft: const Color(0xFF3B2630),
    statBand: const Color(0xFF2E2A1B),
    statBandText: const Color(0xFFF5E6C2),
    statBandLabel: const Color(0xFFD5AE63),
    navActiveBackground: const Color(0xFF223F3D),
    navActive: const Color(0xFF9CC9B8),
    navInactive: const Color(0xFF7B8FA6),
  ),
};

// ---------------------------------------------------------------------------
// Access helper
// ---------------------------------------------------------------------------

extension RewireMindThemeContext on BuildContext {
  /// The active RewireMind theme. Use this instead of hardcoding styles:
  /// `context.k.colors.accent`, `context.k.text.sectionTitle`.
  RewireMindTheme get k =>
      Theme.of(this).extension<RewireMindTheme>() ?? RewireMindTheme.forest;
}
