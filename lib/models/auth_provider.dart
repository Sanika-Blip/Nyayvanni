import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/officer_user.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  static const _tokenKey = 'nv_officer_token';
  static const _userKey = 'nv_officer_user';

  OfficerUser? _user;
  bool _ready = false;
  bool _busy = false;
  String? _error;

  OfficerUser? get user => _user;
  bool get isLoggedIn => _user != null && ApiService.token != null;
  bool get ready => _ready;
  bool get busy => _busy;
  String? get error => _error;

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final raw = prefs.getString(_userKey);
    if (token != null && raw != null) {
      ApiService.token = token;
      try {
        _user = OfficerUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        _user = await ApiService.me();
        await _persist(token, _user!);
      } catch (_) {
        await logout();
      }
    }
    _ready = true;
    notifyListeners();
  }

  Future<void> _persist(String token, OfficerUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  Future<bool> login(String officerId, String password) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final result = await ApiService.login(
        officerId: officerId.trim(),
        password: password,
      );
      ApiService.token = result.token;
      _user = result.user;
      await _persist(result.token, result.user);
      _busy = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _busy = false;
      notifyListeners();
      return false;
    }
  }

  Future<String> register(Map<String, String> fields) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final message = await ApiService.register(
        fullName: fields['fullName'] ?? '',
        email: fields['email'] ?? '',
        phone: fields['phone'] ?? '',
        rank: fields['rank'] ?? '',
        badgeNumber: fields['badgeNumber'] ?? '',
        station: fields['station'] ?? '',
        district: fields['district'] ?? '',
        state: fields['state'] ?? '',
        address: fields['address'] ?? '',
      );
      _busy = false;
      notifyListeners();
      return message;
    } catch (e) {
      _error = e.toString();
      _busy = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> updateProfile(Map<String, dynamic> payload) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      _user = await ApiService.updateMe(payload);
      if (ApiService.token != null) {
        await _persist(ApiService.token!, _user!);
      }
      _busy = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _busy = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _user = null;
    ApiService.token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    notifyListeners();
  }
}
