import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/emergency_provider.dart';
import 'tracking_screen.dart';

// Arguments class to pass vehicleId. Or we can just pass the Vehicle object.
// For now, let's assume valid ID is passed.
class SOSRequestScreenArgs {
  final int vehicleId;
  SOSRequestScreenArgs({required this.vehicleId});
}

class SOSRequestScreen extends StatefulWidget {
  final int vehicleId; 
  // In real app, might pass this via route args, 
  // but constructor is fine if we use named routes with arguments logic or MaterialPageRoute.
  // We'll rely on onGenerateRoute or just passing it if instantiated directly.
  
  const SOSRequestScreen({super.key, required this.vehicleId});

  @override
  State<SOSRequestScreen> createState() => _SOSRequestScreenState();
}

class _SOSRequestScreenState extends State<SOSRequestScreen> {
  final _descriptionController = TextEditingController();
  String _selectedIssue = 'Flat Tire';
  final List<String> _issueTypes = ['Flat Tire', 'Engine Failure', 'Battery Dead', 'Fuel Empty', 'Accident', 'Other'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EmergencyProvider>().getCurrentLocation();
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitSOS() async {
    final requestId = await context.read<EmergencyProvider>().sendSOS(
      vehicleId: widget.vehicleId,
      issueType: _selectedIssue,
      description: _descriptionController.text,
    );

    if (mounted) {
      if (requestId != null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SOS Sent! Help is on the way.')));
        Navigator.pop(context); // Close SOS Request
        // In a real app, we would push Replacement directly to Tracking, 
        // but here we might want to go Home and then show active request, OR go straight to tracking.
        // Let's go to Tracking.
         Navigator.of(context).push(MaterialPageRoute(
           builder: (_) => TrackingScreen(requestId: requestId), 
         ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send SOS. Check location/network.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmergencyProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Request'),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (provider.currentPosition == null)
              const Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: Row(
                  children: [
                    CircularProgressIndicator(strokeWidth: 2),
                    SizedBox(width: 10),
                    Text('Fetching precise location...'),
                  ],
                ),
              )
            else
               Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.green),
                     const SizedBox(width: 10),
                    Text('Location Secured: ${provider.currentPosition!.latitude.toStringAsFixed(4)}, ${provider.currentPosition!.longitude.toStringAsFixed(4)}'),
                  ],
                ),
              ),

            DropdownButtonFormField<String>(
              value: _selectedIssue,
              decoration: const InputDecoration(labelText: 'Issue Type'),
              items: _issueTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
              onChanged: (val) => setState(() => _selectedIssue = val!),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Additional Details (Optional)',
                hintText: 'e.g. Near the big oak tree...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: (provider.isLoading || provider.currentPosition == null) ? null : _submitSOS,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.sos),
                label: provider.isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('SEND REQUEST NOW', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
