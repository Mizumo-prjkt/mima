import 'package:drift/drift.dart';
import 'connection/connection.dart'
    if (dart.library.js_util) 'connection/web.dart'
    if (dart.library.io) 'connection/native.dart' as impl;

part 'drift.g.dart';

// 1. New Key/Value table for core app settings
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

// 2. Expanded ChatSessions to include model configuration knobs
class ChatSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 255)();
  TextColumn get modelName => text()();

  // New configuration options:
  RealColumn get temperature => real().withDefault(const Constant(0.7))();
  TextColumn get systemPrompt =>
      text().nullable()(); // Null means use model default

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// (Keep ChatMessages exact same as before)
class ChatMessages extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId =>
      integer().references(ChatSessions, #id, onDelete: KeyAction.cascade)();
  TextColumn get role => text()();
  TextColumn get content => text()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [AppSettings, ChatSessions, ChatMessages])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(impl.openConnection());

  @override
  int get schemaVersion => 1;
}
