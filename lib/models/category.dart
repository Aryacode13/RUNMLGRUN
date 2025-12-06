class Category {
  final String id;
  final String projectId;
  final String name;
  final double price;
  final int order;
  final DateTime createdAt;

  Category({
    required this.id,
    required this.projectId,
    required this.name,
    this.price = 0,
    this.order = 0,
    required this.createdAt,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      projectId: json['project_id'] as String,
      name: json['name'] as String,
      price: json['price'] != null
          ? (json['price'] as num).toDouble()
          : 0,
      order: json['order'] is int 
          ? json['order'] as int
          : json['order'] is String 
              ? int.tryParse(json['order'] as String) ?? 0
              : (json['order'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'name': name,
      'price': price,
      'order': order,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Category copyWith({
    String? id,
    String? projectId,
    String? name,
    double? price,
    int? order,
    DateTime? createdAt,
  }) {
    return Category(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      name: name ?? this.name,
      price: price ?? this.price,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isFree => price == 0;

  String get formattedPrice {
    if (isFree) return 'Gratis';
    return 'Rp ${price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}';
  }
}

enum CategoryFieldAction {
  add,
  remove,
  hide,
  show;

  static CategoryFieldAction fromString(String value) {
    return CategoryFieldAction.values.firstWhere(
      (e) => e.name == value,
      orElse: () => CategoryFieldAction.add,
    );
  }
}

class CategoryField {
  final String id;
  final String categoryId;
  final String fieldId;
  final CategoryFieldAction action;
  final DateTime createdAt;

  CategoryField({
    required this.id,
    required this.categoryId,
    required this.fieldId,
    required this.action,
    required this.createdAt,
  });

  factory CategoryField.fromJson(Map<String, dynamic> json) {
    return CategoryField(
      id: json['id'] as String,
      categoryId: json['category_id'] as String,
      fieldId: json['field_id'] as String,
      action: CategoryFieldAction.fromString(json['action'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category_id': categoryId,
      'field_id': fieldId,
      'action': action.name,
      'created_at': createdAt.toIso8601String(),
    };
  }

  CategoryField copyWith({
    String? id,
    String? categoryId,
    String? fieldId,
    CategoryFieldAction? action,
    DateTime? createdAt,
  }) {
    return CategoryField(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      fieldId: fieldId ?? this.fieldId,
      action: action ?? this.action,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}



