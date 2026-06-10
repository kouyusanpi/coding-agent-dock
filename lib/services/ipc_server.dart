import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Type of IPC event posted by an agent CLI.
enum IpcEventType {
  /// Agent CLI finished its session (mirrors the Stop hook in Claude Code).
  stop,
  /// Agent produced a structured result to share with the pipeline.
  result,
  /// Generic notification with arbitrary data.
  notify,
  /// Unknown/unparseable event type.
  unknown,
}

/// An event received via the local IPC HTTP server.
class IpcEvent {
  final int sessionId;
  final IpcEventType type;
  final Map<String, dynamic> data;

  const IpcEvent({
    required this.sessionId,
    required this.type,
    required this.data,
  });

  @override
  String toString() => 'IpcEvent(session=$sessionId, type=$type, data=$data)';
}

/// A running session entry returned by [IpcServer]'s `GET /v1/sessions`.
class IpcSessionInfo {
  final int id;
  final String name;
  final String agentId;
  final String status;
  final String? workingDirectory;
  final String? input;

  const IpcSessionInfo({
    required this.id,
    required this.name,
    required this.agentId,
    required this.status,
    this.workingDirectory,
    this.input,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'agent': agentId,
        'status': status,
        if (workingDirectory != null) 'workingDirectory': workingDirectory,
        if (input != null) 'input': input,
      };
}

/// Lightweight localhost HTTP server that agent CLIs can POST events to.
///
/// Binds to a random available port on 127.0.0.1. Each spawned PTY receives:
/// ```
///   AGENTDOCK_IPC_URL     = http://127.0.0.1:<port>/v1/sessions/<id>/events
///   AGENTDOCK_SESSION_ID  = <sessionId>
///   AGENTDOCK_API_BASE    = http://127.0.0.1:<port>/v1  (for discovery/inject)
/// ```
///
/// API:
///   POST /v1/sessions/:id/events
///     Body: {"type": "stop"|"result"|"notify", "data": {...}}
///     Response: 200 {"ok": true}
///
///   GET /v1/sessions
///     Response: 200 {"sessions": [{id, name, agent, status, workingDirectory?, input?}]}
///     Use from hooks/sub-processes to discover other running agents.
///
///   POST /v1/sessions
///     Body: {"agent": "claude", "input": "...", "workingDirectory": "...", "name": "..."}
///     Response: 200 {"sessionId": N}
///              | 400 {"error": "agent and input are required"}
///              | 404 {"error": "agent not found"}
///     Spawn a new agent session programmatically. 'agent' must be a known CLI
///     id (e.g. "claude", "codex"). 'name' and 'workingDirectory' are optional.
///     Powers `agentdock_spawn`.
///
///   GET /v1/sessions/:id
///     Response: 200 {id, name, agent, status, workingDirectory?, input?}
///              | 404 {"error": "session not found"}
///     Single session's current status — poll this to wait for another agent
///     to finish (status leaves 'running'). Powers `agentdock_wait`.
///
///   POST /v1/sessions/:id/inject
///     Body: {"text": "..."}
///     Response: 200 {"ok": true} | 404 {"error": "not found"}
///     Writes text directly into the target agent's PTY stdin — enables
///     agent-to-agent coordination without going through AgentDock UI.
///
///   GET /v1/sessions/:id/output?maxLines=N
///     Response: 200 {"sessionId": N, "lines": [...], "total": N}
///              | 404 {"error": "not found"}
///     Returns the last N lines (default 50) of the target session's terminal
///     buffer. Allows one agent to read another's output for context passing.
///
///   GET /v1/sessions/:id/output/stream
///     Response: text/event-stream  (SSE)
///       data: {"text": "..."}\n\n
///     Streams live PTY output as Server-Sent Events. Stays open until the
///     session ends or the client disconnects. Strip ANSI before using.
///
///   GET /v1/kv
///     Response: 200 {"keys": ["k1","k2",...]}
///     List all live (non-expired) keys in the shared KV store.
///
///   GET /v1/kv/:key
///     Response: 200 {"key":"k","value":"v","expiresAt":"ISO8601"|null}
///              | 404 {"error":"key not found"}
///     Read a single key. Expired entries are treated as missing.
///
///   POST /v1/kv/:key
///     Body: {"value": "...", "ttl": SECONDS (optional)}
///     Response: 200 {"ok":true}
///     Write a key. Optional TTL (integer seconds) makes it auto-expire.
///     Value is capped at 64 KB. Changes are flushed to disk when a
///     persistence path is set (see [loadKv]).
///
///   DELETE /v1/kv/:key
///     Response: 200 {"ok":true}
///     Delete a key. Idempotent. Flushes to disk if persistence is enabled.
///
/// Example Claude Code hook (in ~/.claude/settings.json):
///   "Stop": [{"matcher":"","hooks":[{"type":"command","command":
///     "curl -sf -X POST $AGENTDOCK_IPC_URL -H 'Content-Type: application/json'
///      -d '{\"type\":\"stop\"}' || true"}]}]

/// One entry in the IPC shared key-value store.
class _KvEntry {
  final String value;

  /// Wall-clock time after which this entry is considered expired (null = no TTL).
  final DateTime? expiresAt;

  _KvEntry(this.value, {Duration? ttl})
      : expiresAt = ttl == null ? null : DateTime.now().add(ttl);

  /// Reconstruct an entry with an absolute expiry time (used when loading from disk).
  _KvEntry.withExpiry(this.value, this.expiresAt);

  bool get expired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  Map<String, dynamic> toJson() => {
        'value': value,
        'expiresAt': expiresAt?.toIso8601String(),
      };
}

class IpcServer {
  HttpServer? _server;
  final _controller = StreamController<IpcEvent>.broadcast();

  /// In-process shared key-value store, accessible via the `/v1/kv` endpoints.
  ///
  /// Any agent session (or shell script via curl) can read/write named values.
  /// Values persist for the app lifetime (or until a per-key TTL expires).
  /// When [loadKv] is called with a path, changes are also flushed to disk.
  final Map<String, _KvEntry> _kv = <String, _KvEntry>{};

  /// Path where the KV store is persisted. Set by [loadKv].
  String? _kvPersistPath;

  /// Called for `GET /v1/sessions`. Return the current list of open sessions.
  List<IpcSessionInfo> Function()? onGetSessions;

  /// Called for `POST /v1/sessions`. Spawn a new session and return its DB id,
  /// or null when the requested agent id is unknown / the host widget is gone.
  Future<int?> Function({
    required String agentId,
    required String input,
    String? name,
    String? workingDirectory,
  })? onCreateSession;

  /// Called for `POST /v1/sessions/:id/inject`. Return true if the session was
  /// found and the text was written; false → 404 is returned to the caller.
  Future<bool> Function(int sessionId, String text)? onInject;

  /// Called for `GET /v1/sessions/:id/output`. Return the last [maxLines] lines
  /// of the session's terminal buffer, or null when the session is not found.
  List<String>? Function(int sessionId, int maxLines)? onGetOutput;

  /// Called for `GET /v1/sessions/:id/output/stream`. Return the live output
  /// [Stream] for the session, or null when the session is not found.
  Stream<String>? Function(int sessionId)? onSubscribeOutput;

  /// Stream of events received from agent CLIs.
  Stream<IpcEvent> get events => _controller.stream;

  /// The port this server is listening on, or null if not started.
  int? get port => _server?.port;

  /// Base URL for this server (e.g. http://127.0.0.1:54321).
  String? get baseUrl => port == null ? null : 'http://127.0.0.1:$port';

  /// Build the full event endpoint URL for a specific session.
  String? eventUrl(int sessionId) =>
      baseUrl == null ? null : '$baseUrl/v1/sessions/$sessionId/events';

  bool get isRunning => _server != null;

  /// Start listening on a random available localhost port.
  Future<void> start() async {
    if (_server != null) return;
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _serve(_server!);
  }

  /// Stop the server and close the event stream.
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    await _controller.close();
  }

  /// Load the KV store from [path] (JSON file) and enable disk persistence.
  ///
  /// Call this once after [start]. Expired entries are silently dropped on
  /// load. Subsequent writes/deletes flush the store back to the same path.
  /// Errors are swallowed — the in-memory store still works if the file
  /// can't be read or written.
  Future<void> loadKv(String path) async {
    _kvPersistPath = path;
    try {
      final file = File(path);
      if (!file.existsSync()) return;
      final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      for (final e in raw.entries) {
        final obj = e.value as Map<String, dynamic>?;
        if (obj == null) continue;
        final value = obj['value'] as String? ?? '';
        final expiresAtStr = obj['expiresAt'] as String?;
        final expiresAt =
            expiresAtStr != null ? DateTime.tryParse(expiresAtStr) : null;
        final entry = _KvEntry.withExpiry(value, expiresAt);
        if (!entry.expired) _kv[e.key] = entry;
      }
    } catch (_) {}
  }

  void _saveKv() {
    final path = _kvPersistPath;
    if (path == null) return;
    final live = _kvLive();
    final encoded = jsonEncode(
        live.map((k, v) => MapEntry(k, v.toJson())));
    File(path).parent.create(recursive: true).then((_) {
      File(path).writeAsString(encoded).catchError((_) => File(path));
    }).catchError((_) {});
  }

  /// Evict all expired KV entries and return the live (key → entry) map.
  Map<String, _KvEntry> _kvLive() {
    _kv.removeWhere((_, e) => e.expired);
    return _kv;
  }

  void _serve(HttpServer server) {
    server.listen(
      (req) async {
        try {
          await _handle(req);
        } catch (_) {
          req.response
            ..statusCode = HttpStatus.internalServerError
            ..close();
        }
      },
      onError: (_) {},
      cancelOnError: false,
    );
  }

  Future<void> _handle(HttpRequest req) async {
    final seg = req.uri.pathSegments;
    // seg[0] is always 'v1' for our API.
    if (seg.isEmpty || seg[0] != 'v1') {
      _notFound(req);
      return;
    }

    // GET /v1/sessions — agent discovery
    if (req.method == 'GET' && seg.length == 2 && seg[1] == 'sessions') {
      final infos = onGetSessions?.call() ?? [];
      _json(req, jsonEncode({'sessions': infos.map((s) => s.toJson()).toList()}));
      return;
    }

    // POST /v1/sessions — spawn a new agent session programmatically
    if (req.method == 'POST' && seg.length == 2 && seg[1] == 'sessions') {
      final rawBody = await req.fold<List<int>>(
          [], (acc, chunk) => acc..addAll(chunk));
      Map<String, dynamic> payload = {};
      try {
        payload = jsonDecode(utf8.decode(rawBody)) as Map<String, dynamic>;
      } catch (_) {}
      final agentId = payload['agent'] as String?;
      final input = payload['input'] as String?;
      if (agentId == null || agentId.isEmpty || input == null || input.isEmpty) {
        req.response
          ..statusCode = HttpStatus.badRequest
          ..headers.contentType = ContentType.json
          ..write('{"error":"agent and input are required"}')
          ..close();
        return;
      }
      final name = payload['name'] as String?;
      final workingDirectory = payload['workingDirectory'] as String?;
      final sessionId = await onCreateSession?.call(
        agentId: agentId,
        input: input,
        name: name,
        workingDirectory: workingDirectory,
      );
      if (sessionId == null) {
        req.response
          ..statusCode = HttpStatus.notFound
          ..headers.contentType = ContentType.json
          ..write('{"error":"agent not found"}')
          ..close();
        return;
      }
      _json(req, jsonEncode({'sessionId': sessionId}));
      return;
    }

    // GET /v1/sessions/:id — single session status (for wait/poll barriers)
    if (req.method == 'GET' && seg.length == 3 && seg[1] == 'sessions') {
      final sessionId = int.tryParse(seg[2]);
      if (sessionId == null) {
        req.response..statusCode = HttpStatus.badRequest..close();
        return;
      }
      final infos = onGetSessions?.call() ?? [];
      final match = infos.where((s) => s.id == sessionId).toList();
      if (match.isEmpty) {
        req.response
          ..statusCode = HttpStatus.notFound
          ..headers.contentType = ContentType.json
          ..write('{"error":"session not found"}')
          ..close();
        return;
      }
      _json(req, jsonEncode(match.first.toJson()));
      return;
    }

    // GET /v1/sessions/:id/output?maxLines=N — read terminal output snapshot
    if (req.method == 'GET' && seg.length == 4 && seg[1] == 'sessions' &&
        seg[3] == 'output') {
      final sessionId = int.tryParse(seg[2]);
      if (sessionId == null) {
        req.response..statusCode = HttpStatus.badRequest..close();
        return;
      }
      final maxLines =
          int.tryParse(req.uri.queryParameters['maxLines'] ?? '') ?? 50;
      final lines = onGetOutput?.call(sessionId, maxLines);
      if (lines == null) {
        req.response
          ..statusCode = HttpStatus.notFound
          ..headers.contentType = ContentType.json
          ..write('{"error":"session not found"}')
          ..close();
        return;
      }
      _json(req,
          jsonEncode({'sessionId': sessionId, 'lines': lines, 'total': lines.length}));
      return;
    }

    // GET /v1/sessions/:id/output/stream — SSE live output
    if (req.method == 'GET' && seg.length == 5 && seg[1] == 'sessions' &&
        seg[3] == 'output' && seg[4] == 'stream') {
      final sessionId = int.tryParse(seg[2]);
      if (sessionId == null) {
        req.response..statusCode = HttpStatus.badRequest..close();
        return;
      }
      final stream = onSubscribeOutput?.call(sessionId);
      if (stream == null) {
        req.response
          ..statusCode = HttpStatus.notFound
          ..headers.contentType = ContentType.json
          ..write('{"error":"session not found"}')
          ..close();
        return;
      }
      req.response.statusCode = HttpStatus.ok;
      req.response.headers.set('Content-Type', 'text/event-stream');
      req.response.headers.set('Cache-Control', 'no-cache');
      req.response.headers.set('Connection', 'keep-alive');
      // Send a handshake comment to flush the response headers to the client
      // immediately, before the first data event arrives.
      req.response.write(': connected\n\n');
      await req.response.flush();
      StreamSubscription<String>? sub;
      sub = stream.listen(
        (data) {
          try {
            req.response.write('data: ${jsonEncode({'text': data})}\n\n');
            req.response.flush();
          } catch (_) {
            sub?.cancel();
          }
        },
        onDone: () => req.response.close().catchError((_) {}),
        onError: (_) => req.response.close().catchError((_) {}),
      );
      // Hold the connection open until client disconnects or stream ends.
      await req.response.done.catchError((_) {});
      await sub.cancel();
      return;
    }

    // POST /v1/sessions/:id/events  OR  POST /v1/sessions/:id/inject
    if (req.method == 'POST' && seg.length == 4 && seg[1] == 'sessions') {
      final sessionId = int.tryParse(seg[2]);
      if (sessionId == null) {
        req.response..statusCode = HttpStatus.badRequest..close();
        return;
      }

      final body = await req.fold<List<int>>(
        [],
        (acc, chunk) => acc..addAll(chunk),
      );
      Map<String, dynamic> payload = {};
      try {
        payload = jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
      } catch (_) {}

      if (seg[3] == 'inject') {
        final text = payload['text'] as String? ?? '';
        final ok = await onInject?.call(sessionId, text) ?? false;
        if (!ok) {
          req.response
            ..statusCode = HttpStatus.notFound
            ..headers.contentType = ContentType.json
            ..write('{"error":"session not found"}')
            ..close();
          return;
        }
        _json(req, '{"ok":true}');
        return;
      }

      if (seg[3] == 'events') {
        final typeStr = payload['type'] as String? ?? 'notify';
        final type = switch (typeStr) {
          'stop' => IpcEventType.stop,
          'result' => IpcEventType.result,
          'notify' => IpcEventType.notify,
          _ => IpcEventType.unknown,
        };
        final data = (payload['data'] as Map<String, dynamic>?) ?? {};
        if (!_controller.isClosed) {
          _controller.add(IpcEvent(sessionId: sessionId, type: type, data: data));
        }
        _json(req, '{"ok":true}');
        return;
      }
    }

    // ── KV store endpoints ────────────────────────────────────────────────
    if (seg.length >= 2 && seg[1] == 'kv') {
      await _handleKv(req, seg);
      return;
    }

    _notFound(req);
  }

  Future<void> _handleKv(HttpRequest req, List<String> seg) async {
    // GET /v1/kv — list all live keys
    if (req.method == 'GET' && seg.length == 2) {
      final live = _kvLive();
      _json(req, jsonEncode({'keys': live.keys.toList()}));
      return;
    }

    if (seg.length < 3) {
      req.response..statusCode = HttpStatus.badRequest..close();
      return;
    }
    final key = Uri.decodeComponent(seg[2]);

    // GET /v1/kv/:key
    if (req.method == 'GET') {
      final entry = _kvLive()[key];
      if (entry == null) {
        req.response
          ..statusCode = HttpStatus.notFound
          ..headers.contentType = ContentType.json
          ..write('{"error":"key not found"}')
          ..close();
        return;
      }
      _json(req, jsonEncode({
        'key': key,
        'value': entry.value,
        'expiresAt': entry.expiresAt?.toIso8601String(),
      }));
      return;
    }

    // POST /v1/kv/:key
    if (req.method == 'POST') {
      final raw = await req.fold<List<int>>(
          [], (acc, chunk) => acc..addAll(chunk));
      Map<String, dynamic> payload = {};
      try {
        payload = jsonDecode(utf8.decode(raw)) as Map<String, dynamic>;
      } catch (_) {}
      final rawVal = payload['value'] as String? ?? '';
      final value = rawVal.substring(0, rawVal.length.clamp(0, 64 * 1024));
      final ttlSecs = (payload['ttl'] as num?)?.toInt();
      final ttl = ttlSecs != null && ttlSecs > 0
          ? Duration(seconds: ttlSecs)
          : null;
      _kv[key] = _KvEntry(value, ttl: ttl);
      _saveKv();
      _json(req, '{"ok":true}');
      return;
    }

    // DELETE /v1/kv/:key
    if (req.method == 'DELETE') {
      _kv.remove(key);
      _saveKv();
      _json(req, '{"ok":true}');
      return;
    }

    req.response..statusCode = HttpStatus.methodNotAllowed..close();
  }

  void _json(HttpRequest req, String body) {
    req.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(body)
      ..close();
  }

  void _notFound(HttpRequest req) {
    req.response..statusCode = HttpStatus.notFound..close();
  }
}
