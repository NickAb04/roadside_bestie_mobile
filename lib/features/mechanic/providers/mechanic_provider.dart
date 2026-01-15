import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../../core/services/api_service.dart';

class MechanicProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<dynamic> _pendingJobs = [];
  List<dynamic> _activeJobs = [];
  bool _isLoading = false;

  List<dynamic> get pendingJobs => _pendingJobs;
  List<dynamic> get activeJobs => _activeJobs;
  bool get isLoading => _isLoading;

  Future<void> fetchPendingJobs() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.dio.get('/sos/pending');
      // Assuming response structure: { data: [...] }
      _pendingJobs = response.data['data'] ?? [];
      
      // Also fetch active jobs
      await fetchActiveJobs();
    } catch (e) {
      if (kDebugMode) print('Error fetching jobs: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchActiveJobs() async {
    try {
      final response = await _apiService.dio.get('/mechanic/jobs');
      _activeJobs = response.data['data'] ?? [];
    } catch (e) {
      if (kDebugMode) print('Error fetching active jobs: $e');
    }
  }

  Future<bool> acceptJob(int jobId) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _apiService.dio.post('/sos/$jobId/accept');
      // Refresh list after accepting
      await fetchPendingJobs();
      return true;
    } catch (e) {
      if (kDebugMode) print('Error accepting job: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateLocation(double lat, double long) async {
    try {
      await _apiService.dio.post('/mechanic/location', data: {
        'latitude': lat,
        'longitude': long,
      });
    } catch (e) {
      if (kDebugMode) print('Error updating location: $e');
    }
  }

  Future<bool> completeJob(int jobId) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _apiService.dio.post('/sos/$jobId/complete');
      await fetchPendingJobs(); // Refresh lists
      await fetchActiveJobs();
      return true;
    } catch (e) {
      if (kDebugMode) print('Error completing job: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleStatus(bool isOnline) async {
    _isLoading = true;
    notifyListeners();

    try {
      final status = isOnline ? 'online' : 'offline';
      await _apiService.dio.post('/mechanic/status', data: {
        'status': status,
      });
      // Optionally fetch jobs if going online
      if (isOnline) await fetchPendingJobs();
    } catch (e) {
      if (kDebugMode) print('Error updating status: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
