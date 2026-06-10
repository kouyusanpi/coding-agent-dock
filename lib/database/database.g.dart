// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $TaskSessionsTable extends TaskSessions
    with TableInfo<$TaskSessionsTable, TaskSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaskSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 255,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _agentCliIdMeta = const VerificationMeta(
    'agentCliId',
  );
  @override
  late final GeneratedColumn<String> agentCliId = GeneratedColumn<String>(
    'agent_cli_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 32,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _workingDirectoryMeta = const VerificationMeta(
    'workingDirectory',
  );
  @override
  late final GeneratedColumn<String> workingDirectory = GeneratedColumn<String>(
    'working_directory',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 1024),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 2048),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _exitCodeMeta = const VerificationMeta(
    'exitCode',
  );
  @override
  late final GeneratedColumn<int> exitCode = GeneratedColumn<int>(
    'exit_code',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _inputMeta = const VerificationMeta('input');
  @override
  late final GeneratedColumn<String> input = GeneratedColumn<String>(
    'input',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 65536),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _agentSessionIdMeta = const VerificationMeta(
    'agentSessionId',
  );
  @override
  late final GeneratedColumn<String> agentSessionId = GeneratedColumn<String>(
    'agent_session_id',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 64),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _outputMeta = const VerificationMeta('output');
  @override
  late final GeneratedColumn<String> output = GeneratedColumn<String>(
    'output',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 65536),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 4096),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorLabelMeta = const VerificationMeta(
    'colorLabel',
  );
  @override
  late final GeneratedColumn<String> colorLabel = GeneratedColumn<String>(
    'color_label',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 32),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _batchIdMeta = const VerificationMeta(
    'batchId',
  );
  @override
  late final GeneratedColumn<String> batchId = GeneratedColumn<String>(
    'batch_id',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 64),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parentSessionIdMeta = const VerificationMeta(
    'parentSessionId',
  );
  @override
  late final GeneratedColumn<int> parentSessionId = GeneratedColumn<int>(
    'parent_session_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _workflowRunIdMeta = const VerificationMeta(
    'workflowRunId',
  );
  @override
  late final GeneratedColumn<String> workflowRunId = GeneratedColumn<String>(
    'workflow_run_id',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 64),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _workflowNodeIdMeta = const VerificationMeta(
    'workflowNodeId',
  );
  @override
  late final GeneratedColumn<String> workflowNodeId = GeneratedColumn<String>(
    'workflow_node_id',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 64),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _customArgsMeta = const VerificationMeta(
    'customArgs',
  );
  @override
  late final GeneratedColumn<String> customArgs = GeneratedColumn<String>(
    'custom_args',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 2048),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    agentCliId,
    status,
    workingDirectory,
    description,
    createdAt,
    updatedAt,
    completedAt,
    exitCode,
    durationMs,
    input,
    agentSessionId,
    output,
    notes,
    colorLabel,
    batchId,
    parentSessionId,
    workflowRunId,
    workflowNodeId,
    customArgs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'task_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('agent_cli_id')) {
      context.handle(
        _agentCliIdMeta,
        agentCliId.isAcceptableOrUnknown(
          data['agent_cli_id']!,
          _agentCliIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_agentCliIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('working_directory')) {
      context.handle(
        _workingDirectoryMeta,
        workingDirectory.isAcceptableOrUnknown(
          data['working_directory']!,
          _workingDirectoryMeta,
        ),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('exit_code')) {
      context.handle(
        _exitCodeMeta,
        exitCode.isAcceptableOrUnknown(data['exit_code']!, _exitCodeMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('input')) {
      context.handle(
        _inputMeta,
        input.isAcceptableOrUnknown(data['input']!, _inputMeta),
      );
    }
    if (data.containsKey('agent_session_id')) {
      context.handle(
        _agentSessionIdMeta,
        agentSessionId.isAcceptableOrUnknown(
          data['agent_session_id']!,
          _agentSessionIdMeta,
        ),
      );
    }
    if (data.containsKey('output')) {
      context.handle(
        _outputMeta,
        output.isAcceptableOrUnknown(data['output']!, _outputMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('color_label')) {
      context.handle(
        _colorLabelMeta,
        colorLabel.isAcceptableOrUnknown(data['color_label']!, _colorLabelMeta),
      );
    }
    if (data.containsKey('batch_id')) {
      context.handle(
        _batchIdMeta,
        batchId.isAcceptableOrUnknown(data['batch_id']!, _batchIdMeta),
      );
    }
    if (data.containsKey('parent_session_id')) {
      context.handle(
        _parentSessionIdMeta,
        parentSessionId.isAcceptableOrUnknown(
          data['parent_session_id']!,
          _parentSessionIdMeta,
        ),
      );
    }
    if (data.containsKey('workflow_run_id')) {
      context.handle(
        _workflowRunIdMeta,
        workflowRunId.isAcceptableOrUnknown(
          data['workflow_run_id']!,
          _workflowRunIdMeta,
        ),
      );
    }
    if (data.containsKey('workflow_node_id')) {
      context.handle(
        _workflowNodeIdMeta,
        workflowNodeId.isAcceptableOrUnknown(
          data['workflow_node_id']!,
          _workflowNodeIdMeta,
        ),
      );
    }
    if (data.containsKey('custom_args')) {
      context.handle(
        _customArgsMeta,
        customArgs.isAcceptableOrUnknown(data['custom_args']!, _customArgsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TaskSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskSession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      agentCliId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}agent_cli_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      workingDirectory: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}working_directory'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      exitCode: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}exit_code'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      input: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}input'],
      ),
      agentSessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}agent_session_id'],
      ),
      output: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}output'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      colorLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_label'],
      ),
      batchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}batch_id'],
      ),
      parentSessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}parent_session_id'],
      ),
      workflowRunId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}workflow_run_id'],
      ),
      workflowNodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}workflow_node_id'],
      ),
      customArgs: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}custom_args'],
      ),
    );
  }

  @override
  $TaskSessionsTable createAlias(String alias) {
    return $TaskSessionsTable(attachedDatabase, alias);
  }
}

class TaskSession extends DataClass implements Insertable<TaskSession> {
  final int id;

  /// Human-readable session name
  final String name;

  /// The agent CLI id used for this session (e.g. "claude", "codex")
  final String agentCliId;

  /// Session status: running, completed, failed, cancelled
  final String status;

  /// Working directory for the session
  final String? workingDirectory;

  /// Optional description / goal of the session
  final String? description;

  /// Session creation timestamp
  final DateTime createdAt;

  /// Last update timestamp
  final DateTime updatedAt;

  /// Session completion timestamp
  final DateTime? completedAt;

  /// Exit code (null if still running)
  final int? exitCode;

  /// Duration in milliseconds
  final int? durationMs;

  /// Input prompt / task description
  final String? input;

  /// The agent's own session id (e.g. Claude Code session UUID),
  /// used to resume the conversation with `--resume <id>`.
  final String? agentSessionId;

  /// Output / result summary
  final String? output;

  /// User-written annotation / note attached to this session.
  final String? notes;

  /// User-assigned color label for visual organization.
  /// Stored as a color name string, e.g. 'red', 'blue', 'green'.
  final String? colorLabel;

  /// Cluster batch ID — shared UUID among sessions created together via
  /// "Run on all agents". Null for single-agent sessions.
  final String? batchId;

  /// Parent session ID for relay-chained sessions (created automatically by
  /// the auto-relay pipeline). Null for manually created sessions.
  final int? parentSessionId;

  /// Workflow run ID — links this session to a DAG workflow execution.
  /// Null for sessions not part of a workflow.
  final String? workflowRunId;

  /// Workflow node ID — the WorkflowNode.id within the definition.
  /// Null for sessions not part of a workflow.
  final String? workflowNodeId;

  /// Custom launch arguments override entered by the user in the new-session
  /// dialog. Semantics:
  ///   - null   → use the agent's auto-generated arguments (default behavior)
  ///   - ""     → launch with no extra flags at all (bare command + prompt)
  ///   - "…"    → use exactly these (shell-tokenized) flags instead of the auto ones
  final String? customArgs;
  const TaskSession({
    required this.id,
    required this.name,
    required this.agentCliId,
    required this.status,
    this.workingDirectory,
    this.description,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.exitCode,
    this.durationMs,
    this.input,
    this.agentSessionId,
    this.output,
    this.notes,
    this.colorLabel,
    this.batchId,
    this.parentSessionId,
    this.workflowRunId,
    this.workflowNodeId,
    this.customArgs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['agent_cli_id'] = Variable<String>(agentCliId);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || workingDirectory != null) {
      map['working_directory'] = Variable<String>(workingDirectory);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    if (!nullToAbsent || exitCode != null) {
      map['exit_code'] = Variable<int>(exitCode);
    }
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    if (!nullToAbsent || input != null) {
      map['input'] = Variable<String>(input);
    }
    if (!nullToAbsent || agentSessionId != null) {
      map['agent_session_id'] = Variable<String>(agentSessionId);
    }
    if (!nullToAbsent || output != null) {
      map['output'] = Variable<String>(output);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || colorLabel != null) {
      map['color_label'] = Variable<String>(colorLabel);
    }
    if (!nullToAbsent || batchId != null) {
      map['batch_id'] = Variable<String>(batchId);
    }
    if (!nullToAbsent || parentSessionId != null) {
      map['parent_session_id'] = Variable<int>(parentSessionId);
    }
    if (!nullToAbsent || workflowRunId != null) {
      map['workflow_run_id'] = Variable<String>(workflowRunId);
    }
    if (!nullToAbsent || workflowNodeId != null) {
      map['workflow_node_id'] = Variable<String>(workflowNodeId);
    }
    if (!nullToAbsent || customArgs != null) {
      map['custom_args'] = Variable<String>(customArgs);
    }
    return map;
  }

  TaskSessionsCompanion toCompanion(bool nullToAbsent) {
    return TaskSessionsCompanion(
      id: Value(id),
      name: Value(name),
      agentCliId: Value(agentCliId),
      status: Value(status),
      workingDirectory: workingDirectory == null && nullToAbsent
          ? const Value.absent()
          : Value(workingDirectory),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      exitCode: exitCode == null && nullToAbsent
          ? const Value.absent()
          : Value(exitCode),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      input: input == null && nullToAbsent
          ? const Value.absent()
          : Value(input),
      agentSessionId: agentSessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(agentSessionId),
      output: output == null && nullToAbsent
          ? const Value.absent()
          : Value(output),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      colorLabel: colorLabel == null && nullToAbsent
          ? const Value.absent()
          : Value(colorLabel),
      batchId: batchId == null && nullToAbsent
          ? const Value.absent()
          : Value(batchId),
      parentSessionId: parentSessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentSessionId),
      workflowRunId: workflowRunId == null && nullToAbsent
          ? const Value.absent()
          : Value(workflowRunId),
      workflowNodeId: workflowNodeId == null && nullToAbsent
          ? const Value.absent()
          : Value(workflowNodeId),
      customArgs: customArgs == null && nullToAbsent
          ? const Value.absent()
          : Value(customArgs),
    );
  }

  factory TaskSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskSession(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      agentCliId: serializer.fromJson<String>(json['agentCliId']),
      status: serializer.fromJson<String>(json['status']),
      workingDirectory: serializer.fromJson<String?>(json['workingDirectory']),
      description: serializer.fromJson<String?>(json['description']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      exitCode: serializer.fromJson<int?>(json['exitCode']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      input: serializer.fromJson<String?>(json['input']),
      agentSessionId: serializer.fromJson<String?>(json['agentSessionId']),
      output: serializer.fromJson<String?>(json['output']),
      notes: serializer.fromJson<String?>(json['notes']),
      colorLabel: serializer.fromJson<String?>(json['colorLabel']),
      batchId: serializer.fromJson<String?>(json['batchId']),
      parentSessionId: serializer.fromJson<int?>(json['parentSessionId']),
      workflowRunId: serializer.fromJson<String?>(json['workflowRunId']),
      workflowNodeId: serializer.fromJson<String?>(json['workflowNodeId']),
      customArgs: serializer.fromJson<String?>(json['customArgs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'agentCliId': serializer.toJson<String>(agentCliId),
      'status': serializer.toJson<String>(status),
      'workingDirectory': serializer.toJson<String?>(workingDirectory),
      'description': serializer.toJson<String?>(description),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'exitCode': serializer.toJson<int?>(exitCode),
      'durationMs': serializer.toJson<int?>(durationMs),
      'input': serializer.toJson<String?>(input),
      'agentSessionId': serializer.toJson<String?>(agentSessionId),
      'output': serializer.toJson<String?>(output),
      'notes': serializer.toJson<String?>(notes),
      'colorLabel': serializer.toJson<String?>(colorLabel),
      'batchId': serializer.toJson<String?>(batchId),
      'parentSessionId': serializer.toJson<int?>(parentSessionId),
      'workflowRunId': serializer.toJson<String?>(workflowRunId),
      'workflowNodeId': serializer.toJson<String?>(workflowNodeId),
      'customArgs': serializer.toJson<String?>(customArgs),
    };
  }

  TaskSession copyWith({
    int? id,
    String? name,
    String? agentCliId,
    String? status,
    Value<String?> workingDirectory = const Value.absent(),
    Value<String?> description = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> completedAt = const Value.absent(),
    Value<int?> exitCode = const Value.absent(),
    Value<int?> durationMs = const Value.absent(),
    Value<String?> input = const Value.absent(),
    Value<String?> agentSessionId = const Value.absent(),
    Value<String?> output = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<String?> colorLabel = const Value.absent(),
    Value<String?> batchId = const Value.absent(),
    Value<int?> parentSessionId = const Value.absent(),
    Value<String?> workflowRunId = const Value.absent(),
    Value<String?> workflowNodeId = const Value.absent(),
    Value<String?> customArgs = const Value.absent(),
  }) => TaskSession(
    id: id ?? this.id,
    name: name ?? this.name,
    agentCliId: agentCliId ?? this.agentCliId,
    status: status ?? this.status,
    workingDirectory: workingDirectory.present
        ? workingDirectory.value
        : this.workingDirectory,
    description: description.present ? description.value : this.description,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    exitCode: exitCode.present ? exitCode.value : this.exitCode,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    input: input.present ? input.value : this.input,
    agentSessionId: agentSessionId.present
        ? agentSessionId.value
        : this.agentSessionId,
    output: output.present ? output.value : this.output,
    notes: notes.present ? notes.value : this.notes,
    colorLabel: colorLabel.present ? colorLabel.value : this.colorLabel,
    batchId: batchId.present ? batchId.value : this.batchId,
    parentSessionId: parentSessionId.present
        ? parentSessionId.value
        : this.parentSessionId,
    workflowRunId: workflowRunId.present
        ? workflowRunId.value
        : this.workflowRunId,
    workflowNodeId: workflowNodeId.present
        ? workflowNodeId.value
        : this.workflowNodeId,
    customArgs: customArgs.present ? customArgs.value : this.customArgs,
  );
  TaskSession copyWithCompanion(TaskSessionsCompanion data) {
    return TaskSession(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      agentCliId: data.agentCliId.present
          ? data.agentCliId.value
          : this.agentCliId,
      status: data.status.present ? data.status.value : this.status,
      workingDirectory: data.workingDirectory.present
          ? data.workingDirectory.value
          : this.workingDirectory,
      description: data.description.present
          ? data.description.value
          : this.description,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      exitCode: data.exitCode.present ? data.exitCode.value : this.exitCode,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      input: data.input.present ? data.input.value : this.input,
      agentSessionId: data.agentSessionId.present
          ? data.agentSessionId.value
          : this.agentSessionId,
      output: data.output.present ? data.output.value : this.output,
      notes: data.notes.present ? data.notes.value : this.notes,
      colorLabel: data.colorLabel.present
          ? data.colorLabel.value
          : this.colorLabel,
      batchId: data.batchId.present ? data.batchId.value : this.batchId,
      parentSessionId: data.parentSessionId.present
          ? data.parentSessionId.value
          : this.parentSessionId,
      workflowRunId: data.workflowRunId.present
          ? data.workflowRunId.value
          : this.workflowRunId,
      workflowNodeId: data.workflowNodeId.present
          ? data.workflowNodeId.value
          : this.workflowNodeId,
      customArgs: data.customArgs.present
          ? data.customArgs.value
          : this.customArgs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskSession(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('agentCliId: $agentCliId, ')
          ..write('status: $status, ')
          ..write('workingDirectory: $workingDirectory, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('exitCode: $exitCode, ')
          ..write('durationMs: $durationMs, ')
          ..write('input: $input, ')
          ..write('agentSessionId: $agentSessionId, ')
          ..write('output: $output, ')
          ..write('notes: $notes, ')
          ..write('colorLabel: $colorLabel, ')
          ..write('batchId: $batchId, ')
          ..write('parentSessionId: $parentSessionId, ')
          ..write('workflowRunId: $workflowRunId, ')
          ..write('workflowNodeId: $workflowNodeId, ')
          ..write('customArgs: $customArgs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    name,
    agentCliId,
    status,
    workingDirectory,
    description,
    createdAt,
    updatedAt,
    completedAt,
    exitCode,
    durationMs,
    input,
    agentSessionId,
    output,
    notes,
    colorLabel,
    batchId,
    parentSessionId,
    workflowRunId,
    workflowNodeId,
    customArgs,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskSession &&
          other.id == this.id &&
          other.name == this.name &&
          other.agentCliId == this.agentCliId &&
          other.status == this.status &&
          other.workingDirectory == this.workingDirectory &&
          other.description == this.description &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.completedAt == this.completedAt &&
          other.exitCode == this.exitCode &&
          other.durationMs == this.durationMs &&
          other.input == this.input &&
          other.agentSessionId == this.agentSessionId &&
          other.output == this.output &&
          other.notes == this.notes &&
          other.colorLabel == this.colorLabel &&
          other.batchId == this.batchId &&
          other.parentSessionId == this.parentSessionId &&
          other.workflowRunId == this.workflowRunId &&
          other.workflowNodeId == this.workflowNodeId &&
          other.customArgs == this.customArgs);
}

class TaskSessionsCompanion extends UpdateCompanion<TaskSession> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> agentCliId;
  final Value<String> status;
  final Value<String?> workingDirectory;
  final Value<String?> description;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> completedAt;
  final Value<int?> exitCode;
  final Value<int?> durationMs;
  final Value<String?> input;
  final Value<String?> agentSessionId;
  final Value<String?> output;
  final Value<String?> notes;
  final Value<String?> colorLabel;
  final Value<String?> batchId;
  final Value<int?> parentSessionId;
  final Value<String?> workflowRunId;
  final Value<String?> workflowNodeId;
  final Value<String?> customArgs;
  const TaskSessionsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.agentCliId = const Value.absent(),
    this.status = const Value.absent(),
    this.workingDirectory = const Value.absent(),
    this.description = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.exitCode = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.input = const Value.absent(),
    this.agentSessionId = const Value.absent(),
    this.output = const Value.absent(),
    this.notes = const Value.absent(),
    this.colorLabel = const Value.absent(),
    this.batchId = const Value.absent(),
    this.parentSessionId = const Value.absent(),
    this.workflowRunId = const Value.absent(),
    this.workflowNodeId = const Value.absent(),
    this.customArgs = const Value.absent(),
  });
  TaskSessionsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String agentCliId,
    required String status,
    this.workingDirectory = const Value.absent(),
    this.description = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.completedAt = const Value.absent(),
    this.exitCode = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.input = const Value.absent(),
    this.agentSessionId = const Value.absent(),
    this.output = const Value.absent(),
    this.notes = const Value.absent(),
    this.colorLabel = const Value.absent(),
    this.batchId = const Value.absent(),
    this.parentSessionId = const Value.absent(),
    this.workflowRunId = const Value.absent(),
    this.workflowNodeId = const Value.absent(),
    this.customArgs = const Value.absent(),
  }) : name = Value(name),
       agentCliId = Value(agentCliId),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<TaskSession> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? agentCliId,
    Expression<String>? status,
    Expression<String>? workingDirectory,
    Expression<String>? description,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? completedAt,
    Expression<int>? exitCode,
    Expression<int>? durationMs,
    Expression<String>? input,
    Expression<String>? agentSessionId,
    Expression<String>? output,
    Expression<String>? notes,
    Expression<String>? colorLabel,
    Expression<String>? batchId,
    Expression<int>? parentSessionId,
    Expression<String>? workflowRunId,
    Expression<String>? workflowNodeId,
    Expression<String>? customArgs,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (agentCliId != null) 'agent_cli_id': agentCliId,
      if (status != null) 'status': status,
      if (workingDirectory != null) 'working_directory': workingDirectory,
      if (description != null) 'description': description,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (exitCode != null) 'exit_code': exitCode,
      if (durationMs != null) 'duration_ms': durationMs,
      if (input != null) 'input': input,
      if (agentSessionId != null) 'agent_session_id': agentSessionId,
      if (output != null) 'output': output,
      if (notes != null) 'notes': notes,
      if (colorLabel != null) 'color_label': colorLabel,
      if (batchId != null) 'batch_id': batchId,
      if (parentSessionId != null) 'parent_session_id': parentSessionId,
      if (workflowRunId != null) 'workflow_run_id': workflowRunId,
      if (workflowNodeId != null) 'workflow_node_id': workflowNodeId,
      if (customArgs != null) 'custom_args': customArgs,
    });
  }

  TaskSessionsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? agentCliId,
    Value<String>? status,
    Value<String?>? workingDirectory,
    Value<String?>? description,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? completedAt,
    Value<int?>? exitCode,
    Value<int?>? durationMs,
    Value<String?>? input,
    Value<String?>? agentSessionId,
    Value<String?>? output,
    Value<String?>? notes,
    Value<String?>? colorLabel,
    Value<String?>? batchId,
    Value<int?>? parentSessionId,
    Value<String?>? workflowRunId,
    Value<String?>? workflowNodeId,
    Value<String?>? customArgs,
  }) {
    return TaskSessionsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      agentCliId: agentCliId ?? this.agentCliId,
      status: status ?? this.status,
      workingDirectory: workingDirectory ?? this.workingDirectory,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      exitCode: exitCode ?? this.exitCode,
      durationMs: durationMs ?? this.durationMs,
      input: input ?? this.input,
      agentSessionId: agentSessionId ?? this.agentSessionId,
      output: output ?? this.output,
      notes: notes ?? this.notes,
      colorLabel: colorLabel ?? this.colorLabel,
      batchId: batchId ?? this.batchId,
      parentSessionId: parentSessionId ?? this.parentSessionId,
      workflowRunId: workflowRunId ?? this.workflowRunId,
      workflowNodeId: workflowNodeId ?? this.workflowNodeId,
      customArgs: customArgs ?? this.customArgs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (agentCliId.present) {
      map['agent_cli_id'] = Variable<String>(agentCliId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (workingDirectory.present) {
      map['working_directory'] = Variable<String>(workingDirectory.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (exitCode.present) {
      map['exit_code'] = Variable<int>(exitCode.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (input.present) {
      map['input'] = Variable<String>(input.value);
    }
    if (agentSessionId.present) {
      map['agent_session_id'] = Variable<String>(agentSessionId.value);
    }
    if (output.present) {
      map['output'] = Variable<String>(output.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (colorLabel.present) {
      map['color_label'] = Variable<String>(colorLabel.value);
    }
    if (batchId.present) {
      map['batch_id'] = Variable<String>(batchId.value);
    }
    if (parentSessionId.present) {
      map['parent_session_id'] = Variable<int>(parentSessionId.value);
    }
    if (workflowRunId.present) {
      map['workflow_run_id'] = Variable<String>(workflowRunId.value);
    }
    if (workflowNodeId.present) {
      map['workflow_node_id'] = Variable<String>(workflowNodeId.value);
    }
    if (customArgs.present) {
      map['custom_args'] = Variable<String>(customArgs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaskSessionsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('agentCliId: $agentCliId, ')
          ..write('status: $status, ')
          ..write('workingDirectory: $workingDirectory, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('exitCode: $exitCode, ')
          ..write('durationMs: $durationMs, ')
          ..write('input: $input, ')
          ..write('agentSessionId: $agentSessionId, ')
          ..write('output: $output, ')
          ..write('notes: $notes, ')
          ..write('colorLabel: $colorLabel, ')
          ..write('batchId: $batchId, ')
          ..write('parentSessionId: $parentSessionId, ')
          ..write('workflowRunId: $workflowRunId, ')
          ..write('workflowNodeId: $workflowNodeId, ')
          ..write('customArgs: $customArgs')
          ..write(')'))
        .toString();
  }
}

class $WorkflowRunsTable extends WorkflowRuns
    with TableInfo<$WorkflowRunsTable, WorkflowRunRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkflowRunsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _definitionIdMeta = const VerificationMeta(
    'definitionId',
  );
  @override
  late final GeneratedColumn<String> definitionId = GeneratedColumn<String>(
    'definition_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 64),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _definitionNameMeta = const VerificationMeta(
    'definitionName',
  );
  @override
  late final GeneratedColumn<String> definitionName = GeneratedColumn<String>(
    'definition_name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 255),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _definitionJsonMeta = const VerificationMeta(
    'definitionJson',
  );
  @override
  late final GeneratedColumn<String> definitionJson = GeneratedColumn<String>(
    'definition_json',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 65536),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 32),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    definitionId,
    definitionName,
    definitionJson,
    status,
    startedAt,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workflow_runs';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkflowRunRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('definition_id')) {
      context.handle(
        _definitionIdMeta,
        definitionId.isAcceptableOrUnknown(
          data['definition_id']!,
          _definitionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_definitionIdMeta);
    }
    if (data.containsKey('definition_name')) {
      context.handle(
        _definitionNameMeta,
        definitionName.isAcceptableOrUnknown(
          data['definition_name']!,
          _definitionNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_definitionNameMeta);
    }
    if (data.containsKey('definition_json')) {
      context.handle(
        _definitionJsonMeta,
        definitionJson.isAcceptableOrUnknown(
          data['definition_json']!,
          _definitionJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_definitionJsonMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkflowRunRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkflowRunRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      definitionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}definition_id'],
      )!,
      definitionName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}definition_name'],
      )!,
      definitionJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}definition_json'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $WorkflowRunsTable createAlias(String alias) {
    return $WorkflowRunsTable(attachedDatabase, alias);
  }
}

class WorkflowRunRecord extends DataClass
    implements Insertable<WorkflowRunRecord> {
  /// Run UUID (primary key).
  final String id;

  /// The definition UUID this run was created from.
  final String definitionId;

  /// Human-readable definition name at launch time.
  final String definitionName;

  /// Full WorkflowDefinition JSON snapshot at launch time.
  final String definitionJson;

  /// Run status: running, completed, failed, cancelled.
  final String status;

  /// Run start timestamp.
  final DateTime startedAt;

  /// Run completion timestamp (null while running).
  final DateTime? completedAt;
  const WorkflowRunRecord({
    required this.id,
    required this.definitionId,
    required this.definitionName,
    required this.definitionJson,
    required this.status,
    required this.startedAt,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['definition_id'] = Variable<String>(definitionId);
    map['definition_name'] = Variable<String>(definitionName);
    map['definition_json'] = Variable<String>(definitionJson);
    map['status'] = Variable<String>(status);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    return map;
  }

  WorkflowRunsCompanion toCompanion(bool nullToAbsent) {
    return WorkflowRunsCompanion(
      id: Value(id),
      definitionId: Value(definitionId),
      definitionName: Value(definitionName),
      definitionJson: Value(definitionJson),
      status: Value(status),
      startedAt: Value(startedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory WorkflowRunRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkflowRunRecord(
      id: serializer.fromJson<String>(json['id']),
      definitionId: serializer.fromJson<String>(json['definitionId']),
      definitionName: serializer.fromJson<String>(json['definitionName']),
      definitionJson: serializer.fromJson<String>(json['definitionJson']),
      status: serializer.fromJson<String>(json['status']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'definitionId': serializer.toJson<String>(definitionId),
      'definitionName': serializer.toJson<String>(definitionName),
      'definitionJson': serializer.toJson<String>(definitionJson),
      'status': serializer.toJson<String>(status),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
    };
  }

  WorkflowRunRecord copyWith({
    String? id,
    String? definitionId,
    String? definitionName,
    String? definitionJson,
    String? status,
    DateTime? startedAt,
    Value<DateTime?> completedAt = const Value.absent(),
  }) => WorkflowRunRecord(
    id: id ?? this.id,
    definitionId: definitionId ?? this.definitionId,
    definitionName: definitionName ?? this.definitionName,
    definitionJson: definitionJson ?? this.definitionJson,
    status: status ?? this.status,
    startedAt: startedAt ?? this.startedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  WorkflowRunRecord copyWithCompanion(WorkflowRunsCompanion data) {
    return WorkflowRunRecord(
      id: data.id.present ? data.id.value : this.id,
      definitionId: data.definitionId.present
          ? data.definitionId.value
          : this.definitionId,
      definitionName: data.definitionName.present
          ? data.definitionName.value
          : this.definitionName,
      definitionJson: data.definitionJson.present
          ? data.definitionJson.value
          : this.definitionJson,
      status: data.status.present ? data.status.value : this.status,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkflowRunRecord(')
          ..write('id: $id, ')
          ..write('definitionId: $definitionId, ')
          ..write('definitionName: $definitionName, ')
          ..write('definitionJson: $definitionJson, ')
          ..write('status: $status, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    definitionId,
    definitionName,
    definitionJson,
    status,
    startedAt,
    completedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkflowRunRecord &&
          other.id == this.id &&
          other.definitionId == this.definitionId &&
          other.definitionName == this.definitionName &&
          other.definitionJson == this.definitionJson &&
          other.status == this.status &&
          other.startedAt == this.startedAt &&
          other.completedAt == this.completedAt);
}

class WorkflowRunsCompanion extends UpdateCompanion<WorkflowRunRecord> {
  final Value<String> id;
  final Value<String> definitionId;
  final Value<String> definitionName;
  final Value<String> definitionJson;
  final Value<String> status;
  final Value<DateTime> startedAt;
  final Value<DateTime?> completedAt;
  final Value<int> rowid;
  const WorkflowRunsCompanion({
    this.id = const Value.absent(),
    this.definitionId = const Value.absent(),
    this.definitionName = const Value.absent(),
    this.definitionJson = const Value.absent(),
    this.status = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkflowRunsCompanion.insert({
    required String id,
    required String definitionId,
    required String definitionName,
    required String definitionJson,
    required String status,
    required DateTime startedAt,
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       definitionId = Value(definitionId),
       definitionName = Value(definitionName),
       definitionJson = Value(definitionJson),
       status = Value(status),
       startedAt = Value(startedAt);
  static Insertable<WorkflowRunRecord> custom({
    Expression<String>? id,
    Expression<String>? definitionId,
    Expression<String>? definitionName,
    Expression<String>? definitionJson,
    Expression<String>? status,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (definitionId != null) 'definition_id': definitionId,
      if (definitionName != null) 'definition_name': definitionName,
      if (definitionJson != null) 'definition_json': definitionJson,
      if (status != null) 'status': status,
      if (startedAt != null) 'started_at': startedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkflowRunsCompanion copyWith({
    Value<String>? id,
    Value<String>? definitionId,
    Value<String>? definitionName,
    Value<String>? definitionJson,
    Value<String>? status,
    Value<DateTime>? startedAt,
    Value<DateTime?>? completedAt,
    Value<int>? rowid,
  }) {
    return WorkflowRunsCompanion(
      id: id ?? this.id,
      definitionId: definitionId ?? this.definitionId,
      definitionName: definitionName ?? this.definitionName,
      definitionJson: definitionJson ?? this.definitionJson,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (definitionId.present) {
      map['definition_id'] = Variable<String>(definitionId.value);
    }
    if (definitionName.present) {
      map['definition_name'] = Variable<String>(definitionName.value);
    }
    if (definitionJson.present) {
      map['definition_json'] = Variable<String>(definitionJson.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkflowRunsCompanion(')
          ..write('id: $id, ')
          ..write('definitionId: $definitionId, ')
          ..write('definitionName: $definitionName, ')
          ..write('definitionJson: $definitionJson, ')
          ..write('status: $status, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TaskSessionsTable taskSessions = $TaskSessionsTable(this);
  late final $WorkflowRunsTable workflowRuns = $WorkflowRunsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    taskSessions,
    workflowRuns,
  ];
}

typedef $$TaskSessionsTableCreateCompanionBuilder =
    TaskSessionsCompanion Function({
      Value<int> id,
      required String name,
      required String agentCliId,
      required String status,
      Value<String?> workingDirectory,
      Value<String?> description,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> completedAt,
      Value<int?> exitCode,
      Value<int?> durationMs,
      Value<String?> input,
      Value<String?> agentSessionId,
      Value<String?> output,
      Value<String?> notes,
      Value<String?> colorLabel,
      Value<String?> batchId,
      Value<int?> parentSessionId,
      Value<String?> workflowRunId,
      Value<String?> workflowNodeId,
      Value<String?> customArgs,
    });
typedef $$TaskSessionsTableUpdateCompanionBuilder =
    TaskSessionsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> agentCliId,
      Value<String> status,
      Value<String?> workingDirectory,
      Value<String?> description,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> completedAt,
      Value<int?> exitCode,
      Value<int?> durationMs,
      Value<String?> input,
      Value<String?> agentSessionId,
      Value<String?> output,
      Value<String?> notes,
      Value<String?> colorLabel,
      Value<String?> batchId,
      Value<int?> parentSessionId,
      Value<String?> workflowRunId,
      Value<String?> workflowNodeId,
      Value<String?> customArgs,
    });

class $$TaskSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $TaskSessionsTable> {
  $$TaskSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get agentCliId => $composableBuilder(
    column: $table.agentCliId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get workingDirectory => $composableBuilder(
    column: $table.workingDirectory,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get exitCode => $composableBuilder(
    column: $table.exitCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get input => $composableBuilder(
    column: $table.input,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get agentSessionId => $composableBuilder(
    column: $table.agentSessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get output => $composableBuilder(
    column: $table.output,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorLabel => $composableBuilder(
    column: $table.colorLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get batchId => $composableBuilder(
    column: $table.batchId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get parentSessionId => $composableBuilder(
    column: $table.parentSessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get workflowRunId => $composableBuilder(
    column: $table.workflowRunId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get workflowNodeId => $composableBuilder(
    column: $table.workflowNodeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customArgs => $composableBuilder(
    column: $table.customArgs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TaskSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $TaskSessionsTable> {
  $$TaskSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get agentCliId => $composableBuilder(
    column: $table.agentCliId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get workingDirectory => $composableBuilder(
    column: $table.workingDirectory,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get exitCode => $composableBuilder(
    column: $table.exitCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get input => $composableBuilder(
    column: $table.input,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get agentSessionId => $composableBuilder(
    column: $table.agentSessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get output => $composableBuilder(
    column: $table.output,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorLabel => $composableBuilder(
    column: $table.colorLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get batchId => $composableBuilder(
    column: $table.batchId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get parentSessionId => $composableBuilder(
    column: $table.parentSessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get workflowRunId => $composableBuilder(
    column: $table.workflowRunId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get workflowNodeId => $composableBuilder(
    column: $table.workflowNodeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customArgs => $composableBuilder(
    column: $table.customArgs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TaskSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TaskSessionsTable> {
  $$TaskSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get agentCliId => $composableBuilder(
    column: $table.agentCliId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get workingDirectory => $composableBuilder(
    column: $table.workingDirectory,
    builder: (column) => column,
  );

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get exitCode =>
      $composableBuilder(column: $table.exitCode, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get input =>
      $composableBuilder(column: $table.input, builder: (column) => column);

  GeneratedColumn<String> get agentSessionId => $composableBuilder(
    column: $table.agentSessionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get output =>
      $composableBuilder(column: $table.output, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get colorLabel => $composableBuilder(
    column: $table.colorLabel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get batchId =>
      $composableBuilder(column: $table.batchId, builder: (column) => column);

  GeneratedColumn<int> get parentSessionId => $composableBuilder(
    column: $table.parentSessionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get workflowRunId => $composableBuilder(
    column: $table.workflowRunId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get workflowNodeId => $composableBuilder(
    column: $table.workflowNodeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get customArgs => $composableBuilder(
    column: $table.customArgs,
    builder: (column) => column,
  );
}

class $$TaskSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TaskSessionsTable,
          TaskSession,
          $$TaskSessionsTableFilterComposer,
          $$TaskSessionsTableOrderingComposer,
          $$TaskSessionsTableAnnotationComposer,
          $$TaskSessionsTableCreateCompanionBuilder,
          $$TaskSessionsTableUpdateCompanionBuilder,
          (
            TaskSession,
            BaseReferences<_$AppDatabase, $TaskSessionsTable, TaskSession>,
          ),
          TaskSession,
          PrefetchHooks Function()
        > {
  $$TaskSessionsTableTableManager(_$AppDatabase db, $TaskSessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TaskSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaskSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TaskSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> agentCliId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> workingDirectory = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int?> exitCode = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<String?> input = const Value.absent(),
                Value<String?> agentSessionId = const Value.absent(),
                Value<String?> output = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> colorLabel = const Value.absent(),
                Value<String?> batchId = const Value.absent(),
                Value<int?> parentSessionId = const Value.absent(),
                Value<String?> workflowRunId = const Value.absent(),
                Value<String?> workflowNodeId = const Value.absent(),
                Value<String?> customArgs = const Value.absent(),
              }) => TaskSessionsCompanion(
                id: id,
                name: name,
                agentCliId: agentCliId,
                status: status,
                workingDirectory: workingDirectory,
                description: description,
                createdAt: createdAt,
                updatedAt: updatedAt,
                completedAt: completedAt,
                exitCode: exitCode,
                durationMs: durationMs,
                input: input,
                agentSessionId: agentSessionId,
                output: output,
                notes: notes,
                colorLabel: colorLabel,
                batchId: batchId,
                parentSessionId: parentSessionId,
                workflowRunId: workflowRunId,
                workflowNodeId: workflowNodeId,
                customArgs: customArgs,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String agentCliId,
                required String status,
                Value<String?> workingDirectory = const Value.absent(),
                Value<String?> description = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int?> exitCode = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<String?> input = const Value.absent(),
                Value<String?> agentSessionId = const Value.absent(),
                Value<String?> output = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> colorLabel = const Value.absent(),
                Value<String?> batchId = const Value.absent(),
                Value<int?> parentSessionId = const Value.absent(),
                Value<String?> workflowRunId = const Value.absent(),
                Value<String?> workflowNodeId = const Value.absent(),
                Value<String?> customArgs = const Value.absent(),
              }) => TaskSessionsCompanion.insert(
                id: id,
                name: name,
                agentCliId: agentCliId,
                status: status,
                workingDirectory: workingDirectory,
                description: description,
                createdAt: createdAt,
                updatedAt: updatedAt,
                completedAt: completedAt,
                exitCode: exitCode,
                durationMs: durationMs,
                input: input,
                agentSessionId: agentSessionId,
                output: output,
                notes: notes,
                colorLabel: colorLabel,
                batchId: batchId,
                parentSessionId: parentSessionId,
                workflowRunId: workflowRunId,
                workflowNodeId: workflowNodeId,
                customArgs: customArgs,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TaskSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TaskSessionsTable,
      TaskSession,
      $$TaskSessionsTableFilterComposer,
      $$TaskSessionsTableOrderingComposer,
      $$TaskSessionsTableAnnotationComposer,
      $$TaskSessionsTableCreateCompanionBuilder,
      $$TaskSessionsTableUpdateCompanionBuilder,
      (
        TaskSession,
        BaseReferences<_$AppDatabase, $TaskSessionsTable, TaskSession>,
      ),
      TaskSession,
      PrefetchHooks Function()
    >;
typedef $$WorkflowRunsTableCreateCompanionBuilder =
    WorkflowRunsCompanion Function({
      required String id,
      required String definitionId,
      required String definitionName,
      required String definitionJson,
      required String status,
      required DateTime startedAt,
      Value<DateTime?> completedAt,
      Value<int> rowid,
    });
typedef $$WorkflowRunsTableUpdateCompanionBuilder =
    WorkflowRunsCompanion Function({
      Value<String> id,
      Value<String> definitionId,
      Value<String> definitionName,
      Value<String> definitionJson,
      Value<String> status,
      Value<DateTime> startedAt,
      Value<DateTime?> completedAt,
      Value<int> rowid,
    });

class $$WorkflowRunsTableFilterComposer
    extends Composer<_$AppDatabase, $WorkflowRunsTable> {
  $$WorkflowRunsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get definitionId => $composableBuilder(
    column: $table.definitionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get definitionName => $composableBuilder(
    column: $table.definitionName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get definitionJson => $composableBuilder(
    column: $table.definitionJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WorkflowRunsTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkflowRunsTable> {
  $$WorkflowRunsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get definitionId => $composableBuilder(
    column: $table.definitionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get definitionName => $composableBuilder(
    column: $table.definitionName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get definitionJson => $composableBuilder(
    column: $table.definitionJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorkflowRunsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkflowRunsTable> {
  $$WorkflowRunsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get definitionId => $composableBuilder(
    column: $table.definitionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get definitionName => $composableBuilder(
    column: $table.definitionName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get definitionJson => $composableBuilder(
    column: $table.definitionJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );
}

class $$WorkflowRunsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkflowRunsTable,
          WorkflowRunRecord,
          $$WorkflowRunsTableFilterComposer,
          $$WorkflowRunsTableOrderingComposer,
          $$WorkflowRunsTableAnnotationComposer,
          $$WorkflowRunsTableCreateCompanionBuilder,
          $$WorkflowRunsTableUpdateCompanionBuilder,
          (
            WorkflowRunRecord,
            BaseReferences<
              _$AppDatabase,
              $WorkflowRunsTable,
              WorkflowRunRecord
            >,
          ),
          WorkflowRunRecord,
          PrefetchHooks Function()
        > {
  $$WorkflowRunsTableTableManager(_$AppDatabase db, $WorkflowRunsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkflowRunsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkflowRunsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkflowRunsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> definitionId = const Value.absent(),
                Value<String> definitionName = const Value.absent(),
                Value<String> definitionJson = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkflowRunsCompanion(
                id: id,
                definitionId: definitionId,
                definitionName: definitionName,
                definitionJson: definitionJson,
                status: status,
                startedAt: startedAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String definitionId,
                required String definitionName,
                required String definitionJson,
                required String status,
                required DateTime startedAt,
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkflowRunsCompanion.insert(
                id: id,
                definitionId: definitionId,
                definitionName: definitionName,
                definitionJson: definitionJson,
                status: status,
                startedAt: startedAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WorkflowRunsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkflowRunsTable,
      WorkflowRunRecord,
      $$WorkflowRunsTableFilterComposer,
      $$WorkflowRunsTableOrderingComposer,
      $$WorkflowRunsTableAnnotationComposer,
      $$WorkflowRunsTableCreateCompanionBuilder,
      $$WorkflowRunsTableUpdateCompanionBuilder,
      (
        WorkflowRunRecord,
        BaseReferences<_$AppDatabase, $WorkflowRunsTable, WorkflowRunRecord>,
      ),
      WorkflowRunRecord,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TaskSessionsTableTableManager get taskSessions =>
      $$TaskSessionsTableTableManager(_db, _db.taskSessions);
  $$WorkflowRunsTableTableManager get workflowRuns =>
      $$WorkflowRunsTableTableManager(_db, _db.workflowRuns);
}
