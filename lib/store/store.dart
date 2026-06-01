import 'dart:convert';
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
          ..orderBy([
            (t) => OrderingTerm.desc(t.isPinned),
            (t) => OrderingTerm.desc(t.createdAt),
          ]))
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

  Future<void> updateSessionTitle(int id, String title) async {
    await (db.update(db.chatSessions)..where((t) => t.id.equals(id))).write(
      ChatSessionsCompanion(title: Value(title)),
    );
  }

  Future<void> updateSessionPinned(int id, bool pinned) async {
    await (db.update(db.chatSessions)..where((t) => t.id.equals(id))).write(
      ChatSessionsCompanion(isPinned: Value(pinned)),
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

  Future<String> exportBackupJson() async {
    final sessions = await loadSessions();
    final List<Map<String, dynamic>> sessionsJson = [];

    for (final s in sessions) {
      final messages = await loadMessages(s.id);
      sessionsJson.add({
        'title': s.title,
        'modelName': s.modelName,
        'temperature': s.temperature,
        'systemPrompt': s.systemPrompt,
        'isPinned': s.isPinned,
        'messages': messages.map((m) => {
          'role': m.role,
          'content': m.content,
          'timestamp': m.timestamp.toIso8601String(),
        }).toList(),
      });
    }

    final backup = {
      'version': 1,
      'sessions': sessionsJson,
    };

    return jsonEncode(backup);
  }

  Future<void> importBackupJson(String jsonString) async {
    final data = jsonDecode(jsonString);
    if (data is! Map<String, dynamic> || data['sessions'] is! List) {
      throw const FormatException('Invalid backup file format');
    }

    final sessionsList = data['sessions'] as List;
    for (final sObj in sessionsList) {
      if (sObj is! Map<String, dynamic>) continue;
      final title = sObj['title'] as String? ?? 'Imported Chat';
      final modelName = sObj['modelName'] as String? ?? 'llama3.2';
      final temperature = (sObj['temperature'] as num?)?.toDouble() ?? 0.7;
      final systemPrompt = sObj['systemPrompt'] as String?;
      final isPinned = sObj['isPinned'] as bool? ?? false;

      // Insert session
      final sessionId = await db.into(db.chatSessions).insert(
        ChatSessionsCompanion.insert(
          title: title,
          modelName: modelName,
          temperature: Value(temperature),
          systemPrompt: Value(systemPrompt),
          isPinned: Value(isPinned),
        ),
      );

      final messages = sObj['messages'] as List? ?? [];
      for (final mObj in messages) {
        if (mObj is! Map<String, dynamic>) continue;
        final role = mObj['role'] as String? ?? 'user';
        final content = mObj['content'] as String? ?? '';
        final timestampStr = mObj['timestamp'] as String?;
        final timestamp = timestampStr != null 
            ? DateTime.tryParse(timestampStr) ?? DateTime.now() 
            : DateTime.now();

        await db.into(db.chatMessages).insert(
          ChatMessagesCompanion.insert(
            sessionId: sessionId,
            role: role,
            content: content,
            timestamp: Value(timestamp),
          ),
        );
      }
    }
  }
}

class ChatWithLastMessage {
  final ChatSession session;
  final ChatMessage? lastMessage;

  ChatWithLastMessage({required this.session, this.lastMessage});
}

