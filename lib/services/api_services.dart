import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  // REPLACE WITH YOUR LARAVEL IP ADDRESS (Keep the port 8000)
  static const String baseUrl = 'http://192.168.0.17:8000/api'; 
  
  final Dio _dio = Dio(BaseOptions(baseUrl: baseUrl));
  final _storage = FlutterSecureStorage();

  ApiService() {
    // This adds the token to every request automatically
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'auth_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token'; // 
        }
        options.headers['Accept'] = 'application/json'; // [cite: 408]
        return handler.next(options);
      },
    ));
  }

  // Example method for Daniel to use
  Future<Response> login(String email, String password) async {
    return await _dio.post('/login', data: {
      'email': email, 
      'password': password
    });
  }
}