import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CloudinaryService {
  static const _cloudName = "dopx15jpp";
  static const _uploadPreset = "mychat_upload";
  static const _uploadUrl =
      "https://api.cloudinary.com/v1_1/$_cloudName/auto/upload";
  static const Duration _uploadTimeout = Duration(seconds: 30);
  static String get _groqKey =>
      dotenv.env['GROQ_API_KEY'] ??
      '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';

  // ── CHOISIR IMAGE DEPUIS GALERIE ──────────────────
  static Future<Map<String, String?>?> pickAndUploadImage({
    Function(double)? onProgress,
  }) async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (file == null) return null;
    return await _uploadAndAnalyze(file, onProgress: onProgress);
  }

  // ── PRENDRE PHOTO AVEC CAMÉRA ─────────────────────
  static Future<Map<String, String?>?> captureAndUploadImage({
    Function(double)? onProgress,
  }) async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );
    if (file == null) return null;
    return await _uploadAndAnalyze(file, onProgress: onProgress);
  }

  // ── CHOISIR VIDÉO ─────────────────────────────────
  static Future<Map<String, String?>?> pickAndUploadVideo({
    Function(double)? onProgress,
  }) async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 2),
    );
    if (file == null) return null;
    return await _uploadFile(file, onProgress: onProgress);
  }

  // ── UPLOAD + ANALYSE IA ───────────────────────────
  static Future<Map<String, String?>?> _uploadAndAnalyze(
    XFile file, {
    Function(double)? onProgress,
  }) async {
    // 1. Upload vers Cloudinary
    final result = await _uploadFile(file, onProgress: onProgress);
    if (result == null) return null;

    final url = result['url'];
    if (url == null) return result;

    // 2. Analyse IA avec Groq Vision
    try {
      onProgress?.call(0.95);
      final groqResponse = await http.post(
        Uri.parse("https://api.groq.com/openai/v1/chat/completions"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $_groqKey",
        },
        body: jsonEncode({
          "model": "meta-llama/llama-4-scout-17b-16e-instruct",
          "messages": [
            {
              "role": "user",
              "content": [
                {
                  "type": "text",
                  "text":
                      "Analyse cette image en français. Retourne uniquement un JSON valide avec les clés description et image_prompt. description = une phrase courte et nette. image_prompt = un prompt détaillé pour recréer l'image de façon réaliste et esthétique."
                },
                {
                  "type": "image_url",
                  "image_url": {"url": url}
                }
              ]
            }
          ],
          "response_format": {"type": "json_object"},
          "temperature": 0.7,
          "max_completion_tokens": 1024
        }),
      );

      if (groqResponse.statusCode == 200) {
        final data = jsonDecode(groqResponse.body);
        final content = data["choices"]?[0]?["message"]?["content"];
        if (content is String && content.isNotEmpty) {
          try {
            final parsed = jsonDecode(content);
            final description = parsed['description']?.toString();
            final imagePrompt = parsed['image_prompt']?.toString();
            if (description != null && description.isNotEmpty) {
              result['description'] = description;
            }
            if (imagePrompt != null && imagePrompt.isNotEmpty) {
              result['imagePrompt'] = imagePrompt;
            }
          } catch (_) {
            result['description'] = content;
          }
        }
      }
    } catch (_) {}

    onProgress?.call(1.0);
    return result;
  }

  // ── UPLOAD VERS CLOUDINARY ────────────────────────
  static Future<Map<String, String?>?> _uploadFile(
    XFile file, {
    Function(double)? onProgress,
  }) async {
    try {
      onProgress?.call(0.1);
      final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));
      request.fields['upload_preset'] = _uploadPreset;
      request.fields['resource_type'] = 'auto';

      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        onProgress?.call(0.3);
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: file.name,
        ));
      } else {
        request.files.add(await http.MultipartFile.fromPath(
          'file',
          file.path,
        ));
      }

      onProgress?.call(0.5);
      final response = await request.send().timeout(_uploadTimeout,
          onTimeout: () => throw Exception(
              'Délai d\'attente dépassé pour l\'upload Cloudinary.'));
      onProgress?.call(0.8);
      final responseData = await response.stream.bytesToString();
      final jsonData = jsonDecode(responseData);

      if (response.statusCode == 200) {
        return {
          'url': jsonData['secure_url'] as String,
          'type': jsonData['resource_type'] as String,
          'description': null,
        };
      }

      final errorMessage = jsonData['error']?['message'] ??
          'Échec de l\'upload Cloudinary (${response.statusCode}).';
      throw Exception(errorMessage);
    } catch (e) {
      rethrow;
    }
  }

  static Future<String?> uploadXFile(
    XFile file, {
    Function(double)? onProgress,
  }) async {
    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      return await uploadBytes(bytes, file.name, onProgress: onProgress);
    }
    final result = await _uploadFile(file, onProgress: onProgress);
    return result?['url'];
  }

  static Future<String?> uploadBytes(
    Uint8List bytes,
    String fileName, {
    Function(double)? onProgress,
  }) async {
    try {
      onProgress?.call(0.1);
      final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));
      request.fields['upload_preset'] = _uploadPreset;
      request.fields['resource_type'] = 'auto';
      onProgress?.call(0.3);
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
      ));

      onProgress?.call(0.5);
      final response = await request.send().timeout(_uploadTimeout,
          onTimeout: () => throw Exception(
              'Délai d\'attente dépassé pour l\'upload Cloudinary.'));
      onProgress?.call(0.8);
      final responseData = await response.stream.bytesToString();
      final jsonData = jsonDecode(responseData);

      if (response.statusCode == 200) {
        return jsonData['secure_url'] as String?;
      }

      final errorMessage = jsonData['error']?['message'] ??
          'Échec de l\'upload Cloudinary (${response.statusCode}).';
      throw Exception(errorMessage);
    } catch (e) {
      rethrow;
    }
  }
}
