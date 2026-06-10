import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Writes `~/.agentdock/helpers.sh` — a Bash source-able file containing
/// convenience wrappers for the AgentDock Cluster API.
///
/// The file is regenerated on every IPC server start so it stays in sync with
/// any API changes. It is port-agnostic: all functions reference
/// `$AGENTDOCK_API_BASE` and `$AGENTDOCK_IPC_URL`, which AgentDock injects
/// into every spawned PTY as environment variables.
///
/// Agents can source the file from a Claude Code hook or bash script:
///   source "$AGENTDOCK_HELPERS"
class HelpersScriptService {
  HelpersScriptService._();

  static const _dirName = '.agentdock';
  static const _fileName = 'helpers.sh';

  /// Absolute path where the helpers script is written.
  static String get path {
    final home = Platform.environment['HOME'] ?? '';
    return p.join(home, _dirName, _fileName);
  }

  /// Absolute path for the persistent KV store JSON file.
  static String get kvStorePath {
    final home = Platform.environment['HOME'] ?? '';
    return p.join(home, _dirName, 'kv.json');
  }

  /// Write (or overwrite) the helpers script. Silently no-ops on failure.
  static Future<void> write() async {
    try {
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsString(script, flush: true);
      // Make it executable.
      await Process.run('chmod', ['+x', file.path]);
    } catch (_) {}
  }

  @visibleForTesting
  static const script = r'''#!/usr/bin/env bash
# AgentDock Cluster API helpers — auto-generated on each launch.
# Source this file from Claude Code hooks or shell scripts:
#   source "$AGENTDOCK_HELPERS"
#
# Required env vars (auto-injected into every AgentDock PTY):
#   AGENTDOCK_API_BASE   — base URL, e.g. http://127.0.0.1:PORT/v1
#   AGENTDOCK_IPC_URL    — your session's event endpoint
#   AGENTDOCK_SESSION_ID — your session ID

# --- Internal: JSON field extractor (jq if available, otherwise python3) ---
# Usage: _ad_json FIELD [JSON_STRING]
# If JSON_STRING is omitted, reads from stdin.
_ad_json() {
  local field="$1"
  local input
  if [[ $# -ge 2 ]]; then
    input="$2"
  else
    input="$(cat)"
  fi
  if command -v jq &>/dev/null; then
    printf '%s' "$input" | jq -r ".${field} // empty" 2>/dev/null
  else
    printf '%s' "$input" | \
      python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('${field}',''), end='')" \
      2>/dev/null
  fi
}

# --- Internal: extract array of values from a JSON array of objects ---
# Usage: _ad_json_arr FIELD FILTER_KEY FILTER_VAL [JSON_STRING]
_ad_json_arr() {
  local field="$1" fk="$2" fv="$3"
  local input
  if [[ $# -ge 4 ]]; then input="$4"; else input="$(cat)"; fi
  if command -v jq &>/dev/null; then
    printf '%s' "$input" | \
      jq -r ".${field}[] | select(.${fk}==\"${fv}\") | .id" 2>/dev/null
  else
    printf '%s' "$input" | \
      python3 -c "
import sys,json
data=json.loads(sys.stdin.read())
[print(s['id']) for s in data.get('${field}',[]) if s.get('${fk}')==sys.argv[1]]
" "$fv" 2>/dev/null
  fi
}

# List all running agent sessions (JSON).
agentdock_list() {
  curl -sf "${AGENTDOCK_API_BASE}/sessions"
}

# Fetch a single session's current status object (JSON).
# Usage: agentdock_status SESSION_ID
agentdock_status() {
  local id="${1:?Usage: agentdock_status SESSION_ID}"
  curl -sf "${AGENTDOCK_API_BASE}/sessions/${id}"
}

# Block until a session is no longer running, then print its final status.
# Useful for "dispatch work to another agent, then continue once it's done".
# Usage: agentdock_wait SESSION_ID [TIMEOUT_SECONDS] [POLL_SECONDS]
#   TIMEOUT_SECONDS — give up after this long (default 600; 0 = no timeout)
#   POLL_SECONDS    — interval between checks (default 2)
# Returns 0 when the session finishes, 1 on timeout, 2 if it vanishes.
agentdock_wait() {
  local id="${1:?Usage: agentdock_wait SESSION_ID [TIMEOUT] [POLL]}"
  local timeout="${2:-600}"
  local poll="${3:-2}"
  # Declare loop locals ONCE up front: re-running `local` inside the loop
  # makes zsh echo the variable (typeset behaviour). 'status' is also a
  # read-only special var in zsh, so use 'sess_status'.
  local elapsed=0 body sess_status
  while true; do
    body="$(agentdock_status "$id" 2>/dev/null)"
    if [[ -z "$body" ]]; then
      echo "session $id not found" >&2
      return 2
    fi
    sess_status="$(_ad_json status "$body")"
    if [[ -n "$sess_status" && "$sess_status" != "running" ]]; then
      printf '%s\n' "$sess_status"
      return 0
    fi
    if [[ "$timeout" != "0" && "$elapsed" -ge "$timeout" ]]; then
      echo "timeout waiting for session $id" >&2
      return 1
    fi
    sleep "$poll"
    elapsed=$((elapsed + poll))
  done
}

# Read the last N lines of a session's output (JSON).
# Usage: agentdock_output SESSION_ID [MAX_LINES]
agentdock_output() {
  local id="${1:?Usage: agentdock_output SESSION_ID [MAX_LINES]}"
  local lines="${2:-50}"
  curl -sf "${AGENTDOCK_API_BASE}/sessions/${id}/output?maxLines=${lines}"
}

# Stream a session's live output (SSE), printing text lines only.
# Usage: agentdock_stream SESSION_ID
agentdock_stream() {
  local id="${1:?Usage: agentdock_stream SESSION_ID}"
  curl -sf "${AGENTDOCK_API_BASE}/sessions/${id}/output/stream" | \
    while IFS= read -r line; do
      if [[ "$line" == data:* ]]; then
        local payload="${line#data: }"
        local text
        text="$(_ad_json text "$payload")"
        if [[ -n "$text" ]]; then
          printf '%s' "$text"
        else
          printf '%s\n' "$payload"
        fi
      fi
    done
}

# Inject a message into a running session's stdin.
# Usage: agentdock_inject SESSION_ID "message"
agentdock_inject() {
  local id="${1:?Usage: agentdock_inject SESSION_ID MESSAGE}"
  local text="${2:?Usage: agentdock_inject SESSION_ID MESSAGE}"
  # Escape double quotes in text.
  local escaped="${text//\"/\\\"}"
  curl -sf -X POST "${AGENTDOCK_API_BASE}/sessions/${id}/inject" \
    -H "Content-Type: application/json" \
    -d "{\"text\": \"${escaped}\"}"
}

# Post an event to AgentDock from the current session.
# Usage: agentdock_notify [TYPE] [DATA_JSON]
#   TYPE    — stop | result | notify (default: notify)
#   DATA    — arbitrary JSON object (default: {})
agentdock_notify() {
  local type="${1:-notify}"
  local data="${2:-{}}"
  curl -sf -X POST "${AGENTDOCK_IPC_URL}" \
    -H "Content-Type: application/json" \
    -d "{\"type\": \"${type}\", \"data\": ${data}}" || true
}

# Print the IDs of all currently running sessions.
# Usage: agentdock_running_ids
agentdock_running_ids() {
  local list
  list="$(agentdock_list 2>/dev/null)"
  if command -v jq &>/dev/null; then
    printf '%s' "$list" | \
      jq -r '.sessions[] | select(.status=="running") | .id' 2>/dev/null
  else
    printf '%s' "$list" | \
      python3 -c "import sys,json; [print(s['id']) for s in json.load(sys.stdin).get('sessions',[]) if s.get('status')=='running']" \
      2>/dev/null
  fi
}

# Broadcast a message to all running sessions except the current one.
# Usage: agentdock_broadcast "message"
agentdock_broadcast() {
  local msg="${1:?Usage: agentdock_broadcast MESSAGE}"
  local self="${AGENTDOCK_SESSION_ID:-0}"
  while IFS= read -r id; do
    if [[ "$id" != "$self" ]]; then
      agentdock_inject "$id" "$msg"
    fi
  done < <(agentdock_running_ids)
}

# --- Shared Key-Value Store ---
# Agents can store and retrieve named values via the KV API.
# Values persist across app restarts (written to ~/.agentdock/kv.json).
# Optional TTL makes an entry auto-expire.

# Read a value by key. Prints the value, returns 1 if the key does not exist.
# Usage: agentdock_kv_get KEY
agentdock_kv_get() {
  local key="${1:?Usage: agentdock_kv_get KEY}"
  local resp
  resp="$(curl -sf "${AGENTDOCK_API_BASE}/kv/${key}")" || return 1
  _ad_json value "$resp"
}

# Write a value. Optional TTL (integer seconds) makes the entry auto-expire.
# Usage: agentdock_kv_set KEY VALUE [TTL_SECONDS]
agentdock_kv_set() {
  local key="${1:?Usage: agentdock_kv_set KEY VALUE [TTL]}"
  local value="${2?Usage: agentdock_kv_set KEY VALUE [TTL]}"
  local ttl="${3:-0}"
  local payload
  if command -v jq &>/dev/null; then
    if [[ "$ttl" -gt 0 ]]; then
      payload="$(jq -n --arg v "$value" --argjson t "$ttl" '{"value":$v,"ttl":$t}')"
    else
      payload="$(jq -n --arg v "$value" '{"value":$v}')"
    fi
  else
    local escaped_value
    escaped_value="$(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$value")"
    if [[ "$ttl" -gt 0 ]]; then
      payload="{\"value\": ${escaped_value}, \"ttl\": ${ttl}}"
    else
      payload="{\"value\": ${escaped_value}}"
    fi
  fi
  curl -sf -X POST "${AGENTDOCK_API_BASE}/kv/${key}" \
    -H "Content-Type: application/json" \
    -d "$payload" > /dev/null
}

# Delete a key from the KV store.
# Usage: agentdock_kv_del KEY
agentdock_kv_del() {
  local key="${1:?Usage: agentdock_kv_del KEY}"
  curl -sf -X DELETE "${AGENTDOCK_API_BASE}/kv/${key}" > /dev/null
}

# List all live keys in the KV store (one per line).
# Usage: agentdock_kv_list
agentdock_kv_list() {
  local resp
  resp="$(curl -sf "${AGENTDOCK_API_BASE}/kv")"
  if command -v jq &>/dev/null; then
    printf '%s' "$resp" | jq -r '.keys[]' 2>/dev/null
  else
    printf '%s' "$resp" | \
      python3 -c "import sys,json; [print(k) for k in json.load(sys.stdin).get('keys',[])]" \
      2>/dev/null
  fi
}

# Spawn a new agent session from within another agent.
# The new session is opened in the AgentDock UI immediately.
# Usage: agentdock_spawn AGENT_ID INPUT [WORKING_DIR] [NAME]
#   AGENT_ID    — e.g. "claude", "codex", "gemini"
#   INPUT       — the task/prompt for the new session
#   WORKING_DIR — optional; defaults to the server's working directory
#   NAME        — optional display name in AgentDock
# Prints the numeric session ID on success, exits 1 on failure.
agentdock_spawn() {
  local agent="${1:?Usage: agentdock_spawn AGENT_ID INPUT [WORKING_DIR] [NAME]}"
  local input="${2:?Usage: agentdock_spawn AGENT_ID INPUT [WORKING_DIR] [NAME]}"
  local workdir="${3:-}"
  local name="${4:-}"
  local payload
  if command -v jq &>/dev/null; then
    payload="$(jq -n \
      --arg a "$agent" \
      --arg i "$input" \
      --arg w "$workdir" \
      --arg n "$name" \
      '{agent:$a,input:$i} |
       if $w != "" then . + {workingDirectory:$w} else . end |
       if $n != "" then . + {name:$n} else . end')"
  else
    local ea ei ew en
    ea="$(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$agent")"
    ei="$(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$input")"
    payload="{\"agent\":${ea},\"input\":${ei}"
    if [[ -n "$workdir" ]]; then
      ew="$(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$workdir")"
      payload="${payload},\"workingDirectory\":${ew}"
    fi
    if [[ -n "$name" ]]; then
      en="$(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$name")"
      payload="${payload},\"name\":${en}"
    fi
    payload="${payload}}"
  fi
  local resp
  resp="$(curl -sf -X POST "${AGENTDOCK_API_BASE}/sessions" \
    -H "Content-Type: application/json" \
    -d "$payload")" || { echo "agentdock_spawn: HTTP request failed" >&2; return 1; }
  local sid
  sid="$(_ad_json sessionId "$resp")"
  if [[ -z "$sid" ]]; then
    echo "agentdock_spawn: spawn failed — $resp" >&2
    return 1
  fi
  printf '%s\n' "$sid"
}
''';
}
