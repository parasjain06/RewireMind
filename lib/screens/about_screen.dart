import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../content/app_content.dart';
import '../content/app_links.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import '../widgets/link_row.dart';
import '../widgets/settings_group.dart';

/// The app's own particulars: what it is, what version of it you have, who
/// made it and what it is made of.
///
/// It used to be seven identical link rows in a column with a version number
/// underneath. Everything looked equally important, and the two rows that are
/// legally load-bearing sat between "follow us on X" and a build number. Now
/// the identity is a proper header, the outward links are grouped by what they
/// are for, and the licences page — which every serious app has and this one
/// did not — is where it belongs.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const AboutScreen()));
  }

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _readVersion();
  }

  Future<void> _readVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _version = '${info.version} (${info.buildNumber})');
    }
  }

  void _open(String url, {String? fallback}) => openLink(
    context,
    url: Uri.parse(url),
    fallback: fallback == null ? null : Uri.parse(fallback),
    failure: AppContent.linkFailed,
  );

  @override
  Widget build(BuildContext context) {
    final k = context.k;

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
            AppContent.aboutTitle,
            style: k.text.sectionTitle.copyWith(fontSize: 17),
          ),
        ),
        body: ListView(
          padding: EdgeInsets.fromLTRB(
            k.geometry.screenPadding,
            4,
            k.geometry.screenPadding,
            28,
          ),
          children: [
            _Identity(version: _version),
            const SizedBox(height: 18),

            SettingsGroup(
              title: AppContent.groupFollow,
              children: [
                SettingsRow(
                  icon: Icons.language,
                  label: AppContent.aboutWebsite,
                  subtitle: 'rewiremind.app',
                  external: true,
                  onTap: () => _open(AppLinks.website),
                ),
                SettingsRow(
                  icon: Icons.alternate_email,
                  label: AppContent.aboutX,
                  external: true,
                  onTap: () => _open(AppLinks.x),
                ),
                SettingsRow(
                  icon: Icons.groups_outlined,
                  label: AppContent.aboutLinkedIn,
                  external: true,
                  onTap: () => _open(AppLinks.linkedIn),
                ),
                SettingsRow(
                  icon: Icons.star_outline,
                  label: AppContent.aboutRate,
                  subtitle: AppContent.aboutRateBody,
                  external: true,
                  // The store app where it is installed, the web listing where
                  // it is not — a `market://` link on a phone without Play
                  // Services opens nothing at all.
                  onTap: () =>
                      _open(AppLinks.rateNative, fallback: AppLinks.rateWeb),
                ),
              ],
            ),
            const SizedBox(height: 18),

            SettingsGroup(
              title: AppContent.groupLegal,
              children: [
                SettingsRow(
                  icon: Icons.description_outlined,
                  label: AppContent.aboutTerms,
                  external: true,
                  onTap: () => _open(AppLinks.terms),
                ),
                SettingsRow(
                  icon: Icons.lock_outline,
                  label: AppContent.aboutPrivacy,
                  external: true,
                  onTap: () => _open(AppLinks.privacy),
                ),
              ],
            ),
            const SizedBox(height: 22),

            Center(
              child: Text(
                AppContent.aboutMadeBy,
                textAlign: TextAlign.center,
                style: k.text.caption.copyWith(fontSize: 11),
              ),
            ),
            // Small, but here. Neither store asks for it; the open-source
            // packages this is built on do — their licences are granted on
            // condition their notices ship with the app, and this is Flutter's
            // own page for exactly that.
            Center(
              child: TextButton(
                onPressed: () => showLicensePage(
                  context: context,
                  applicationName: AppContent.appName,
                  applicationVersion: _version,
                ),
                style: TextButton.styleFrom(
                  foregroundColor: k.colors.textMuted,
                  textStyle: k.text.caption.copyWith(
                    fontSize: 11,
                    decoration: TextDecoration.underline,
                  ),
                ),
                child: Text(AppContent.aboutLicences),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// The block at the top: the icon, the name, and exactly which build this is.
///
/// The version used to be a grey line at the bottom of the page. It is the
/// first thing anybody is asked for when something goes wrong, so it is now
/// the second thing on the screen.
class _Identity extends StatelessWidget {
  const _Identity({required this.version});

  final String version;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            'assets/brand/icon.png',
            width: 58,
            height: 58,
            // The asset is the launcher icon; if it ever goes missing the
            // screen should still render rather than throw a grey box at
            // somebody who came here to read a version number.
            errorBuilder: (_, _, _) =>
                Container(width: 58, height: 58, color: k.colors.primarySoft),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppContent.appName,
                style: k.text.cardTitle.copyWith(fontSize: 19),
              ),
              const SizedBox(height: 3),
              Text(
                version.isEmpty
                    ? AppContent.aboutVersion
                    : '${AppContent.aboutVersion} $version',
                style: k.text.caption.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
