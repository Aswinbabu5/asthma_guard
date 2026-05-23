// lib/models/user_model.dart
class User {
  final int id;
  final String name;
  final String username;

  User({required this.id, required this.name, required this.username});

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] ?? 0,
    name: json['name'] ?? '',
    username: json['username'] ?? '',
  );
}

// lib/models/reading_model.dart
class Reading {
  final int? id;
  final double pm25;
  final double pm10;
  final double no2;
  final double so2;
  final double co;
  final double o3;
  final double temp;
  final double humidity;
  final double spo2;
  final double heartRate;
  final int aqi;
  final String risk;
  final String category;
  final String timestamp;

  Reading({
    this.id,
    required this.pm25,
    required this.pm10,
    required this.no2,
    required this.so2,
    required this.co,
    required this.o3,
    required this.temp,
    required this.humidity,
    required this.spo2,
    required this.heartRate,
    required this.aqi,
    required this.risk,
    required this.category,
    required this.timestamp,
  });

  factory Reading.fromJson(Map<String, dynamic> json) => Reading(
    id: json['id'],
    pm25: (json['pm25'] ?? 0).toDouble(),
    pm10: (json['pm10'] ?? 0).toDouble(),
    no2: (json['no2'] ?? 0).toDouble(),
    so2: (json['so2'] ?? 0).toDouble(),
    co: (json['co'] ?? 0).toDouble(),
    o3: (json['o3'] ?? 0).toDouble(),
    temp: (json['temp'] ?? 0).toDouble(),
    humidity: (json['humidity'] ?? 0).toDouble(),
    spo2: (json['spo2'] ?? 0).toDouble(),
    heartRate: (json['heart_rate'] ?? 0).toDouble(),
    aqi: (json['aqi'] ?? 0).toInt(),
    risk: json['risk'] ?? '',
    category: json['aqi_cat'] ?? json['category'] ?? '',
    timestamp: json['timestamp'] ?? json['recorded'] ?? '',
  );
}
