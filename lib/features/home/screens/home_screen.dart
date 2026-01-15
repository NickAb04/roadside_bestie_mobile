import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';
import '../../sos/providers/emergency_provider.dart';
import '../../sos/screens/sos_request_screen.dart';
import '../../sos/screens/tracking_screen.dart';
import '../../booking/screens/booking_form.dart';
import '../providers/vehicle_provider.dart';
import '../widgets/add_vehicle_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GoogleMapController? _mapController;
  LatLng _initialPosition = const LatLng(3.1390, 101.6869); // Default KL
  bool _loadingLocation = true;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    // Fetch vehicles in background for Drawer/SOS check
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VehicleProvider>().fetchVehicles();
    });
  }

  Future<void> _getUserLocation() async {
    // Rely on EmergencyProvider's location logic if possible, or do simple check here
    // For map readiness, we want immediate location
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _loadingLocation = false);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _loadingLocation = false);
        return;
      }
    }

    Position position = await Geolocator.getCurrentPosition();
    if (mounted) {
      setState(() {
        _initialPosition = LatLng(position.latitude, position.longitude);
        _loadingLocation = false;
      });
      _mapController?.animateCamera(CameraUpdate.newLatLng(_initialPosition));
    }
  }

  void _handleSOS() async {
    final vehicleProvider = context.read<VehicleProvider>();
    
    if (vehicleProvider.vehicles.isEmpty) {
      // Prompt to add vehicle first
      bool? added = await showDialog(
        context: context,
        builder: (_) => const AddVehicleDialog(),
      );
      
      if (added == true && vehicleProvider.vehicles.isNotEmpty) {
        // Retry SOS if added
        _proceedToSOS(vehicleProvider.vehicles.first.id); // Default to first
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("A vehicle is required for SOS.")),
        );
      }
      return;
    }

    // If multiple vehicles, pick one. For now, pick first or show picker.
    // Let's use the SOS Request Screen's logic, but we need to pass a vehicle ID.
    // Simple approach: Picker if > 1, else first.
    if (vehicleProvider.vehicles.length == 1) {
      _proceedToSOS(vehicleProvider.vehicles.first.id);
    } else {
      _showVehiclePicker(context);
    }
  }

  void _showVehiclePicker(BuildContext context) {
    final vehicles = context.read<VehicleProvider>().vehicles;
    showModalBottomSheet(
      context: context,
      builder: (_) => ListView.builder(
        shrinkWrap: true,
        itemCount: vehicles.length,
        itemBuilder: (context, index) => ListTile(
          title: Text('${vehicles[index].make} ${vehicles[index].model}'),
          subtitle: Text(vehicles[index].plateNumber),
          onTap: () {
            Navigator.pop(context);
            _proceedToSOS(vehicles[index].id);
          },
        ),
      ),
    );
  }

  void _proceedToSOS(int vehicleId) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SOSRequestScreen(vehicleId: vehicleId),
    ));
  }

  void _showMyGarage() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("My Garage", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => showDialog(context: context, builder: (_) => const AddVehicleDialog()),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Consumer<VehicleProvider>(
                  builder: (context, provider, _) {
                    if (provider.isLoading) return const Center(child: CircularProgressIndicator());
                    if (provider.vehicles.isEmpty) return const Center(child: Text("No vehicles. Add one!"));
                    
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: provider.vehicles.length,
                      itemBuilder: (ctx, i) {
                        final v = provider.vehicles[i];
                        return ListTile(
                          leading: const Icon(Icons.directions_car, color: Colors.blueAccent),
                          title: Text("${v.make} ${v.model}"),
                          subtitle: Text(v.plateNumber),
                          trailing: TextButton(
                            child: const Text("BOOK"),
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.push(context, MaterialPageRoute(builder: (_) => BookingFormScreen(vehicleId: v.id)));
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
             UserAccountsDrawerHeader(
              accountName: const Text("Roadside User"), // Could fetch from AuthProvider
              accountEmail: const Text("Full Access"),
              currentAccountPicture: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.person, color: Colors.orange)),
              decoration: const BoxDecoration(color: Colors.orange),
            ),
            ListTile(
              leading: const Icon(Icons.commute),
              title: const Text('My Garage'),
              onTap: () {
                Navigator.pop(context);
                _showMyGarage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Book Appointment'),
              onTap: () {
                Navigator.pop(context);
                _showMyGarage(); // Garage has Booking buttons
              },
            ),
             const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout'),
              onTap: () {
                context.read<AuthProvider>().logout();
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: const Text("Roadside Bestie"), 
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // 1. MAP LAYER
          _loadingLocation 
            ? const Center(child: CircularProgressIndicator())
            : GoogleMap(
                initialCameraPosition: CameraPosition(target: _initialPosition, zoom: 15),
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                onMapCreated: (ctrl) => _mapController = ctrl,
              ),

          // 2. SOS BUTTON (Centered Bottom)
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: SizedBox(
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _handleSOS,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 5,
                ),
                icon: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 30),
                label: const Text("REQUEST SOS", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ),

          // 3. RESUME SOS BUTTON (Above Request Button)
          Consumer<EmergencyProvider>(
            builder: (context, emergency, _) {
              if (emergency.activeRequestId != null) {
                return Positioned(
                  bottom: 110, 
                  right: 20,
                  child: FloatingActionButton.extended(
                    heroTag: 'track',
                    onPressed: () {
                       Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TrackingScreen(requestId: emergency.activeRequestId!),
                        ),
                      );
                    },
                    backgroundColor: Colors.blueAccent,
                    label: const Text("Track SOS"),
                    icon: const Icon(Icons.navigation),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}
