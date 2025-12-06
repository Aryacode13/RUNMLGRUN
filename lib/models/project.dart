class Project {
  final String id;
  final String name;
  final String tableName;
  final String? eventCode; // Code untuk menghubungkan dengan event
  final String status; // 'draft' or 'published'
  final double? registrationFee; // Harga pendaftaran (null atau 0 = gratis)
  final String? redeemCode; // Kode redeem/promo (bisa multiple codes dipisahkan koma)
  final double? redeemDiscountPercentage; // Persentase diskon jika menggunakan kode redeem (0-100)
  final bool useCategories; // Jika true, menggunakan categories untuk pricing dan field management
  final DateTime createdAt;
  final DateTime updatedAt;

  Project({
    required this.id,
    required this.name,
    required this.tableName,
    this.eventCode,
    this.status = 'draft',
    this.registrationFee,
    this.redeemCode,
    this.redeemDiscountPercentage,
    this.useCategories = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String,
      name: json['name'] as String,
      tableName: json['table_name'] as String,
      eventCode: json['event_code']?.toString(),
      status: json['status'] as String? ?? 'draft',
      registrationFee: json['registration_fee'] != null
          ? (json['registration_fee'] as num).toDouble()
          : null,
      redeemCode: json['redeem_code']?.toString(),
      redeemDiscountPercentage: json['redeem_discount_percentage'] != null
          ? (json['redeem_discount_percentage'] as num).toDouble()
          : null,
      useCategories: json['use_categories'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'table_name': tableName,
      'event_code': eventCode,
      'status': status,
      'registration_fee': registrationFee,
      'redeem_code': redeemCode,
      'redeem_discount_percentage': redeemDiscountPercentage,
      'use_categories': useCategories,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Project copyWith({
    String? id,
    String? name,
    String? tableName,
    String? eventCode,
    String? status,
    double? registrationFee,
    String? redeemCode,
    double? redeemDiscountPercentage,
    bool? useCategories,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      tableName: tableName ?? this.tableName,
      eventCode: eventCode ?? this.eventCode,
      status: status ?? this.status,
      registrationFee: registrationFee ?? this.registrationFee,
      redeemCode: redeemCode ?? this.redeemCode,
      redeemDiscountPercentage: redeemDiscountPercentage ?? this.redeemDiscountPercentage,
      useCategories: useCategories ?? this.useCategories,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
  
  bool get isFree => registrationFee == null || registrationFee == 0;
  
  String get formattedPrice {
    if (isFree) return 'Gratis';
    return 'Rp ${registrationFee!.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}';
  }
  
  /// Get list of redeem codes (split by comma)
  List<String> get redeemCodes {
    if (redeemCode == null || redeemCode!.isEmpty) return [];
    return redeemCode!.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }
  
  /// Check if a code is valid
  bool isValidRedeemCode(String code) {
    if (redeemCode == null || redeemCode!.isEmpty) return false;
    final codes = redeemCodes;
    return codes.contains(code.trim());
  }
  
  /// Calculate price after discount
  double? getPriceAfterDiscount({bool useRedeem = false}) {
    if (isFree) return 0;
    if (registrationFee == null) return null;
    
    if (useRedeem && redeemDiscountPercentage != null && redeemDiscountPercentage! > 0) {
      final discount = registrationFee! * (redeemDiscountPercentage! / 100);
      return registrationFee! - discount;
    }
    
    return registrationFee;
  }
  
  /// Get formatted price after discount
  String getFormattedPriceAfterDiscount({bool useRedeem = false}) {
    final price = getPriceAfterDiscount(useRedeem: useRedeem);
    if (price == null || price == 0) return 'Gratis';
    return 'Rp ${price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}';
  }
  
  /// Get discount amount
  double? getDiscountAmount() {
    if (isFree || registrationFee == null) return null;
    if (redeemDiscountPercentage == null || redeemDiscountPercentage! <= 0) return null;
    return registrationFee! * (redeemDiscountPercentage! / 100);
  }
  
  /// Get formatted discount amount
  String? getFormattedDiscountAmount() {
    final discount = getDiscountAmount();
    if (discount == null) return null;
    return 'Rp ${discount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}';
  }
}



