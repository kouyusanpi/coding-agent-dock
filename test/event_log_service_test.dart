import 'package:flutter_test/flutter_test.dart';

import 'package:claude_code_cli_flutter/services/event_log_service.dart';

void main() {
  group('EventLogService', () {
    late EventLogService log;

    setUp(() => log = EventLogService());
    tearDown(() => log.dispose());

    test('starts empty', () {
      expect(log.count, 0);
      expect(log.events, isEmpty);
      expect(log.errorCount, 0);
    });

    test('log() adds an entry with correct fields', () {
      log.log(
        ClusterEventKind.sessionStarted,
        sessionName: 'my-session',
        detail: 'some detail',
      );
      expect(log.count, 1);
      final e = log.events.first;
      expect(e.kind, ClusterEventKind.sessionStarted);
      expect(e.sessionName, 'my-session');
      expect(e.detail, 'some detail');
    });

    test('log() without detail sets detail to null', () {
      log.log(ClusterEventKind.sessionCompleted, sessionName: 'x');
      expect(log.events.first.detail, isNull);
    });

    test('recent() returns newest first', () {
      log.log(ClusterEventKind.sessionStarted, sessionName: 'first');
      log.log(ClusterEventKind.sessionCompleted, sessionName: 'second');
      final r = log.recent(count: 10);
      expect(r.first.sessionName, 'second');
      expect(r.last.sessionName, 'first');
    });

    test('recent() limits to count', () {
      for (var i = 0; i < 10; i++) {
        log.log(ClusterEventKind.sessionStarted, sessionName: 's$i');
      }
      expect(log.recent(count: 3).length, 3);
    });

    test('errorCount counts failed and watchdogExhausted', () {
      log.log(ClusterEventKind.sessionFailed, sessionName: 'a');
      log.log(ClusterEventKind.watchdogExhausted, sessionName: 'b');
      log.log(ClusterEventKind.sessionCompleted, sessionName: 'c');
      expect(log.errorCount, 2);
    });

    test('clear() empties events and notifies', () {
      log.log(ClusterEventKind.sessionStarted, sessionName: 'x');
      var notified = false;
      log.addListener(() => notified = true);
      log.clear();
      expect(log.count, 0);
      expect(notified, isTrue);
    });

    test('notifies listeners when a log entry is added', () {
      var notified = false;
      log.addListener(() => notified = true);
      log.log(ClusterEventKind.sessionStarted, sessionName: 'x');
      expect(notified, isTrue);
    });

    test('caps at 200 entries', () {
      for (var i = 0; i < 210; i++) {
        log.log(ClusterEventKind.sessionStarted, sessionName: 's$i');
      }
      expect(log.count, 200);
      // Most recent entries should survive
      expect(log.events.last.sessionName, 's209');
    });

    group('ClusterEvent.kindLabel', () {
      for (final pair in [
        (ClusterEventKind.sessionStarted, 'started'),
        (ClusterEventKind.sessionCompleted, 'completed'),
        (ClusterEventKind.sessionFailed, 'failed'),
        (ClusterEventKind.sessionCancelled, 'cancelled'),
        (ClusterEventKind.ipcStop, 'IPC stop'),
        (ClusterEventKind.ipcResult, 'IPC result'),
        (ClusterEventKind.ipcNotify, 'IPC notify'),
        (ClusterEventKind.pipelineRelay, 'relayed'),
        (ClusterEventKind.watchdogRetry, 'watchdog retry'),
        (ClusterEventKind.watchdogExhausted, 'watchdog exhausted'),
        (ClusterEventKind.memorySync, 'memory sync'),
      ]) {
        test('${pair.$1} → "${pair.$2}"', () {
          final ev = ClusterEvent(
            kind: pair.$1,
            timestamp: DateTime.now(),
            sessionName: 'x',
          );
          expect(ev.kindLabel, pair.$2);
        });
      }
    });

    group('ClusterEvent.isError / isSuccess / isInfo', () {
      test('sessionFailed is error', () {
        final e = ClusterEvent(
            kind: ClusterEventKind.sessionFailed,
            timestamp: DateTime.now(),
            sessionName: 'x');
        expect(e.isError, isTrue);
        expect(e.isSuccess, isFalse);
        expect(e.isInfo, isFalse);
      });

      test('sessionCompleted is success', () {
        final e = ClusterEvent(
            kind: ClusterEventKind.sessionCompleted,
            timestamp: DateTime.now(),
            sessionName: 'x');
        expect(e.isError, isFalse);
        expect(e.isSuccess, isTrue);
        expect(e.isInfo, isFalse);
      });

      test('ipcNotify is info', () {
        final e = ClusterEvent(
            kind: ClusterEventKind.ipcNotify,
            timestamp: DateTime.now(),
            sessionName: 'x');
        expect(e.isError, isFalse);
        expect(e.isSuccess, isFalse);
        expect(e.isInfo, isTrue);
      });
    });
  });
}
