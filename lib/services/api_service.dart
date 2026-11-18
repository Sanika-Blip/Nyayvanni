import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/officer_user.dart';
import '../models/report_model.dart';
import 'fir_parser.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});

  bool get isAuthError => statusCode == 401;

  @override
  String toString() => message;
}

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://127.0.0.1:3000',
  );

  static String? token;

  /// Called when the server rejects the saved session (expired, disabled or removed account).
  static void Function()? onUnauthorized;

  /// Turns any error into a short message that is safe to show to the officer.
  static String describe(Object e) {
    if (e is ApiException) return e.message;
    if (e is TimeoutException) {
      return 'The server took too long to respond. Please try again.';
    }
    if (e is SocketException || e is http.ClientException) {
      return 'Cannot reach the server. Check your connection and try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null && token!.isNotEmpty)
          'Authorization': 'Bearer $token',
      };

  static Future<Map<String, dynamic>> _decode(http.Response response) async {
    Map<String, dynamic> body = {};
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {}
    if (response.statusCode >= 400) {
      if (response.statusCode == 401 && token != null) {
        onUnauthorized?.call();
      }
      throw ApiException(
        body['error'] as String? ?? 'Request failed',
        statusCode: response.statusCode,
      );
    }
    return body;
  }

  static Future<({String token, OfficerUser user})> login({
    required String officerId,
    required String password,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'officerId': officerId, 'password': password}),
        )
        .timeout(const Duration(seconds: 12));
    final body = await _decode(response);
    return (
      token: body['token'] as String,
      user: OfficerUser.fromJson(Map<String, dynamic>.from(body['user'])),
    );
  }

  static Future<String> register({
    required String fullName,
    required String email,
    required String phone,
    required String rank,
    required String badgeNumber,
    required String station,
    required String district,
    required String state,
    required String address,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/registrations'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'fullName': fullName,
            'email': email,
            'phone': phone,
            'rank': rank,
            'badgeNumber': badgeNumber,
            'station': station,
            'district': district,
            'state': state,
            'address': address,
          }),
        )
        .timeout(const Duration(seconds: 12));
    final body = await _decode(response);
    return body['message'] as String? ?? 'Registration submitted.';
  }

  static Future<OfficerUser> me() async {
    final response = await http
        .get(Uri.parse('$baseUrl/api/me'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    final body = await _decode(response);
    return OfficerUser.fromJson(Map<String, dynamic>.from(body['user']));
  }

  static Future<OfficerUser> updateMe(Map<String, dynamic> payload) async {
    final response = await http
        .put(
          Uri.parse('$baseUrl/api/me'),
          headers: _headers,
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 10));
    final body = await _decode(response);
    return OfficerUser.fromJson(Map<String, dynamic>.from(body['data']));
  }

  static Future<List<Map<String, dynamic>>> fetchStations() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/stations'))
          .timeout(const Duration(seconds: 8));
      final body = await _decode(response);
      return (body['data'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<ParsedFirFields> parseTranscript({
    required String transcript,
    required Language language,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/parse'),
            headers: _headers,
            body: jsonEncode({
              'transcript': transcript,
              'language': language.name,
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final data = body['data'] as Map<String, dynamic>? ?? body;
        return ParsedFirFields.fromJson(data);
      }
    } catch (_) {}
    return FirParser.parse(transcript, language: language);
  }

  static Future<List<PoliceReport>> fetchDrafts() async {
    final response = await http
        .get(Uri.parse('$baseUrl/api/drafts'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    final body = await _decode(response);
    return (body['data'] as List<dynamic>? ?? [])
        .map((e) => PoliceReport.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Returns true only when the server confirmed the save, so callers can retry later.
  static Future<bool> upsertDraft(PoliceReport report) async {
    if (token == null) return false;
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/drafts'),
            headers: _headers,
            body: jsonEncode(report.toJson()),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 401) onUnauthorized?.call();
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// Returns true when the draft is gone from the server (deleted or already missing).
  static Future<bool> deleteDraft(String id) async {
    if (token == null) return false;
    try {
      final response = await http
          .delete(Uri.parse('$baseUrl/api/drafts/$id'), headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 401) onUnauthorized?.call();
      return (response.statusCode >= 200 && response.statusCode < 300) ||
          response.statusCode == 404;
    } catch (_) {
      return false;
    }
  }

  /// Sends a finished draft to the station supervisor. Throws [ApiException] with
  /// a readable message (for example when required fields are missing).
  static Future<PoliceReport> submitDraft(String id) async {
    final response = await http
        .post(Uri.parse('$baseUrl/api/drafts/$id/submit'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    final body = await _decode(response);
    return PoliceReport.fromJson(Map<String, dynamic>.from(body['data']));
  }

  static Future<List<PoliceReport>> fetchReviewQueue() async {
    final response = await http
        .get(Uri.parse('$baseUrl/api/review/queue'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    final body = await _decode(response);
    return (body['data'] as List<dynamic>? ?? [])
        .map((e) => PoliceReport.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// decision is 'approved' or 'returned'; a comment is required to return.
  static Future<PoliceReport> reviewDraft(
    String id, {
    required String decision,
    String comment = '',
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/review/$id'),
          headers: _headers,
          body: jsonEncode({'decision': decision, 'comment': comment}),
        )
        .timeout(const Duration(seconds: 10));
    final body = await _decode(response);
    return PoliceReport.fromJson(Map<String, dynamic>.from(body['data']));
  }
}
