import 'dart:io';

import 'package:flutter/material.dart';

import '../database/database.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../utils/ansi_utils.dart';

/// Exports a task session as a Markdown file to the Desktop.
class ExportService {
  ExportService._();

  /// Build and write a Markdown export file, then show a snack bar.
  /// [liveOutput] is the raw PTY text for running sessions (overrides DB output).
  static Future<void> exportSession(
    BuildContext context,
    TaskSession session, {
    required String agentName,
    String? liveOutput,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final buf = _buildMarkdown(session, agentName, liveOutput, l10n);

    final home = Platform.environment['HOME'] ?? '';
    final safe = session.name.replaceAll(RegExp(r'[^\w\s-]'), '_');
    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = '$home/Desktop/agentdock-$safe-$ts.md';

    try {
      await File(path).writeAsString(buf);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.savedToDesktop(path.split('/').last)),
          duration: const Duration(seconds: 3),
          backgroundColor: AppColors.bg800,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.exportFailed('$e')),
          backgroundColor: AppColors.red500,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ));
      }
    }
  }

  static String _buildMarkdown(
    TaskSession s,
    String agentName,
    String? liveOutput,
    AppLocalizations l10n,
  ) {
    final buf = StringBuffer();
    buf.writeln('# ${s.name}');
    buf.writeln();
    buf.writeln('**${l10n.agentLabel}:** $agentName  ');
    buf.writeln('**${l10n.statusLabel}:** ${s.status}  ');
    if (s.workingDirectory != null && s.workingDirectory!.isNotEmpty) {
      buf.writeln('**${l10n.workingDirectory}:** `${s.workingDirectory}`  ');
    }
    buf.writeln('**${l10n.sessions}:** ${s.createdAt.toIso8601String()}  ');
    if (s.durationMs != null) {
      buf.writeln('**${l10n.duration}:** ${_fmtMs(s.durationMs!)}  ');
    }
    buf.writeln();
    if (s.input != null && s.input!.trim().isNotEmpty) {
      buf.writeln('---');
      buf.writeln();
      buf.writeln('## ${l10n.inputPrompt}');
      buf.writeln();
      buf.writeln(s.input!.trim());
      buf.writeln();
    }
    if (s.notes != null && s.notes!.isNotEmpty) {
      buf.writeln('---');
      buf.writeln();
      buf.writeln('## ${l10n.notes}');
      buf.writeln();
      buf.writeln(s.notes!.trim());
      buf.writeln();
    }

    final rawOutput = liveOutput ?? s.output;
    if (rawOutput != null && rawOutput.trim().isNotEmpty) {
      final clean = AnsiUtils.stripAnsi(rawOutput).trim();
      buf.writeln('---');
      buf.writeln();
      buf.writeln('## Output');
      buf.writeln();
      buf.writeln('```');
      buf.writeln(clean);
      buf.writeln('```');
    }
    return buf.toString();
  }

  static String _fmtMs(int ms) {
    if (ms < 1000) return '${ms}ms';
    final s = ms ~/ 1000;
    if (s < 60) return '${s}s';
    return '${s ~/ 60}m ${s % 60}s';
  }
}
