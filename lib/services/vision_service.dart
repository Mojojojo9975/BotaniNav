// lib/services/vision_service.dart
//
// Calls the Claude vision API to determine whether a user's photo matches
// a given plant description. Returns a HuntResult with match, confidence,
// and a short explanation suitable for display to a garden visitor.

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/env.dart';
import '../models/treasure_hunt.dart';

class VisionService {
  static const _model = 'claude-sonnet-4-20250514';
  static const _endpoint = 'https://api.anthropic.com/v1/messages';

  /// Check whether [imageFile] matches [plant] at [difficulty].
  static Future<HuntResult> checkPlant({
    required File imageFile,
    required HuntPlant plant,
    required HuntDifficulty difficulty,
  }) async {
    // Encode image to base64.
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);
    final mediaType = _mediaType(imageFile.path);

    final prompt = '''
You are helping judge a botanical garden treasure hunt.

The player was searching for a plant using this hint:
"${plant.hintFor(difficulty)}"

The plant they should have found is described as:
"${plant.imageDescription}"

Look carefully at the attached photo and decide:
1. Does the photo show a plant that matches the description above?
2. How confident are you? (a number between 0.0 and 1.0)
3. Write a short, friendly explanation (1–2 sentences) suitable for a garden visitor.

Respond ONLY with valid JSON — no markdown, no extra text:
{"matched": true, "confidence": 0.85, "explanation": "..."}
''';

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': Env.anthropicApiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': _model,
        'max_tokens': 256,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'image',
                'source': {
                  'type': 'base64',
                  'media_type': mediaType,
                  'data': base64Image,
                },
              },
              {
                'type': 'text',
                'text': prompt,
              },
            ],
          },
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Vision API error ${response.statusCode}: ${response.body}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final text = (body['content'] as List)
        .whereType<Map>()
        .where((b) => b['type'] == 'text')
        .map((b) => b['text'] as String)
        .join();

    // Strip any accidental markdown fences.
    final clean = text
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();

    final result = jsonDecode(clean) as Map<String, dynamic>;
    return HuntResult.fromJson(result, plant.id);
  }

  static String _mediaType(String path) {
    final ext = path.split('.').last.toLowerCase();
    return switch (ext) {
      'png'  => 'image/png',
      'webp' => 'image/webp',
      'gif'  => 'image/gif',
      _      => 'image/jpeg',
    };
  }
}
