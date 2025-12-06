import 'package:flutter/material.dart';
import '../../services/cms_service.dart';
import '../../models/project.dart';
import '../../models/form_field.dart';
import '../../utils/error_handler.dart';

class SubmissionsScreen extends StatefulWidget {
  final Project project;

  const SubmissionsScreen({super.key, required this.project});

  @override
  State<SubmissionsScreen> createState() => _SubmissionsScreenState();
}

class _SubmissionsScreenState extends State<SubmissionsScreen> {
  final CmsService _cmsService = CmsService();
  List<FormFieldModel> _fields = [];
  List<Map<String, dynamic>> _submissions = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final fields = await _cmsService.getFormFields(widget.project.id);
      final submissions = await _cmsService.getFormSubmissions(
        widget.project.tableName,
        eventCode: widget.project.eventCode,
      );
      setState(() {
        _fields = fields;
        _submissions = submissions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ErrorHandler.showError(context, e);
      }
    }
  }

  Future<void> _deleteSubmission(String submissionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Submission'),
        content: const Text('Are you sure you want to delete this submission?'),
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
        await _cmsService.deleteSubmission(widget.project.tableName, submissionId, projectId: widget.project.id);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Submission deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ErrorHandler.showError(context, e);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Submissions: ${widget.project.name}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cari submission...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade900,
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                    ),
                    style: const TextStyle(color: Colors.white),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                // Submissions list
                Expanded(
                  child: _submissions.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'No submissions yet',
                                style: TextStyle(fontSize: 18, color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : _buildFilteredSubmissions(),
                ),
              ],
            ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final dateTime = date is String ? DateTime.parse(date) : date as DateTime;
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return date.toString();
    }
  }

  Widget _buildFilteredSubmissions() {
    // Filter submissions based on search query
    final filteredSubmissions = _submissions.where((submission) {
      if (_searchQuery.isEmpty) return true;
      
      final query = _searchQuery.toLowerCase();
      
      // Search in username
      final username = (submission['_username'] ?? '').toString().toLowerCase();
      if (username.contains(query)) return true;
      
      // Search in submission ID
      final id = submission['id'].toString().toLowerCase();
      if (id.contains(query)) return true;
      
      // Search in all field values
      for (final field in _fields) {
        final value = submission[field.columnName];
        if (value != null) {
          final valueStr = _formatValue(value, field.fieldType).toLowerCase();
          if (valueStr.contains(query)) return true;
          
          // Also search in field display name
          final fieldName = field.displayName.toLowerCase();
          if (fieldName.contains(query)) return true;
        }
      }
      
      return false;
    }).toList();

    if (filteredSubmissions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? 'No submissions yet'
                  : 'No submissions found for "${_searchQuery}"',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: filteredSubmissions.length,
        itemBuilder: (context, index) {
          final submission = filteredSubmissions[index];
          final originalIndex = _submissions.indexOf(submission);
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ExpansionTile(
              leading: const Icon(Icons.description, color: Colors.white),
              title: Text(
                'Submission #${originalIndex + 1}',
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ID: ${submission['id'].toString().substring(0, 8)}...',
                    style: TextStyle(color: Colors.grey.shade400),
                  ),
                  if (submission['_username'] != null && submission['_username'].toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Username: @${submission['_username']}',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _fields.map((field) {
                      final value = submission[field.columnName];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 120,
                              child: Text(
                                '${field.displayName}:',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                _formatValue(value, field.fieldType),
                                style: TextStyle(color: Colors.grey.shade400),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _deleteSubmission(submission['id'] as String),
                        icon: const Icon(Icons.delete, color: Colors.red),
                        label: const Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatValue(dynamic value, FieldType fieldType) {
    if (value == null) return 'N/A';
    
    switch (fieldType) {
      case FieldType.checkbox:
        return value == true ? 'Yes' : 'No';
      case FieldType.file:
        return value.toString(); // URL
      case FieldType.date:
        return _formatDate(value);
      default:
        return value.toString();
    }
  }
}


