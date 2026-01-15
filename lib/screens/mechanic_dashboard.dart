import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/mechanic/providers/mechanic_provider.dart';
import '../features/sos/screens/tracking_screen.dart'; // Re-use tracking screen or make a mechanic version
import 'package:geolocator/geolocator.dart';

class MechanicDashboard extends StatefulWidget {
  const MechanicDashboard({super.key});

  @override
  _MechanicDashboardState createState() => _MechanicDashboardState();
}

class _MechanicDashboardState extends State<MechanicDashboard> with WidgetsBindingObserver {
  bool isOnline = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MechanicProvider>().fetchPendingJobs();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) {
        context.read<MechanicProvider>().fetchPendingJobs();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mechanic Dashboard"),
        backgroundColor: isOnline ? Colors.green : Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: Colors.blueGrey),
              accountName: Text("Mechanic Profile"), // Ideally fetch name
              accountEmail: Text("mechanic@roadside.com"), // Ideally fetch email
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 40, color: Colors.blueGrey),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Job History'),
              onTap: () {
                // TODO: Navigate to history
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () async {
                await context.read<AuthProvider>().logout();
                if (mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                }
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Status Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isOnline ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
              border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOnline ? "YOU ARE ONLINE" : "YOU ARE OFFLINE",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isOnline ? Colors.green : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isOnline ? "Waiting for requests..." : "Go online to start receiving jobs.",
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
                Transform.scale(
                  scale: 1.2,
                  child: Switch(
                    value: isOnline,
                    activeColor: Colors.green,
                    onChanged: (val) async {
                      if (val) {
                        final hasPermission = await _handleLocationPermission();
                        if (!hasPermission) {
                          setState(() => isOnline = false);
                          return;
                        }
                      }

                      if (val) {
                         final hasPermission = await _handleLocationPermission();
                         if (!hasPermission) {
                           setState(() => isOnline = false);
                           return;
                         }
                      }
                      
                      setState(() => isOnline = val);
                      await context.read<MechanicProvider>().toggleStatus(val);
                      if (val) {
                         // Get Real Location
                         try {
                           Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
                           if (context.mounted) {
                             context.read<MechanicProvider>().updateLocation(position.latitude, position.longitude);
                           }
                         } catch (e) {
                           print("Error getting location: $e");
                           // Fallback or show error
                         }
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          // Dashboard Stats (Placeholder)
          if (isOnline)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
            child: Row(
              children: [
                Expanded(child: _buildStatCard("Today's Earnings", "\$0.00", Icons.attach_money, Colors.green)),
                const SizedBox(width: 10),
                Expanded(child: _buildStatCard("Jobs Done", "0", Icons.check_circle, Colors.blue)),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text("Incoming Requests", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),

          Expanded(
            child: Consumer<MechanicProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                return Column(
                  children: [
                    // Debug Info
                    if (isOnline)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                            "Debug: Active Jobs: ${provider.activeJobs.length}, Pending: ${provider.pendingJobs.length}",
                            style: const TextStyle(color: Colors.grey, fontSize: 10)),
                      ),

                    // Active Job Card
                    if (provider.activeJobs.isNotEmpty) ...[
                      Builder(builder: (context) {
                        final activeJob = provider.activeJobs.first;
                        if (activeJob['status'] == 'completed') return const SizedBox.shrink();
                        return Column(
                          children: [
                            Container(
                              margin: const EdgeInsets.all(16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                border: Border.all(color: Colors.blue),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.directions_car, color: Colors.blue),
                                      SizedBox(width: 8),
                                      Text("CURRENT ACTIVE JOB",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold, color: Colors.blue)),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                      "Status: ${activeJob['status'].toString().toUpperCase()}",
                                      style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 5),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white),
                                    onPressed: () {
                                      Navigator.of(context).push(MaterialPageRoute(
                                        builder: (_) =>
                                            TrackingScreen(requestId: activeJob['id'], isMechanic: true),
                                      ));
                                    },
                                    child: const Text("OPEN MAP & TRACK"),
                                  )
                                ],
                              ),
                            ),
                            const Divider(),
                            const Text("Other Pending Requests",
                                style: TextStyle(color: Colors.grey)),
                          ],
                        );
                      }),
                    ],

                    // Pending Jobs List
                    Expanded(
                      child: provider.pendingJobs.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.notifications_none,
                                      size: 60, color: Colors.grey[400]),
                                  const SizedBox(height: 10),
                                  const Text("No pending jobs nearby."),
                                  const SizedBox(height: 5),
                                  ElevatedButton.icon(
                                    onPressed: () => provider.fetchPendingJobs(),
                                    icon: const Icon(Icons.refresh),
                                    label: const Text("Refresh"),
                                  )
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: () => provider.fetchPendingJobs(),
                              child: ListView.builder(
                                itemCount: provider.pendingJobs.length,
                                itemBuilder: (context, index) {
                                  final job = provider.pendingJobs[index];
                                  final vehicle = job['vehicle'] ?? {};
                                  return Card(
                                    elevation: 3,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                    child: Column(
                                      children: [
                                        ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor: Colors.red[50],
                                            child: const Icon(Icons.warning,
                                                color: Colors.red),
                                          ),
                                          title: Text(
                                              "${job['issue_type'] ?? 'Emergency'}",
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                          subtitle: Text(
                                              "Vehicle: ${vehicle['brand']} ${vehicle['model']}\nPlate: ${vehicle['plate_number']}"),
                                          isThreeLine: true,
                                        ),
                                        const Divider(height: 1),
                                        Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  "\"${job['description'] ?? 'No details provided.'}\"",
                                                  style: TextStyle(
                                                      fontStyle: FontStyle.italic,
                                                      color: Colors.grey[700]),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.blueAccent,
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(8)),
                                                ),
                                                onPressed: () async {
                                                  final success =
                                                      await provider.acceptJob(job['id']);
                                                  if (success && context.mounted) {
                                                    ScaffoldMessenger.of(context)
                                                        .showSnackBar(const SnackBar(
                                                            content: Text(
                                                                'Job Accepted! Go to Tracking.')));
                                                    // Explicitly fetch jobs to update UI
                                                    await provider.fetchPendingJobs();
                                                    
                                                     Navigator.of(context).push(MaterialPageRoute(
                                                       builder: (_) => TrackingScreen(requestId: job['id'], isMechanic: true),
                                                     ));
                                                  }
                                                },
                                                child: const Text("ACCEPT"),
                                              ),
                                            ],
                                          ),
                                        )
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 5)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location services are disabled. Please enable them.')));
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are denied')));
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are permanently denied, we cannot request permissions.')));
      return false;
    }

    return true;
  }
}
