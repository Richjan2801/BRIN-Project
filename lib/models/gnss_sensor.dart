// lib/models/gnss_sensor.dart

class GnssSensor {
  final String gnssId;
  final String sensorId;
  final String timestamp;
  final dynamic value;

  GnssSensor({
    required this.gnssId,
    required this.sensorId,
    required this.timestamp,
    required this.value,
  });

  factory GnssSensor.fromJson(Map<String, dynamic> json) {
    return GnssSensor(
      gnssId: json['gnss_id'],
      sensorId: json['sensor_id'].toString(),
      timestamp: json['timestamp'],
      value: json['value'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gnss_id': gnssId,
      'sensor_id': sensorId,
      'timestamp': timestamp,
      'value': value,
    };
  }
}