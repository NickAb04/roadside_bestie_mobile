import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import '../../../core/services/api_service.dart';

class EmergencyProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  Position? _currentPosition;
  int? _activeRequestId;

  bool get isLoading => _isLoading;
  Position? get currentPosition => _currentPosition;
  int? get activeRequestId => _activeRequestId;

  Future<void> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (kDebugMode) print('Location services are disabled.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
         if (kDebugMode) print('Location permissions are denied');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
       if (kDebugMode) print('Location permissions are permanently denied, we cannot request permissions.');
      return;
    }

    try {
      _currentPosition = await Geolocator.getCurrentPosition();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error getting location: $e');
    }
  }

  Future<int?> sendSOS({
    required int vehicleId,
    required String issueType,
    required String description,
  }) async {
    if (_currentPosition == null) {
      await getCurrentLocation();
      if (_currentPosition == null) return null; // Location is mandatory
    }

    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.dio.post('/sos', data: {
        'vehicle_id': vehicleId,
        'issue_type': issueType,
        'description': description,
        'location_lat': _currentPosition!.latitude,
        'location_long': _currentPosition!.longitude,
      });
      // Assuming response.data['id'] or response.data['data']['id']
      final data = response.data['data'] ?? response.data;
      _activeRequestId = data['id'];
      return data['id'];
    } on DioException catch (e) {
      if (kDebugMode) print('SOS Error: ${e.response?.data}');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> fetchStatus(int requestId) async {
    try {
      final response = await _apiService.dio.get('/sos/$requestId/status');
      // Returns { status: '...', mechanic_location: {...}, data: {...} }
      return response.data; 
    } catch (e) {
      if (kDebugMode) print('Fetch Status Error: $e');
      return null;
    }
  }
}
