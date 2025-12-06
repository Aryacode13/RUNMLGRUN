import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/project.dart';
import '../models/form_field.dart';
import '../models/category.dart';
import 'supabase_service.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class CmsService {
  static final CmsService _instance = CmsService._internal();
  factory CmsService() => _instance;
  CmsService._internal();

  late SupabaseClient _client;
  final String _storageBucket = 'form-uploads';

  void initialize(SupabaseClient client) {
    _client = client;
  }

  // ==========================
  // Project Operations
  // ==========================

  Future<List<Project>> getProjects() async {
    final response = await _client
        .from('projects')
        .select()
        .order('created_at', ascending: false);
    
    return (response as List)
        .map((json) => Project.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<Project>> getPublishedProjects() async {
    final response = await _client
        .from('projects')
        .select()
        .eq('status', 'published')
        .order('created_at', ascending: false);
    
    return (response as List)
        .map((json) => Project.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Project> createProject({
    required String name,
    required String tableName,
    String? eventCode,
    double? registrationFee,
    String? redeemCode,
    double? redeemDiscountPercentage,
    bool useCategories = false,
  }) async {
    // Create project record - only include fields that exist in database
    final projectData = <String, dynamic>{
      'name': name,
      'table_name': tableName,
      'event_code': eventCode,
      'status': 'draft',
    };
    
    // Only add registration_fee if provided (check if column exists)
    if (registrationFee != null) {
      projectData['registration_fee'] = registrationFee;
    }
    
    // Only add redeem_code if provided (check if column exists)
    if (redeemCode != null && redeemCode.isNotEmpty) {
      projectData['redeem_code'] = redeemCode;
    }
    
    // Only add redeem_discount_percentage if provided (check if column exists)
    if (redeemDiscountPercentage != null) {
      projectData['redeem_discount_percentage'] = redeemDiscountPercentage;
    }
    
    // Add use_categories
    projectData['use_categories'] = useCategories;
    
    final projectResponse = await _client
        .from('projects')
        .insert(projectData)
        .select()
        .single();

    final project = Project.fromJson(projectResponse);

    // Create base table dynamically
    await createBaseTable(tableName);

    return project;
  }

  Future<Project> updateProject(String id, Map<String, dynamic> updates) async {
    final response = await _client
        .from('projects')
        .update(updates)
        .eq('id', id)
        .select()
        .single();

    return Project.fromJson(response);
  }

  Future<void> deleteProject(String id) async {
    // Get project to get table_name
    final project = await _client
        .from('projects')
        .select('table_name')
        .eq('id', id)
        .single();

    final tableName = project['table_name'] as String;

    // Delete project (cascade will delete form_fields)
    await _client.from('projects').delete().eq('id', id);

    // Drop dynamic table
    await dropTable(tableName);
  }

  Future<Project?> getProjectByEventCode(String eventCode) async {
    final response = await _client
        .from('projects')
        .select()
        .eq('event_code', eventCode)
        .maybeSingle();

    if (response == null) return null;
    return Project.fromJson(response);
  }

  Future<Project?> getProject(String projectId) async {
    final response = await _client
        .from('projects')
        .select()
        .eq('id', projectId)
        .maybeSingle();

    if (response == null) return null;
    return Project.fromJson(response);
  }

  // ==========================
  // Form Field Operations
  // ==========================

  Future<List<FormFieldModel>> getFormFields(String projectId) async {
    final response = await _client
        .from('form_fields')
        .select()
        .eq('project_id', projectId)
        .order('order', ascending: true);

    return (response as List)
        .map((json) => FormFieldModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Check if column name already exists for a project
  Future<bool> columnNameExists(String projectId, String columnName, {String? excludeFieldId}) async {
    var query = _client
        .from('form_fields')
        .select('id')
        .eq('project_id', projectId)
        .eq('column_name', columnName);
    
    if (excludeFieldId != null) {
      query = query.neq('id', excludeFieldId);
    }
    
    final result = await query.maybeSingle();
    return result != null;
  }

  Future<FormFieldModel> createFormField({
    required String projectId,
    required FieldType fieldType,
    required String fieldLabel,
    required String columnName,
    bool isRequired = false,
    List<String> options = const [],
    String? placeholder,
    Map<String, dynamic> validationRules = const {},
    String? categoryId,
  }) async {
    // Check if column_name already exists for this project
    final existingField = await _client
        .from('form_fields')
        .select('id')
        .eq('project_id', projectId)
        .eq('column_name', columnName)
        .maybeSingle();

    if (existingField != null) {
      throw Exception(
        'Column name "$columnName" already exists in this project. '
        'Please use a different column name.',
      );
    }

    // Get project to get table_name
    final project = await _client
        .from('projects')
        .select('table_name')
        .eq('id', projectId)
        .single();

    final tableName = project['table_name'] as String;

    // Get max order
    final maxOrderResponse = await _client
        .from('form_fields')
        .select('order')
        .eq('project_id', projectId)
        .order('order', ascending: false)
        .limit(1)
        .maybeSingle();

    final order = maxOrderResponse != null 
        ? (maxOrderResponse['order'] is int
            ? maxOrderResponse['order'] as int
            : maxOrderResponse['order'] is String
                ? int.tryParse(maxOrderResponse['order'] as String) ?? 0
                : (maxOrderResponse['order'] as num?)?.toInt() ?? 0) + 1
        : 0;

    // Create field record
    final fieldData = {
      'project_id': projectId,
      'field_type': fieldType.name,
      'field_label': fieldLabel,
      'column_name': columnName,
      'is_required': isRequired,
      'options': options,
      'placeholder': placeholder,
      'validation_rules': validationRules,
      'order': order,
    };
    
    // Add category_id if provided
    if (categoryId != null && categoryId.isNotEmpty) {
      fieldData['category_id'] = categoryId;
    }
    
    final fieldResponse = await _client
        .from('form_fields')
        .insert(fieldData)
        .select()
        .single();

    final field = FormFieldModel.fromJson(fieldResponse);

    // Add column to dynamic table
    await addColumnToTable(tableName, field);

    return field;
  }

  Future<FormFieldModel> updateFormField(
    String id,
    Map<String, dynamic> updates,
  ) async {
    // Get existing field
    final existingField = await _client
        .from('form_fields')
        .select()
        .eq('id', id)
        .single();

    final field = FormFieldModel.fromJson(existingField);

    // Get project
    final project = await _client
        .from('projects')
        .select('table_name')
        .eq('id', field.projectId)
        .single();

    final tableName = project['table_name'] as String;

    // Check if column_name or field_type changed
    final oldColumnName = field.columnName;
    final oldFieldType = field.fieldType;
    final newColumnName = updates['column_name'] as String?;
    final newFieldType = updates['field_type'] != null
        ? FieldType.fromString(updates['field_type'] as String)
        : null;

    // Check if new column_name already exists (if changed)
    if (newColumnName != null && newColumnName != oldColumnName) {
      final duplicateField = await _client
          .from('form_fields')
          .select('id')
          .eq('project_id', field.projectId)
          .eq('column_name', newColumnName)
          .neq('id', id)
          .maybeSingle();

      if (duplicateField != null) {
        throw Exception(
          'Column name "$newColumnName" already exists in this project. '
          'Please use a different column name.',
        );
      }
    }

    // Update field record
    final response = await _client
        .from('form_fields')
        .update(updates)
        .eq('id', id)
        .select()
        .single();

    final updatedField = FormFieldModel.fromJson(response);

    // Handle column changes
    if (newColumnName != null && newColumnName != oldColumnName) {
      // Rename column
      await renameColumnInTable(tableName, oldColumnName, newColumnName, updatedField.fieldType);
    }

    if (newFieldType != null && newFieldType != oldFieldType) {
      // Alter column type
      final columnName = newColumnName ?? oldColumnName;
      await alterColumnType(tableName, columnName, newFieldType);
    }

    return updatedField;
  }

  Future<void> deleteFormField(String id) async {
    // Get field
    final field = await _client
        .from('form_fields')
        .select()
        .eq('id', id)
        .single();

    final fieldModel = FormFieldModel.fromJson(field);

    // Get project
    final project = await _client
        .from('projects')
        .select('table_name')
        .eq('id', fieldModel.projectId)
        .single();

    final tableName = project['table_name'] as String;

    // Delete field record
    await _client.from('form_fields').delete().eq('id', id);

    // Remove column from table
    await removeColumnFromTable(tableName, fieldModel.columnName);
  }

  Future<void> reorderFields(String projectId, List<String> fieldIds) async {
    for (int i = 0; i < fieldIds.length; i++) {
      await _client
          .from('form_fields')
          .update({'order': i})
          .eq('id', fieldIds[i]);
    }
  }

  // ==========================
  // Category Operations
  // ==========================

  Future<List<Category>> getCategories(String projectId) async {
    final response = await _client
        .from('categories')
        .select()
        .eq('project_id', projectId)
        .order('order', ascending: true);

    return (response as List)
        .map((json) => Category.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Category> createCategory({
    required String projectId,
    required String name,
    double price = 0,
  }) async {
    // Check if category name already exists for this project
    final existingCategory = await _client
        .from('categories')
        .select('id')
        .eq('project_id', projectId)
        .eq('name', name)
        .maybeSingle();

    if (existingCategory != null) {
      throw Exception(
        'Category "$name" already exists in this project. '
        'Please use a different name.',
      );
    }

    // Get max order
    final maxOrderResponse = await _client
        .from('categories')
        .select('order')
        .eq('project_id', projectId)
        .order('order', ascending: false)
        .limit(1)
        .maybeSingle();

    final order = maxOrderResponse != null 
        ? (maxOrderResponse['order'] is int
            ? maxOrderResponse['order'] as int
            : maxOrderResponse['order'] is String
                ? int.tryParse(maxOrderResponse['order'] as String) ?? 0
                : (maxOrderResponse['order'] as num?)?.toInt() ?? 0) + 1
        : 0;

    // Create category
    final response = await _client
        .from('categories')
        .insert({
          'project_id': projectId,
          'name': name,
          'price': price,
          'order': order,
        })
        .select()
        .single();

    return Category.fromJson(response);
  }

  Future<Category> updateCategory(
    String id,
    Map<String, dynamic> updates,
  ) async {
    // Check if name is being updated and if it conflicts
    if (updates.containsKey('name')) {
      final existingCategory = await _client
          .from('categories')
          .select('project_id')
          .eq('id', id)
          .single();

      final projectId = existingCategory['project_id'] as String;
      final newName = updates['name'] as String;

      final duplicateCategory = await _client
          .from('categories')
          .select('id')
          .eq('project_id', projectId)
          .eq('name', newName)
          .neq('id', id)
          .maybeSingle();

      if (duplicateCategory != null) {
        throw Exception(
          'Category "$newName" already exists in this project. '
          'Please use a different name.',
        );
      }
    }

    final response = await _client
        .from('categories')
        .update(updates)
        .eq('id', id)
        .select()
        .single();

    return Category.fromJson(response);
  }

  Future<void> deleteCategory(String id) async {
    await _client.from('categories').delete().eq('id', id);
  }

  Future<void> reorderCategories(String projectId, List<String> categoryIds) async {
    for (int i = 0; i < categoryIds.length; i++) {
      await _client
          .from('categories')
          .update({'order': i})
          .eq('id', categoryIds[i]);
    }
  }

  // ==========================
  // Category Field Operations
  // ==========================

  Future<List<CategoryField>> getCategoryFields(String categoryId) async {
    final response = await _client
        .from('category_fields')
        .select()
        .eq('category_id', categoryId);

    return (response as List)
        .map((json) => CategoryField.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<CategoryField>> getCategoryFieldsByProject(String projectId) async {
    // Get all categories for this project
    final categories = await getCategories(projectId);
    if (categories.isEmpty) return [];

    final categoryIds = categories.map((c) => c.id).toList();

    // Build OR filter for multiple category IDs
    final filter = categoryIds.map((id) => 'category_id.eq.$id').join(',');
    
    final response = await _client
        .from('category_fields')
        .select()
        .or(filter);

    return (response as List)
        .map((json) => CategoryField.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<CategoryField> createCategoryField({
    required String categoryId,
    required String fieldId,
    required CategoryFieldAction action,
  }) async {
    // Check if already exists
    final existing = await _client
        .from('category_fields')
        .select('id')
        .eq('category_id', categoryId)
        .eq('field_id', fieldId)
        .maybeSingle();

    if (existing != null) {
      // Update existing
      final response = await _client
          .from('category_fields')
          .update({'action': action.name})
          .eq('id', existing['id'] as String)
          .select()
          .single();
      return CategoryField.fromJson(response);
    }

    // Create new
    final response = await _client
        .from('category_fields')
        .insert({
          'category_id': categoryId,
          'field_id': fieldId,
          'action': action.name,
        })
        .select()
        .single();

    return CategoryField.fromJson(response);
  }

  Future<void> deleteCategoryField(String id) async {
    await _client.from('category_fields').delete().eq('id', id);
  }

  Future<void> deleteCategoryFieldsByCategory(String categoryId) async {
    await _client.from('category_fields').delete().eq('category_id', categoryId);
  }

  Future<void> deleteCategoryFieldsByField(String fieldId) async {
    await _client.from('category_fields').delete().eq('field_id', fieldId);
  }

  // ==========================
  // Dynamic Table Operations
  // ==========================

  Future<void> createBaseTable(String tableName) async {
    final sanitizedTableName = _sanitizeTableName(tableName);
    final query = '''
      CREATE TABLE IF NOT EXISTS "$sanitizedTableName" (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid()
      );
    ''';

    await _executeSql(query);
  }

  Future<void> addColumnToTable(String tableName, FormFieldModel field) async {
    final sanitizedTableName = _sanitizeTableName(tableName);
    final sanitizedColumnName = _sanitizeColumnName(field.columnName);
    final columnType = _getColumnType(field.fieldType);

    final query = '''
      ALTER TABLE "$sanitizedTableName"
      ADD COLUMN IF NOT EXISTS "$sanitizedColumnName" $columnType;
    ''';

    await _executeSql(query);
  }

  Future<void> removeColumnFromTable(String tableName, String columnName) async {
    final sanitizedTableName = _sanitizeTableName(tableName);
    final sanitizedColumnName = _sanitizeColumnName(columnName);

    final query = '''
      ALTER TABLE "$sanitizedTableName"
      DROP COLUMN IF EXISTS "$sanitizedColumnName";
    ''';

    await _executeSql(query);
  }

  Future<void> renameColumnInTable(
    String tableName,
    String oldColumnName,
    String newColumnName,
    FieldType fieldType,
  ) async {
    final sanitizedTableName = _sanitizeTableName(tableName);
    final sanitizedOldName = _sanitizeColumnName(oldColumnName);
    final sanitizedNewName = _sanitizeColumnName(newColumnName);

    final query = '''
      ALTER TABLE "$sanitizedTableName"
      RENAME COLUMN "$sanitizedOldName" TO "$sanitizedNewName";
    ''';

    await _executeSql(query);
  }

  Future<void> alterColumnType(
    String tableName,
    String columnName,
    FieldType newFieldType,
  ) async {
    final sanitizedTableName = _sanitizeTableName(tableName);
    final sanitizedColumnName = _sanitizeColumnName(columnName);
    final newColumnType = _getColumnType(newFieldType);

    final query = '''
      ALTER TABLE "$sanitizedTableName"
      ALTER COLUMN "$sanitizedColumnName" TYPE $newColumnType;
    ''';

    await _executeSql(query);
  }

  Future<void> dropTable(String tableName) async {
    final sanitizedTableName = _sanitizeTableName(tableName);
    final query = 'DROP TABLE IF EXISTS "$sanitizedTableName";';
    await _executeSql(query);
  }

  // ==========================
  // Form Submission Operations
  // ==========================

  Future<Map<String, dynamic>> submitFormData({
    required String tableName,
    required Map<String, dynamic> data,
    required String projectId,
  }) async {
    final sanitizedTableName = _sanitizeTableName(tableName);

    // Get project to check event_code
    final projectResponse = await _client
        .from('projects')
        .select()
        .eq('id', projectId)
        .single();
    
    final project = Project.fromJson(projectResponse as Map<String, dynamic>);

    // Handle file uploads
    final processedData = Map<String, dynamic>.from(data);
    final fileFields = <String, Map<String, dynamic>>{};

    for (var entry in data.entries) {
      if (entry.value is Map && (entry.value as Map).containsKey('bytes')) {
        // This is a file field
        fileFields[entry.key] = entry.value as Map<String, dynamic>;
        processedData.remove(entry.key);
      }
    }

    // Upload files and get URLs
    for (var entry in fileFields.entries) {
      final fileData = entry.value;
      final bytes = fileData['bytes'] as Uint8List;
      final fileName = fileData['name'] as String;
      final extension = fileData['extension'] as String;

      final fileUrl = await uploadFile(
        projectId: projectId,
        columnName: entry.key,
        bytes: bytes,
        fileName: fileName,
        extension: extension,
      );

      processedData[entry.key] = fileUrl;
    }

    // Insert data into dynamic table
    final response = await _client
        .from(sanitizedTableName)
        .insert(processedData)
        .select()
        .single();

    // Jika project punya event_code, buat registration record
    if (project.eventCode != null && project.eventCode!.isNotEmpty) {
      try {
        // Cari event dengan event_code yang sama
        final eventResponse = await _client
            .from('events')
            .select('id')
            .eq('event_code', project.eventCode!)
            .eq('is_active', true)
            .maybeSingle();

        if (eventResponse != null) {
          final eventId = eventResponse['id'] as String;
          
          // Get current user
          final supabaseService = SupabaseService();
          final currentUser = await supabaseService.getCurrentUser();
          
          if (currentUser != null) {
            // Cek apakah sudah terdaftar
            final isRegistered = await supabaseService.isRegistered(eventId, currentUser.id);
            
            // Cari payment receipt dari form submission
            String? paymentReceiptUrl;
            try {
              // Strategi 1: Cari field dengan nama yang relevan (case insensitive)
              final receiptFieldNames = ['payment_receipt', 'receipt', 'bukti_pembayaran', 'payment_proof', 'resi', 'proof_of_payment', 'bukti', 'payment'];
              for (var fieldName in receiptFieldNames) {
                // Cek exact match
                if (processedData.containsKey(fieldName) && processedData[fieldName] != null) {
                  final value = processedData[fieldName].toString();
                  if (value.startsWith('http://') || value.startsWith('https://')) {
                    paymentReceiptUrl = value;
                    break;
                  }
                }
                // Cek case-insensitive match
                for (var key in processedData.keys) {
                  if (key.toLowerCase().contains(fieldName.toLowerCase())) {
                    final value = processedData[key].toString();
                    if (value.startsWith('http://') || value.startsWith('https://')) {
                      paymentReceiptUrl = value;
                      break;
                    }
                  }
                }
                if (paymentReceiptUrl != null) break;
              }
              
              // Strategi 2: Jika belum ketemu, ambil file upload pertama yang ada
              // (untuk form yang hanya punya satu file upload field)
              if (paymentReceiptUrl == null) {
                for (var entry in processedData.entries) {
                  final value = entry.value?.toString() ?? '';
                  // Jika value adalah URL (dari file upload), gunakan sebagai payment receipt
                  if (value.startsWith('http://') || value.startsWith('https://')) {
                    // Pastikan ini adalah URL file (bukan URL biasa)
                    if (value.contains('/storage/') || value.contains('.jpg') || value.contains('.jpeg') || 
                        value.contains('.png') || value.contains('.pdf') || value.contains('.webp')) {
                      paymentReceiptUrl = value;
                      break;
                    }
                  }
                }
              }
            } catch (e) {
              print('⚠️ Error finding payment receipt: $e');
            }
            
            if (!isRegistered) {
              // Buat registration record dengan payment receipt jika ada
              await supabaseService.registerForEvent(
                eventId, 
                currentUser.id,
                paymentReceiptUrl: paymentReceiptUrl,
              );
              print('✅ Registration created for event: $eventId');
            } else {
              // Update existing registration dengan payment receipt jika ada
              if (paymentReceiptUrl != null) {
                await supabaseService.updateRegistrationReceipt(eventId, currentUser.id, paymentReceiptUrl);
                print('✅ Payment receipt updated for event: $eventId');
              }
              print('ℹ️ User already registered for this event');
            }
          } else {
            print('⚠️ No current user found, skipping registration');
          }
        } else {
          print('⚠️ No active event found with event_code: ${project.eventCode}');
        }
      } catch (e) {
        // Log error but don't fail form submission
        print('⚠️ Error creating registration: $e');
      }
    }

    return response as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getFormSubmissions(String tableName, {String? eventCode}) async {
    final sanitizedTableName = _sanitizeTableName(tableName);
    final response = await _client
        .from(sanitizedTableName)
        .select()
        .order('id', ascending: false);

    final submissions = (response as List).cast<Map<String, dynamic>>();

    // If eventCode is provided, fetch usernames from registrations
    if (eventCode != null && eventCode.isNotEmpty) {
      try {
        // Get event_id from event_code
        final eventResponse = await _client
            .from('events')
            .select('id')
            .eq('event_code', eventCode)
            .eq('is_active', true)
            .maybeSingle();

        if (eventResponse != null) {
          final eventId = eventResponse['id'] as String;
          
          // Get all registrations for this event with username, ordered by registered_at (oldest first)
          final registrationsResponse = await _client
              .from('registrations')
              .select('username, registered_at')
              .eq('event_id', eventId)
              .not('username', 'is', null)
              .order('registered_at', ascending: true); // Oldest first to match with submission order

          // Get list of usernames from registrations
          final usernames = <String>[];
          for (var reg in registrationsResponse) {
            final username = reg['username']?.toString();
            if (username != null && username.isNotEmpty) {
              usernames.add(username);
            }
          }

          // Match usernames with submissions by index (submission #1 = first username, etc.)
          if (usernames.isNotEmpty) {
            for (int i = 0; i < submissions.length; i++) {
              if (i < usernames.length) {
                submissions[i]['_username'] = usernames[i];
              }
            }
          }
        }
      } catch (e) {
        print('⚠️ Error fetching usernames from registrations: $e');
        // Continue without username if fetch fails
      }
    }

    return submissions;
  }

  Future<void> deleteSubmission(String tableName, String submissionId, {required String projectId}) async {
    final sanitizedTableName = _sanitizeTableName(tableName);

    // Get submission to check for file fields
    final submission = await _client
        .from(sanitizedTableName)
        .select()
        .eq('id', submissionId)
        .single();

    // Delete files from storage if any
    final fields = await _client
        .from('form_fields')
        .select('column_name, field_type')
        .eq('project_id', projectId)
        .eq('field_type', 'file');

    for (var field in fields) {
      final columnName = field['column_name'] as String;
      final fileUrl = submission[columnName] as String?;
      if (fileUrl != null && fileUrl.isNotEmpty) {
        try {
          await _client.storage.from(_storageBucket).remove([fileUrl]);
        } catch (e) {
          print('Error deleting file: $e');
        }
      }
    }

    // Delete submission
    await _client.from(sanitizedTableName).delete().eq('id', submissionId);
  }

  // ==========================
  // File Upload Operations
  // ==========================

  Future<String> uploadFile({
    required String projectId,
    required String columnName,
    required Uint8List bytes,
    required String fileName,
    required String extension,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final sanitizedFileName = fileName.replaceAll(RegExp(r'[^\w\s.-]'), '_');
    final path = '$projectId/$columnName/${timestamp}_$sanitizedFileName';

    final contentType = _getContentType(extension);

    await _client.storage.from(_storageBucket).uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        contentType: contentType,
        upsert: false,
      ),
    );

    // Get public URL
    final url = _client.storage.from(_storageBucket).getPublicUrl(path);
    return url;
  }

  Future<Map<String, dynamic>?> pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx', 'xls', 'xlsx'],
        withData: true, // Get file bytes directly
      );

      if (result != null && result.files.single.size > 0) {
        final file = result.files.single;
        
        // Read file bytes
        Uint8List bytes;
        if (kIsWeb || file.bytes != null) {
          bytes = file.bytes!;
        } else if (file.path != null) {
          bytes = await File(file.path!).readAsBytes();
        } else {
          return null;
        }

        final extension = file.extension?.toLowerCase() ?? 
            (file.name.split('.').length > 1 
                ? file.name.split('.').last.toLowerCase() 
                : '');
        final fileName = file.name;

        return {
          'bytes': bytes,
          'name': fileName,
          'extension': extension,
          'size': bytes.length,
        };
      }
    } catch (e) {
      print('Error picking file: $e');
    }
    return null;
  }

  // ==========================
  // Helper Methods
  // ==========================

  String _getColumnType(FieldType fieldType) {
    switch (fieldType) {
      case FieldType.text:
      case FieldType.textarea:
      case FieldType.email:
      case FieldType.phone:
      case FieldType.url:
      case FieldType.radio:
      case FieldType.dropdown:
      case FieldType.file:
        return 'TEXT';
      case FieldType.number:
        return 'NUMERIC';
      case FieldType.date:
        return 'DATE';
      case FieldType.checkbox:
        return 'BOOLEAN';
    }
  }

  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      default:
        return 'application/octet-stream';
    }
  }

  String _sanitizeTableName(String name) {
    // Only allow alphanumeric and underscore, must start with letter
    return name.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  }

  String _sanitizeColumnName(String name) {
    // Only allow alphanumeric and underscore, must start with letter
    return name.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  }

  Future<void> _executeSql(String query) async {
    try {
      await _client.rpc('execute_sql', params: {'query_text': query});
    } catch (e) {
      print('Error executing SQL: $e');
      rethrow;
    }
  }
}

