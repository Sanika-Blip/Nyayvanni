import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/officer_user.dart';
import '../models/report_model.dart';
import 'fir_parser.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://127.0.0.1:3000',
  );

  static String? token;

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
      throw ApiException(body['error'] as String? ?? 'Request failed');
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

  static Future<void> upsertDraft(PoliceReport report) async {
    try {
      await http
          .post(
            Uri.parse('$baseUrl/api/drafts'),
            headers: _headers,
            body: jsonEncode(report.toJson()),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  static Future<void> deleteDraft(String id) async {
    try {
      await http
          .delete(Uri.parse('$baseUrl/api/drafts/$id'), headers: _headers)
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
  }
}
