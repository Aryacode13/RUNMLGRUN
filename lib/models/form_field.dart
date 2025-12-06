enum FieldType {
  text,
  textarea,
  email,
  number,
  phone,
  date,
  radio,
  dropdown,
  checkbox,
  file,
  url;

  static FieldType fromString(String value) {
    return FieldType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => FieldType.text,
    );
  }

  String get displayName {
    switch (this) {
      case FieldType.text:
        return 'Text';
      case FieldType.textarea:
        return 'Textarea';
      case FieldType.email:
        return 'Email';
      case FieldType.number:
        return 'Number';
      case FieldType.phone:
        return 'Phone';
      case FieldType.date:
        return 'Date';
      case FieldType.radio:
        return 'Radio Buttons';
      case FieldType.dropdown:
        return 'Dropdown';
      case FieldType.checkbox:
        return 'Checkbox';
      case FieldType.file:
        return 'File Upload';
      case FieldType.url:
        return 'URL';
    }
  }

  String get icon {
    switch (this) {
      case FieldType.text:
        return '📝';
      case FieldType.textarea:
        return '📄';
      case FieldType.email:
        return '✉️';
      case FieldType.number:
        return '🔢';
      case FieldType.phone:
        return '📱';
      case FieldType.date:
        return '📅';
      case FieldType.radio:
        return '🔘';
      case FieldType.dropdown:
        return '📋';
      case FieldType.checkbox:
        return '☑️';
      case FieldType.file:
        return '📎';
      case FieldType.url:
        return '🔗';
    }
  }
}

class FormFieldModel {
  final String id;
  final String projectId;
  final FieldType fieldType;
  final String fieldLabel;
  final String columnName;
  final bool isRequired;
  final List<String> options; // For radio and dropdown
  final String? placeholder;
  final Map<String, dynamic> validationRules;
  final int order;
  final String? categoryId; // ID category untuk field ini (null = base field)
  final DateTime createdAt;

  FormFieldModel({
    required this.id,
    required this.projectId,
    required this.fieldType,
    required this.fieldLabel,
    required this.columnName,
    this.isRequired = false,
    this.options = const [],
    this.placeholder,
    this.validationRules = const {},
    this.order = 0,
    this.categoryId,
    required this.createdAt,
  });

  /// Get display name (use fieldLabel, fallback to column name converted to Title Case)
  String get displayName => fieldLabel.isNotEmpty ? fieldLabel : _columnNameToDisplayName(columnName);

  String _columnNameToDisplayName(String columnName) {
    if (columnName.isEmpty) return columnName;
    final parts = columnName.split('_');
    final displayParts = parts.map((part) {
      if (part.isEmpty) return '';
      return part[0].toUpperCase() + part.substring(1).toLowerCase();
    }).where((part) => part.isNotEmpty).toList();
    return displayParts.join(' ');
  }

  factory FormFieldModel.fromJson(Map<String, dynamic> json) {
    return FormFieldModel(
      id: json['id'] as String,
      projectId: json['project_id'] as String,
      fieldType: FieldType.fromString(json['field_type'] as String),
      fieldLabel: json['field_label'] as String? ?? json['column_name'] as String,
      columnName: json['column_name'] as String,
      isRequired: json['is_required'] as bool? ?? false,
      options: json['options'] != null
          ? List<String>.from(json['options'] as List)
          : [],
      placeholder: json['placeholder'] as String?,
      validationRules: json['validation_rules'] != null
          ? Map<String, dynamic>.from(json['validation_rules'] as Map)
          : {},
      order: json['order'] is int 
          ? json['order'] as int
          : json['order'] is String 
              ? int.tryParse(json['order'] as String) ?? 0
              : (json['order'] as num?)?.toInt() ?? 0,
      categoryId: json['category_id']?.toString(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'field_type': fieldType.name,
      'field_label': fieldLabel,
      'column_name': columnName,
      'is_required': isRequired,
      'options': options,
      'placeholder': placeholder,
      'validation_rules': validationRules,
      'order': order,
      'category_id': categoryId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  FormFieldModel copyWith({
    String? id,
    String? projectId,
    FieldType? fieldType,
    String? fieldLabel,
    String? columnName,
    bool? isRequired,
    List<String>? options,
    String? placeholder,
    Map<String, dynamic>? validationRules,
    int? order,
    String? categoryId,
    DateTime? createdAt,
  }) {
    return FormFieldModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      fieldType: fieldType ?? this.fieldType,
      fieldLabel: fieldLabel ?? this.fieldLabel,
      columnName: columnName ?? this.columnName,
      isRequired: isRequired ?? this.isRequired,
      options: options ?? this.options,
      placeholder: placeholder ?? this.placeholder,
      validationRules: validationRules ?? this.validationRules,
      order: order ?? this.order,
      categoryId: categoryId ?? this.categoryId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}


