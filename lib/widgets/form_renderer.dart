import 'package:flutter/material.dart';
import '../services/cms_service.dart';
import '../models/form_field.dart';
import '../models/category.dart';
import '../models/project.dart';
import 'dynamic_form_field.dart';

class FormRenderer extends StatefulWidget {
  final String projectId;
  final Map<String, dynamic> formData;
  final Function(String key, dynamic value) onFieldChanged;
  final bool readOnly;
  final VoidCallback? onSubmit;
  final Function(List<String> selectedCategoryIds)? onCategoriesChanged;

  const FormRenderer({
    super.key,
    required this.projectId,
    required this.formData,
    required this.onFieldChanged,
    this.readOnly = false,
    this.onSubmit,
    this.onCategoriesChanged,
  });

  @override
  State<FormRenderer> createState() => _FormRendererState();
}

class _FormRendererState extends State<FormRenderer> {
  final CmsService _cmsService = CmsService();
  final _formKey = GlobalKey<FormState>();
  Project? _project;
  List<FormFieldModel> _allFields = [];
  List<FormFieldModel> _visibleFields = [];
  List<Category> _categories = [];
  String? _selectedCategoryId; // Single selection
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Load project to check useCategories
      _project = await _cmsService.getProject(widget.projectId);
      if (_project == null) {
        throw Exception('Project not found');
      }
      
      final fields = await _cmsService.getFormFields(widget.projectId);
      
      // Only load categories if project uses categories
      List<Category> categories = [];
      if (_project!.useCategories) {
        categories = await _cmsService.getCategories(widget.projectId);
      }

      setState(() {
        _allFields = fields;
        _categories = categories;
        _updateVisibleFields();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading form: $e')),
        );
      }
    }
  }

  void _updateVisibleFields() {
    // If project doesn't use categories, show all fields
    if (_project == null || !_project!.useCategories) {
      _visibleFields = List.from(_allFields);
      return;
    }

    // If no category selected, show only base fields (category_id is null)
    if (_selectedCategoryId == null) {
      _visibleFields = _allFields.where((field) => field.categoryId == null).toList();
      return;
    }

    // If category selected, show base fields + fields for this category
    _visibleFields = _allFields.where((field) {
      // Base field (for all categories) or field for selected category
      return field.categoryId == null || field.categoryId == _selectedCategoryId;
    }).toList();
    
    // Maintain order
    _visibleFields.sort((a, b) => a.order.compareTo(b.order));
  }

  void _selectCategory(String? categoryId) {
    setState(() {
      // If clicking the same category, deselect it (allow unselecting)
      if (_selectedCategoryId == categoryId) {
        _selectedCategoryId = null;
      } else {
        _selectedCategoryId = categoryId;
      }
      _updateVisibleFields();
    });
    
    // Notify parent about category changes (send as list for compatibility)
    widget.onCategoriesChanged?.call(_selectedCategoryId != null ? [_selectedCategoryId!] : []);
  }

  void _handleSubmit() {
    // If project uses categories and categories exist, require a category selection
    if (_project != null &&
        _project!.useCategories &&
        _categories.isNotEmpty &&
        _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih kategori terlebih dahulu'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      widget.onSubmit?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Category Selection (only if project uses categories and categories exist)
          if (_project != null && _project!.useCategories && _categories.isNotEmpty && !widget.readOnly) ...[
            Card(
              color: Colors.blueGrey.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pilih Kategori',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        // Judul "Pilih Kategori" dibuat hitam agar kontras
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._categories.map((category) {
                      return RadioListTile<String>(
                        title: Text(
                          category.name,
                          style: const TextStyle(
                            color: Colors.black,
                          ),
                        ),
                        subtitle: Text(
                          category.formattedPrice,
                          style: const TextStyle(
                            color: Colors.black,
                          ),
                        ),
                        value: category.id,
                        groupValue: _selectedCategoryId,
                        onChanged: (value) => _selectCategory(value),
                        contentPadding: EdgeInsets.zero,
                        toggleable: true, // Allow unselecting
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          // Form Fields
          ..._visibleFields.map((field) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: DynamicFormField(
                field: field,
                value: widget.formData[field.columnName],
                onChanged: (value) {
                  widget.onFieldChanged(field.columnName, value);
                },
                readOnly: widget.readOnly,
              ),
            );
          }),
          if (!widget.readOnly && widget.onSubmit != null) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text(
                  'Kirim Form',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}



