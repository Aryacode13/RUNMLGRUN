import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/strava_auth_service.dart';
import '../services/notification_service.dart';
import '../models/activity.dart';
import '../models/user.dart';
import '../models/event.dart';
import '../widgets/activity_card.dart';
import '../widgets/event_card.dart';
import '../widgets/shimmer_loading.dart';
import 'events_page.dart';
import 'profile_page.dart';
import 'event_detail.dart';
import 'my_events_page.dart';
import 'activities_page.dart';
import 'notifications_page.dart';
import 'settings_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final SupabaseService _supabaseService = SupabaseService();
  final StravaAuthService _stravaAuth = StravaAuthService();
  User? _currentUser;
  List<Activity> _activities = [];
  List<Event> _activeEvents = [];
  List<Registration> _userRegistrations = [];
  int _unreadNotificationsCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    // Stop listening to notifications when leaving dashboard
    NotificationService().stopListening();
    super.dispose();
  }

  Future<int> _getUnreadNotificationsCount(String userId) async {
    try {
      final response = await _supabaseService.client
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);
      return (response as List).length;
    } catch (e) {
      // Table doesn't exist yet, return 0
      return 0;
    }
  }

  Future<void> _loadData() async {
    print('=== DASHBOARD LOAD DATA START ===');
    setState(() {
      _isLoading = true;
    });

    try {
      print('Getting current user...');
      final user = await _supabaseService.getCurrentUser();
      print('Current user result: ${user != null ? "Found (ID: ${user.id})" : "null"}');
      
      if (user != null && user.id.isNotEmpty) {
        // Sync ulang activities dari Strava ke Supabase jika punya Strava connection
        try {
          final stravaUser = await _supabaseService.getStravaUserByUserId(user.id);
          if (stravaUser != null && stravaUser['access_token'] != null) {
            final accessToken = stravaUser['access_token'] as String;
            print('Syncing activities from Strava...');
            await _stravaAuth.syncActivitiesToSupabase(
              userId: user.id,
              accessToken: accessToken,
            );
            print('Activities synced successfully');
          } else {
            print('No Strava connection, skipping activity sync');
          }
        } catch (e) {
          // Log saja, jangan blok UI
          print('⚠️ Failed to sync activities on dashboard refresh: $e');
        }

        // Setelah sync, load semua data secara paralel
        print('Loading activities, events, registrations, and notifications...');
        final results = await Future.wait([
          _supabaseService.getActivities(userId: user.id),
          _supabaseService.getEvents(isActive: true),
          _supabaseService.getUserRegistrations(user.id),
          _getUnreadNotificationsCount(user.id),
        ]);

        final activities = results[0] as List<Activity>;
        final events = results[1] as List<Event>;
        final registrations = results[2] as List<Registration>;
        final unreadCount = results[3] as int;

        print('=== USER DATA DEBUG ===');
        print('User ID: ${user.id}');
        print('Profile Picture: ${user.profilePicture}');
        print('Activities: ${activities.length}');
        print('Active Events: ${events.length}');
        print('Registrations: ${registrations.length}');
        print('======================');

        if (mounted) {
          setState(() {
            _currentUser = user;
            _activities = activities;
            _activeEvents = events; // Show all active events
            _userRegistrations = registrations;
            _unreadNotificationsCount = unreadCount;
          });
          
          // Start listening to push notifications
          try {
            await NotificationService().startListening(user.id);
            print('Started listening to push notifications');
          } catch (e) {
            print('Error starting notification listener: $e');
          }
          
          print('Dashboard state updated successfully');
        }
      } else {
        // User not found or not authenticated
        print('User not found or not authenticated');
        if (mounted) {
          setState(() {
            _currentUser = null;
            _activities = [];
            _activeEvents = [];
            _userRegistrations = [];
            _unreadNotificationsCount = 0;
          });
        }
      }
      print('=== DASHBOARD LOAD DATA SUCCESS ===');
    } catch (e, stackTrace) {
      print('=== ERROR LOADING DATA ===');
      print('Error: $e');
      print('Error type: ${e.runtimeType}');
      print('Stack trace: $stackTrace');
      print('==========================');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load data. Please try again.'),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.red,
          ),
        );
        // Set empty state on error to prevent blank screen
        setState(() {
          _currentUser = null;
          _activities = [];
          _activeEvents = [];
          _userRegistrations = [];
          _unreadNotificationsCount = 0;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Profile Icon - Always visible
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ProfilePage(),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2.5,
                    ),
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  ),
                  child: ClipOval(
                    child: _currentUser?.profilePicture != null &&
                            _currentUser!.profilePicture!.isNotEmpty &&
                            _currentUser!.profilePicture!.trim().isNotEmpty
                        ? Image.network(
                            _currentUser!.profilePicture!.trim(),
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              print('Error loading profile picture: $error');
                              print('URL: ${_currentUser!.profilePicture}');
                              // Fallback ke icon jika error load gambar
                              return Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              // Tampilkan loading indicator
                              return Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          )
                        : Container(
                            // Fallback icon jika tidak ada foto profil
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.message),
                // Badge untuk pemberitahuan baru (jika ada)
                if (_unreadNotificationsCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        _unreadNotificationsCount > 99 ? '99+' : '$_unreadNotificationsCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const NotificationsPage(),
                ),
              );
              // Refresh notification count after returning
              if (mounted && _currentUser != null) {
                final count = await _getUnreadNotificationsCount(_currentUser!.id);
                if (mounted) {
                  setState(() {
                    _unreadNotificationsCount = count;
                  });
                }
              }
            },
            tooltip: 'Pemberitahuan',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'setting') {
                // Navigate to settings page
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SettingsPage(),
                  ),
                );
              } else if (value == 'report') {
                // Show report dialog or navigate to report page
                _showReportDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'setting',
                child: Row(
                  children: [
                    Icon(Icons.settings, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Setting'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.report, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Report'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const DashboardShimmer()
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.primary.withOpacity(0.7),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Selamat Datang,',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currentUser?.fullName ?? 'User',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Stats Cards
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const ActivitiesPage(),
                                  ),
                                );
                              },
                              child: _buildStatCard(
                                'Total Activities',
                                _activities.length.toString(),
                                Icons.directions_run,
                                Colors.orange,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const MyEventsPage(),
                                  ),
                                ).then((_) {
                                  // Refresh data after returning
                                  _loadData();
                                });
                              },
                              child: _buildStatCard(
                                'Events Joined',
                                _userRegistrations.length.toString(),
                                Icons.event,
                                Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Active Events Section - Always show
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Events Aktif',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const EventsPage(),
                                ),
                              );
                            },
                            child: const Text('Lihat Semua'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _activeEvents.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(32),
                            child: SizedBox(
                              height: 220,
                              width: double.infinity,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.event_busy,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Belum ada events aktif',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Events yang dipublish akan muncul di sini',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.8),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : SizedBox(
                            height: 200,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _activeEvents.length,
                              itemBuilder: (context, index) {
                                final event = _activeEvents[index];
                                return Container(
                                  width: 300,
                                  margin: const EdgeInsets.only(right: 12),
                                  child: EventCard(
                                    event: event,
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => EventDetailPage(event: event),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                    const SizedBox(height: 24),

                    // Activities Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Aktivitas Terbaru',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _activities.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(32),
                            child: SizedBox(
                              height: 220,
                              width: double.infinity,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.directions_run,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Belum ada aktivitas',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tarik ke bawah untuk refresh',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.8),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _activities.length,
                            itemBuilder: (context, index) {
                              return ActivityCard(
                                activity: _activities[index],
                              );
                            },
                          ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 28),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showReportDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Report',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Fitur report sedang dalam pengembangan.',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

