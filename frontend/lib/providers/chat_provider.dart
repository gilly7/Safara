import 'dart:convert';

import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/source_info.dart';
import '../services/api_service.dart';

class ChatProvider extends ChangeNotifier {
  ChatProvider(this._apiService);

  final ApiService _apiService;
  final _uuid = const Uuid();

  static const _sessionKey = 'current_session_id';
  static const _messagesPrefix = 'messages_';
  static const _sessionListKey = 'session_ids';

  final ChatUser safaraUser = ChatUser(
    id: 'safara',
    firstName: 'Safara',
    profileImage: null,
  );

  late ChatUser currentUser = ChatUser(id: 'user', firstName: 'You');

  String _sessionId = '';
  List<ChatMessage> _messages = [];
  final Map<String, List<SourceInfo>> _sourcesByMessageId = {};
  bool _isStreaming = false;
  CancelToken? _cancelToken;

  String get sessionId => _sessionId;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isStreaming => _isStreaming;
  Map<String, List<SourceInfo>> get sourcesByMessageId => Map.unmodifiable(_sourcesByMessageId);

  List<SourceInfo> sourcesForMessage(String messageId) =>
      _sourcesByMessageId[messageId] ?? [];

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _sessionId = prefs.getString(_sessionKey) ?? _uuid.v4();
    await prefs.setString(_sessionKey, _sessionId);
    await _loadMessages();
    notifyListeners();
  }

  Future<void> newSession() async {
    _sessionId = _uuid.v4();
    _messages = [];
    _sourcesByMessageId.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, _sessionId);
    final sessions = prefs.getStringList(_sessionListKey) ?? [];
    if (!sessions.contains(_sessionId)) {
      sessions.insert(0, _sessionId);
      await prefs.setStringList(_sessionListKey, sessions);
    }
    await _saveMessages();
    notifyListeners();
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || _isStreaming) return;

    final userMessage = ChatMessage(
      text: text.trim(),
      user: currentUser,
      createdAt: DateTime.now(),
    );
    _messages.insert(0, userMessage);
    notifyListeners();

    final aiMessageId = _uuid.v4();
    var aiText = '';
    final aiMessage = ChatMessage(
      text: '',
      user: safaraUser,
      createdAt: DateTime.now(),
      customProperties: {'id': aiMessageId, 'streaming': true},
    );
    _messages.insert(0, aiMessage);

    _isStreaming = true;
    _cancelToken = CancelToken();
    notifyListeners();

    List<SourceInfo>? pendingSources;

    await _apiService.streamChat(
      sessionId: _sessionId,
      message: text.trim(),
      cancelToken: _cancelToken,
      callbacks: (
        onSources: (sources) {
          pendingSources = sources;
          _sourcesByMessageId[aiMessageId] = sources;
          notifyListeners();
        },
        onToken: (token) {
          aiText += token;
          _updateAiMessage(aiMessageId, aiText, streaming: true);
        },
        onDone: () {
          _updateAiMessage(aiMessageId, aiText, streaming: false);
          if (pendingSources != null) {
            _sourcesByMessageId[aiMessageId] = pendingSources!;
          }
          _isStreaming = false;
          _cancelToken = null;
          _saveMessages();
          notifyListeners();
        },
        onError: (error) {
          _updateAiMessage(
            aiMessageId,
            aiText.isEmpty ? 'Sorry, something went wrong: $error' : aiText,
            streaming: false,
          );
          _isStreaming = false;
          _cancelToken = null;
          _saveMessages();
          notifyListeners();
        },
      ),
    );
  }

  void _updateAiMessage(String id, String text, {required bool streaming}) {
    final index = _messages.indexWhere(
      (m) => m.customProperties?['id'] == id,
    );
    if (index == -1) return;

    final existing = _messages[index];
    _messages[index] = ChatMessage(
      text: text,
      user: existing.user,
      createdAt: existing.createdAt,
      customProperties: {'id': id, 'streaming': streaming},
    );
    notifyListeners();
  }

  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_messagesPrefix$_sessionId');
    if (raw == null) {
      _messages = [];
      return;
    }

    final data = jsonDecode(raw) as Map<String, dynamic>;
    _messages = (data['messages'] as List<dynamic>).map((m) {
      final map = m as Map<String, dynamic>;
      final isSafara = map['isSafara'] as bool;
      return ChatMessage(
        text: map['text'] as String,
        user: isSafara ? safaraUser : currentUser,
        createdAt: DateTime.parse(map['createdAt'] as String),
        customProperties: map['customProperties'] as Map<String, dynamic>?,
      );
    }).toList();

    final sourcesRaw = data['sources'] as Map<String, dynamic>? ?? {};
    _sourcesByMessageId.clear();
    for (final entry in sourcesRaw.entries) {
      _sourcesByMessageId[entry.key] = (entry.value as List<dynamic>)
          .map((e) => SourceInfo.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  }

  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final serialized = {
      'messages': _messages.map((m) {
        return {
          'text': m.text,
          'isSafara': m.user.id == safaraUser.id,
          'createdAt': m.createdAt.toIso8601String(),
          'customProperties': m.customProperties,
        };
      }).toList(),
      'sources': _sourcesByMessageId.map(
        (key, value) => MapEntry(
          key,
          value
              .map((s) => {
                    'fileName': s.fileName,
                    'excerpt': s.excerpt,
                    'score': s.score,
                  })
              .toList(),
        ),
      ),
    };
    await prefs.setString('$_messagesPrefix$_sessionId', jsonEncode(serialized));
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }
}
