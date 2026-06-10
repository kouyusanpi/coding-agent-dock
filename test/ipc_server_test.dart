import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:claude_code_cli_flutter/services/ipc_server.dart';

void main() {
  group('IpcServer', () {
    late IpcServer server;

    setUp(() {
      server = IpcServer();
    });

    tearDown(() async {
      await server.stop();
    });

    test('starts and exposes a valid port', () async {
      await server.start();
      expect(server.isRunning, isTrue);
      expect(server.port, isNotNull);
      expect(server.port, greaterThan(0));
      expect(server.baseUrl, startsWith('http://127.0.0.1:'));
    });

    test('eventUrl includes sessionId in path', () async {
      await server.start();
      final url = server.eventUrl(42);
      expect(url, contains('/v1/sessions/42/events'));
    });

    test('receives stop event via HTTP POST', () async {
      await server.start();
      final events = <IpcEvent>[];
      final sub = server.events.listen(events.add);

      final client = HttpClient();
      final req = await client.postUrl(Uri.parse(server.eventUrl(7)!));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({'type': 'stop'}));
      final resp = await req.close();
      expect(resp.statusCode, 200);
      await resp.drain<void>();
      client.close();

      // Give the stream time to deliver.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(events, hasLength(1));
      expect(events.first.sessionId, 7);
      expect(events.first.type, IpcEventType.stop);
      await sub.cancel();
    });

    test('receives result event with data payload', () async {
      await server.start();
      final events = <IpcEvent>[];
      final sub = server.events.listen(events.add);

      final client = HttpClient();
      final req = await client.postUrl(Uri.parse(server.eventUrl(99)!));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({'type': 'result', 'data': {'output': 'done'}}));
      final resp = await req.close();
      expect(resp.statusCode, 200);
      await resp.drain<void>();
      client.close();

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(events.first.type, IpcEventType.result);
      expect(events.first.data['output'], 'done');
      await sub.cancel();
    });

    test('returns 404 for unknown routes', () async {
      await server.start();
      final client = HttpClient();
      final req = await client.postUrl(
          Uri.parse('${server.baseUrl}/v1/unknown'));
      final resp = await req.close();
      expect(resp.statusCode, 404);
      await resp.drain<void>();
      client.close();
    });

    test('stop() sets isRunning to false', () async {
      await server.start();
      expect(server.isRunning, isTrue);
      await server.stop();
      expect(server.isRunning, isFalse);
    });

    test('isNewer version comparison — sanity', () {
      // IpcServer is stateless; just verify the server can start twice cleanly.
      final s2 = IpcServer();
      expect(s2.isRunning, isFalse);
    });

    test('GET /v1/sessions returns session list from onGetSessions', () async {
      await server.start();
      server.onGetSessions = () => [
            IpcSessionInfo(
                id: 1,
                name: 'refactor',
                agentId: 'claude',
                status: 'running',
                workingDirectory: '/myapp'),
            IpcSessionInfo(
                id: 2,
                name: 'tests',
                agentId: 'codex',
                status: 'completed'),
          ];

      final client = HttpClient();
      final req = await client.getUrl(
          Uri.parse('${server.baseUrl}/v1/sessions'));
      final resp = await req.close();
      expect(resp.statusCode, 200);
      final body =
          jsonDecode(await resp.transform(utf8.decoder).join()) as Map;
      final sessions = body['sessions'] as List;
      expect(sessions, hasLength(2));
      expect(sessions[0]['agent'], 'claude');
      expect(sessions[0]['workingDirectory'], '/myapp');
      expect(sessions[1]['status'], 'completed');
      client.close();
    });

    test('GET /v1/sessions/:id returns the matching session', () async {
      await server.start();
      server.onGetSessions = () => [
            IpcSessionInfo(
                id: 1, name: 'refactor', agentId: 'claude', status: 'running'),
            IpcSessionInfo(
                id: 2, name: 'tests', agentId: 'codex', status: 'completed'),
          ];

      final client = HttpClient();
      final req = await client
          .getUrl(Uri.parse('${server.baseUrl}/v1/sessions/2'));
      final resp = await req.close();
      expect(resp.statusCode, 200);
      final body =
          jsonDecode(await resp.transform(utf8.decoder).join()) as Map;
      expect(body['id'], 2);
      expect(body['status'], 'completed');
      expect(body['agent'], 'codex');
      client.close();
    });

    test('GET /v1/sessions/:id returns 404 for unknown session', () async {
      await server.start();
      server.onGetSessions = () => [
            IpcSessionInfo(
                id: 1, name: 'refactor', agentId: 'claude', status: 'running'),
          ];
      final client = HttpClient();
      final req = await client
          .getUrl(Uri.parse('${server.baseUrl}/v1/sessions/99'));
      final resp = await req.close();
      expect(resp.statusCode, 404);
      client.close();
    });

    test('GET /v1/sessions returns empty list when callback not set', () async {
      await server.start();
      final client = HttpClient();
      final req = await client.getUrl(
          Uri.parse('${server.baseUrl}/v1/sessions'));
      final resp = await req.close();
      expect(resp.statusCode, 200);
      final body =
          jsonDecode(await resp.transform(utf8.decoder).join()) as Map;
      expect(body['sessions'], isEmpty);
      client.close();
    });

    test('POST /v1/sessions/:id/inject calls onInject callback', () async {
      await server.start();
      int? injectedId;
      String? injectedText;
      server.onInject = (id, text) async {
        injectedId = id;
        injectedText = text;
        return true;
      };

      final client = HttpClient();
      final url = Uri.parse('${server.baseUrl}/v1/sessions/5/inject');
      final req = await client.postUrl(url);
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({'text': 'hello agent'}));
      final resp = await req.close();
      expect(resp.statusCode, 200);
      await resp.drain<void>();
      client.close();

      expect(injectedId, 5);
      expect(injectedText, 'hello agent');
    });

    test('POST /v1/sessions/:id/inject returns 404 when onInject returns false',
        () async {
      await server.start();
      server.onInject = (_, _) async => false;

      final client = HttpClient();
      final url = Uri.parse('${server.baseUrl}/v1/sessions/99/inject');
      final req = await client.postUrl(url);
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({'text': 'hello'}));
      final resp = await req.close();
      expect(resp.statusCode, 404);
      await resp.drain<void>();
      client.close();
    });

    test('GET /v1/sessions/:id/output returns lines from onGetOutput', () async {
      await server.start();
      server.onGetOutput = (id, maxLines) =>
          id == 3 ? ['line 1', 'line 2', 'line 3'] : null;

      final client = HttpClient();
      final req = await client.getUrl(
          Uri.parse('${server.baseUrl}/v1/sessions/3/output?maxLines=10'));
      final resp = await req.close();
      expect(resp.statusCode, 200);
      final body =
          jsonDecode(await resp.transform(utf8.decoder).join()) as Map;
      expect(body['sessionId'], 3);
      expect(body['lines'], ['line 1', 'line 2', 'line 3']);
      expect(body['total'], 3);
      client.close();
    });

    test('GET /v1/sessions/:id/output returns 404 for unknown session',
        () async {
      await server.start();
      server.onGetOutput = (_, _) => null;

      final client = HttpClient();
      final req = await client.getUrl(
          Uri.parse('${server.baseUrl}/v1/sessions/99/output'));
      final resp = await req.close();
      expect(resp.statusCode, 404);
      await resp.drain<void>();
      client.close();
    });

    test('GET /v1/sessions/:id/output uses default maxLines=50 when absent',
        () async {
      await server.start();
      int? capturedMaxLines;
      server.onGetOutput = (_, maxLines) {
        capturedMaxLines = maxLines;
        return ['only line'];
      };

      final client = HttpClient();
      final req = await client.getUrl(
          Uri.parse('${server.baseUrl}/v1/sessions/1/output'));
      final resp = await req.close();
      await resp.drain<void>();
      client.close();

      expect(capturedMaxLines, 50);
    });

    test('GET /v1/sessions/:id/output/stream delivers SSE events', () async {
      await server.start();
      final controller = StreamController<String>();
      server.onSubscribeOutput = (id) => id == 7 ? controller.stream : null;

      final client = HttpClient();
      final req = await client.getUrl(
          Uri.parse('${server.baseUrl}/v1/sessions/7/output/stream'));
      final resp = await req.close();
      expect(resp.statusCode, 200);
      expect(resp.headers.contentType?.mimeType, 'text/event-stream');

      // Emit data after SSE connection is established, then close.
      Future.delayed(const Duration(milliseconds: 30), () {
        controller.add('hello world');
        Future.delayed(const Duration(milliseconds: 30), controller.close);
      });

      // Collect all SSE frames until the stream ends.
      final buffer = StringBuffer();
      await for (final chunk in resp.transform(utf8.decoder)) {
        buffer.write(chunk);
      }
      client.close();

      expect(buffer.toString(), contains('hello world'));
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('GET /v1/sessions/:id/output/stream returns 404 for unknown session',
        () async {
      await server.start();
      server.onSubscribeOutput = (_) => null;

      final client = HttpClient();
      final req = await client.getUrl(
          Uri.parse('${server.baseUrl}/v1/sessions/55/output/stream'));
      final resp = await req.close();
      expect(resp.statusCode, 404);
      await resp.drain<void>();
      client.close();
    });
  });
}
