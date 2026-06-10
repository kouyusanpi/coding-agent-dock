import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/pipeline_rule.dart';

/// Persists pipeline rules in SharedPreferences.
class PipelineRuleService {
  static const _key = 'pipeline_rules_v1';

  static Future<List<PipelineRule>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .cast<Map<String, dynamic>>()
          .map(PipelineRule.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _save(List<PipelineRule> rules) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(rules.map((r) => r.toJson()).toList()),
    );
  }

  static Future<PipelineRule> create({
    required String sourceAgentId,
    required String targetAgentId,
    bool onSuccessOnly = true,
  }) async {
    final rules = await load();
    final rule = PipelineRule(
      id: const Uuid().v4(),
      sourceAgentId: sourceAgentId,
      targetAgentId: targetAgentId,
      onSuccessOnly: onSuccessOnly,
    );
    rules.add(rule);
    await _save(rules);
    return rule;
  }

  static Future<void> delete(String id) async {
    final rules = await load();
    rules.removeWhere((r) => r.id == id);
    await _save(rules);
  }

  static Future<void> update(PipelineRule updated) async {
    final rules = await load();
    final idx = rules.indexWhere((r) => r.id == updated.id);
    if (idx < 0) return;
    rules[idx] = updated;
    await _save(rules);
  }

  /// Returns matching enabled rules for a given source agent.
  static List<PipelineRule> rulesFor(
    List<PipelineRule> all,
    String sourceAgentId, {
    required bool success,
  }) {
    return all.where((r) {
      if (!r.enabled) return false;
      if (r.sourceAgentId != sourceAgentId) return false;
      if (r.onSuccessOnly && !success) return false;
      return true;
    }).toList();
  }
}
