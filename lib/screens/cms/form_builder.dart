import 'package:flutter/material.dart';
import '../../services/cms_service.dart';
import '../../models/project.dart';
import '../../models/form_field.dart';
import 'field_config_dialog.dart';
import 'preview_form.dart';
import 'submissions_screen.dart';

class FormBuilderScreen extends StatefulWidget {
  final Project project;

  const FormBuilderScreen({super.key, required this.project});

  @override
  State<FormBuilderScreen> createState() => _FormBuilderScreenState();
}

class _FormBuilderScreenState extends State<FormBuilderScreen> {
  final CmsService _cmsService = CmsService();
  List<FormFieldModel> _fields = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFields();
  }

  Future<void> _loadFields() async {
    setState(() => _isLoading = true);
    try {
      final fields = await _cmsService.getFormFields(widget.project.id);
      setState(() {
        _fields = fields;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading fields: $e')),
        );
      }
    }
  }


  Future<void> _addField() async {
    final field = await showDialog<FormFieldModel>(
      context: context,
      barrierDismissible: true,
      builder: (context) => FieldConfigDialog(projectId: widget.project.id),
    );

    if (field != null) {
      _loadFields();
    }
  }

  Future<void> _editField(FormFieldModel field) async {
    final updatedField = await showDialog<FormFieldModel>(
      context: context,
      barrierDismissible: true,
      builder: (context) => FieldConfigDialog(
        projectId: widget.project.id,
        existingField: field,
      ),
    );

    if (updatedField != null) {
      _loadFields();
    }
  }

  Future<void> _deleteField(FormFieldModel field) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Field'),
        content: Text('Are you sure you want to delete "${field.displayName}"? This will also remove the column from the database table.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _cmsService.deleteFormField(field.id);
        _loadFields();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Field deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting field: $e')),
          );
        }
      }
    }
  }

  Future<void> _reorderFields(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    // Update local state immediately for better UX
    final item = _fields.removeAt(oldIndex);
    _fields.insert(newIndex, item);

    setState(() {});

    try {
      // Update order in database
      final fieldIds = _fields.map((f) => f.id).toList();
      await _cmsService.reorderFields(widget.project.id, fieldIds);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Field order updated'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      // Reload on error to restore original order
      _loadFields();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reordering fields: $e')),
        );
      }
    }
  }

  Future<void> _togglePublish() async {
    final newStatus = widget.project.status == 'published' ? 'draft' : 'published';
    try {
      await _cmsService.updateProject(widget.project.id, {'status': newStatus});
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e')),
        );
      }
    }
  }

  // Categories are now managed in create_project.dart
  // All category management functions have been moved there

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.project.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.preview),
            tooltip: 'Preview Form',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PreviewFormScreen(project: widget.project),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.table_chart),
            tooltip: 'View Submissions',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SubmissionsScreen(project: widget.project),
                ),
              );
            },
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'publish',
                child: Row(
                  children: [
                    Icon(
                      widget.project.status == 'published' ? Icons.unpublished : Icons.publish,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(widget.project.status == 'published' ? 'Unpublish' : 'Publish'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'publish') {
                _togglePublish();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _fields.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_circle_outline, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text(
                              'No fields yet',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Add your first field to start building the form',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ReorderableListView(
                        // Extra bottom padding so last field is not hidden behind the Add Field button
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                        onReorder: _reorderFields,
                        children: _fields.map((field) {
                          return Card(
                            key: ValueKey(field.id),
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.drag_handle,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(width: 8),
                                  CircleAvatar(
                                    backgroundColor: Colors.orange.shade700,
                                    foregroundColor: Colors.white,
                                    child: Text(field.fieldType.icon),
                                  ),
                                ],
                              ),
                              title: Text(field.fieldLabel.isNotEmpty ? field.fieldLabel : field.displayName),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Type: ${field.fieldType.displayName}'),
                                  Text('Column: ${field.columnName}'),
                                  if (field.isRequired)
                                    const Chip(
                                      label: Text('Required', style: TextStyle(fontSize: 10)),
                                      backgroundColor: Colors.red,
                                      labelStyle: TextStyle(color: Colors.white),
                                    ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () => _editField(field),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteField(field),
                                  ),
                                ],
                              ),
                              isThreeLine: true,
                            ),
                          );
                        }).toList(),
                      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addField,
        icon: const Icon(Icons.add),
        label: const Text('Add Field'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
    );
  }
}

