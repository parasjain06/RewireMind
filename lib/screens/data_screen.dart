import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../content/app_content.dart';
import '../data/history_export.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/bullet_list.dart';
import '../widgets/k_card.dart';
import '../content/premium_content.dart';
import '../widgets/premium_gate.dart';

/// Getting your history out of the app, and back into it.
///
/// The app keeps everything on the phone and talks to no server, which is the
/// right default and also means a lost phone is a lost history. This screen is
/// the answer to that: a file you own, that you put somewhere you trust.
class DataScreen extends StatelessWidget {
  const DataScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const DataScreen()));
  }

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
            AppContent.dataTitle,
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
          children: const [
            _Intro(),
            SizedBox(height: 14),
            _ExportCard(),
            SizedBox(height: 10),
            _ImportCard(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final state = context.watch<AppState>();

    return KCard(
      soft: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppContent.dataIntroTitle, style: k.text.cardTitle),
          const SizedBox(height: 6),
          BulletList(
            points: AppContent.dataIntroPoints(
              state.everyHabit.length,
              state.checkInCount,
            ),
          ),
        ],
      ),
    );
  }
}

/// Everything since the first day, as a spreadsheet or a report.
///
/// Asks which first: a spreadsheet is for sorting and filtering, a PDF is for
/// reading, printing and sending to somebody, and they are different enough
/// that guessing would be wrong half the time.
class _ExportCard extends StatelessWidget {
  const _ExportCard();

  Future<void> _run(BuildContext context) async {
    final format = await showModalBottomSheet<_Format>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _FormatSheet(),
    );
    if (format == null || !context.mounted) return;

    final state = context.read<AppState>();
    // Dated, so a folder of these sorts itself and you can tell at a glance
    // which one is the recent one.
    final stamp = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final name = 'rewiremind-history-$stamp.${format.extension}';

    final Uint8List bytes;
    switch (format) {
      case _Format.excel:
        // The photo goes in too, so an import brings the face back as well.
        final path = state.profile.photoPath;
        bytes = HistoryExport.excel(
          state,
          photo: path != null && File(path).existsSync()
              ? await File(path).readAsBytes()
              : null,
        );
      case _Format.pdf:
        final bundle = DefaultAssetBundle.of(context);
        final regular = await bundle.load('assets/fonts/Poppins-Regular.ttf');
        final bold = await bundle.load('assets/fonts/Poppins-SemiBold.ttf');
        // The profile photo goes on the front of the report, when there is
        // one and it is still where it was saved.
        final path = state.profile.photoPath;
        final photo = path != null && File(path).existsSync()
            ? await File(path).readAsBytes()
            : null;
        bytes = await HistoryExport.pdf(
          state,
          regular: regular,
          bold: bold,
          photo: photo,
        );
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes);

    if (!context.mounted) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: format.mime)],
        fileNameOverrides: [name],
        subject: AppContent.dataExportSubject,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _Row(
    icon: Icons.ios_share,
    title: AppContent.dataExportTitle,
    body: AppContent.dataExportBody,
    onTap: () => _run(context),
  );
}

/// Puts back everything from an Excel file this app exported.
class _ImportCard extends StatelessWidget {
  const _ImportCard();

  Future<void> _run(BuildContext context) =>
      ifPremium(context, PremiumContent.lockedImport, () => _import(context));

  Future<void> _import(BuildContext context) async {
    final k = context.k;
    final state = context.read<AppState>();

    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
    );
    if (picked == null || !context.mounted) return;

    final raw = HistoryExport.backupFrom(await picked.readAsBytes());
    final backup = raw == null ? null : AppState.inspectBackup(raw);
    if (!context.mounted) return;
    if (backup == null) {
      await showAppSnackBar(
        context,
        message: AppContent.dataImportUnreadable,
        duration: const Duration(seconds: 5),
      );
      return;
    }

    // Replaces rather than merges, so it says so and waits for a yes.
    final go = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: k.colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(k.geometry.cardRadius),
        ),
        title: Text(AppContent.dataImportTitle, style: k.text.cardTitle),
        content: Text(
          AppContent.dataImportConfirm(
            habits: backup.habits,
            checkIns: backup.checkIns,
            takenAt: backup.takenAt,
            name: backup.name,
          ),
          style: k.text.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Cancel',
              style: k.text.captionStrong.copyWith(
                color: k.colors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              AppContent.dataImportAction,
              style: k.text.captionStrong.copyWith(color: k.colors.primary),
            ),
          ),
        ],
      ),
    );
    if (go != true) return;

    // The photo, where the file carried one, saved on this phone first so
    // the profile points at a picture that is actually here.
    final photo = backup.json['photo'];
    if (photo is String && photo.isNotEmpty) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final at = DateTime.now().millisecondsSinceEpoch;
        final saved = File('${dir.path}/avatar_$at.png');
        await saved.writeAsBytes(base64Decode(photo));
        final profile = backup.json['profile'];
        if (profile is Map<String, dynamic>) profile['photoPath'] = saved.path;
      } catch (_) {
        // No photo, then; the rest still comes back.
      }
    } else {
      final profile = backup.json['profile'];
      if (profile is Map<String, dynamic>) profile.remove('photoPath');
    }

    await state.restoreBackup(backup);
    if (!context.mounted) return;
    await showAppSnackBar(
      context,
      message: AppContent.dataImported(backup.habits),
    );
  }

  @override
  Widget build(BuildContext context) => _Row(
    icon: Icons.file_download_outlined,
    title: AppContent.dataImportTitle,
    body: AppContent.dataImportBody,
    onTap: () => _run(context),
  );
}

enum _Format {
  excel(
    'xlsx',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  ),
  pdf('pdf', 'application/pdf');

  const _Format(this.extension, this.mime);

  final String extension;
  final String mime;
}

/// The two choices, and what each one is for.
class _FormatSheet extends StatelessWidget {
  const _FormatSheet();

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    Widget option(_Format format, IconData icon, String title, String body) =>
        Material(
          color: k.colors.surfaceSoft,
          borderRadius: BorderRadius.circular(k.geometry.innerRadius),
          child: InkWell(
            borderRadius: BorderRadius.circular(k.geometry.innerRadius),
            onTap: () => Navigator.of(context).pop(format),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(icon, color: k.colors.primary, size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: k.text.cardTitle),
                        const SizedBox(height: 2),
                        Text(body, style: k.text.caption),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: k.colors.textMuted),
                ],
              ),
            ),
          ),
        );

    return Container(
      decoration: BoxDecoration(
        color: k.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: k.colors.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(AppContent.dataFormatTitle, style: k.text.sectionTitle),
              const SizedBox(height: 4),
              Text(AppContent.dataFormatBody, style: k.text.caption),
              const SizedBox(height: 14),
              option(
                _Format.excel,
                Icons.table_chart_outlined,
                AppContent.dataFormatExcel,
                AppContent.dataFormatExcelBody,
              ),
              const SizedBox(height: 10),
              option(
                _Format.pdf,
                Icons.picture_as_pdf_outlined,
                AppContent.dataFormatPdf,
                AppContent.dataFormatPdfBody,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.k;

    return KCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: k.colors.primary),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: k.text.cardTitle.copyWith(fontSize: 14)),
                const SizedBox(height: 3),
                Text(body, style: k.text.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
