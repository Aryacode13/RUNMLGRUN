class SlugGenerator {
  /// Generate URL-friendly slug from string
  static String generate(String input) {
    // Convert to lowercase
    String slug = input.toLowerCase();
    
    // Replace spaces and special characters with dashes
    slug = slug.replaceAll(RegExp(r'[^\w\s-]'), '');
    slug = slug.replaceAll(RegExp(r'[\s_-]+'), '-');
    
    // Remove leading/trailing dashes
    slug = slug.replaceAll(RegExp(r'^-+|-+$'), '');
    
    // Limit length
    if (slug.length > 50) {
      slug = slug.substring(0, 50);
      slug = slug.replaceAll(RegExp(r'-+$'), '');
    }
    
    return slug;
  }

  /// Generate column name from label
  static String generateColumnName(String label) {
    // Similar to slug but for database column names
    String columnName = label.toLowerCase();
    columnName = columnName.replaceAll(RegExp(r'[^\w\s]'), '');
    columnName = columnName.replaceAll(RegExp(r'\s+'), '_');
    columnName = columnName.replaceAll(RegExp(r'_+'), '_');
    columnName = columnName.replaceAll(RegExp(r'^_+|_+$'), '');
    
    // Ensure it doesn't start with a number
    if (RegExp(r'^\d').hasMatch(columnName)) {
      columnName = 'field_$columnName';
    }
    
    return columnName;
  }

  /// Validate slug format
  static bool isValid(String slug) {
    return RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(slug);
  }

  /// Validate table name format
  static bool isValidTableName(String tableName) {
    return RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(tableName.toLowerCase());
  }

  /// Convert column name to display name (Title Case)
  /// Example: "full_name" -> "Full Name", "email_address" -> "Email Address"
  static String columnNameToDisplayName(String columnName) {
    if (columnName.isEmpty) return columnName;
    
    // Split by underscore and capitalize each word
    final parts = columnName.split('_');
    final displayParts = parts.map((part) {
      if (part.isEmpty) return '';
      return part[0].toUpperCase() + part.substring(1).toLowerCase();
    }).where((part) => part.isNotEmpty).toList();
    
    return displayParts.join(' ');
  }
}


