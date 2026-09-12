import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import 'app_snackbar.dart';
import 'k_card.dart';

/// Opens [url] outside the app, and says so plainly when it cannot.
///
/// A tap that does nothing is worse than an error: the phone may have no
/// browser, no mail app, or no Play Store, and the honest answer is to say
/// which rather than to leave somebody tapping.
Future<void> openLink(
  BuildContext context, {
  required Uri url,
  Uri? fallback,
  required String failure,
}) async {
  for (final candidate in [url, ?fallback]) {
    try {
      if (await launchUrl(candidate, mode: LaunchMode.externalApplication)) {
        return;
      }
    } on PlatformException {
      // No app claims this scheme. Try the next one.
    }
  }
  if (context.mounted) await showAppSnackBar(context, message: failure);
}

/// One outbound link, as a row: an icon, a label, and the arrow that says
/// this leaves the app.
class LinkRow extends StatelessWidget {
  const LinkRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return KCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Icon(icon, size: 19, color: k.colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: k.text.cardTitle.copyWith(fontSize: 14)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: k.text.caption.copyWith(fontSize: 11)),
                ],
              ],
            ),
          ),
          Icon(Icons.north_east, size: 15, color: k.colors.textMuted),
        ],
      ),
    );
  }
}
