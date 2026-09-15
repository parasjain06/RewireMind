/// ============================================================================
/// EVERY LINK THAT LEAVES THE APP
/// ============================================================================
/// One file, so changing where the app points is a change in one place and not
/// a hunt through six screens.
///
/// The handles below are the ones the site would imply. Anything that is not
/// yet claimed should be corrected here rather than in the screen that shows
/// it — a wrong link is worse than a missing one, so delete the entry instead
/// of leaving it pointing somewhere that does not exist.
/// ============================================================================
library;

class AppLinks {
  const AppLinks._();

  static const String website = 'https://rewiremind.app';
  static const String x = 'https://x.com/rewiremindapp';
  static const String linkedIn = 'https://www.linkedin.com/company/rewiremindapp';
  static const String terms = 'https://rewiremind.app/terms';
  static const String privacy = 'https://rewiremind.app/privacy';

  /// The address feedback goes to. A mail app rather than a form: there is no
  /// server to take a form, and pretending otherwise would drop what people
  /// wrote on the floor.
  static const String feedbackEmail = 'hello@rewiremind.app';

  /// The app's own id, which is what the store listing is keyed on.
  static const String androidId = 'com.parasjain.rewiremind';

  /// Opens the Play Store app directly where it is installed.
  static const String rateNative = 'market://details?id=$androidId';

  /// The same listing in a browser, for when it is not.
  static const String rateWeb =
      'https://play.google.com/store/apps/details?id=$androidId';

  /// A bug report, with the shape of one already in the body.
  ///
  /// The blank-page problem is real: "send feedback" opens an empty draft and
  /// most people close it again. Three headings is enough scaffolding that
  /// somebody fills them in, and it is the difference between a report that
  /// can be acted on and one that says "it's broken".
  static Uri problem(String version) => Uri(
    scheme: 'mailto',
    path: feedbackEmail,
    queryParameters: {
      'subject': 'RewireMind problem report',
      'body':
          'What happened:\n\n\n'
          'What you expected:\n\n\n'
          'How to see it again:\n\n\n'
          '---\nRewireMind $version',
    },
  );

  static Uri feedback(String version) => Uri(
    scheme: 'mailto',
    path: feedbackEmail,
    queryParameters: {
      'subject': 'RewireMind feedback',
      // The version is what makes a report actionable, and asking somebody to
      // go and find it themselves is how you end up without it.
      'body': '\n\n---\nRewireMind $version',
    },
  );
}
