import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/admin_auth_service.dart';
import '../services/supabase_service.dart';
import '../services/cms_service.dart';
import '../services/fcm_service.dart';
import '../models/admin.dart';
import '../models/user.dart' as models;
import '../models/event.dart';
import '../models/project.dart';
import 'cms/dashboard.dart' as cms;
import 'admin_login_page.dart';
import 'event_detail.dart';
import '../widgets/shimmer_loading.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final AdminAuthService _adminAuth = AdminAuthService();
  final SupabaseService _supabaseService = SupabaseService();
  final CmsService _cmsService = CmsService();
  Admin? _currentAdmin;
  List<models.User> _users = [];
  List<Event> _events = [];
  List<Project> _projects = [];
  bool _isLoading = true;
  int _selectedIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final TextEditingController _eventsSearchController = TextEditingController();
  String _eventsSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _eventsSearchController.dispose();
    super.dispose();
  }

  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Admin Dashboard';
      case 1:
        return 'Users';
      case 2:
        return 'Events';
      case 3:
        return 'Form Builder';
      default:
        return 'Admin';
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final admin = await _adminAuth.getCurrentAdmin();
      setState(() {
        _currentAdmin = admin;
        _isLoading = false;
      });
      // Load initial data for tabs
      _loadUsers();
      _loadEvents();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUsers() async {
    if (!mounted) return;
    
    try {
      // Get all users from database
      final response = await _supabaseService.client
          .from('users')
          .select()
          .order('created_at', ascending: false);
      
      if (mounted) {
        setState(() {
          _users = (response as List)
              .map((json) => models.User.fromJson(json as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Failed to load users. Please try again.')),
        );
      }
    }
  }

  Future<void> _loadEvents() async {
    if (!mounted) return;
    
    try {
      final events = await _supabaseService.getEvents();
      if (mounted) {
        setState(() {
          _events = events;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Failed to load events. Please try again.')),
        );
      }
    }
  }

  Future<void> _logout() async {
    await _adminAuth.logout();
    if (!mounted) return;

    // Kembali ke halaman login admin, bersihkan semua route sebelumnya
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const AdminLoginPage(),
      ),
      (route) => false,
    );
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // iOS-style Welcome Message
          Text(
            'Welcome, ${_currentAdmin?.displayName ?? 'Admin'}!',
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.37,
              height: 1.12,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 32),
          
          // iOS-style Stats cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Users',
                  _users.length.toString(),
                  Icons.people,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Total Events',
                  _events.length.toString(),
                  Icons.event,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // iOS-style Quick actions
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.35,
              height: 1.27,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'Manage Users',
                  Icons.people_outline,
                  Colors.orange,
                  () {
                    setState(() {
                      _selectedIndex = 1;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  'Manage Events',
                  Icons.event_note,
                  Colors.orange,
                  () {
                    setState(() {
                      _selectedIndex = 2;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  'Form Builder',
                  Icons.dynamic_form,
                  Colors.orange,
                  () {
                    setState(() {
                      _selectedIndex = 3;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFF1C1C1E),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.37,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                letterSpacing: -0.24,
                height: 1.33,
                color: Color(0xFF8E8E93),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 110,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 8),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.08,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUsersTab() {
    // Filter users based on search query
    final filteredUsers = _users.where((user) {
      if (_searchQuery.isEmpty) return true;
      
      final query = _searchQuery.toLowerCase();
      final fullName = user.fullName.toLowerCase();
      final username = (user.username ?? '').toLowerCase();
      final email = (user.emailUsers ?? '').toLowerCase();
      final firstName = (user.firstname ?? '').toLowerCase();
      final lastName = (user.lastname ?? '').toLowerCase();
      
      return fullName.contains(query) ||
          username.contains(query) ||
          email.contains(query) ||
          firstName.contains(query) ||
          lastName.contains(query);
    }).toList();

    return Column(
      children: [
        // iOS-style Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari user...',
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
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _users.isEmpty ? null : _showSendNotificationToAllDialog,
                icon: const Icon(Icons.send, size: 18),
                label: const Text('Kirim ke Semua'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
        // User list
        Expanded(
          child: filteredUsers.isEmpty
              ? Center(
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
                            ? 'No users found'
                            : 'No users found for "${_searchQuery}"',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  // Extra bottom padding so last event card is not hidden behind the Create Event button
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange.shade900,
                          backgroundImage: user.profilePicture != null
                              ? NetworkImage(user.profilePicture!)
                              : null,
                          child: user.profilePicture == null
                              ? Text(
                                  user.firstname?.substring(0, 1).toUpperCase() ?? 'U',
                                  style: const TextStyle(color: Colors.white),
                                )
                              : null,
                        ),
                        title: Text(
                          user.fullName,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          '@${user.username ?? 'N/A'}',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Chip(
                              label: Text(
                                user.role ?? 'user',
                                style: const TextStyle(color: Colors.white),
                              ),
                              backgroundColor: user.role == 'admin'
                                  ? Colors.orange.shade100
                                  : Colors.orange.shade300,
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, color: Colors.white),
                              onSelected: (value) {
                                if (value == 'send_notification') {
                                  _showSendNotificationDialog(user);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'send_notification',
                                  child: Row(
                                    children: [
                                      Icon(Icons.message, color: Colors.orange),
                                      SizedBox(width: 8),
                                      Text('Kirim Pemberitahuan'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEventsTab() {
    // Filter events based on search query
    final filteredEvents = _events.where((event) {
      if (_eventsSearchQuery.isEmpty) return true;
      
      final query = _eventsSearchQuery.toLowerCase();
      final title = event.title.toLowerCase();
      final eventCode = (event.eventCode ?? '').toLowerCase();
      final description = (event.description ?? '').toLowerCase();
      
      return title.contains(query) ||
          eventCode.contains(query) ||
          description.contains(query);
    }).toList();

    return Column(
      children: [
        // iOS-style Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: TextField(
            controller: _eventsSearchController,
            decoration: InputDecoration(
              hintText: 'Cari event...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF8E8E93)),
              suffixIcon: _eventsSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Color(0xFF8E8E93)),
                      onPressed: () {
                        _eventsSearchController.clear();
                        setState(() {
                          _eventsSearchQuery = '';
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
                _eventsSearchQuery = value;
              });
            },
          ),
        ),
        // Events list
        Expanded(
          child: filteredEvents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _eventsSearchQuery.isEmpty
                            ? Icons.event_busy
                            : Icons.search_off,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _eventsSearchQuery.isEmpty
                            ? 'No events found'
                            : 'No events found for "${_eventsSearchQuery}"',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      if (_eventsSearchQuery.isEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Tap + button to create new event',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  itemCount: filteredEvents.length,
                  itemBuilder: (context, index) {
                    final event = filteredEvents[index];
                    return Card(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (event.isActive ? Colors.green : Colors.grey).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.event,
                            color: event.isActive ? Colors.green : Colors.grey,
                            size: 24,
                          ),
                        ),
                        title: Text(
                          event.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.41,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${event.totalRegistered}/${event.quota} registered',
                            style: const TextStyle(
                              color: Color(0xFF8E8E93),
                              fontSize: 15,
                              letterSpacing: -0.24,
                            ),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            event.isActive
                                ? const Chip(
                                    label: Text(
                                      'Active',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    backgroundColor: Colors.green,
                                  )
                                : const Chip(
                                    label: Text(
                                      'Inactive',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, color: Colors.white),
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _showEditEventDialog(event);
                                } else if (value == 'toggle') {
                                  _toggleEventStatus(event);
                                } else if (value == 'delete') {
                                  _deleteEvent(event);
                                }
                              },
                              itemBuilder: (BuildContext context) => [
                                PopupMenuItem<String>(
                                  value: 'edit',
                                  child: const Row(
                                    children: [
                                      Icon(Icons.edit, color: Colors.orange),
                                      SizedBox(width: 8),
                                      Text('Edit Event'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem<String>(
                                  value: 'toggle',
                                  child: Row(
                                    children: [
                                      Icon(
                                        event.isActive ? Icons.visibility_off : Icons.visibility,
                                        color: event.isActive ? Colors.orange : Colors.green,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(event.isActive ? 'Deactivate' : 'Activate'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem<String>(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Delete Event'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => EventDetailPage(event: event),
                            ),
                          ).then((_) {
                            // Refresh events after returning from detail page
                            _loadEvents();
                          });
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _showCreateEventDialog() async {
    if (!mounted) return;
    
    // Load projects untuk dropdown event code
    List<Project> projects = [];
    try {
      projects = await _cmsService.getProjects();
      // Filter hanya yang punya event_code
      projects = projects.where((p) => p.eventCode != null && p.eventCode!.isNotEmpty).toList();
    } catch (e) {
      print('Error loading projects: $e');
    }
    
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final quotaController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? selectedEventCode;
    DateTime? selectedStartDate;
    bool isActive = false;
    PlatformFile? selectedImageFile;
    Uint8List? selectedImageBytes;

    String? title;
    String? description;
    int? quota;

    try {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create New Event'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Event Title *',
                      hintText: 'e.g., Malang Marathon 2024',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter event title';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Event description (optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: quotaController,
                    decoration: const InputDecoration(
                      labelText: 'Quota *',
                      hintText: 'e.g., 100',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter quota';
                      }
                      final quotaValue = int.tryParse(value);
                      if (quotaValue == null || quotaValue <= 0) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedEventCode,
                    decoration: const InputDecoration(
                      labelText: 'Event Code',
                      hintText: 'Pilih form pendaftaran (opsional)',
                      border: OutlineInputBorder(),
                      helperText: 'Connect with registration form',
                      helperMaxLines: 2,
                    ),
                    selectedItemBuilder: (BuildContext context) {
                      return [
                        const Text(
                          'None',
                          style: TextStyle(
                            fontSize: 17,
                            letterSpacing: -0.41,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        ...projects.map((project) {
                          return Text(
                            project.eventCode!,
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
                          'None',
                          style: const TextStyle(
                            fontSize: 17,
                            letterSpacing: -0.41,
                          ),
                        ),
                      ),
                      ...projects.map((project) {
                        return DropdownMenuItem<String>(
                          value: project.eventCode,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                project.eventCode!,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              Text(
                                project.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        selectedEventCode = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: selectedStartDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                      );
                      if (pickedDate != null) {
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: selectedStartDate != null
                              ? TimeOfDay.fromDateTime(selectedStartDate!)
                              : TimeOfDay.now(),
                        );
                        if (pickedTime != null) {
                          setDialogState(() {
                            selectedStartDate = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );
                          });
                        }
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Tanggal Mulai Event',
                        hintText: 'Pilih tanggal dan waktu',
                        border: const OutlineInputBorder(),
                        suffixIcon: const Icon(Icons.calendar_today),
                        helperText: 'Tanggal dan waktu mulai event',
                      ),
                      child: Text(
                        selectedStartDate != null
                            ? '${selectedStartDate!.day}/${selectedStartDate!.month}/${selectedStartDate!.year} ${selectedStartDate!.hour}:${selectedStartDate!.minute.toString().padLeft(2, '0')}'
                            : 'Pilih tanggal dan waktu',
                        style: TextStyle(
                          color: selectedStartDate != null
                              ? Colors.black87
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Image Upload Section
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Gambar Event',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (selectedImageFile != null)
                        Container(
                          height: 150,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              selectedImageBytes!,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                            ),
                          ),
                        )
                      else
                        Container(
                          height: 150,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey.shade100,
                          ),
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.image, size: 48, color: Colors.grey),
                                SizedBox(height: 8),
                                Text(
                                  'Belum ada gambar',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                try {
                                  final result = await FilePicker.platform.pickFiles(
                                    type: FileType.image,
                                    allowMultiple: false,
                                  );
                                  if (result != null && result.files.isNotEmpty) {
                                    final file = result.files.single;
                                    Uint8List? bytes = file.bytes;
                                    
                                    // Jika bytes null (terjadi di Android untuk file besar), baca dari path
                                    if (bytes == null && file.path != null && !kIsWeb) {
                                      try {
                                        final fileData = await File(file.path!).readAsBytes();
                                        bytes = fileData;
                                      } catch (e) {
                                        print('Error reading file from path: $e');
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: const Text('Failed to read file. Please try again.'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                        return;
                                      }
                                    }
                                    
                                    if (bytes != null) {
                                      setDialogState(() {
                                        selectedImageFile = file;
                                        selectedImageBytes = bytes;
                                      });
                                    } else {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Unable to read image file'),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );
                                      }
                                    }
                                  }
                                } catch (e) {
                                  print('Error picking file: $e');
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('An error occurred. Please try again.'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.upload),
                              label: const Text('Pilih Gambar'),
                            ),
                          ),
                          if (selectedImageFile != null) ...[
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () {
                                setDialogState(() {
                                  selectedImageFile = null;
                                  selectedImageBytes = null;
                                });
                              },
                              icon: const Icon(Icons.delete),
                              label: const Text('Hapus'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: isActive,
                        onChanged: (value) {
                          setDialogState(() {
                            isActive = value ?? true;
                          });
                        },
                      ),
                      const Expanded(
                        child: Text(
                          'Aktifkan Event',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  // Save values before closing dialog
                  title = titleController.text.trim();
                  description = descriptionController.text.trim().isEmpty
                      ? null
                      : descriptionController.text.trim();
                  quota = int.tryParse(quotaController.text.trim());
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
      );

      // If user clicked Create, proceed with creating event
      if (result == true && mounted && title != null && quota != null) {
        // Small delay to ensure dialog is fully closed before async operation
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) {
          await _createEvent(
            title: title!,
            description: description,
            quota: quota!,
            eventCode: selectedEventCode,
            startDate: selectedStartDate,
            isActive: isActive,
            imageBytes: selectedImageBytes,
            imageFileName: selectedImageFile?.name,
          );
        }
      }
    } finally {
      // Jangan dispose TextEditingController di sini.
      // Dialog dan controller akan dibersihkan otomatis ketika function selesai.
      // Dispose manual di sini sempat memicu error "TextEditingController was used after being disposed"
      // saat dialog ditutup dengan tombol Cancel / tombol Back.
    }
  }

  Future<void> _toggleEventStatus(Event event) async {
    if (!mounted) return;

    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Text('Updating event status...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      await _supabaseService.updateEvent(
        eventId: event.id,
        isActive: !event.isActive,
      );

      // Small delay to ensure database write is complete
      await Future.delayed(const Duration(milliseconds: 300));

      // Refresh events list
      if (mounted) {
        await _loadEvents();
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              event.isActive
                  ? 'Event deactivated successfully!'
                  : 'Event activated successfully!',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to update event status. Please try again.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _showEditEventDialog(Event event) async {
    if (!mounted) return;
    
    // Load projects untuk dropdown event code
    List<Project> projects = [];
    try {
      projects = await _cmsService.getProjects();
      // Filter hanya yang punya event_code
      projects = projects.where((p) => p.eventCode != null && p.eventCode!.isNotEmpty).toList();
    } catch (e) {
      print('Error loading projects: $e');
    }
    
    final titleController = TextEditingController(text: event.title);
    final descriptionController = TextEditingController(text: event.description ?? '');
    final quotaController = TextEditingController(text: event.quota.toString());
    final formKey = GlobalKey<FormState>();
    // Check if event.eventCode exists in projects list, if not set to null
    String? selectedEventCode = event.eventCode;
    if (selectedEventCode != null && selectedEventCode.isNotEmpty) {
      final projectExists = projects.any((p) => p.eventCode == selectedEventCode);
      if (!projectExists) {
        selectedEventCode = null;
        print('Event code ${event.eventCode} not found in projects, setting to null');
      }
    }
    DateTime? selectedStartDate = event.startDate;
    bool isActive = event.isActive;
    PlatformFile? selectedImageFile;
    Uint8List? selectedImageBytes;
    String? currentImageUrl = event.imageUrl; // Store current image URL

    String? title;
    String? description;
    int? quota;

    try {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Event'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Event Title *',
                      hintText: 'e.g., Malang Marathon 2024',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter event title';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Event description (optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: quotaController,
                    decoration: const InputDecoration(
                      labelText: 'Quota *',
                      hintText: 'e.g., 100',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter quota';
                      }
                      final quotaValue = int.tryParse(value);
                      if (quotaValue == null || quotaValue <= 0) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedEventCode,
                    decoration: const InputDecoration(
                      labelText: 'Event Code',
                      hintText: 'Pilih form pendaftaran (opsional)',
                      border: OutlineInputBorder(),
                      helperText: 'Connect with registration form',
                      helperMaxLines: 2,
                    ),
                    selectedItemBuilder: (BuildContext context) {
                      return [
                        const Text(
                          'None',
                          style: TextStyle(
                            fontSize: 17,
                            letterSpacing: -0.41,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        ...projects.map((project) {
                          return Text(
                            project.eventCode!,
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
                          'None',
                          style: const TextStyle(
                            fontSize: 17,
                            letterSpacing: -0.41,
                          ),
                        ),
                      ),
                      ...projects.map((project) {
                        return DropdownMenuItem<String>(
                          value: project.eventCode,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                project.eventCode!,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              Text(
                                project.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        selectedEventCode = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final pickedDate = await showDatePicker(
                              context: context,
                              initialDate: selectedStartDate ?? DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                            );
                            if (pickedDate != null) {
                              final pickedTime = await showTimePicker(
                                context: context,
                                initialTime: selectedStartDate != null
                                    ? TimeOfDay.fromDateTime(selectedStartDate!)
                                    : TimeOfDay.now(),
                              );
                              if (pickedTime != null) {
                                setDialogState(() {
                                  selectedStartDate = DateTime(
                                    pickedDate.year,
                                    pickedDate.month,
                                    pickedDate.day,
                                    pickedTime.hour,
                                    pickedTime.minute,
                                  );
                                });
                              }
                            }
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Tanggal Mulai Event',
                              hintText: 'Pilih tanggal dan waktu',
                              border: const OutlineInputBorder(),
                              suffixIcon: const Icon(Icons.calendar_today),
                              helperText: 'Tanggal dan waktu mulai event',
                            ),
                            child: Text(
                              selectedStartDate != null
                                  ? '${selectedStartDate!.day}/${selectedStartDate!.month}/${selectedStartDate!.year} ${selectedStartDate!.hour}:${selectedStartDate!.minute.toString().padLeft(2, '0')}'
                                  : 'Pilih tanggal dan waktu',
                              style: TextStyle(
                                color: selectedStartDate != null
                                    ? Colors.black87
                                    : Colors.grey.shade600,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ),
                      if (selectedStartDate != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.clear, color: Colors.red),
                          onPressed: () {
                            setDialogState(() {
                              selectedStartDate = null;
                            });
                          },
                          tooltip: 'Hapus tanggal',
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Image Upload Section
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Gambar Event',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Show current image or new selected image
                      if (selectedImageFile != null)
                        Container(
                          height: 150,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              selectedImageBytes!,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                            ),
                          ),
                        )
                      else if (currentImageUrl != null && currentImageUrl!.isNotEmpty)
                        Container(
                          height: 150,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              currentImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 150,
                                  color: Colors.grey.shade200,
                                  child: const Center(
                                    child: Icon(Icons.broken_image, color: Colors.grey),
                                  ),
                                );
                              },
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  height: 150,
                                  color: Colors.grey.shade200,
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              },
                            ),
                          ),
                        )
                      else
                        Container(
                          height: 150,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey.shade100,
                          ),
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.image, size: 48, color: Colors.grey),
                                SizedBox(height: 8),
                                Text(
                                  'Belum ada gambar',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child:                             OutlinedButton.icon(
                              onPressed: () async {
                                try {
                                  final result = await FilePicker.platform.pickFiles(
                                    type: FileType.image,
                                    allowMultiple: false,
                                  );
                                  if (result != null && result.files.isNotEmpty) {
                                    final file = result.files.single;
                                    Uint8List? bytes = file.bytes;
                                    
                                    // Jika bytes null (terjadi di Android untuk file besar), baca dari path
                                    if (bytes == null && file.path != null && !kIsWeb) {
                                      try {
                                        final fileData = await File(file.path!).readAsBytes();
                                        bytes = fileData;
                                      } catch (e) {
                                        print('Error reading file from path: $e');
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: const Text('Failed to read file. Please try again.'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                        return;
                                      }
                                    }
                                    
                                    if (bytes != null) {
                                      setDialogState(() {
                                        selectedImageFile = file;
                                        selectedImageBytes = bytes;
                                        currentImageUrl = null; // Clear current URL when new image selected
                                      });
                                    } else {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Unable to read image file'),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );
                                      }
                                    }
                                  }
                                } catch (e) {
                                  print('Error picking file: $e');
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('An error occurred. Please try again.'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.upload),
                              label: const Text('Pilih Gambar Baru'),
                            ),
                          ),
                          if (selectedImageFile != null || (currentImageUrl != null && currentImageUrl!.isNotEmpty)) ...[
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () {
                                setDialogState(() {
                                  selectedImageFile = null;
                                  selectedImageBytes = null;
                                  currentImageUrl = null; // Clear image URL
                                });
                              },
                              icon: const Icon(Icons.delete),
                              label: const Text('Hapus'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: isActive,
                        onChanged: (value) {
                          setDialogState(() {
                            isActive = value ?? true;
                          });
                        },
                      ),
                      const Expanded(
                        child: Text(
                          'Aktifkan Event',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  // Save values before closing dialog
                  title = titleController.text.trim();
                  description = descriptionController.text.trim().isEmpty
                      ? null
                      : descriptionController.text.trim();
                  quota = int.tryParse(quotaController.text.trim());
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
      );

      // If user clicked Update, proceed with updating event
      if (result == true && mounted && title != null && quota != null) {
        // Small delay to ensure dialog is fully closed before async operation
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) {
          // Check if startDate was cleared (had value before, now null)
          final wasStartDateCleared = event.startDate != null && selectedStartDate == null;
          
          await _updateEvent(
            eventId: event.id,
            title: title!,
            description: description,
            quota: quota!,
            eventCode: selectedEventCode,
            startDate: selectedStartDate,
            isActive: isActive,
            clearStartDate: wasStartDateCleared,
            imageBytes: selectedImageBytes,
            imageFileName: selectedImageFile?.name,
            clearImage: currentImageUrl == null && selectedImageFile == null && event.imageUrl != null,
          );
        }
      }
    } finally {
      // Jangan dispose TextEditingController di sini.
      // Dialog dan controller akan dibersihkan otomatis ketika function selesai.
      // Dispose manual di sini sempat memicu error "TextEditingController was used after being disposed"
      // saat dialog ditutup dengan tombol Cancel / tombol Back.
    }
  }

  Future<void> _updateEvent({
    required String eventId,
    required String title,
    String? description,
    required int quota,
    String? eventCode,
    DateTime? startDate,
    bool isActive = true,
    bool clearStartDate = false,
    Uint8List? imageBytes,
    String? imageFileName,
    bool clearImage = false,
  }) async {
    if (!mounted) return;
    
    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Text('Updating event...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      // Upload new image if provided
      String? imageUrl;
      if (imageBytes != null && imageFileName != null) {
        try {
          print('=== UPLOADING NEW EVENT IMAGE ===');
          print('File name: $imageFileName');
          print('File size: ${imageBytes.length} bytes');
          imageUrl = await _supabaseService.uploadEventImage(
            imageBytes: imageBytes,
            fileName: imageFileName,
          );
          print('Image uploaded successfully!');
          print('Image URL: $imageUrl');
          print('==================================');
        } catch (e) {
          print('=== ERROR UPLOADING IMAGE ===');
          print('Error: $e');
          print('============================');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Failed to upload image. Please try again.'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
              ),
            );
          }
          // Continue updating event without new image
        }
      } else if (clearImage) {
        // Clear image URL if user deleted the image
        imageUrl = null;
      }

      await _supabaseService.updateEvent(
        eventId: eventId,
        title: title,
        description: description,
        quota: quota,
        eventCode: eventCode,
        startDate: startDate,
        isActive: isActive,
        clearStartDate: clearStartDate,
        imageUrl: imageUrl,
        clearImage: clearImage,
        // Jika eventCode null (dipilih "Tidak ada (kosongkan)"), kosongkan kolom di DB
        clearEventCode: eventCode == null,
      );

      // Small delay to ensure database write is complete
      await Future.delayed(const Duration(milliseconds: 300));

      // Refresh events list
      if (mounted) {
        await _loadEvents();
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event updated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to update event. Please try again.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _deleteEvent(Event event) async {
    if (!mounted) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text(
          'Are you sure you want to delete "${event.title}"?\n\n'
          'This will also delete all registrations for this event. '
          'This action cannot be undone.',
        ),
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

    if (confirmed != true) return;

    if (!mounted) return;

    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Text('Deleting event...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      await _supabaseService.deleteEvent(event.id);

      // Small delay to ensure database write is complete
      await Future.delayed(const Duration(milliseconds: 300));

      // Refresh events list
      if (mounted) {
        await _loadEvents();
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event deleted successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to delete event. Please try again.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _createEvent({
    required String title,
    String? description,
    required int quota,
    String? eventCode,
    DateTime? startDate,
    bool isActive = true,
    Uint8List? imageBytes,
    String? imageFileName,
  }) async {
    if (!mounted) return;
    
    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Text('Creating event...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      // Upload image first if provided
      String? imageUrl;
      print('=== CHECKING IMAGE UPLOAD ===');
      print('imageBytes is null: ${imageBytes == null}');
      print('imageFileName is null: ${imageFileName == null}');
      if (imageBytes != null) {
        print('imageBytes length: ${imageBytes.length}');
      }
      print('imageFileName: $imageFileName');
      
      if (imageBytes != null && imageFileName != null) {
        try {
          print('=== UPLOADING EVENT IMAGE ===');
          print('File name: $imageFileName');
          print('File size: ${imageBytes.length} bytes');
          
          // Show uploading message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 16),
                    Text('Uploading image...'),
                  ],
                ),
                duration: Duration(seconds: 5),
              ),
            );
          }
          
          imageUrl = await _supabaseService.uploadEventImage(
            imageBytes: imageBytes,
            fileName: imageFileName,
          );
          
          print('=== IMAGE UPLOAD SUCCESS ===');
          print('Image URL received: $imageUrl');
          print('Image URL is null: ${imageUrl == null}');
          print('Image URL is empty: ${imageUrl?.isEmpty ?? true}');
          if (imageUrl != null) {
            print('Image URL length: ${imageUrl.length}');
            print('Image URL preview: ${imageUrl.substring(0, imageUrl.length > 100 ? 100 : imageUrl.length)}...');
          }
          print('============================');
          
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Image uploaded! URL: ${imageUrl?.substring(0, imageUrl!.length > 50 ? 50 : imageUrl.length)}...'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } catch (e, stackTrace) {
          print('=== ERROR UPLOADING IMAGE ===');
          print('Error type: ${e.runtimeType}');
          print('Error: $e');
          print('Stack trace: $stackTrace');
          print('============================');
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Error uploading image:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      e.toString(),
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Pastikan storage bucket "event-images" sudah dibuat di Supabase!',
                      style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
          // Continue creating event without image
          imageUrl = null; // Explicitly set to null on error
        }
      } else {
        print('=== NO IMAGE TO UPLOAD ===');
        print('Skipping image upload');
        print('========================');
      }

      print('=== BEFORE CREATE EVENT ===');
      print('Title: $title');
      print('Image URL to save: $imageUrl');
      print('Image URL is null: ${imageUrl == null}');
      print('===========================');

      await _supabaseService.createEvent(
        title: title,
        description: description,
        quota: quota,
        createdBy: null, // Admin tidak ada di tabel users, jadi null
        eventCode: eventCode,
        startDate: startDate,
        isActive: isActive,
        imageUrl: imageUrl,
      );
      
      print('=== AFTER CREATE EVENT ===');
      print('Event created');
      print('==========================');

      // Small delay to ensure database write is complete
      await Future.delayed(const Duration(milliseconds: 300));

      // Refresh events list
      if (mounted) {
        await _loadEvents();
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event created successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to create event. Please try again.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _showSendNotificationToAllDialog() async {
    if (!mounted) return;

    final titleController = TextEditingController();
    final messageController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          title: const Text(
            'Kirim Pemberitahuan ke Semua User',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pesan akan dikirim ke ${_users.length} user',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Judul',
                    labelStyle: const TextStyle(color: Colors.grey),
                    hintText: 'Masukkan judul pemberitahuan',
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF2C2C2E),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade700),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.orange, width: 2),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                  maxLines: 1,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: messageController,
                  decoration: InputDecoration(
                    labelText: 'Pesan',
                    labelStyle: const TextStyle(color: Colors.grey),
                    hintText: 'Masukkan pesan pemberitahuan',
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF2C2C2E),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade700),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.orange, width: 2),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                  maxLines: 5,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Title cannot be empty'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                if (messageController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Message cannot be empty'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Save values before closing
                final title = titleController.text.trim();
                final message = messageController.text.trim();
                
                // Return values and close dialog
                Navigator.of(dialogContext).pop({
                  'title': title,
                  'message': message,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Kirim ke Semua'),
            ),
          ],
        ),
      ),
    );

    // Handle result outside dialog
    if (result != null && mounted) {
      final title = result['title']!;
      final message = result['message']!;
      
      // Small delay to ensure dialog is fully closed
      await Future.delayed(const Duration(milliseconds: 100));
      
      if (!mounted) return;
      
      // Show progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (progressContext) => PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: const Color(0xFF1C1C1E),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                ),
                const SizedBox(height: 16),
                Text(
                  'Mengirim pemberitahuan ke ${_users.length} user...',
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
      
      try {
        // Get current admin
        final admin = await _adminAuth.getCurrentAdmin();
        
        // Debug: Check users count
        print('Total users to send notification: ${_users.length}');
        print('Admin ID: ${admin?.id}');
        
        // Send notification to all users
        int successCount = 0;
        int failCount = 0;
        
        if (_users.isEmpty) {
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No users available to send notifications'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
        
        // First, insert all notifications to database
        final userIds = <String>[];
        for (final user in _users) {
          if (!mounted) break;
          try {
            final insertData = {
              'user_id': user.id,
              'title': title,
              'message': message,
              'is_read': false,
              'created_by': admin?.id,
            };
            
            print('Inserting notification to database for user ${user.id} (${user.fullName})');
            
            // Use RPC function to bypass RLS (for admin without auth.uid())
            try {
              await _supabaseService.client.rpc('insert_notification', params: {
                'p_user_id': user.id,
                'p_title': title,
                'p_message': message,
                'p_created_by': admin?.id,
              });
              userIds.add(user.id);
              successCount++;
              print('Success inserting notification for user ${user.id}');
            } catch (rpcError) {
              // Fallback to direct insert if function doesn't exist
              print('RPC function failed, trying direct insert: $rpcError');
              await _supabaseService.client
                  .from('notifications')
                  .insert(insertData);
              userIds.add(user.id);
              successCount++;
              print('Success inserting notification for user ${user.id} (direct insert)');
            }
          } catch (e) {
            failCount++;
            print('Error inserting notification for user ${user.id} (${user.fullName}): $e');
            debugPrint('Error details: ${e.toString()}');
          }
        }
        
        // Then, send FCM push notifications to all users at once (more efficient)
        if (userIds.isNotEmpty) {
          try {
            print('Sending FCM push notifications to ${userIds.length} users...');
            final fcmResult = await FcmService().sendNotificationToAll(
              title: title,
              message: message,
              userIds: userIds,
            );
            
            if (fcmResult['success'] == true) {
              final data = fcmResult['data'] as Map<String, dynamic>?;
              if (data != null) {
                final fcmSent = data['sent'] as int? ?? 0;
                final fcmFailed = data['failed'] as int? ?? 0;
                print('FCM notifications sent: $fcmSent success, $fcmFailed failed');
              }
            } else {
              print('FCM notification error: ${fcmResult['error']}');
            }
          } catch (e) {
            print('Error sending FCM notifications: $e');
            // Continue even if FCM fails - notifications are already in database
          }
        }

        // Close progress dialog
        if (mounted) {
          Navigator.pop(context);
          
          // Show result
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Berhasil mengirim ke $successCount user${failCount > 0 ? '\nGagal: $failCount user' : ''}',
              ),
              backgroundColor: failCount == 0 ? Colors.green : Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        print('Error in _showSendNotificationToAllDialog: $e');
        debugPrint('Error details: ${e.toString()}');
        // Close progress dialog if still open
        if (mounted) {
          try {
            Navigator.pop(context);
          } catch (e2) {
            // Dialog might already be closed
          }
          
          // Show error with details
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send notification: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
    
    // Dispose controllers after dialog is fully closed
    // Use Future.delayed to ensure disposal happens after dialog animation completes
    Future.delayed(const Duration(milliseconds: 300), () {
      try {
        titleController.dispose();
      } catch (e) {
        // Controller already disposed
      }
      try {
        messageController.dispose();
      } catch (e) {
        // Controller already disposed
      }
    });
  }

  Future<void> _showSendNotificationDialog(models.User user) async {
    if (!mounted) return;

    final titleController = TextEditingController();
    final messageController = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          title: const Text(
            'Kirim Pemberitahuan',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Untuk: ${user.fullName}',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Judul',
                    labelStyle: const TextStyle(color: Colors.grey),
                    hintText: 'Masukkan judul pemberitahuan',
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF2C2C2E),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade700),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.orange, width: 2),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                  maxLines: 1,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: messageController,
                  decoration: InputDecoration(
                    labelText: 'Pesan',
                    labelStyle: const TextStyle(color: Colors.grey),
                    hintText: 'Masukkan pesan pemberitahuan',
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF2C2C2E),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade700),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.orange, width: 2),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                  maxLines: 5,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Title cannot be empty'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                if (messageController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Message cannot be empty'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                try {
                  // Get current admin
                  final admin = await _adminAuth.getCurrentAdmin();
                  
                  final title = titleController.text.trim();
                  final message = messageController.text.trim();
                  
                  // Insert notification to database using RPC function (bypasses RLS)
                  String? notificationId;
                  try {
                    // Try using RPC function first (more secure, bypasses RLS)
                    final result = await _supabaseService.client.rpc('insert_notification', params: {
                      'p_user_id': user.id,
                      'p_title': title,
                      'p_message': message,
                      'p_created_by': admin?.id,
                    });
                    notificationId = result as String?;
                    print('Notification inserted via RPC function: $notificationId');
                  } catch (rpcError) {
                    // Fallback to direct insert if function doesn't exist
                    print('RPC function failed, trying direct insert: $rpcError');
                    final notificationResponse = await _supabaseService.client
                        .from('notifications')
                        .insert({
                          'user_id': user.id,
                          'title': title,
                          'message': message,
                          'is_read': false,
                          'created_by': admin?.id,
                        })
                        .select()
                        .single();
                    notificationId = notificationResponse['id'] as String?;
                    print('Notification inserted via direct insert: $notificationId');
                  }
                  
                  // Send FCM push notification
                  try {
                    await FcmService().sendNotificationToUser(
                      userId: user.id,
                      title: title,
                      message: message,
                      notificationId: notificationId,
                    );
                    print('FCM notification sent to user ${user.id}');
                  } catch (e) {
                    print('Error sending FCM to user ${user.id}: $e');
                    // Continue even if FCM fails - notification is already in database
                  }

                  if (mounted) {
                    Navigator.of(dialogContext).pop();
                    // Small delay to ensure dialog is fully closed
                    await Future.delayed(const Duration(milliseconds: 100));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Notification sent successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  print('Error sending notification to user ${user.id}: $e');
                  debugPrint('Error details: ${e.toString()}');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to send notification: ${e.toString()}'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Kirim'),
            ),
          ],
        ),
      ),
    );
    
    // Dispose controllers after dialog is fully closed
    // Use Future.delayed to ensure disposal happens after dialog animation completes
    Future.delayed(const Duration(milliseconds: 300), () {
      try {
        titleController.dispose();
      } catch (e) {
        // Controller already disposed
      }
      try {
        messageController.dispose();
      } catch (e) {
        // Controller already disposed
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: ShimmerList(itemHeight: 90),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _getAppBarTitle(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: [
              _buildDashboard(),
              _buildUsersTab(),
              _buildEventsTab(),
              const cms.CmsDashboard(),
            ],
          ),
          // Floating Action Button hanya muncul di tab Events
          if (_selectedIndex == 2)
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton.extended(
                onPressed: _showCreateEventDialog,
                icon: const Icon(Icons.add),
                label: const Text('Create Event'),
                backgroundColor: Colors.orange,
              ),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
          // Load data when switching tabs
          if (index == 1) {
            _loadUsers();
          } else if (index == 2) {
            _loadEvents();
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outlined),
            selectedIcon: Icon(Icons.people),
            label: 'Users',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event),
            label: 'Events',
          ),
          NavigationDestination(
            icon: Icon(Icons.dynamic_form_outlined),
            selectedIcon: Icon(Icons.dynamic_form),
            label: 'Forms',
          ),
        ],
      ),
    );
  }
}

