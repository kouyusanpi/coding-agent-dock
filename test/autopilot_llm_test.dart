import 'package:flutter_test/flutter_test.dart';

import 'package:coding_agent_dock/services/autopilot_llm.dart';

void main() {
  group('OpenAiCompatLlm prompts', () {
    const config = AutopilotLlmConfig(
      baseUrl: 'http://localhost/v1',
      apiKey: 'k',
      model: 'm',
    );

    test('defaults to the built-in prompts when none provided', () {
      final llm = OpenAiCompatLlm(config);
      expect(llm.planPrompt, OpenAiCompatLlm.defaultPlanPrompt);
      expect(llm.decidePrompt, OpenAiCompatLlm.defaultDecidePrompt);
    });

    test('uses the user-provided prompts when set', () {
      final llm = OpenAiCompatLlm(
        config,
        planPrompt: 'MY PLAN PROMPT',
        decidePrompt: 'MY DECIDE PROMPT',
      );
      expect(llm.planPrompt, 'MY PLAN PROMPT');
      expect(llm.decidePrompt, 'MY DECIDE PROMPT');
    });

    test('blank user prompt falls back to the default', () {
      final llm = OpenAiCompatLlm(
        config,
        planPrompt: '   ',
        decidePrompt: '',
      );
      expect(llm.planPrompt, OpenAiCompatLlm.defaultPlanPrompt);
      expect(llm.decidePrompt, OpenAiCompatLlm.defaultDecidePrompt);
    });

    test('default prompts retain the JSON output contract', () {
      expect(OpenAiCompatLlm.defaultPlanPrompt, contains('JSON array'));
      expect(OpenAiCompatLlm.defaultDecidePrompt, contains('JSON object'));
    });
  });
}
