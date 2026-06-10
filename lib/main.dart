import 'package:flutter/material.dart';

import 'app.dart';
import 'database/database.dart';
import 'services/attachment_service.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SettingsService.init();
  final database = await AppDatabase.getInstance();
  await NotificationService.init('AgentDock');
  // Housekeeping: drop pasted-image temp files older than 3 days.
  AttachmentService.cleanOldPastes();

  runApp(AgentCliApp(database: database));
}
