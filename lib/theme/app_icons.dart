import 'package:flutter/material.dart';

/// Glyphs for the icon keys used by habits, the habit library and profile rows.
///
/// A key resolves to a glyph here and to colours in
/// `RewireMindColors.accentFor`, so both are swappable per theme. Add a new key
/// in both places and it works everywhere a habit is drawn.
class AppIcons {
  const AppIcons._();

  static const Map<String, IconData> _catalog = {
    // -- movement ---------------------------------------------------------
    'walk': Icons.directions_walk,
    'run': Icons.directions_run,
    'cycle': Icons.directions_bike,
    'swim': Icons.pool,
    'yoga': Icons.self_improvement,
    'stretch': Icons.accessibility_new,
    'exercise': Icons.fitness_center,
    'stand': Icons.accessibility,
    'steps': Icons.hiking,
    'calories': Icons.local_fire_department,
    'sports': Icons.sports_soccer,

    // -- health -----------------------------------------------------------
    'water': Icons.water_drop,
    'sleep': Icons.bedtime,
    'vitamins': Icons.medication,
    'vegetables': Icons.eco,
    'fruit': Icons.local_florist,
    'breakfast': Icons.breakfast_dining,
    'meal': Icons.restaurant,
    'tea': Icons.emoji_food_beverage,
    'weight': Icons.monitor_weight,

    // -- mind -------------------------------------------------------------
    'meditate': Icons.spa,
    'breathe': Icons.air,
    'journal': Icons.edit_note,
    'gratitude': Icons.volunteer_activism,
    'book': Icons.menu_book,
    'study': Icons.school,
    'review': Icons.fact_check,
    'music': Icons.music_note,

    // -- lifestyle --------------------------------------------------------
    'money': Icons.savings,
    'expenses': Icons.receipt_long,
    'tidy': Icons.cleaning_services,
    'plan': Icons.event_note,
    'family': Icons.groups,
    'outdoors': Icons.park,
    'selfcare': Icons.face,

    // -- cutting back -----------------------------------------------------
    'sugar': Icons.cake,
    'caffeine': Icons.local_cafe,
    'alcohol': Icons.local_bar,
    'smoking': Icons.smoke_free,
    'social': Icons.smartphone,
    'tv': Icons.tv,
    'game': Icons.sports_esports,
    'sitting': Icons.chair,
    'spending': Icons.money_off,
    'junk': Icons.fastfood,

    // -- profile menu -----------------------------------------------------
    'account': Icons.person_outline,
    'notifications': Icons.notifications_none,
    'appearance': Icons.palette_outlined,
    'defaults': Icons.tune,
    'challenge': Icons.psychology_outlined,
    'widgets': Icons.widgets_outlined,
    'privacy': Icons.download_outlined,
    'help': Icons.help_outline,
    'about': Icons.info_outline,
    'share_app': Icons.ios_share,
    'feedback': Icons.rate_review_outlined,
    'test_app': Icons.science_outlined,
    'journal_menu': Icons.auto_stories_outlined,
    'premium': Icons.workspace_premium_rounded,
  };

  static IconData forKey(String key) =>
      _catalog[key] ?? Icons.check_circle_outline;

  /// Keys offered in the habit editor's icon picker, in display order.
  static const List<String> habitKeys = [
    'water',
    'book',
    'exercise',
    'meditate',
    'sleep',
    'run',
    'walk',
    'cycle',
    'yoga',
    'stretch',
    'meal',
    'vegetables',
    'fruit',
    'study',
    'journal',
    'music',
    'money',
    'tidy',
    'outdoors',
    'social',
  ];
}
