class StravaUser {
  final String id;
  final String userId; // Link to users table
  final int stravaId;
  final String? accessToken;
  final String? refreshToken;
  final int? tokenExpires;
  final DateTime createdAt;
  final DateTime updatedAt;

  StravaUser({
    required this.id,
    required this.userId,
    required this.stravaId,
    this.accessToken,
    this.refreshToken,
    this.tokenExpires,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StravaUser.fromJson(Map<String, dynamic> json) {
    return StravaUser(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      stravaId: json['strava_id'] as int,
      accessToken: json['access_token'] as String?,
      refreshToken: json['refresh_token'] as String?,
      tokenExpires: json['token_expires'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'strava_id': stravaId,
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'token_expires': tokenExpires,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}














