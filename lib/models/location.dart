class Location {

  final int? id;
  final double latitude;
  final double longitude;
  final DateTime? timestamp;

  final String? userName;
  final int? userId;

  Location({
    this.id,
    required this.latitude,
    required this.longitude,
    this.timestamp,
    this.userName,
    this.userId,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      id: json['idLocation'] as int?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),

      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : null,

      userName: json['name'] as String?,
      userId: json['userId'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
