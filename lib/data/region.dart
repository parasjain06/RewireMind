import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Which country this copy of the app is in, for the prices it shows.
///
/// Asked of the platform once and kept: the SIM first (a phone in India is
/// often set to en-GB, and the language is not where somebody lives), then
/// the system locale. A real store prices by the buyer's billing country and
/// hands back a formatted price, which is what should be shown the day
/// billing is wired up — this is the guess until then.
class Region {
  const Region._();

  static const MethodChannel _channel = MethodChannel(
    'com.parasjain.rewiremind/widgets',
  );

  /// Overridden by tests.
  @visibleForTesting
  static String? override;

  static String? _country;
  static bool _asked = false;

  /// What was found last time, without waiting: null until [resolve] has run.
  static String? get country => override ?? _country ?? _fromLocale();

  static String? _fromLocale() {
    final fromUi = ui.PlatformDispatcher.instance.locale.countryCode;
    if (fromUi != null && fromUi.isNotEmpty) return fromUi;
    if (!kIsWeb) {
      final parts = Platform.localeName.split(RegExp('[_-]'));
      if (parts.length > 1 && parts[1].isNotEmpty) return parts[1];
    }
    return null;
  }

  /// Asks the platform, once.
  static Future<String?> resolve() async {
    if (_asked) return country;
    _asked = true;
    if (!kIsWeb && Platform.isAndroid) {
      try {
        _country = await _channel.invokeMethod<String>('country');
      } on PlatformException {
        _country = null;
      } on MissingPluginException {
        _country = null;
      }
    }
    return country;
  }
}
