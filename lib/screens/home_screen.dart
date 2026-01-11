import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// =========================================================
// 1. API SERVICE ( The Bridge )
// =========================================================
class ApiService {
  // Use 10.0.2.2 for Android Emulator connecting to Laragon
  static const String baseUrl = "http://192.168.0.16:8000/api"; 

  // --- EXISTING: Send SOS ---
  static Future<Map<String, dynamic>> sendSOS(int userId, double lat, double long, String notes) async {
    final response = await http.post(
      Uri.parse('$baseUrl/sos'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "user_id": userId,
        "latitude": lat,
        "longitude": long,
        "vehicle_type": "Car", 
        "notes": notes,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Server Error: ${response.body}');
    }
  }

  // --- NEW: Check Mechanic ETA ---
  static Future<Map<String, dynamic>> checkSosStatus(int sosId) async {
    // Ensure your Laravel route is: Route::get('/sos/{id}/status', ...);
    final response = await http.get(Uri.parse('$baseUrl/sos/$sosId/status'));

    if (response.statusCode == 200) {
      // "eta" and "arrival_time" MUST match the JSON keys from Alia/Ameerah
      return jsonDecode(response.body); 
    } else {
      throw Exception('Failed to load status');
    }
  }

  // --- NEW: Book Appointment ---
  static Future<void> bookAppointment(int userId, int workshopId, String date, String issue) async {
    final response = await http.post(
      Uri.parse('$baseUrl/appointment/book'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        // THESE NAMES MUST MATCH YOUR DATABASE COLUMNS EXACTLY
        "user_id": userId,
        "workshop_id": workshopId,       // You requested 'workshop_id'
        "appointment_date": date,        // You requested 'appointment_date'
        "car_issue": issue,              // You requested 'car_issue'
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to book: ${response.body}');
    }
  }

  // --- NEW: Get Vehicle Status ---
  static Future<Map<String, dynamic>> getVehicleStatus(int userId) async {
    final response = await http.get(Uri.parse('$baseUrl/user/$userId/vehicle-status'));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get vehicle status');
    }
  }
}

// =========================================================
// 2. USER INTERFACE ( The Screen )
// =========================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GoogleMapController? mapController;
  LatLng _currentPosition = const LatLng(3.1390, 101.6869); // Default KL
  bool _isLoading = true;
  
  // Variables to hold SOS data
  int? _currentSosId; 
  String _mechanicStatus = "Idle"; // Default status
  String _mechanicEta = "--";

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
      _isLoading = false;
    });

    mapController?.animateCamera(CameraUpdate.newLatLng(_currentPosition));
  }

  // --- FUNCTION: Send SOS ---
  void _sendSOS() async {
    setState(() => _isLoading = true);
    try {
      Map<String, dynamic> response = await ApiService.sendSOS(1, _currentPosition.latitude, _currentPosition.longitude, "Help! Car broke down.");
      
      setState(() {
        // If response uses 'id' use ['id']. If it uses 'sos_id', change this to ['sos_id']
        _currentSosId = response['id'] ?? response['sos_id']; 
        _mechanicStatus = "Looking for mechanic...";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("SOS Sent! ID: $_currentSosId"), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
    setState(() => _isLoading = false);
  }

  // --- FUNCTION: Check Status (Updates ETA) ---
  void _checkStatus() async {
    if (_currentSosId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("No active SOS request")));
      return;
    }

    try {
      var data = await ApiService.checkSosStatus(_currentSosId!);
      setState(() {
        // CHANGE HERE if database names change
        // We use the keys you requested: 'eta' and 'arrival_time'
        _mechanicEta = "${data['eta']} (Arriving at ${data['arrival_time']})"; 
        _mechanicStatus = "Mechanic Found";
      });
      
      _showNotificationDialog("Update: $_mechanicEta");

    } catch (e) {
      print("Error checking status: $e");
    }
  }

  // --- FUNCTION: Book Appointment Dialog ---
  void _showBookingDialog() {
    TextEditingController dateController = TextEditingController();
    TextEditingController issueController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Book Workshop Appointment"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: dateController, decoration: InputDecoration(labelText: "Date (YYYY-MM-DD)", hintText: "2023-12-25")),
            TextField(controller: issueController, decoration: InputDecoration(labelText: "Car Issue")),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              try {
                // Hardcoding Workshop ID = 101 for demo purposes
                await ApiService.bookAppointment(1, 101, dateController.text, issueController.text);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Appointment Booked Successfully!")));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Booking Failed"), backgroundColor: Colors.red));
                print(e);
              }
            },
            child: Text("Confirm Booking"),
          )
        ],
      ),
    );
  }

  // --- FUNCTION: Vehicle Status Dialog ---
  void _showVehicleStatus() async {
    try {
      var data = await ApiService.getVehicleStatus(1); // User ID 1
      
      // CHANGE HERE: Map the database status string to your UI
      // expected values: "in progress", "ready for pickup"
      String status = data['status']; 
      Color statusColor = status == "ready for pickup" ? Colors.green : Colors.orange;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("My Vehicle Status"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Current Status:", style: TextStyle(fontWeight: FontWeight.bold)),
              Container(
                padding: EdgeInsets.all(8),
                color: statusColor.withOpacity(0.2),
                child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
              ),
              SizedBox(height: 10),
              Text("Mechanic Notes: ${data['notes'] ?? 'No notes yet'}"),
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text("Close"))],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("No vehicle in workshop found.")));
    }
  }

  void _showNotificationDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Notification"),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text("OK"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // --- LEFT SIDE DRAWER MENU ---
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.orange),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.account_circle, size: 50, color: Colors.white),
                  SizedBox(height: 10),
                  Text("Welcome User", style: TextStyle(color: Colors.white, fontSize: 20)),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.calendar_month),
              title: Text("Book Appointment"),
              onTap: () {
                Navigator.pop(context);
                _showBookingDialog();
              },
            ),
            ListTile(
              leading: Icon(Icons.car_repair),
              title: Text("My Vehicle Status"),
              onTap: () {
                Navigator.pop(context);
                _showVehicleStatus();
              },
            ),
            ListTile(
              leading: Icon(Icons.timer),
              title: Text("Check Mechanic ETA"),
              onTap: () {
                Navigator.pop(context);
                _checkStatus();
              },
            ),
          ],
        ),
      ),
      
      appBar: AppBar(
        title: Text("Roadside Bestie"), 
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: Icon(Icons.notifications),
            onPressed: () => _showNotificationDialog("No new notifications"),
          )
        ],
      ),

      body: Stack(
        children: [
          // 1. THE MAP LAYER
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _currentPosition, zoom: 14),
            myLocationEnabled: true,
            onMapCreated: (controller) => mapController = controller,
          ),
          
          // 2. SOS INFO CARD (Visible only if SOS active)
          if (_currentSosId != null)
            Positioned(
              top: 10, left: 15, right: 15,
              child: Card(
                elevation: 5,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Status: $_mechanicStatus", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          if (_mechanicStatus == "Mechanic Found") Icon(Icons.check_circle, color: Colors.green)
                        ],
                      ),
                      Divider(),
                      Text("ETA: $_mechanicEta", style: TextStyle(fontSize: 18, color: Colors.blue[800])),
                    ],
                  ),
                ),
              ),
            ),

          // 3. SOS BUTTON LAYER
          Positioned(
            bottom: 30, left: 20, right: 20,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _sendSOS,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 10,
              ),
              child: _isLoading 
                ? CircularProgressIndicator(color: Colors.white)
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.white, size: 30),
                      SizedBox(width: 10),
                      Text("REQUEST SOS", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
            ),
          ),
        ],
      ),
    );
  }
}