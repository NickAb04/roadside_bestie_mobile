import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/services/api_service.dart';

class BookingProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  Future<bool> createBooking({
    required int vehicleId,
    required DateTime date,
    required TimeOfDay time,
    required String notes,
  }) async {
    _isLoading = true;
    notifyListeners();

    // Format Date and Time for Laravel (YYYY-MM-DD HH:mm:ss usually)
    final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final timeStr = "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";

    try {
      await _apiService.dio.post('/bookings', data: {
        'vehicle_id': vehicleId,
        'service_type': 'General Service', // Default for now
        'booking_date': dateStr,
        'booking_time': timeStr,
        'notes': notes,
      });
      return true;
    } on DioException catch (e) {
      if (kDebugMode) print('Booking Error: ${e.response?.data}');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
