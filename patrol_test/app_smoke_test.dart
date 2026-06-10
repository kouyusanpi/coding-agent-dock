import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'package:coding_agent_dock/app.dart';
import 'package:coding_agent_dock/database/database.dart';
import 'package:coding_agent_dock/screens/new_session_dialog.dart';
import 'package:coding_agent_dock/services/settings_service.dart';

void main() {
  patrolTest('app boots, detects CLIs and shows the home screen',
      ($) async {
    await SettingsService.init();
    final database = await AppDatabase.getInstance();

    await $.pumpWidgetAndSettle(AgentCliApp(database: database));

    // Sidebar lists the known agents (displayName is locale-independent).
    await $('Claude Code').waitUntilVisible();
    expect($('Gemini CLI'), findsOneWidget);

    // Selecting an agent shows its sessions page.
    await $('Claude Code').tap();
    expect($(Icons.terminal), findsWidgets);
  });

  patrolTest('new session dialog opens and can be dismissed', ($) async {
    await SettingsService.init();
    final database = await AppDatabase.getInstance();

    await $.pumpWidgetAndSettle(AgentCliApp(database: database));
    await $('Claude Code').waitUntilVisible();

    // Bottom "Initialize New ... Session" button opens the dialog.
    await $(OutlinedButton).tap();
    expect($(NewSessionDialog), findsOneWidget);

    // Dismiss via the dialog's cancel button (first TextButton).
    // Note: the home screen keeps its own search TextField, so assert on
    // the dialog widget itself rather than on TextField count.
    await $(TextButton).first.tap();
    expect($(NewSessionDialog), findsNothing);
  });
}
