# RewireMind

Habit tracker built to the approved mockups — Home, Calendar, Progress and
Profile. Real habit data with local persistence; check-ins survive restarts.

## Running

```bash
flutter run
```

Web is the quickest way to eyeball the UI:

```bash
flutter run -d web-server --web-port 51234
```

On web only, two query parameters jump straight to a screen while developing:

- `?tab=0|1|2|3` — Home / Calendar / Progress / Profile
- `?range=week|month|year|allTime` — which Progress view to open

## Tests

```bash
flutter test
```

- `test/screens_test.dart` renders every tab and all four Progress ranges at
  phone size and fails on any layout exception (unbounded constraints,
  overflow). Run it after touching layout — it catches what a screenshot
  review misses.
- `test/modules_test.dart` drives the real flows: creating a habit and
  validating the form, the detail stepper, deleting, selecting a past day and
  backfilling it, and that backfilled progress reaches the Progress stats.
- `test/widget_test.dart` covers seeding, persistence and the streak maths.

## Customising

Two files hold everything you would want to restyle or reword. No widget
hardcodes a colour, text style or user-facing string.

### `lib/theme/app_theme.dart`

The whole visual language: palette, typography, geometry (radii, spacing,
gaps), card shadows. Widgets read tokens through `context.k`:

```dart
color: context.k.colors.accent
style: context.k.text.sectionTitle
```

To add a theme, copy `RewireMindTheme.forest` (or `.copyWith(...)` it), add it to
`RewireMindTheme.presets`, and call `AppState.setTheme(...)`. The selected id is
persisted. Themes lerp, so switching can animate.

Icon chips resolve by key in two places — `colors.accents` for the colour pair
and `AppIcons.forKey` for the glyph — so a theme can restyle every habit and
menu icon without touching a screen.

### `lib/content/app_content.dart`

Every quote, handwritten annotation, section heading, encouragement banner and
Profile menu row. Per-range Progress copy lives in `AppContent.progress`.

## Layout

```
lib/
  theme/        app_theme.dart (design tokens), app_icons.dart
  content/      app_content.dart (all copy and quotes)
  models/       habit, habit_log, user_profile, stats, progress_range
  data/         storage.dart (shared_preferences), seed_data.dart
  state/        app_state.dart — owns data, derives every statistic
  screens/      home_shell + home / calendar / progress / profile
  widgets/      cards, header, illustrations, charts, day dot, bottom nav
```

`AppState` is the single source of truth. Screens read derived values
(`statsFor(range)`, `currentStreak`, `dayStatus(day)`) rather than computing
anything themselves; range statistics are cached and invalidated on write.

## Seed data

A fresh install creates the five habits from the mockups **and ~2 years of
generated history**, so Calendar and Progress have something to show. The
history is tuned to produce a 12-day current streak and a 124-day best streak.

Turn it off for a genuinely empty start:

```dart
// lib/data/seed_data.dart
const bool seedDemoHistory = false;
```

Everything else behaves identically either way.

## Illustrations

The tree and mountain headers are drawn with `CustomPainter`
(`lib/widgets/illustrations.dart`) rather than shipped as images — they recolour
with the theme and add nothing to the bundle. Replace `TreeScene` and
`MountainScene` with real artwork when you have it; nothing else needs to
change.

## Platforms

The app is pure Dart/Flutter — no platform channels, no `dart:io`/`dart:html`,
no native code. `shared_preferences` is the only plugin and it supports iOS,
Android and web; `provider`, `intl` and `uuid` are pure Dart.

Android is built and verified here. **iOS should work as-is but has not been
compiled** — that needs macOS with Xcode, which is an Apple restriction, not a
code one. On a Mac the first run is:

```bash
cd ios && pod install && cd .. && flutter run
```

Then in Xcode set a signing team and bundle identifier. `Info.plist` already
carries the display name; app icons are still the Flutter defaults.

## Layout rule

Every tab pins its header and scrolls only its content region, rather than
sliding the whole page. Home scrolls just the habit list; Calendar is built to
fit one screen with only the habit overview table scrolling, and only once
there are more habits than fit; Progress pins the range selector so switching
period never scrolls out of reach.

If you add content to a tab, keep it inside the scrolling region — moving it
into the pinned header will squeeze the part the user actually works in.

## Build vs cut back

`HabitKind` distinguishes habits you want to *do* from habits you want to
*avoid*. Both are one daily tick underneath, but they read differently:

- a build habit shows its goal ("0 / 2 L") and "Completed! 🎉"
- a cut-back habit shows "Not marked yet" / "Stayed on track 💪", and the
  editor hides the goal fields entirely — there is no amount to measure

Home labels the two groups only when you have both, so a list of purely build
habits stays uncluttered.

## Discontinuing vs deleting

**Discontinue** (`archiveHabit`) sets `archivedAt` and is the button offered on
the habit detail screen. The habit stops appearing from that day, but every day
it was running still counts — so past percentages, streaks and charts stay true
to what actually happened. It shows struck through and dimmed wherever a past
period includes it, with a "Discontinued" badge on Home.

**Delete** (`deleteHabit`) removes the habit *and its logs*, which silently
rewrites history. It is still available, below Discontinue, but archiving is
the right default. `test/lifecycle_test.dart` pins this distinction down.

`Habit.isActiveOnDay` is the single check for "was this habit being tracked on
this day" — weekday schedule, created date and archived date together. Every
statistic counts against it.

## Habit lifecycle

- **Create** — the `+` on Home opens the **habit library**: ready-made habits
  grouped into Popular / Health / Sports / Mindful / Lifestyle / Cut back.
  Tapping `+` on a row adds it with the preset's goal; tapping the row itself
  opens the editor prefilled so the goal can be adjusted first. "Custom habit"
  opens an empty editor. Presets already in your list show as *Added*.
  A new habit starts with no history, so its statistics count only from the
  day it was created.
- **The catalogue** lives in `lib/content/habit_library.dart` — edit that file
  to change what the library offers. Each preset's `iconKey` must exist in
  `AppIcons` and in the theme's `colors.accents`; a test enforces this.
- **Edit / delete** — the pencil in the habit detail app bar reopens the same
  sheet; delete asks for confirmation and removes the habit's logs with it.
- **Detail** — tapping a habit row opens `HabitDetailScreen`: today's progress
  with a stepper (steps by a quarter of the target), current and best streak,
  lifetime completion, and an eight-week grid. Squares in that grid are
  tappable, so you can fix a day straight from the history.

## Backfilling a missed day

Three ways in, all writing to the same store:

- **Home week strip** — tap any day to list that day's habits; the header
  offers "Back to today" while you're away from it. Future days render but
  can't be checked off.
- **Calendar grid** — tap a date to open that day's habits in a sheet.
- **Calendar habit overview** — tap a cell in the week table to toggle that
  habit on that day directly.

## Not built yet

The Profile menu rows (Account, Notifications, Appearance, Habit Defaults,
Data & Privacy, Help) are laid out and tappable but show a "coming soon"
snackbar, as do Edit Profile, Log Out and the notification bell.
