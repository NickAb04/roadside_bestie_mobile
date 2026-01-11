import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // 10.0.2.2 is the special IP for Android Emulator to talk to Laragon
  static const String baseUrl = "http://192.168.0.16:8000/api"; 

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