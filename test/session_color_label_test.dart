import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coding_agent_dock/database/database.dart';
import 'package:drift/drift.dart' show Value;

AppDatabase _makeDb() => AppDatabase.forTesting(NativeDatabase.memory());

TaskSessionsCompanion _entry(String name) => TaskSessionsCompanion(
      name: Value(name),
      agentCliId: const Value('claude'),
      status: const Value('created'),
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    );

void main() {
  group('session color label', () {
    test('colorLabel is null by default', () async {
      final db = _makeDb();
      final id = await db.createSession(_entry('test'));
      final s = await db.getSession(id);
      expect(s!.colorLabel, isNull);
      await db.close();
    });

    test('set and read a color label', () async {
      final db = _makeDb();
      final id = await db.createSession(_entry('labeled'));
      await db.updateSessionColorLabel(id, 'blue');
      final s = await db.getSession(id);
      expect(s!.colorLabel, 'blue');
      await db.close();
    });

    test('update color label to a different color', () async {
      final db = _makeDb();
      final id = await db.createSession(_entry('change'));
      await db.updateSessionColorLabel(id, 'red');
      await db.updateSessionColorLabel(id, 'purple');
      final s = await db.getSession(id);
      expect(s!.colorLabel, 'purple');
      await db.close();
    });

    test('clear color label by passing null', () async {
      final db = _makeDb();
      final id = await db.createSession(_entry('clear'));
      await db.updateSessionColorLabel(id, 'green');
      await db.updateSessionColorLabel(id, null);
      final s = await db.getSession(id);
      expect(s!.colorLabel, isNull);
      await db.close();
    });

    test('returns false for non-existent session id', () async {
      final db = _makeDb();
      final updated = await db.updateSessionColorLabel(9999, 'red');
      expect(updated, isFalse);
      await db.close();
    });

    test('color label persists across multiple sessions independently', () async {
      final db = _makeDb();
      final id1 = await db.createSession(_entry('session1'));
      final id2 = await db.createSession(_entry('session2'));
      await db.updateSessionColorLabel(id1, 'orange');
      final s1 = await db.getSession(id1);
      final s2 = await db.getSession(id2);
      expect(s1!.colorLabel, 'orange');
      expect(s2!.colorLabel, isNull);
      await db.close();
    });
  });
}
