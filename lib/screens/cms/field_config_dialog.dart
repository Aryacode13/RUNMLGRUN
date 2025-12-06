import 'package:flutter/material.dart';
import '../../services/cms_service.dart';
import '../../models/form_field.dart';
import '../../models/category.dart';
import '../../utils/slug_generator.dart';

class FieldConfigDialog extends StatefulWidget {
  final String projectId;
  final FormFieldModel? existingField;

  const FieldConfigDialog({
    super.key,
    required this.projectId,
    this.existingField,
  });

  @override
  State<FieldConfigDialog> createState() => _FieldConfigDialogState();
}

class _FieldConfigDialogState extends State<FieldConfigDialog> {
  final _formKey = GlobalKey<FormState>();
  final _fieldLabelController = TextEditingController();
  final _columnNameController = TextEditingController();
  final _placeholderController = TextEditingController();
  final CmsService _cmsService = CmsService();

  FieldType _selectedType = FieldType.text;
  bool _isRequired = false;
  List<String> _options = [];
  final List<TextEditingController> _optionControllers = [];
  bool _isLoading = false;
  List<Category> _categories = [];
  String? _selectedCategoryId;
  bool _isLoadingCategories = true;

  @override
  void initState() {
    super.initState();
    if (widget.existingField != null) {
      final field = widget.existingField!;
      _selectedType = field.fieldType;
      _fieldLabelController.text = field.fieldLabel;
      _columnNameController.text = field.columnName;
      _placeholderController.text = field.placeholder ?? '';
      _isRequired = field.isRequired;
      _options = List<String>.from(field.options);
      _optionControllers.addAll(_options.map((o) => TextEditingController(text: o)));
      _selectedCategoryId = field.categoryId;
    }
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _cmsService.getCategories(widget.projectId);
      if (mounted) {
        setState(() {
          _categories = categories;
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _fieldLabelController.dispose();
    _columnNameController.dispose();
    _placeholderController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _generateColumnNameFromLabel() {
    if (_fieldLabelController.text.isNotEmpty) {
      _columnNameController.text = SlugGenerator.generateColumnName(_fieldLabelController.text);
    }
  }

  void _addOption() {
    if (!mounted) return;
    setState(() {
      _optionControllers.add(TextEditingController());
      _options.add('');
    });
  }

  void _removeOption(int index) {
    setState(() {
      _optionControllers[index].dispose();
      _optionControllers.removeAt(index);
      _options.removeAt(index);
    });
  }

  Future<void> _saveField() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Update options from controllers
    _options = _optionControllers.map((c) => c.text.trim()).where((o) => o.isNotEmpty).toList();

    // Validate options for radio/dropdown
    if ((_selectedType == FieldType.radio || _selectedType == FieldType.dropdown) && _options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one option')),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      FormFieldModel? savedField;
      
      if (widget.existingField != null) {
        // Update existing field
        savedField = await _cmsService.updateFormField(
          widget.existingField!.id,
          {
            'field_type': _selectedType.name,
            'field_label': _fieldLabelController.text.trim(),
            'column_name': _columnNameController.text.trim(),
            'is_required': _isRequired,
            'options': _options,
            'placeholder': _placeholderController.text.trim().isEmpty
                ? null
                : _placeholderController.text.trim(),
            'category_id': _selectedCategoryId,
          },
        );
      } else {
        // Create new field
        savedField = await _cmsService.createFormField(
          projectId: widget.projectId,
          fieldType: _selectedType,
          fieldLabel: _fieldLabelController.text.trim(),
          columnName: _columnNameController.text.trim(),
          isRequired: _isRequired,
          options: _options,
          placeholder: _placeholderController.text.trim().isEmpty
              ? null
              : _placeholderController.text.trim(),
          categoryId: _selectedCategoryId,
        );
      }

      // Close dialog after successful save and return the saved field
      if (mounted) {
        Navigator.of(context).pop(savedField);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      
      String errorMessage = 'Error saving field';
      final errorString = e.toString();
      if (errorString.contains('duplicate key') || 
          errorString.contains('already exists')) {
        final columnMatch = RegExp(r'"([^"]+)"').firstMatch(errorString);
        if (columnMatch != null) {
          errorMessage = 'Column name "${columnMatch.group(1)}" already exists. Please use a different column name.';
        } else {
          errorMessage = 'This column name already exists in this project. Please use a different column name.';
        }
      } else if (errorString.contains('Column name')) {
        errorMessage = errorString.replaceAll('Exception: ', '');
      } else {
        errorMessage = 'Error saving field: ${errorString.replaceAll('Exception: ', '')}';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final needsOptions = _selectedType == FieldType.radio || _selectedType == FieldType.dropdown;

    return Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: const BoxConstraints(maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: Text(
                  widget.existingField == null ? 'Add Field' : 'Edit Field',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.blueGrey,
                foregroundColor: Colors.white,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                ),
                automaticallyImplyLeading: false,
              ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<FieldType>(
                        value: _selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Field Type *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category),
                        ),
                        selectedItemBuilder: (BuildContext context) {
                          return FieldType.values.map((type) {
                            return Row(
                              children: [
                                Text(type.icon),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    type.displayName,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      letterSpacing: -0.41,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            );
                          }).toList();
                        },
                        isExpanded: true,
                        items: FieldType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Row(
                              children: [
                                Text(type.icon),
                                const SizedBox(width: 8),
                                Text(
                                  type.displayName,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    letterSpacing: -0.41,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedType = value;
                              // Clear options if switching away from radio/dropdown
                              if (value != FieldType.radio && value != FieldType.dropdown) {
                                for (var controller in _optionControllers) {
                                  controller.dispose();
                                }
                                _optionControllers.clear();
                                _options.clear();
                              }
                              // Initialize with one empty option if switching to radio/dropdown and no options exist
                              else if (_optionControllers.isEmpty) {
                                _addOption();
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _fieldLabelController,
                        decoration: const InputDecoration(
                          labelText: 'Title *',
                          hintText: 'e.g., Full Name',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.label),
                          helperText: 'Label yang akan ditampilkan di form',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter title';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _columnNameController,
                              decoration: const InputDecoration(
                                labelText: 'Column Name *',
                                hintText: 'e.g., full_name',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.table_chart),
                                helperText: 'Nama kolom di database',
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter column name';
                                }
                                if (!SlugGenerator.isValidTableName(value.trim())) {
                                  return 'Invalid column name format';
                                }
                                return null;
                              },
                              onChanged: (value) {
                                // Clear any previous error when user types
                                if (_formKey.currentState != null) {
                                  _formKey.currentState!.validate();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.auto_fix_high),
                            tooltip: 'Generate column name from title',
                            onPressed: _generateColumnNameFromLabel,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _placeholderController,
                        decoration: const InputDecoration(
                          labelText: 'Placeholder (Optional)',
                          hintText: 'e.g., Enter your name',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.place),
                        ),
                      ),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        title: const Text('Required Field'),
                        value: _isRequired,
                        onChanged: (value) {
                          setState(() => _isRequired = value ?? false);
                        },
                      ),
                      // Category Selection (only if project has categories)
                      if (!_isLoadingCategories && _categories.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedCategoryId,
                          decoration: const InputDecoration(
                            labelText: 'Untuk Category (Opsional)',
                            hintText: 'Pilih category atau kosongkan untuk base field',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.category),
                            helperText: 'Jika dipilih, field ini hanya muncul untuk category yang dipilih. Kosongkan untuk base field.',
                          ),
                          selectedItemBuilder: (BuildContext context) {
                            return [
                              const Text(
                                'Semua Category',
                                style: TextStyle(
                                  fontSize: 17,
                                  letterSpacing: -0.41,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              ..._categories.map((category) {
                                return Text(
                                  category.name,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    letterSpacing: -0.41,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                );
                              }),
                            ];
                          },
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text(
                                'Semua Category',
                                style: TextStyle(
                                  fontSize: 17,
                                  letterSpacing: -0.41,
                                ),
                              ),
                            ),
                            ..._categories.map((category) {
                              return DropdownMenuItem<String>(
                                value: category.id,
                                child: Text(
                                  category.name,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    letterSpacing: -0.41,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedCategoryId = value;
                            });
                          },
                        ),
                      ],
                      if (needsOptions) ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Options *',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            TextButton.icon(
                              onPressed: _addOption,
                              icon: const Icon(Icons.add),
                              label: const Text('Add Option'),
                            ),
                          ],
                        ),
                        ...List.generate(_optionControllers.length, (index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _optionControllers[index],
                                    decoration: InputDecoration(
                                      labelText: 'Option ${index + 1}',
                                      border: const OutlineInputBorder(),
                                    ),
                                    onChanged: (value) {
                                      // Update options list when user types
                                      if (index < _options.length) {
                                        _options[index] = value.trim();
                                      } else {
                                        // If index is out of bounds, add to list
                                        while (_options.length <= index) {
                                          _options.add('');
                                        }
                                        _options[index] = value.trim();
                                      }
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _removeOption(index),
                                ),
                              ],
                            ),
                          );
                        }),
                        if (_optionControllers.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'No options yet. Click "Add Option" to add options.',
                              style: TextStyle(color: Colors.grey.shade600),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveField,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Save'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


