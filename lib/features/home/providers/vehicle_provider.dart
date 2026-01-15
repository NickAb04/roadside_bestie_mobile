import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../core/services/api_service.dart';
import '../../../core/models/vehicle.dart';

class VehicleProvider with ChangeNotifier {
  List<Vehicle> _vehicles = [];
  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  List<Vehicle> get vehicles => _vehicles;
  bool get isLoading => _isLoading;

  Future<void> fetchVehicles() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.dio.get('/vehicles');
       // Assuming response.data is List or { 'data': [...] }
      final List<dynamic> data = response.data['data'] ?? response.data;
      
      _vehicles = data.map((json) => Vehicle.fromJson(json)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching vehicles: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addVehicle(String make, String model, String year, String plate) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final response = await _apiService.dio.post('/vehicles', data: {
        'make': make,
        'model': model,
        'year': year,
        'plate_number': plate,
      });
      
      if (response.statusCode == 201) {
        // Refresh list
        await fetchVehicles(); 
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) print('Add Vehicle Error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
