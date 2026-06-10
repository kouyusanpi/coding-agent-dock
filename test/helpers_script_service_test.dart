import 'package:flutter_test/flutter_test.dart';

import 'package:coding_agent_dock/services/helpers_script_service.dart';

void main() {
  group('HelpersScriptService', () {
    test('path ends with .agentdock/helpers.sh', () {
      expect(HelpersScriptService.path, endsWith('.agentdock/helpers.sh'));
    });

    test('script contains all expected function names', () {
      final script = HelpersScriptService.script;
      expect(script, contains('agentdock_list'));
      expect(script, contains('agentdock_output'));
      expect(script, contains('agentdock_stream'));
      expect(script, contains('agentdock_inject'));
      expect(script, contains('agentdock_notify'));
      expect(script, contains('agentdock_broadcast'));
      expect(script, contains('agentdock_running_ids'));
    });

    test('script references AGENTDOCK_API_BASE env var', () {
      expect(HelpersScriptService.script,
          contains(r'${AGENTDOCK_API_BASE}'));
    });

    test('script references AGENTDOCK_IPC_URL env var', () {
      expect(HelpersScriptService.script,
          contains(r'${AGENTDOCK_IPC_URL}'));
    });

    test('script references AGENTDOCK_SESSION_ID for broadcast exclusion', () {
      expect(HelpersScriptService.script,
          contains(r'${AGENTDOCK_SESSION_ID'));
    });

    test('kvStorePath ends with .agentdock/kv.json', () {
      expect(HelpersScriptService.kvStorePath, endsWith('.agentdock/kv.json'));
    });

    test('script contains all KV helper function names', () {
      final s = HelpersScriptService.script;
      expect(s, contains('agentdock_kv_get'));
      expect(s, contains('agentdock_kv_set'));
      expect(s, contains('agentdock_kv_del'));
      expect(s, contains('agentdock_kv_list'));
    });

    test('script contains _ad_json jq/python3 fallback helper', () {
      final s = HelpersScriptService.script;
      expect(s, contains('_ad_json'));
      expect(s, contains('jq'));
      expect(s, contains('python3'));
    });

    test('agentdock_kv_get uses GET /v1/kv/:key endpoint', () {
      expect(HelpersScriptService.script,
          contains(r'${AGENTDOCK_API_BASE}/kv/${key}'));
    });

    test('agentdock_kv_del uses DELETE method', () {
      expect(HelpersScriptService.script, contains('-X DELETE'));
    });

    test('agentdock_wait uses _ad_json for status extraction', () {
      final s = HelpersScriptService.script;
      final waitFn = s.substring(
          s.indexOf('agentdock_wait()'), s.indexOf('agentdock_output()'));
      expect(waitFn, contains('_ad_json status'));
    });

    test('agentdock_wait declares loop variables before the loop', () {
      final s = HelpersScriptService.script;
      final waitFn = s.substring(
          s.indexOf('agentdock_wait()'), s.indexOf('agentdock_output()'));
      expect(waitFn, contains('local elapsed=0 body sess_status'));
    });
  });
}
