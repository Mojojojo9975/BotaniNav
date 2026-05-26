// lib/services/vision_service.dart
//
// Calls the Gemini Vision API to check whether a user's photo matches
// a given plant description.
//
// Uses gemini-2.5-flash — free tier: 1,500 requests/day, no credit card.
// Get a free API key at: https://aistudio.google.com/apikey

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/env.dart';
import '../models/treasure_hunt.dart';

class VisionService {
  static const _model = 'gemini-2.5-flash';
  // Updated endpoint to v1beta for Structured Outputs support
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  /// Check whether [imageFile] matches [plant] at [difficulty].
  static Future<HuntResult> checkPlant({
    required File imageFile,
    required HuntPlant plant,
    required HuntDifficulty difficulty,
  }) async {
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
3. Write a short friendly explanation (1–2 sentences) for a garden visitor.

Respond ONLY with valid JSON — no markdown, no extra text:
{"matched": true, "confidence": 0.85, "explanation": "..."}
''';

    final response = await http.post(
      Uri.parse('$_endpoint?key=${Env.geminiApiKey}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {
                'inline_data': {
                  'mime_type': mediaType,
                  'data': base64Image,
                },
              },
              {
                'text': prompt,
              },
            ],
          },
        ],
        // Added safety settings to prevent false positives on botanical terms
        'safetySettings': [
          {
            'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
            'threshold': 'BLOCK_ONLY_HIGH', 
          },
        ],
        'generationConfig': {
          'temperature': 0.2,
          'maxOutputTokens': 1024,
          'responseMimeType': 'application/json',
          // Added response schema to force strict JSON compliance
          'responseSchema': {
            'type': 'OBJECT',
            'properties': {
              'matched': {
                'type': 'BOOLEAN'
              },
              'confidence': {
                'type': 'NUMBER'
              },
              'explanation': {
                'type': 'STRING'
              }
            },
            'required': ['matched', 'confidence', 'explanation']
          }
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Gemini API error ${response.statusCode}: ${response.body}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    // Extract text from Gemini response structure:
    // { "candidates": [{ "content": { "parts": [{ "text": "..." }] } }] }
    final text = (body['candidates'] as List)
        .first['content']['parts']
        .first['text'] as String;

    // Strip markdown fences if present.
    String clean = text
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();

    // Use regex to extract the JSON object in case of extra text.
    final jsonMatch = RegExp(r'\{[^{}]*\}').firstMatch(clean);
    if (jsonMatch != null) {
      clean = jsonMatch.group(0)!;
    }

    // Try-catch block added for safe JSON decoding
    try {
      final result = jsonDecode(clean) as Map<String, dynamic>;
      return HuntResult.fromJson(result, plant.id);
    } on FormatException catch (_) {
      throw Exception('The AI lost its train of thought. Please tap "Try again".');
    } catch (e) {
      throw Exception('Failed to read AI response: $e');
    }
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