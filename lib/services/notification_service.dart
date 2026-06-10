import 'package:flutter/services.dart';

import 'settings_service.dart';

/// Sends macOS system notifications for task lifecycle events via the
/// native `agentdock/notifications` MethodChannel (UNUserNotificationCenter).
///
/// The native side requests authorization lazily on the first notification
/// and skips posting while the app is active (the in-app status dots and
/// unread indicators cover the foreground case).
class NotificationService {
  NotificationService._();

  static const MethodChannel _channel =
      MethodChannel('agentdock/notifications');

  static Future<void> init(String appName) async {}

  static Future<void> taskFinished({
    required String taskName,
    required String agentName,
    required String status,
  }) async {
    if (!SettingsService.notificationsEnabled) return;
    final emoji = switch (status) {
      'completed' => '✅',
      'failed' => '❌',
      _ => 'ℹ️',
    };
    try {
      await _channel.invokeMethod('show', {
        'title': '$emoji $taskName',
        'body': '$agentName · $status',
        'onlyWhenInactive': true,
      });
    } catch (_) {
      // MissingPluginException in tests / non-macOS — notifications are
      // best-effort, never break the exit flow.
    }
  }
}
