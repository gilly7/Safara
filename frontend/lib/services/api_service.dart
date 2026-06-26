import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/document_info.dart';
import '../models/source_info.dart';

class ApiConfig {
  static String get defaultBaseUrl {
    if (kIsWeb) return 'http://localhost:8080';
    if (Platform.isAndroid) return 'http://10.0.2.2:8080';
    return 'http://localhost:8080';
  }
}

typedef ChatStreamCallbacks = ({
  void Function(List<SourceInfo> sources) onSources,
  void Function(String token) onToken,
  void Function() onDone,
  void Function(String error) onError,
});

class ApiService {
  ApiService({String? baseUrl}) : _baseUrl = baseUrl ?? ApiConfig.defaultBaseUrl {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 5),
    ));
  }

  final String _baseUrl;
  late final Dio _dio;

  String get baseUrl => _baseUrl;

  Future<void> streamChat({
    required String sessionId,
    required String message,
    required ChatStreamCallbacks callbacks,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.post<ResponseBody>(
        '/api/chat',
        data: {'sessionId': sessionId, 'message': message},
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Accept': 'text/event-stream'},
        ),
        cancelToken: cancelToken,
      );

      String? currentEvent;
      final stream = response.data?.stream;
      if (stream == null) {
        callbacks.onError('No response stream');
        return;
      }

      await for (final line in utf8.decoder.bind(stream).transform(const LineSplitter())) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        if (trimmed.startsWith('event:')) {
          currentEvent = trimmed.substring(6).trim();
        } else if (trimmed.startsWith('data:')) {
          final data = trimmed.substring(5).trim();
          _handleSseEvent(currentEvent, data, callbacks);
        }
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return;
      callbacks.onError(e.message ?? 'Network error');
    } catch (e) {
      callbacks.onError(e.toString());
    }
  }

  void _handleSseEvent(String? event, String data, ChatStreamCallbacks callbacks) {
    switch (event) {
      case 'sources':
        final list = (jsonDecode(data) as List<dynamic>)
            .map((e) => SourceInfo.fromJson(e as Map<String, dynamic>))
            .toList();
        callbacks.onSources(list);
      case 'token':
        callbacks.onToken(data);
      case 'done':
        callbacks.onDone();
      case 'error':
        callbacks.onError(data);
      default:
        if (data.isNotEmpty && data != 'complete') {
          callbacks.onToken(data);
        }
    }
  }

  Future<List<DocumentInfo>> fetchDocuments() async {
    final response = await _dio.get<List<dynamic>>('/api/documents');
    return (response.data ?? [])
        .map((e) => DocumentInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Map<String, dynamic>>> uploadDocuments(List<String> filePaths) async {
    final files = <MultipartFile>[];
    for (final path in filePaths) {
      final name = path.split(Platform.pathSeparator).last;
      files.add(await MultipartFile.fromFile(path, filename: name));
    }

    final formData = FormData.fromMap({'files': files});
    final response = await _dio.post<List<dynamic>>(
      '/api/ingest',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    return (response.data ?? []).cast<Map<String, dynamic>>();
  }
}
