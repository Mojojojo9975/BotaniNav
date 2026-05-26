// lib/services/vision_service.dart
//
// Calls the Gemini Vision API to check whether a user's photo matches
// a given plant description.
//
// Uses gemini-1.5-flash — free tier: 1,500 requests/day, no credit card.
// Get a free API key at: https://aistudio.google.com/apikey

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/env.dart';
import '../models/treasure_hunt.dart';

class VisionService {
  // Using 'latest' to avoid 404s on v1beta
  static const _model = 'gemini-2.5-flash';
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
3. Write a short friendly explanation (1–2 sentences) for a garden visitor. (CRITICAL: Do not use any double quotes inside your explanation string, use single quotes if needed).

Respond ONLY with valid JSON — no markdown, no extra text:
{"matched": true, "confidence": 0.85, "explanation": "..."}
''';

    final requestBody = jsonEncode({
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
        'responseSchema': {
          'type': 'OBJECT',
          'properties': {
            'matched': {'type': 'BOOLEAN'},
            'confidence': {'type': 'NUMBER'},
            'explanation': {'type': 'STRING'}
          },
          'required': ['matched', 'confidence', 'explanation']
        }
      },
    });

    // ── Retry Logic for 503 and 429 Errors ──────────────────────────────────
    int maxAttempts = 3;
    http.Response? response;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        response = await http.post(
          Uri.parse('$_endpoint?key=${Env.geminiApiKey}'),
          headers: {'Content-Type': 'application/json'},
          body: requestBody,
        );

        // If successful, or if it's an error we shouldn't retry (like 400 Bad Request)
        if (response.statusCode == 200 || 
           (response.statusCode != 503 && response.statusCode != 429)) {
          break;
        }

        // If it's a 503 or 429 and we have attempts left, wait and try again
        if (attempt < maxAttempts) {
          await Future.delayed(Duration(seconds: attempt)); // Exponential backoff: 1s, 2s...
        }
      } catch (e) {
        // Handle network drops (e.g., SocketException)
        if (attempt == maxAttempts) {
          throw Exception('Network error: Unable to reach the AI. Please check your connection and try again.');
        }
        await Future.delayed(Duration(seconds: attempt));
      }
    }

    // ── Error Handling ──────────────────────────────────────────────────────
    if (response == null) {
      throw Exception('Failed to connect to the server.');
    }

    if (response.statusCode == 503) {
      throw Exception('The botanical AI is taking a quick break due to high traffic! 🌿 Wait a few seconds and tap "Try again".');
    } else if (response.statusCode == 429) {
      throw Exception('Whoa, too many photos at once! Please wait a moment before trying again.');
    } else if (response.statusCode != 200) {
      throw Exception('API Error ${response.statusCode}: ${response.body}');
    }

    // ── JSON Parsing ────────────────────────────────────────────────────────
    final body = jsonDecode(response.body) as Map<String, dynamic>;

    final text = (body['candidates'] as List)
        .first['content']['parts']
        .first['text'] as String;

    try {
      // Because responseMimeType is application/json, 'text' is already pure JSON!
      final result = jsonDecode(text.trim()) as Map<String, dynamic>;
      return HuntResult.fromJson(result, plant.id);
    } on FormatException catch (_) {
      // TEMPORARY DEBUGGING: Let's see exactly what the AI output was if it fails
      throw Exception('JSON Error. Raw output was: \n\n$text');
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