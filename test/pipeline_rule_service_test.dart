import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:coding_agent_dock/models/pipeline_rule.dart';
import 'package:coding_agent_dock/services/pipeline_rule_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PipelineRuleService', () {
    test('returns empty list by default', () async {
      final rules = await PipelineRuleService.load();
      expect(rules, isEmpty);
    });

    test('creates and persists a rule', () async {
      final rule = await PipelineRuleService.create(
        sourceAgentId: 'claude',
        targetAgentId: 'aider',
      );
      expect(rule.sourceAgentId, 'claude');
      expect(rule.targetAgentId, 'aider');
      expect(rule.onSuccessOnly, isTrue);
      expect(rule.enabled, isTrue);

      final loaded = await PipelineRuleService.load();
      expect(loaded.length, 1);
      expect(loaded.first.id, rule.id);
    });

    test('creates rule with onSuccessOnly=false', () async {
      final rule = await PipelineRuleService.create(
        sourceAgentId: 'claude',
        targetAgentId: 'gemini',
        onSuccessOnly: false,
      );
      expect(rule.onSuccessOnly, isFalse);
    });

    test('deletes a rule by id', () async {
      final r1 = await PipelineRuleService.create(
          sourceAgentId: 'a', targetAgentId: 'b');
      final r2 = await PipelineRuleService.create(
          sourceAgentId: 'b', targetAgentId: 'c');

      await PipelineRuleService.delete(r1.id);

      final loaded = await PipelineRuleService.load();
      expect(loaded.length, 1);
      expect(loaded.first.id, r2.id);
    });

    test('updates an existing rule', () async {
      final rule = await PipelineRuleService.create(
          sourceAgentId: 'claude', targetAgentId: 'aider');

      final updated = rule.copyWith(enabled: false, onSuccessOnly: false);
      await PipelineRuleService.update(updated);

      final loaded = await PipelineRuleService.load();
      expect(loaded.first.enabled, isFalse);
      expect(loaded.first.onSuccessOnly, isFalse);
    });

    test('update is no-op for unknown id', () async {
      await PipelineRuleService.create(
          sourceAgentId: 'a', targetAgentId: 'b');
      final phantom = PipelineRule(
        id: 'nonexistent',
        sourceAgentId: 'x',
        targetAgentId: 'y',
      );
      await PipelineRuleService.update(phantom);

      final loaded = await PipelineRuleService.load();
      expect(loaded.length, 1);
      expect(loaded.first.sourceAgentId, 'a');
    });

    group('rulesFor', () {
      test('returns matching enabled rules on success', () {
        final rules = [
          PipelineRule(
              id: '1', sourceAgentId: 'claude', targetAgentId: 'aider'),
          PipelineRule(
              id: '2',
              sourceAgentId: 'gemini',
              targetAgentId: 'aider'),
        ];
        final result = PipelineRuleService.rulesFor(rules, 'claude',
            success: true);
        expect(result.length, 1);
        expect(result.first.id, '1');
      });

      test('excludes disabled rules', () {
        final rules = [
          PipelineRule(
              id: '1',
              sourceAgentId: 'claude',
              targetAgentId: 'aider',
              enabled: false),
        ];
        expect(
            PipelineRuleService.rulesFor(rules, 'claude', success: true),
            isEmpty);
      });

      test('excludes onSuccessOnly rules when failed', () {
        final rules = [
          PipelineRule(
              id: '1',
              sourceAgentId: 'claude',
              targetAgentId: 'aider',
              onSuccessOnly: true),
        ];
        expect(
            PipelineRuleService.rulesFor(rules, 'claude', success: false),
            isEmpty);
      });

      test('includes always-relay rules regardless of exit code', () {
        final rules = [
          PipelineRule(
              id: '1',
              sourceAgentId: 'claude',
              targetAgentId: 'aider',
              onSuccessOnly: false),
        ];
        final onFail = PipelineRuleService.rulesFor(rules, 'claude',
            success: false);
        final onPass = PipelineRuleService.rulesFor(rules, 'claude',
            success: true);
        expect(onFail.length, 1);
        expect(onPass.length, 1);
      });

      test('returns empty for unknown sourceAgentId', () {
        final rules = [
          PipelineRule(
              id: '1', sourceAgentId: 'claude', targetAgentId: 'aider'),
        ];
        expect(
            PipelineRuleService.rulesFor(rules, 'unknown', success: true),
            isEmpty);
      });
    });
  });
}
