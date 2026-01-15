import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // REPLACE THIS IP with your Backend Teammate's IPv4 Address
  // If testing on Emulator: 'http://10.0.2.2:8000/api'
  // If testing on Real Phone: 'http://10.79.3.29:8000/api'
  static const String baseUrl = 'http://10.79.3.29:8000/api'; 

  final Dio _dio = Dio(BaseOptions(baseUrl: baseUrl));
  final _storage = const FlutterSecureStorage();

  ApiService() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'auth_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        options.headers['Accept'] = 'application/json';
        return handler.next(options);
      },
    ));
  }

  // Login Method
  Future<Response> login(String email, String password) async {
    return await _dio.post('/login', data: {'email': email, 'password': password});
  }

  // Mechanic: Accept Job
  Future<Response> acceptJob(int jobId) async {
    return await _dio.post('/sos/$jobId/accept');
  }

  // Mechanic: Complete Job
  Future<Response> completeJob(int jobId) async {
    return await _dio.post('/sos/$jobId/complete');
  }

  // Mechanic: Get Status
  Future<Response> getJobStatus(int jobId) async {
    return await _dio.get('/sos/$jobId/status');
  }

  static Future<Map<String, dynamic>> sendSOS(int userId, double lat, double long, String notes) async {
    try {
      print("🚀 Sending SOS to: $baseUrl/sos"); // Debug print
      
      final response = await http.post(
        Uri.parse('$baseUrl/sos'),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "user_id": userId,
          "latitude": lat,
          "longitude": long,
          "notes": notes,
        }),
      );

      print("Response Code: ${response.statusCode}"); // Debug print
      print("Response Body: ${response.body}"); // Debug print

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Server Error: ${response.body}');
      }
    } catch (e) {
      throw Exception('Connection Error: $e');
    }
  }
}