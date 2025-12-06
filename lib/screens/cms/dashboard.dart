import 'package:flutter/material.dart';
import '../../services/cms_service.dart';
import '../../models/project.dart';
import 'create_project.dart';
import 'form_builder.dart';

class CmsDashboard extends StatefulWidget {
  const CmsDashboard({super.key});

  @override
  State<CmsDashboard> createState() => _CmsDashboardState();
}

class _CmsDashboardState extends State<CmsDashboard> {
  final CmsService _cmsService = CmsService();
  List<Project> _projects = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    setState(() => _isLoading = true);
    try {
      final projects = await _cmsService.getProjects();
      setState(() {
        _projects = projects;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading projects: $e')),
        );
      }
    }
  }

  Future<void> _togglePublish(Project project) async {
    final isCurrentlyPublished = project.status == 'published';
    final newStatus = isCurrentlyPublished ? 'draft' : 'published';

    try {
      await _cmsService.updateProject(project.id, {'status': newStatus});
      await _loadProjects();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isCurrentlyPublished ? 'Project moved to DRAFT' : 'Project published',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating status: $e')),
      );
    }
  }

  Future<void> _deleteProject(Project project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text('Are you sure you want to delete "${project.name}"? This will also delete all form fields and submissions.'),
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
        await _cmsService.deleteProject(project.id);
        _loadProjects();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Project deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting project: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar is handled by the parent (AdminDashboard), so only provide body here
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // iOS-style Search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cari project...',
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF8E8E93)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Color(0xFF8E8E93)),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF1C1C1E),
                      hintStyle: const TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 17,
                        letterSpacing: -0.41,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      letterSpacing: -0.41,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                // Projects list
                Expanded(
                  child: _projects.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.inbox, size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              const Text(
                                'No projects yet',
                                style: TextStyle(fontSize: 18, color: Colors.grey),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Create your first form project',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : _buildFilteredProjects(),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateProjectScreen()),
          );
          if (result == true) {
            _loadProjects();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('New Project'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Widget _buildFilteredProjects() {
    // Filter projects based on search query
    final filteredProjects = _projects.where((project) {
      if (_searchQuery.isEmpty) return true;
      
      final query = _searchQuery.toLowerCase();
      final name = project.name.toLowerCase();
      final tableName = project.tableName.toLowerCase();
      final eventCode = (project.eventCode ?? '').toLowerCase();
      final status = project.status.toLowerCase();
      
      return name.contains(query) ||
          tableName.contains(query) ||
          eventCode.contains(query) ||
          status.contains(query);
    }).toList();

    if (filteredProjects.isEmpty) {
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
              'No projects found for "${_searchQuery}"',
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
      onRefresh: _loadProjects,
      child: ListView.builder(
        // Extra bottom padding so last project card is not hidden behind the New Project button
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        itemCount: filteredProjects.length,
        itemBuilder: (context, index) {
          final project = filteredProjects[index];
          return Card(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (project.status == 'published' ? Colors.green : Colors.orange).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  project.status == 'published'
                      ? Icons.public
                      : Icons.edit_note,
                  color: project.status == 'published' ? Colors.green : Colors.orange,
                  size: 24,
                ),
              ),
              title: Text(
                project.name,
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Table: ${project.tableName}',
                      style: const TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 15,
                        letterSpacing: -0.24,
                      ),
                    ),
                    if (project.eventCode != null && project.eventCode!.isNotEmpty)
                      Text(
                        'Event Code: ${project.eventCode}',
                        style: const TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 15,
                          letterSpacing: -0.24,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Chip(
                          label: Text(
                            project.status.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          backgroundColor: project.status == 'published'
                              ? Colors.green
                              : Colors.red,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              trailing: PopupMenuButton(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'toggle',
                    child: Row(
                      children: [
                        Icon(
                          project.status == 'published'
                              ? Icons.unpublished
                              : Icons.publish,
                          size: 20,
                          color: project.status == 'published'
                              ? Colors.orange
                              : Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          project.status == 'published'
                              ? 'Set Draft'
                              : 'Publish',
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'toggle') {
                    _togglePublish(project);
                  } else if (value == 'edit') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateProjectScreen(project: project),
                      ),
                    ).then((_) => _loadProjects());
                  } else if (value == 'delete') {
                    _deleteProject(project);
                  }
                },
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FormBuilderScreen(project: project),
                  ),
                ).then((_) => _loadProjects());
              },
            ),
          );
        },
      ),
    );
  }
}

