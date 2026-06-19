import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../models/ecosystem_model.dart';
import '../models/mains_evaluation_model.dart';

/// Service layer for communicating with the Go backend API.
///
/// Base URL defaults:
///   - Web:     http://localhost:8080
///   - Android: http://10.0.2.2:8080  (emulator loopback)
///   - iOS:     http://localhost:8080
///   - Desktop: http://localhost:8080
class ApiService {
  late final String baseUrl;
  String? _authToken;

  ApiService({String? customBaseUrl}) {
    if (customBaseUrl != null) {
      baseUrl = customBaseUrl;
    } else if (kIsWeb) {
      baseUrl = 'http://localhost:8080';
    } else if (Platform.isAndroid) {
      baseUrl = 'http://10.0.2.2:8080';
    } else {
      baseUrl = 'http://localhost:8080';
    }
  }

  /// Set the JWT auth token for authenticated requests.
  void setAuthToken(String? token) {
    _authToken = token;
  }

  /// Default headers for all API requests.
  Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      };

  // ─── Health Check ──────────────────────────────────────────────

  /// Pings the backend health-check endpoint.
  /// Returns the raw JSON map on success, throws on failure.
  Future<Map<String, dynamic>> ping() async {
    final uri = Uri.parse('$baseUrl/ping');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Health check failed',
        body: response.body,
      );
    }
  }

  // ─── Syllabus Refresher ───────────────────────────────────────

  /// Calls GET /api/v1/syllabus-refresher?topic=...
  ///
  /// Returns the high-yield summary string on success.
  /// Throws [ApiException] for HTTP errors.
  Future<String> getTopicRefresher(String topic) async {
    final uri = Uri.parse('$baseUrl/api/v1/syllabus-refresher?topic=${Uri.encodeComponent(topic)}');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return json['summary'] as String;
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Failed to fetch syllabus refresher',
        body: response.body,
      );
    }
  }

  // ─── Ecosystem Generation ─────────────────────────────────────

  /// Calls POST /api/v1/generate-ecosystem with the given request.
  ///
  /// Returns a fully parsed [EcosystemResponse] on success.
  /// Throws [ApiException] for HTTP errors.
  /// Throws [ApiException] with statusCode 0 for network/timeout errors.
  Future<EcosystemResponse> generateEcosystem(
      EcosystemRequest request) async {
    final uri = Uri.parse('$baseUrl/api/v1/generate-ecosystem');

    try {
      final response = await http
          .post(
            uri,
            headers: _headers,
            body: jsonEncode(request.toJson()),
          )
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () => throw ApiException(
              statusCode: 0,
              message: 'Request timed out after 60 seconds. '
                  'The AI is taking too long — try a shorter topic.',
              body: '',
            ),
          );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return EcosystemResponse.fromJson(json);
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Ecosystem generation failed',
          body: response.body,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        statusCode: 0,
        message: 'Network error: $e',
        body: '',
      );
    }
  }

  // ─── Bookmarks ────────────────────────────────────────────────

  /// Calls POST /api/v1/bookmarks to save a question to the database.
  /// Returns true on success, throws an ApiException on failure.
  Future<bool> saveBookmark({
    required String topic,
    required String questionId,
    required GeneratedQuestion question,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/bookmarks');

    try {
      final response = await http.post(
        uri,
        headers: _headers,
        body: jsonEncode({
          'topic': topic,
          'questionId': questionId,
          'question': {
            'id': question.id,
            'subject': question.subject,
            'difficulty': question.difficulty,
            'question_en': question.questionEn,
            'question_hi': question.questionHi,
            'options_en': question.optionsEn,
            'options_hi': question.optionsHi,
            'correct_option_index': question.correctOptionIndex,
            'explanation_en': question.explanationEn,
            'explanation_hi': question.explanationHi,
          }
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Failed to save bookmark',
          body: response.body,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        statusCode: 0,
        message: 'Network error while bookmarking: $e',
        body: '',
      );
    }
  }

  /// Calls DELETE /api/v1/bookmarks to remove a saved question.
  Future<bool> deleteBookmark(String questionId) async {
    // Send to the same URL as POST, but with DELETE method and JSON body
    final uri = Uri.parse('$baseUrl/api/v1/bookmarks');

    try {
      final response = await http.delete(
        uri, 
        headers: _headers, 
        body: jsonEncode({'questionId': questionId}) // Send ID in body
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Failed to remove bookmark',
          body: response.body,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        statusCode: 0,
        message: 'Network error while removing bookmark: $e',
        body: '',
      );
    }
  }

  /// Calls GET /api/v1/bookmarks/check to check if a bookmark exists.
  Future<bool> isBookmarked(String questionId) async {
    final uri = Uri.parse('$baseUrl/api/v1/bookmarks/check?questionId=$questionId');

    try {
      final response = await http.get(
        uri,
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json is Map<String, dynamic>) {
          if (json.containsKey('exists')) return json['exists'] == true;
          if (json.containsKey('bookmarked')) return json['bookmarked'] == true;
        }
        return true; // Fallback if 200 OK
      }
      return false;
    } catch (e) {
      // If endpoint fails or times out, safely return false for initial check
      return false;
    }
  }

  /// Calls GET /api/v1/bookmarks to retrieve all saved bookmarks.
  Future<List<Bookmark>> getBookmarks() async {
    final uri = Uri.parse('$baseUrl/api/v1/bookmarks');

    try {
      final response = await http.get(
        uri,
        headers: _headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final bookmarksJson = json['bookmarks'] as List<dynamic>? ?? [];
        return bookmarksJson
            .map((e) => Bookmark.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Failed to load bookmarks',
          body: response.body,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        statusCode: 0,
        message: 'Network error while loading bookmarks: $e',
        body: '',
      );
    }
  }

  // ─── AI Tutor Agent ───────────────────────────────────────────

  /// Calls POST /api/v1/tutor with a specific doubt query.
  Future<String> askTutor({
    required String questionText,
    required String correctAnswer,
    required String originalExplanation,
    required String doubtQuery,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/tutor');

    try {
      final response = await http.post(
        uri,
        headers: _headers,
        body: jsonEncode({
          'question_text': questionText,
          'correct_answer': correctAnswer,
          'original_explanation': originalExplanation,
          'doubt_query': doubtQuery,
        }),
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return json['response'] as String;
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Tutor generation failed',
          body: response.body,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        statusCode: 0,
        message: 'Tutor network error: $e',
        body: '',
      );
    }
  }

  // ─── Mains Evaluation ─────────────────────────────────────────

  /// Calls POST /api/v1/mains-evaluate to get feedback on a Mains essay.
  Future<MainsEvaluationResponse> evaluateMainsEssay(String topic, String essay) async {
    final uri = Uri.parse('$baseUrl/api/v1/mains-evaluate');

    try {
      final response = await http.post(
        uri,
        headers: _headers,
        body: jsonEncode({
          'topic': topic,
          'essay': essay,
        }),
      ).timeout(const Duration(seconds: 90));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return MainsEvaluationResponse.fromJson(json);
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Mains evaluation failed',
          body: response.body,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        statusCode: 0,
        message: 'Network error during mains evaluation: $e',
        body: '',
      );
    }
  }

  // ─── Daily Quiz ─────────────────────────────────────────────────

  /// Calls POST /api/v1/daily-quiz to generate 15 mixed PYQ questions.
  Future<EcosystemResponse> getDailyQuiz() async {
    final uri = Uri.parse('$baseUrl/api/v1/daily-quiz');

    try {
      final response = await http.post(
        uri,
        headers: _headers,
      ).timeout(
        const Duration(seconds: 90),
        onTimeout: () => throw ApiException(
          statusCode: 0,
          message: 'Daily quiz generation timed out. Please try again.',
          body: '',
        ),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return EcosystemResponse.fromJson(json);
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Daily quiz generation failed',
          body: response.body,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        statusCode: 0,
        message: 'Network error: $e',
        body: '',
      );
    }
  }

  // ─── Syllabus ───────────────────────────────────────────────────

  /// Calls GET /api/v1/syllabus to fetch the complete BPSC syllabus.
  Future<Map<String, dynamic>> getSyllabus() async {
    final uri = Uri.parse('$baseUrl/api/v1/syllabus');

    try {
      final response = await http.get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Failed to load syllabus',
          body: response.body,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        statusCode: 0,
        message: 'Network error: $e',
        body: '',
      );
    }
  }

  // ─── Profile ────────────────────────────────────────────────────

  /// Calls GET /api/v1/profile to fetch the user profile.
  Future<Map<String, dynamic>> getProfile() async {
    final uri = Uri.parse('$baseUrl/api/v1/profile');

    try {
      final response = await http.get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Failed to load profile',
          body: response.body,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        statusCode: 0,
        message: 'Network error: $e',
        body: '',
      );
    }
  }

  /// Calls PUT /api/v1/profile to update profile fields.
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> updates) async {
    final uri = Uri.parse('$baseUrl/api/v1/profile');

    try {
      final response = await http.put(
        uri,
        headers: _headers,
        body: jsonEncode(updates),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Failed to update profile',
          body: response.body,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        statusCode: 0,
        message: 'Network error: $e',
        body: '',
      );
    }
  }

  /// Calls GET /api/v1/profile/stats to fetch user stats.
  Future<Map<String, dynamic>> getProfileStats() async {
    final uri = Uri.parse('$baseUrl/api/v1/profile/stats');

    try {
      final response = await http.get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Failed to load stats',
          body: response.body,
        );
      }
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        statusCode: 0,
        message: 'Network error: $e',
        body: '',
      );
    }
  }
}

/// Custom exception for API errors with status code and body.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String body;

  const ApiException({
    required this.statusCode,
    required this.message,
    required this.body,
  });

  @override
  String toString() =>
      'ApiException($statusCode): $message\nBody: $body';
}
