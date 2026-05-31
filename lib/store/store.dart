import 'package:drift/drift.dart';
import 'drift.dart';

class MimaStore {
  MimaStore._();
  static final MimaStore instance = MimaStore._();

  final AppDatabase db = AppDatabase();

  // ---- Settings Helpers ----

  Future<String?> getSetting(String key) async {
    final query = db.select(db.appSettings)..where((t) => t.key.equals(key));
    final row = await query.getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, String value) async {
    await db.into(db.appSettings).insertOnConflictUpdate(
      AppSettingsCompanion(
        key: Value(key),
        value: Value(value),
      ),
    );
  }

  // ---- Chat Session Helpers ----

  Future<List<ChatSession>> loadSessions() async {
    return (db.select(db.chatSessions)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  Future<List<ChatWithLastMessage>> loadSessionsWithLastMessage() async {
    final sessions = await loadSessions();
    final list = <ChatWithLastMessage>[];
    for (final s in sessions) {
      final lastMsgQuery = db.select(db.chatMessages)
        ..where((t) => t.sessionId.equals(s.id))
        ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
        ..limit(1);
      final lastMsg = await lastMsgQuery.getSingleOrNull();
      list.add(ChatWithLastMessage(session: s, lastMessage: lastMsg));
    }
    return list;
  }


  Future<ChatSession> createSession(
    String title,
    String modelName, {
    double temperature = 0.7,
    String? systemPrompt,
  }) async {
    final id = await db.into(db.chatSessions).insert(
          ChatSessionsCompanion.insert(
            title: title,
            modelName: modelName,
            temperature: Value(temperature),
            systemPrompt: Value(systemPrompt),
          ),
        );
    return (db.select(db.chatSessions)..where((t) => t.id.equals(id)))
        .getSingle();
  }

  Future<void> updateSessionModel(int id, String modelName) async {
    await (db.update(db.chatSessions)..where((t) => t.id.equals(id))).write(
      ChatSessionsCompanion(modelName: Value(modelName)),
    );
  }

  Future<void> updateSessionConfig(int id,
      {double? temperature, String? systemPrompt}) async {
    await (db.update(db.chatSessions)..where((t) => t.id.equals(id))).write(
      ChatSessionsCompanion(
        temperature:
            temperature != null ? Value(temperature) : const Value.absent(),
        systemPrompt: Value(systemPrompt),
      ),
    );
  }

  Future<void> deleteSession(int id) async {
    await (db.delete(db.chatSessions)..where((t) => t.id.equals(id))).go();
  }

  // ---- Message Helpers ----

  Future<List<ChatMessage>> loadMessages(int sessionId) async {
    return (db.select(db.chatMessages)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
        .get();
  }

  Future<ChatMessage> addMessage(
      int sessionId, String role, String content) async {
    final id = await db.into(db.chatMessages).insert(
          ChatMessagesCompanion.insert(
            sessionId: sessionId,
            role: role,
            content: content,
          ),
        );
    return (db.select(db.chatMessages)..where((t) => t.id.equals(id)))
        .getSingle();
  }

  // ---- Global Cleanup ----

  Future<void> clearAllData() async {
    await db.delete(db.chatMessages).go();
    await db.delete(db.chatSessions).go();
    await db.delete(db.appSettings).go();
  }

  Future<void> clearAppSettings() async {
    await db.delete(db.appSettings).go();
  }

  Future<void> clearChatDatabase() async {
    await db.delete(db.chatMessages).go();
    await db.delete(db.chatSessions).go();
  }
}

class ChatWithLastMessage {
  final ChatSession session;
  final ChatMessage? lastMessage;

  ChatWithLastMessage({required this.session, this.lastMessage});
}

