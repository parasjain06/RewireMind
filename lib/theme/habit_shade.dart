/// ============================================================================
/// THE SHADE LANGUAGE
/// ============================================================================
/// Two axes, and only two: **hue says which habit, depth says how much of it
/// got done.** The board invented this to make ten weeks readable without
/// counting anything, and it only works as a language if the rest of the app
/// speaks it too — a habit that is amber on Home and green on the Calendar is
/// two habits as far as the eye is concerned.
///
/// The hue itself comes from [AppState.colorFor], which either honours a
/// colour the user chose or deals one out of [AppContent.habitColours]. This
/// file is only about the second axis: how deep to draw it.
/// ============================================================================
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/habit.dart';

/// The palest a day that had *something* done to it may be drawn.
///
/// High on purpose. Below roughly a third, a light day stops reading as the
/// habit's own colour and starts reading as a smudge on the page — and the
/// whole point is that a glance tells you which habit a mark belongs to.
const double kShadeFloor = 0.34;

/// Bends the ramp so the bottom half of it is easier to tell apart.
///
/// Values below one lift the dark end: a fifth done and two fifths done come
/// out distinguishable rather than both landing on "nearly nothing".
const double kShadeGamma = 0.75;

/// How opaque a day is drawn, from how much of it was done.
///
/// Zero is not on this scale. A day with none of it done is drawn as nothing
/// at all — an absence, not a pale square somebody has to stop and interpret —
/// so callers check for zero before asking.
double shadeAlpha(double fraction) =>
    kShadeFloor +
    (1 - kShadeFloor) * math.pow(fraction.clamp(0, 1), kShadeGamma).toDouble();

/// [base] at the depth [fraction] earned.
Color habitShade(Color base, double fraction) =>
    base.withValues(alpha: shadeAlpha(fraction));

/// How much of one day's target a logged value represents, 0 to 1.
///
/// A habit with no target is all or nothing, so anything at all counts as the
/// whole of it.
double doneFraction(Habit habit, double value) => habit.target <= 0
    ? (value > 0 ? 1.0 : 0.0)
    : (value / habit.target).clamp(0.0, 1.0);
