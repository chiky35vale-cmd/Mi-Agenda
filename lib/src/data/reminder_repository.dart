import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../models/reminder.dart';

abstract interface class ReminderRepository {
  Future<void> initialize();
  Future<List<Reminder>> fetchAll();
  Future<Reminder?> fetchById(int reminderId);
  Future<Reminder> insert(Reminder reminder);
  Future<Reminder> update(Reminder reminder);
  Future<void> delete(int reminderId);
}

class SqfliteReminderRepository implements ReminderRepository {
  static const String _databaseName = 'recordatorio.db';
  static const String _tableName = 'reminders';

  Database? _database;

  @override
  Future<void> initialize() async {
    if (_database != null) {
      return;
    }

    final databasePath = await getDatabasesPath();
    _database = await openDatabase(
      path.join(databasePath, _databaseName),
      version: 6,
      onCreate: _createSchema,
      onUpgrade: _upgradeSchema,
    );
  }

  @override
  Future<List<Reminder>> fetchAll() async {
    final rows = await _db.query(_tableName);
    return rows.map(Reminder.fromMap).toList();
  }

  @override
  Future<Reminder?> fetchById(int reminderId) async {
    final rows = await _db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: <Object?>[reminderId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return Reminder.fromMap(rows.first);
  }

  @override
  Future<Reminder> insert(Reminder reminder) async {
    final values = reminder.toMap()..remove('id');
    final reminderId = await _db.insert(_tableName, values);
    return reminder.copyWith(id: reminderId);
  }

  @override
  Future<Reminder> update(Reminder reminder) async {
    final reminderId = reminder.id;
    if (reminderId == null) {
      throw ArgumentError('El recordatorio necesita un id para actualizarse.');
    }

    final values = reminder.toMap()..remove('id');
    await _db.update(
      _tableName,
      values,
      where: 'id = ?',
      whereArgs: <Object?>[reminderId],
    );
    return reminder;
  }

  @override
  Future<void> delete(int reminderId) async {
    await _db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: <Object?>[reminderId],
    );
  }

  Database get _db {
    final database = _database;
    if (database == null) {
      throw StateError('La base de datos no se ha inicializado.');
    }
    return database;
  }

  Future<void> _createSchema(Database database, int version) async {
    await database.execute('''
      CREATE TABLE $_tableName(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        scheduled_at TEXT NOT NULL,
        advance_minutes INTEGER NOT NULL DEFAULT 0,
        repeat_interval TEXT NOT NULL DEFAULT 'none',
        repeat_month_day INTEGER,
        repeat_month_week INTEGER,
        repeat_month_week_from_end INTEGER,
        repeat_month_weekday INTEGER,
        repeat_month_last_day INTEGER NOT NULL DEFAULT 0,
        is_completed INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        kind TEXT NOT NULL DEFAULT 'reminder',
        has_schedule INTEGER NOT NULL DEFAULT 1,
        snoozed_until TEXT
      )
    ''');
  }

  Future<void> _upgradeSchema(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await database.execute(
        'ALTER TABLE $_tableName ADD COLUMN advance_minutes INTEGER NOT NULL DEFAULT 0',
      );
      await database.execute(
        'ALTER TABLE $_tableName ADD COLUMN snoozed_until TEXT',
      );
    }
    if (oldVersion < 3) {
      await database.execute(
        "ALTER TABLE $_tableName ADD COLUMN repeat_interval TEXT NOT NULL DEFAULT 'none'",
      );
    }
    if (oldVersion < 4) {
      await database.execute(
        'ALTER TABLE $_tableName ADD COLUMN repeat_month_day INTEGER',
      );
      await database.execute(
        'ALTER TABLE $_tableName ADD COLUMN repeat_month_week INTEGER',
      );
      await database.execute(
        'ALTER TABLE $_tableName ADD COLUMN repeat_month_weekday INTEGER',
      );
      await database.execute(
        'ALTER TABLE $_tableName ADD COLUMN repeat_month_last_day INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 5) {
      await database.execute(
        'ALTER TABLE $_tableName ADD COLUMN repeat_month_week_from_end INTEGER',
      );
    }
    if (oldVersion < 6) {
      await database.execute(
        "ALTER TABLE $_tableName ADD COLUMN kind TEXT NOT NULL DEFAULT 'reminder'",
      );
      await database.execute(
        'ALTER TABLE $_tableName ADD COLUMN has_schedule INTEGER NOT NULL DEFAULT 1',
      );
    }
  }
}
