class Event {
  final String id;
  final String title;
  final String? description;
  final int quota;
  final String? createdBy;
  final String? eventCode; // Code untuk menghubungkan dengan form pendaftaran
  final DateTime? startDate; // Tanggal mulai event
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? totalRegistered;
  final int? remainingQuota;
  final String? imageUrl; // URL gambar event

  Event({
    required this.id,
    required this.title,
    this.description,
    required this.quota,
    this.createdBy,
    this.eventCode,
    this.startDate,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.totalRegistered,
    this.remainingQuota,
    this.imageUrl,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      quota: (json['quota'] as num?)?.toInt() ?? 0,
      createdBy: json['created_by']?.toString(),
      eventCode: json['event_code']?.toString(),
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'].toString())
          : null,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'].toString())
          : (json['created_at'] != null
              ? DateTime.parse(json['created_at'].toString())
              : DateTime.now()),
      totalRegistered: (json['total_registered'] as num?)?.toInt(),
      remainingQuota: (json['remaining_quota'] as num?)?.toInt(),
      imageUrl: json['image_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'quota': quota,
      'created_by': createdBy,
      'event_code': eventCode,
      'start_date': startDate?.toIso8601String(),
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'image_url': imageUrl,
    };
  }

  bool get isFull {
    final remaining = remainingQuota ?? (quota - (totalRegistered ?? 0));
    return remaining <= 0;
  }

  bool get canRegister {
    return isActive && !isFull;
  }
}

class Registration {
  final String id;
  final String eventId;
  final String userId;
  final DateTime registeredAt;
  final String? username;
  final String? paymentReceiptUrl;

  Registration({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.registeredAt,
    this.username,
    this.paymentReceiptUrl,
  });

  factory Registration.fromJson(Map<String, dynamic> json) {
    return Registration(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      userId: json['user_id'] as String,
      registeredAt: DateTime.parse(json['registered_at'] as String),
      username: json['username']?.toString(),
      paymentReceiptUrl: json['payment_receipt_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'user_id': userId,
      'registered_at': registeredAt.toIso8601String(),
      'username': username,
      'payment_receipt_url': paymentReceiptUrl,
    };
  }
}

