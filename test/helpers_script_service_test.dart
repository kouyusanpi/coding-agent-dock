import 'package:flutter_test/flutter_test.dart';

import 'package:claude_code_cli_flutter/services/helpers_script_service.dart';

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
  });
}
