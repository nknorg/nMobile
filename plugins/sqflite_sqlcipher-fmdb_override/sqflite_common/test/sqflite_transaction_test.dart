import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common/src/exception.dart';
import 'package:test/test.dart';

import 'test_scenario.dart';

void main() {
  group('transaction', () {
    final openStep = [
      'openDatabase',
      {'path': ':memory:', 'singleInstance': true},
      1
    ];
    final closeStep = [
      'closeDatabase',
      {'id': 1},
      null
    ];
    final transactionBeginStep = [
      'execute',
      {
        'sql': 'BEGIN IMMEDIATE',
        'arguments': null,
        'id': 1,
        'inTransaction': true
      },
      null,
    ];
    final transactionBeginFailureStep = [
      'execute',
      {
        'sql': 'BEGIN IMMEDIATE',
        'arguments': null,
        'id': 1,
        'inTransaction': true
      },
      SqfliteDatabaseException('failure', null),
    ];
    final transactionEndStep = [
      'execute',
      {'sql': 'COMMIT', 'arguments': null, 'id': 1, 'inTransaction': false},
      1
    ];
    test('basic', () async {
      final scenario = startScenario([
        openStep,
        transactionBeginStep,
        transactionEndStep,
        transactionBeginStep,
        transactionEndStep,
        closeStep,
      ]);
      final factory = scenario.factory;
      final db = await factory.openDatabase(inMemoryDatabasePath);

      await db.transaction((txn) async {});
      await db.transaction((txn) async {});
      await db.close();
      scenario.end();
    });
    test('error in begin', () async {
      final scenario = startScenario([
        openStep,
        transactionBeginFailureStep,
        transactionBeginStep,
        transactionEndStep,
        closeStep,
      ]);
      final factory = scenario.factory;
      final db = await factory.openDatabase(inMemoryDatabasePath);

      try {
        await db.transaction((txn) async {});
        fail('should fail');
      } on DatabaseException catch (_) {}
      await db.transaction((txn) async {});
      await db.close();
      scenario.end();
    });
    test('error in begin during open', () async {
      final scenario = startScenario([
        openStep,
        [
          'query',
          {'sql': 'PRAGMA user_version', 'arguments': null, 'id': 1},
          {},
        ],
        [
          'execute',
          {
            'sql': 'BEGIN EXCLUSIVE',
            'arguments': null,
            'id': 1,
            'inTransaction': true
          },
          SqfliteDatabaseException('failure', null),
        ],
        [
          'execute',
          {
            'sql': 'ROLLBACK',
            'arguments': null,
            'id': 1,
            'inTransaction': false
          },
          null,
        ],
        closeStep,
      ]);
      final factory = scenario.factory;
      try {
        await factory.openDatabase(inMemoryDatabasePath,
            options:
                OpenDatabaseOptions(version: 1, onCreate: (db, version) {}));
      } on DatabaseException catch (_) {}
      scenario.end();
    });
  });
}
