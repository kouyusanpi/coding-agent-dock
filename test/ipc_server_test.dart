import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:coding_agent_dock/services/ipc_server.dart';

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

    test('GET /v1/sessions exposes input field when set', () async {
      await server.start();
      server.onGetSessions = () => [
            const IpcSessionInfo(
              id: 3,
              name: 'write tests',
              agentId: 'claude',
              status: 'running',
              input: 'Write unit tests for auth module',
            ),
          ];
      final client = HttpClient();
      final req = await client.getUrl(
          Uri.parse('${server.baseUrl}/v1/sessions'));
      final resp = await req.close();
      final body =
          jsonDecode(await resp.transform(utf8.decoder).join()) as Map;
      final sessions = body['sessions'] as List;
      expect(sessions.first['input'], 'Write unit tests for auth module');
      client.close();
    });

    test('POST /v1/sessions calls onCreateSession and returns sessionId',
        () async {
      await server.start();
      String? capturedAgent;
      String? capturedInput;
      String? capturedDir;
      String? capturedName;
      server.onCreateSession = ({
        required agentId,
        required input,
        name,
        workingDirectory,
      }) async {
        capturedAgent = agentId;
        capturedInput = input;
        capturedDir = workingDirectory;
        capturedName = name;
        return 42;
      };

      final client = HttpClient();
      final req = await client.postUrl(
          Uri.parse('${server.baseUrl}/v1/sessions'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'agent': 'claude',
        'input': 'refactor the auth module',
        'workingDirectory': '/home/user/project',
        'name': 'auth refactor',
      }));
      final resp = await req.close();
      expect(resp.statusCode, 200);
      final body =
          jsonDecode(await resp.transform(utf8.decoder).join()) as Map;
      expect(body['sessionId'], 42);
      expect(capturedAgent, 'claude');
      expect(capturedInput, 'refactor the auth module');
      expect(capturedDir, '/home/user/project');
      expect(capturedName, 'auth refactor');
      client.close();
    });

    test('POST /v1/sessions returns 400 when agent or input missing', () async {
      await server.start();
      server.onCreateSession = ({
        required agentId,
        required input,
        name,
        workingDirectory,
      }) async =>
          1;

      final client = HttpClient();

      // Missing input
      final r1 = await client.postUrl(
          Uri.parse('${server.baseUrl}/v1/sessions'));
      r1.headers.contentType = ContentType.json;
      r1.write(jsonEncode({'agent': 'claude'}));
      final resp1 = await r1.close();
      expect(resp1.statusCode, 400);
      await resp1.drain<void>();

      // Missing agent
      final r2 = await client.postUrl(
          Uri.parse('${server.baseUrl}/v1/sessions'));
      r2.headers.contentType = ContentType.json;
      r2.write(jsonEncode({'input': 'do something'}));
      final resp2 = await r2.close();
      expect(resp2.statusCode, 400);
      await resp2.drain<void>();

      client.close();
    });

    test('POST /v1/sessions returns 404 when onCreateSession returns null',
        () async {
      await server.start();
      server.onCreateSession = ({
        required agentId,
        required input,
        name,
        workingDirectory,
      }) async =>
          null;

      final client = HttpClient();
      final req = await client.postUrl(
          Uri.parse('${server.baseUrl}/v1/sessions'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({'agent': 'unknown_cli', 'input': 'do it'}));
      final resp = await req.close();
      expect(resp.statusCode, 404);
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

    // ── KV store ─────────────────────────────────────────────────────────────

    Future<Map<String, dynamic>> kvGet(
        HttpClient c, String base, String key) async {
      final req = await c.getUrl(Uri.parse('$base/v1/kv/$key'));
      final resp = await req.close();
      final body = jsonDecode(await resp.transform(utf8.decoder).join())
          as Map<String, dynamic>;
      return {'status': resp.statusCode, ...body};
    }

    Future<int> kvSet(HttpClient c, String base, String key, String value,
        {int? ttl}) async {
      final req = await c.postUrl(Uri.parse('$base/v1/kv/$key'));
      req.headers.contentType = ContentType.json;
      final payload = <String, dynamic>{'value': value};
      if (ttl != null) payload['ttl'] = ttl;
      req.write(jsonEncode(payload));
      final resp = await req.close();
      await resp.drain<void>();
      return resp.statusCode;
    }

    Future<int> kvDel(HttpClient c, String base, String key) async {
      final req = await c.deleteUrl(Uri.parse('$base/v1/kv/$key'));
      final resp = await req.close();
      await resp.drain<void>();
      return resp.statusCode;
    }

    Future<List<String>> kvList(HttpClient c, String base) async {
      final req = await c.getUrl(Uri.parse('$base/v1/kv'));
      final resp = await req.close();
      final body = jsonDecode(await resp.transform(utf8.decoder).join()) as Map;
      return (body['keys'] as List).cast<String>();
    }

    test('GET /v1/kv returns empty list initially', () async {
      await server.start();
      final client = HttpClient();
      final keys = await kvList(client, server.baseUrl!);
      expect(keys, isEmpty);
      client.close();
    });

    test('POST /v1/kv/:key writes a value and GET reads it back', () async {
      await server.start();
      final client = HttpClient();
      await kvSet(client, server.baseUrl!, 'mykey', 'myval');
      final got = await kvGet(client, server.baseUrl!, 'mykey');
      expect(got['status'], 200);
      expect(got['key'], 'mykey');
      expect(got['value'], 'myval');
      client.close();
    });

    test('GET /v1/kv/:key returns 404 for missing key', () async {
      await server.start();
      final client = HttpClient();
      final got = await kvGet(client, server.baseUrl!, 'nosuchkey');
      expect(got['status'], 404);
      client.close();
    });

    test('DELETE /v1/kv/:key removes a key', () async {
      await server.start();
      final client = HttpClient();
      await kvSet(client, server.baseUrl!, 'toDelete', 'v');
      await kvDel(client, server.baseUrl!, 'toDelete');
      final got = await kvGet(client, server.baseUrl!, 'toDelete');
      expect(got['status'], 404);
      client.close();
    });

    test('DELETE /v1/kv/:key is idempotent', () async {
      await server.start();
      final client = HttpClient();
      expect(await kvDel(client, server.baseUrl!, 'nonexistent'), 200);
      expect(await kvDel(client, server.baseUrl!, 'nonexistent'), 200);
      client.close();
    });

    test('GET /v1/kv lists all written keys', () async {
      await server.start();
      final client = HttpClient();
      await kvSet(client, server.baseUrl!, 'alpha', '1');
      await kvSet(client, server.baseUrl!, 'beta', '2');
      await kvSet(client, server.baseUrl!, 'gamma', '3');
      final keys = await kvList(client, server.baseUrl!);
      expect(keys, containsAll(['alpha', 'beta', 'gamma']));
      expect(keys, hasLength(3));
      client.close();
    });

    test('GET /v1/kv does not list deleted keys', () async {
      await server.start();
      final client = HttpClient();
      await kvSet(client, server.baseUrl!, 'keep', '1');
      await kvSet(client, server.baseUrl!, 'gone', '2');
      await kvDel(client, server.baseUrl!, 'gone');
      final keys = await kvList(client, server.baseUrl!);
      expect(keys, contains('keep'));
      expect(keys, isNot(contains('gone')));
      client.close();
    });

    test('POST /v1/kv/:key overwrites an existing value', () async {
      await server.start();
      final client = HttpClient();
      await kvSet(client, server.baseUrl!, 'x', 'first');
      await kvSet(client, server.baseUrl!, 'x', 'second');
      final got = await kvGet(client, server.baseUrl!, 'x');
      expect(got['value'], 'second');
      client.close();
    });

    test('POST /v1/kv/:key with ttl=1 expires after delay', () async {
      await server.start();
      final client = HttpClient();
      await kvSet(client, server.baseUrl!, 'ephemeral', 'hi', ttl: 1);
      final before = await kvGet(client, server.baseUrl!, 'ephemeral');
      expect(before['status'], 200);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      final after = await kvGet(client, server.baseUrl!, 'ephemeral');
      expect(after['status'], 404);
      client.close();
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('expired key does not appear in GET /v1/kv list', () async {
      await server.start();
      final client = HttpClient();
      await kvSet(client, server.baseUrl!, 'live', 'yes');
      await kvSet(client, server.baseUrl!, 'dead', 'no', ttl: 1);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      final keys = await kvList(client, server.baseUrl!);
      expect(keys, contains('live'));
      expect(keys, isNot(contains('dead')));
      client.close();
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('GET /v1/kv/:key response includes expiresAt when TTL set', () async {
      await server.start();
      final client = HttpClient();
      await kvSet(client, server.baseUrl!, 'timed', 'val', ttl: 3600);
      final got = await kvGet(client, server.baseUrl!, 'timed');
      expect(got['status'], 200);
      expect(got['expiresAt'], isNotNull);
      final exp = DateTime.parse(got['expiresAt'] as String);
      expect(exp.isAfter(DateTime.now()), isTrue);
      client.close();
    });

    test('GET /v1/kv/:key has null expiresAt when no TTL', () async {
      await server.start();
      final client = HttpClient();
      await kvSet(client, server.baseUrl!, 'forever', 'val');
      final got = await kvGet(client, server.baseUrl!, 'forever');
      expect(got['expiresAt'], isNull);
      client.close();
    });

    test('loadKv restores persisted entries from a temp file', () async {
      await server.start();
      // Write a JSON file simulating a previous run's state.
      final tmp = await File('${Directory.systemTemp.path}/ad_kv_test.json')
          .writeAsString(jsonEncode({
        'persistent_key': {'value': 'hello', 'expiresAt': null},
        'expired_key': {
          'value': 'gone',
          'expiresAt': DateTime.now()
              .subtract(const Duration(seconds: 10))
              .toIso8601String(),
        },
      }));
      await server.loadKv(tmp.path);
      final client = HttpClient();
      // Persistent key survives.
      final got = await kvGet(client, server.baseUrl!, 'persistent_key');
      expect(got['status'], 200);
      expect(got['value'], 'hello');
      // Expired key is dropped on load.
      final expired = await kvGet(client, server.baseUrl!, 'expired_key');
      expect(expired['status'], 404);
      client.close();
      await tmp.delete();
    });
  });
}
