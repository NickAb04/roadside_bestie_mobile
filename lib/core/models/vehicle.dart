class Vehicle {
  final int id;
  final String make;
  final String model;
  final String year;
  final String plateNumber;

  Vehicle({
    required this.id,
    required this.make,
    required this.model,
    required this.year,
    required this.plateNumber,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'],
      make: json['brand'] ?? 'Unknown', // Map DB 'brand' to App 'make'
      model: json['model'],
      year: json['year'].toString(),
      plateNumber: json['plate_number'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'make': make,
      'model': model,
      'year': year,
      'plate_number': plateNumber,
    };
  }
}
