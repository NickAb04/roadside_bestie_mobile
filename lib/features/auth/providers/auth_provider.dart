import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/api_service.dart';
import 'package:dio/dio.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider with ChangeNotifier {
  AuthStatus _status = AuthStatus.unknown;
  String? _token;
  String? _role;
  final ApiService _apiService = ApiService();

  AuthStatus get status => _status;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  String? get role => _role;

  AuthProvider() {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    _role = prefs.getString('auth_role');
    if (_token != null) {
      _status = AuthStatus.authenticated;
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    try {
      final response = await _apiService.dio.post('/login', data: {
        'email': email,
        'password': password,
      });

      final token = response.data['access_token'];
      final user = response.data['user'];
      
      if (token != null) {
        await _saveAuthData(token, user['role']);
        return true;
      }
      return false;
    } on DioException catch (e) {
      if (kDebugMode) print('Login Error: ${e.response?.data}');
      return false;
    } catch (e) {
      if (kDebugMode) print('Login Error: $e');
      return false;
    }
  }

  Future<String?> register({
    required String name,
    required String username,
    required String email,
    required String phone,
    required String role,
    required String password,
    required String confirmation,
  }) async {
    try {
      final response = await _apiService.dio.post('/register', data: {
        'name': name,
        'username': username,
        'email': email,
        'phone_number': phone,
        'role': role,
        'password': password,
        'password_confirmation': confirmation,
      });

      final token = response.data['access_token'];
      final user = response.data['user'];

      if (token != null) {
        await _saveAuthData(token, user['role']);
        return null; // Success
      }
      return 'Registration failed: No token received';
    } on DioException catch (e) {
      // ... existing error handling ...
      if (e.response != null && e.response!.data != null) {
        final data = e.response!.data;
        if (data is Map && data.containsKey('message')) {
            if (data.containsKey('errors')) {
                return data['errors'].toString();
            }
            return data['message'].toString();
        }
        return 'Error: ${e.response!.data}';
      }
      return 'Network Error: ${e.message}';
    } catch (e) {
      return 'Unexpected Error: $e';
    }
  }

  Future<void> logout() async {
    try {
      await _apiService.dio.post('/logout');
    } catch (e) {
      // Ignore
    } finally {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('auth_role');
      _token = null;
      _role = null;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  Future<void> _saveAuthData(String token, String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setString('auth_role', role);
    _token = token;
    _role = role;
    _status = AuthStatus.authenticated;
    notifyListeners();
  }
}
