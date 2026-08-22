import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/transcription.dart';

class CloudSttService {
  static const String _endpoint =
      'https://api.groq.com/openai/v1/audio/transcriptions';
  static const String _model = 'whisper-large-v3';

  final String apiKey;
  final http.Client? client;

  const CloudSttService({
    required this.apiKey,
    this.client,
  });

  Future<Transcription> transcribe(String audioPath) async {
    if (apiKey.isEmpty) {
      throw const TranscriptionException(
          'API key de Groq no configurada. Ve a Settings para agregarla.');
    }

    final file = File(audioPath);
    if (!await file.exists()) {
      throw const TranscriptionException('Archivo de audio no encontrado.');
    }

    final request = http.MultipartRequest('POST', Uri.parse(_endpoint));
    request.headers['Authorization'] = 'Bearer $apiKey';
    request.fields['model'] = _model;
    request.fields['language'] = 'es';
    request.files.add(await http.MultipartFile.fromPath('file', audioPath));

    http.StreamedResponse response;
    try {
      final effectiveClient = client;
      final future = effectiveClient != null
          ? effectiveClient.send(request)
          : request.send();
      response = await future.timeout(
        const Duration(seconds: 30),
      );
    } on SocketException {
      throw const TranscriptionException('Sin conexión a internet.');
    } on http.ClientException {
      throw const TranscriptionException('Sin conexión a internet.');
    } on HttpException {
      throw const TranscriptionException('Sin conexión a internet.');
    } on HandshakeException {
      throw const TranscriptionException('Sin conexión a internet.');
    } on TlsException {
      throw const TranscriptionException('Sin conexión a internet.');
    } on TimeoutException {
      throw const TranscriptionException(
          'Tiempo de espera agotado al conectar con el servidor.');
    } catch (e) {
      if (e is TranscriptionException) rethrow;
      throw const TranscriptionException('Sin conexión a internet.');
    }

    if (response.statusCode == 200) {
      final body = await response.stream.bytesToString();
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final text = decoded['text'] as String;
      return Transcription(
        text: text,
        timestamp: DateTime.now(),
        isLocal: false,
      );
    }

    if (response.statusCode == 401) {
      throw const TranscriptionException(
          'API key inválida. Verifica tu clave en Settings.');
    }
    if (response.statusCode == 429) {
      throw const TranscriptionException(
          'Límite de solicitudes alcanzado. Espera un momento e intenta de nuevo.');
    }

    throw TranscriptionException(
        'Error del servidor Groq (${response.statusCode}). Intenta de nuevo.');
  }
}

class TranscriptionException implements Exception {
  final String message;
  const TranscriptionException(this.message);

  @override
  String toString() => message;
}
