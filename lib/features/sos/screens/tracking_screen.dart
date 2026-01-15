import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../mechanic/providers/mechanic_provider.dart';
import '../../sos/providers/emergency_provider.dart';

class TrackingScreen extends StatefulWidget {
  final int requestId;
  final bool isMechanic;
  
  const TrackingScreen({super.key, required this.requestId, this.isMechanic = false});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  Timer? _timer;
  StreamSubscription<Position>? _positionStream;
  String _status = 'Pending';
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  LatLng? _customerLoc;
  LatLng? _mechanicLoc;
  // Local mechanic location buffer to smooth movement if needed
  LatLng? _myCurrentLoc; 

  @override
  void initState() {
    super.initState();
    _fetchStatus();
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _fetchStatus();
    });

    if (widget.isMechanic) {
      _startLocationUpdates();
    }
  }

  void _startLocationUpdates() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
    
    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position? position) {
        if (position != null) {
          _myCurrentLoc = LatLng(position.latitude, position.longitude);
           
           // Update Server
           context.read<MechanicProvider>().updateLocation(position.latitude, position.longitude);
           
           // Optimistically update local UI for smoother experience
           if (mounted) {
             setState(() {
               _mechanicLoc = _myCurrentLoc;
               _updateMarkers();
             });
           }
        }
      },
      onError: (e) => print("Location Stream Error: $e"),
    );
  }

  Future<void> _fetchStatus() async {
    final data = await context.read<EmergencyProvider>().fetchStatus(widget.requestId);
    if (mounted && data != null) {
      setState(() {
        _status = data['status'];
        
        // Parse Customer Location
        if (data['data'] != null) {
           final lat = double.tryParse(data['data']['location_lat'].toString());
           final lng = double.tryParse(data['data']['location_long'].toString());
           if (lat != null && lng != null) {
             _customerLoc = LatLng(lat, lng);
           }
        }

        // Parse Mechanic Location (Only if we are NOT the mechanic, otherwise rely on stream/local)
        // Or strictly: if we are mechanic, we trust our GPS. If we are customer, we trust server.
        if (!widget.isMechanic && data['mechanic_location'] != null) {
           final lat = double.tryParse(data['mechanic_location']['latitude'].toString());
           final lng = double.tryParse(data['mechanic_location']['longitude'].toString());
           if (lat != null && lng != null) {
             _mechanicLoc = LatLng(lat, lng);
           }
        } else if (widget.isMechanic && _myCurrentLoc != null) {
           // Ensure we keep our local fresh location
           _mechanicLoc = _myCurrentLoc;
        }
        
        _updateMarkers();
      });
    }
  }

  void _updateMarkers() {
    _markers.clear();
    if (_customerLoc != null) {
      _markers.add(Marker(
        markerId: const MarkerId('customer'),
        position: _customerLoc!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'Customer Location'),
      ));
    }
    if (_mechanicLoc != null) {
      _markers.add(Marker(
        markerId: const MarkerId('mechanic'),
        position: _mechanicLoc!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: 'Mechanic'),
      ));
    }
    
    // Auto-zoom logic... (keep existing)
     if (_mapController != null && _customerLoc != null && _mechanicLoc != null) {
       LatLngBounds bounds;
       double minLat = _customerLoc!.latitude < _mechanicLoc!.latitude ? _customerLoc!.latitude : _mechanicLoc!.latitude;
       double maxLat = _customerLoc!.latitude > _mechanicLoc!.latitude ? _customerLoc!.latitude : _mechanicLoc!.latitude;
       double minLng = _customerLoc!.longitude < _mechanicLoc!.longitude ? _customerLoc!.longitude : _mechanicLoc!.longitude;
       double maxLng = _customerLoc!.longitude > _mechanicLoc!.longitude ? _customerLoc!.longitude : _mechanicLoc!.longitude;

       bounds = LatLngBounds(
         southwest: LatLng(minLat, minLng),
         northeast: LatLng(maxLat, maxLng),
       );
       
       try {
         _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
       } catch (e) {
         // Silently fail if bounds are invalid or map not ready
       }
    } else if (_mapController != null && _customerLoc != null) {
       _mapController!.animateCamera(CameraUpdate.newLatLngZoom(_customerLoc!, 15));
    } else if (_mapController != null && _mechanicLoc != null) {
       _mapController!.animateCamera(CameraUpdate.newLatLngZoom(_mechanicLoc!, 15));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionStream?.cancel();
    super.dispose();
  }

  Color _getStatusColor() {
    switch (_status.toLowerCase()) {
      case 'pending': return Colors.orange;
      case 'accepted': return Colors.blue;
      case 'en_route': return Colors.purple;
      case 'arrived': return Colors.green;
      case 'completed': return Colors.grey;
      default: return Colors.black;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Request #${widget.requestId} - $_status'),
        backgroundColor: _getStatusColor(),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          _customerLoc == null 
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
                  initialCameraPosition: CameraPosition(target: _customerLoc!, zoom: 14),
                  markers: _markers,
                  myLocationEnabled: widget.isMechanic, // Show blue dot for mechanic
                  myLocationButtonEnabled: widget.isMechanic,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    _updateMarkers();
                  },
                ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Card(
              color: Colors.white.withOpacity(0.9),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Status: ${_status.toUpperCase()}',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _getStatusColor()),
                    ),
                    const SizedBox(height: 5),
                    if (_mechanicLoc == null && _status == 'pending')
                       const Text('Waiting for mechanic...', style: TextStyle(fontStyle: FontStyle.italic))
                    else if (_mechanicLoc != null && _status != 'completed')
                       const Text('Mechanic is on the way!', style: TextStyle(fontWeight: FontWeight.bold)),
                    
                    const SizedBox(height: 10),
                    
                    // Mechanic Actions
                    if (widget.isMechanic && _status != 'completed')
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                          icon: const Icon(Icons.check_circle),
                          label: const Text("COMPLETE JOB"),
                          onPressed: () async {
                             final success = await context.read<MechanicProvider>().completeJob(widget.requestId);
                             if (success && mounted) {
                               Navigator.pop(context); // Go back to dashboard on complete
                             }
                          },
                        ),
                      ),
                      
                    // Customer / Completion View
                    if (_status == 'completed')
                      Column(
                        children: [
                          const Text("JOB COMPLETED", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 18)),
                          const SizedBox(height: 5),
                          const Text("Thank you for using Roadside Bestie!", textAlign: TextAlign.center),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).popUntil((route) => route.isFirst);
                              },
                              child: const Text("BACK TO HOME"),
                            ),
                          )
                        ],
                      )
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
