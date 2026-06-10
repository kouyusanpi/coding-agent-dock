import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/workflow_definition.dart';

/// Persists workflow definitions in SharedPreferences.
class WorkflowService {
  static const _key = 'workflow_definitions_v1';

  /// Load all saved workflow definitions.
  static Future<List<WorkflowDefinition>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .cast<Map<String, dynamic>>()
          .map(WorkflowDefinition.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _save(List<WorkflowDefinition> definitions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(definitions.map((d) => d.toJson()).toList()),
    );
  }

  /// Create a new workflow definition and persist it.
  static Future<WorkflowDefinition> create({
    required String name,
    String? description,
    List<WorkflowNode> nodes = const [],
    List<WorkflowEdge> edges = const [],
    String? defaultWorkingDirectory,
  }) async {
    final definitions = await load();
    final definition = WorkflowDefinition.create(
      name: name,
      description: description,
      nodes: nodes,
      edges: edges,
      defaultWorkingDirectory: defaultWorkingDirectory,
    );
    definitions.add(definition);
    await _save(definitions);
    return definition;
  }

  /// Delete a workflow definition by id.
  static Future<void> delete(String id) async {
    final definitions = await load();
    definitions.removeWhere((d) => d.id == id);
    await _save(definitions);
  }

  /// Update an existing workflow definition.
  static Future<void> update(WorkflowDefinition updated) async {
    final definitions = await load();
    final idx = definitions.indexWhere((d) => d.id == updated.id);
    if (idx < 0) return;
    definitions[idx] = updated;
    await _save(definitions);
  }

  /// Export a single workflow definition as pretty-printed JSON.
  static Future<String> exportJson(String id) async {
    final definitions = await load();
    final definition = definitions.firstWhere(
      (d) => d.id == id,
      orElse: () => throw StateError('Workflow definition not found: $id'),
    );
    return const JsonEncoder.withIndent('  ').convert(definition.toJson());
  }

  /// Import a workflow definition from a JSON string.
  /// Assigns a new id and timestamps to avoid collisions.
  static Future<WorkflowDefinition> importJson(String jsonString) async {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    final imported = WorkflowDefinition.fromJson(json);
    final definitions = await load();
    final now = DateTime.now();
    final newDef = WorkflowDefinition(
      id: const Uuid().v4(),
      name: imported.name,
      description: imported.description,
      nodes: imported.nodes,
      edges: imported.edges,
      defaultWorkingDirectory: imported.defaultWorkingDirectory,
      createdAt: now,
      updatedAt: now,
    );
    definitions.add(newDef);
    await _save(definitions);
    return newDef;
  }
}
