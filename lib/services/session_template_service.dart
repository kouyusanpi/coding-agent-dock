import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/session_template.dart';

/// Persists session templates in SharedPreferences as a JSON list.
class SessionTemplateService {
  static const _key = 'session_templates_v1';

  static Future<List<SessionTemplate>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .cast<Map<String, dynamic>>()
          .map(SessionTemplate.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _save(List<SessionTemplate> templates) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(templates.map((t) => t.toJson()).toList()),
    );
  }

  static Future<SessionTemplate> create({
    required String name,
    required String agentId,
    String? workingDirectory,
    required String prompt,
  }) async {
    final templates = await load();
    final template = SessionTemplate(
      id: const Uuid().v4(),
      name: name,
      agentId: agentId,
      workingDirectory: workingDirectory,
      prompt: prompt,
      createdAt: DateTime.now(),
    );
    templates.add(template);
    await _save(templates);
    return template;
  }

  static Future<void> delete(String id) async {
    final templates = await load();
    templates.removeWhere((t) => t.id == id);
    await _save(templates);
  }

  static Future<void> update(SessionTemplate updated) async {
    final templates = await load();
    final idx = templates.indexWhere((t) => t.id == updated.id);
    if (idx < 0) return;
    templates[idx] = updated;
    await _save(templates);
  }
}
