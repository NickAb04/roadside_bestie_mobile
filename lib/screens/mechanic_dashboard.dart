import 'package:flutter/material.dart';
import '../services/api_services.dart';

class MechanicDashboard extends StatefulWidget {
  @override
  _MechanicDashboardState createState() => _MechanicDashboardState();
}

class _MechanicDashboardState extends State<MechanicDashboard> {
  final ApiService _api = ApiService();
  bool isOnline = false; // "Mechanic on Duty" state [cite: 201]
  
  // Fake list for now (replace with API call later)
  List<Map<String, dynamic>> incomingJobs = [
    {"id": 101, "issue": "Flat Tire", "dist": "2.5km"},
    {"id": 102, "issue": "Engine Smoke", "dist": "5.0km"}
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Mechanic Dashboard")),
      body: Column(
        children: [
          // 1. ONLINE/OFFLINE TOGGLE [cite: 304]
          Container(
            color: isOnline ? Colors.green[100] : Colors.grey[200],
            padding: EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isOnline ? "STATUS: ONLINE" : "STATUS: OFFLINE",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Switch(
                  value: isOnline,
                  onChanged: (val) {
                    setState(() => isOnline = val);
                    // TODO: Call API to update availability
                  },
                ),
              ],
            ),
          ),

          // 2. JOB FEED
          Expanded(
            child: isOnline 
              ? ListView.builder(
                  itemCount: incomingJobs.length,
                  itemBuilder: (context, index) {
                    final job = incomingJobs[index];
                    return Card(
                      margin: EdgeInsets.all(10),
                      child: ListTile(
                        leading: Icon(Icons.car_repair, color: Colors.red),
                        title: Text("SOS: ${job['issue']}"),
                        subtitle: Text("Distance: ${job['dist']}"),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                          onPressed: () {
                            _acceptJob(job['id']);
                          },
                          child: Text("VIEW"),
                        ),
                      ),
                    );
                  },
                )
              : Center(child: Text("Go Online to receive jobs")),
          ),
        ],
      ),
    );
  }

  // 3. LOGIC TO ACCEPT JOB [cite: 484]
  void _acceptJob(int jobId) async {
    try {
      // Call your API Service
      await _api.acceptJob(jobId); 
      
      // If success, navigate to the Tracking Map (Shared Task)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Job Accepted!")));
      // Navigator.push(context, MaterialPageRoute(builder: (_) => TrackingMap(jobId: jobId)));
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to accept job")));
    }
  }
}