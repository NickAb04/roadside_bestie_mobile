class EmergencyJob {
  final int id;
  final String description;
  final double latitude;
  final double longitude;
  final String status; // 'pending', 'accepted', 'completed'

  EmergencyJob({
    required this.id,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.status,
  });

  factory EmergencyJob.fromJson(Map<String, dynamic> json) {
    return EmergencyJob(
      id: json['id'],
      description: json['description'] ?? 'Emergency Request',
      latitude: double.parse(json['mechanic_location']['latitude'].toString()), // Example mapping
      longitude: double.parse(json['mechanic_location']['longitude'].toString()),
      status: json['status'],
    );
  }
}