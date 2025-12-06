class Activity {
  final String id;
  final String userId;
  final int? stravaActivityId;
  final String? name;
  final double? distance;
  final int? movingTime;
  final int? elapsedTime;
  final String? type;
  final DateTime? startDate;
  final String? mapPolyline;
  final DateTime createdAt;

  Activity({
    required this.id,
    required this.userId,
    this.stravaActivityId,
    this.name,
    this.distance,
    this.movingTime,
    this.elapsedTime,
    this.type,
    this.startDate,
    this.mapPolyline,
    required this.createdAt,
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      stravaActivityId: json['strava_activity_id'] as int?,
      name: json['name'] as String?,
      distance: (json['distance'] as num?)?.toDouble(),
      movingTime: json['moving_time'] as int?,
      elapsedTime: json['elapsed_time'] as int?,
      type: json['type'] as String?,
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'] as String)
          : null,
      mapPolyline: json['map_polyline'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'strava_activity_id': stravaActivityId,
      'name': name,
      'distance': distance,
      'moving_time': movingTime,
      'elapsed_time': elapsedTime,
      'type': type,
      'start_date': startDate?.toIso8601String(),
      'map_polyline': mapPolyline,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Format distance seperti Strava (selalu dalam km dengan 2 desimal)
  String get formattedDistance {
    if (distance == null) return '0.00 km';
    final km = distance! / 1000.0;
    return '${km.toStringAsFixed(2)} km';
  }

  /// Format duration mirip Strava
  /// - < 60 detik  → `10s`
  /// - < 60 menit → `Xm`
  /// - >= 60 menit → `Xh Ym`
  String get formattedDuration {
    if (movingTime == null) return '0s';
    final totalSeconds = movingTime!;
    if (totalSeconds < 60) {
      return '${totalSeconds}s';
    }
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

