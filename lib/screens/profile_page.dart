import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/strava_auth_service.dart';
import '../models/user.dart' as models;
import 'login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final SupabaseService _supabaseService = SupabaseService();
  final StravaAuthService _stravaAuth = StravaAuthService();
  models.User? _currentUser;
  Map<String, dynamic>? _stravaUser; // Data Strava dari tabel strava_users
  bool _isLoading = true;
  bool _isConnectingStrava = false;
  bool _isUploadingAvatar = false;
  bool _isDisconnectingStrava = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      print('=== PROFILE PAGE DEBUG ===');
      
      // Get user data from users table using getCurrentUser()
      // This method handles SharedPreferences and fallback methods
      final user = await _supabaseService.getCurrentUser();
      
      print('User from database: ${user?.id}');
      print('User full name: ${user?.fullName}');
      print('User profile picture: ${user?.profilePicture}');
      print('User is_active: ${user?.isActive}');
      print('==========================');
      
      // Get Strava data jika user sudah connect
      Map<String, dynamic>? stravaUser;
      if (user != null) {
        stravaUser = await _supabaseService.getStravaUserByUserId(user.id);
      }

      setState(() {
        _currentUser = user;
        _stravaUser = stravaUser;
        _isLoading = false;
      });
      
      if (user == null && mounted) {
        // Check SharedPreferences to see if there's a stored user ID
        final prefs = await SharedPreferences.getInstance();
        final storedUserId = prefs.getString('current_user_id');
        
        print('=== USER NOT FOUND DEBUG ===');
        print('Stored User ID in SharedPreferences: $storedUserId');
        
        // Try to get user directly by ID (without is_active check)
        if (storedUserId != null && storedUserId.isNotEmpty) {
          try {
            final directUser = await _supabaseService.client
                .from('users')
                .select('id, strava_id, username, firstname, lastname, profile_picture, access_token, refresh_token, token_expires, email_users, role, is_active, created_at, updated_at')
                .eq('id', storedUserId)
                .maybeSingle();
            
            print('Direct user query result: ${directUser != null}');
            if (directUser != null) {
              print('User is_active: ${directUser['is_active']}');
              print('User name: ${directUser['firstname']} ${directUser['lastname']}');
              
              if (directUser['is_active'] == false) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Session expired. Please login again.'),
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            }
          } catch (e) {
            print('Error checking user directly: $e');
          }
        }
        print('============================');
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User not found. Please login again.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Error loading user data: $e');
      print('Stack trace: ${StackTrace.current}');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to load profile. Please try again.'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        print('=== LOGOUT PROCESS START ===');
        print('Current User: ${_currentUser?.id}');
        print('Current User Name: ${_currentUser?.fullName}');
        
        // Get user ID from current user or SharedPreferences as fallback
        String? userIdToLogout = _currentUser?.id;
        
        if (userIdToLogout == null || userIdToLogout.isEmpty) {
          // Try to get from SharedPreferences as fallback
          final prefs = await SharedPreferences.getInstance();
          userIdToLogout = prefs.getString('current_user_id');
          print('User ID from SharedPreferences: $userIdToLogout');
        }
        
        // Set user as logged out (is_active = false)
        if (userIdToLogout != null && userIdToLogout.isNotEmpty) {
          print('Setting user as logged out: $userIdToLogout');
          await _supabaseService.setUserLoggedOut(userIdToLogout);
          
          // Verify the update
          final verifyUser = await _supabaseService.client
              .from('users')
              .select('id, is_active')
              .eq('id', userIdToLogout)
              .maybeSingle();
          
          if (verifyUser != null) {
            print('Verification - User ID: ${verifyUser['id']}');
            print('Verification - Is Active: ${verifyUser['is_active']}');
          }
        } else {
          print('WARNING: No user ID found to logout');
        }
        
        // Clear current user ID from SharedPreferences
        await _supabaseService.clearCurrentUserId();
        print('Cleared SharedPreferences');
        
        // Sign out from Supabase Auth
        try {
          await _supabaseService.client.auth.signOut();
          print('Signed out from Supabase Auth');
        } catch (e) {
          print('Auth signout error (ignored): $e');
        }
        
        print('=== LOGOUT PROCESS COMPLETE ===');
        
        if (mounted) {
          // Navigate to login page
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
          );
        }
      } catch (e) {
        print('=== LOGOUT ERROR ===');
        print('Error: $e');
        print('Stack trace: ${StackTrace.current}');
        print('===================');
        if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to logout. Please try again.')),
        );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentUser == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.person_off, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'User not found',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Your session may have expired or the user is inactive.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () async {
                            // Try to reactivate user if found
                            final prefs = await SharedPreferences.getInstance();
                            final storedUserId = prefs.getString('current_user_id');
                            
                            if (storedUserId != null && storedUserId.isNotEmpty) {
                              try {
                                // Try to set user as active
                                await _supabaseService.setUserLoggedIn(storedUserId);
                                // Reload user data
                                await _loadUserData();
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('An error occurred. Please try again.'),
                                      duration: Duration(seconds: 3),
                                    ),
                                  );
                                }
                              }
                            } else {
                              // No stored user ID, go to login
                              _logout();
                            }
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try to Reactivate'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout),
                          label: const Text('Logout'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadUserData,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 24),
                        // Profile Picture (tap to change)
                        GestureDetector(
                          onTap: _isUploadingAvatar ? null : _changeProfilePicture,
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 60,
                                backgroundColor: Colors.grey.shade900,
                                backgroundImage: _currentUser!.profilePicture != null &&
                                        _currentUser!.profilePicture!.isNotEmpty
                                    ? NetworkImage(_currentUser!.profilePicture!)
                                    : null,
                                child: _currentUser!.profilePicture == null ||
                                        _currentUser!.profilePicture!.isEmpty
                                    ? const Icon(
                                        Icons.person,
                                        size: 60,
                                        color: Colors.orange,
                                      )
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: _isUploadingAvatar
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.camera_alt,
                                          size: 20,
                                          color: Colors.white,
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Full Name
                        Text(
                          _currentUser!.fullName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Username
                        if (_currentUser!.username != null &&
                            _currentUser!.username!.isNotEmpty)
                          Text(
                            '@${_currentUser!.username}',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        const SizedBox(height: 32),
                        // Profile Information Card
                        Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _buildInfoRow(
                                  icon: Icons.person,
                                  label: 'First Name',
                                  value: _currentUser!.firstname ?? 'Not set',
                                ),
                                const Divider(),
                                _buildInfoRow(
                                  icon: Icons.person_outline,
                                  label: 'Last Name',
                                  value: _currentUser!.lastname ?? 'Not set',
                                ),
                                const Divider(),
                                _buildInfoRow(
                                  icon: Icons.badge,
                                  label: 'Username',
                                  value: _currentUser!.username ?? 'Not set',
                                ),
                                // Hanya tampilkan Strava ID dan Member Since jika sudah connect ke Strava
                                if (_stravaUser != null && _stravaUser!['strava_id'] != null) ...[
                                  const Divider(),
                                  _buildInfoRow(
                                    icon: Icons.fitness_center,
                                    label: 'Strava ID',
                                    value: _stravaUser!['strava_id'].toString(),
                                  ),
                                  const Divider(),
                                  _buildInfoRow(
                                    icon: Icons.calendar_today,
                                    label: 'Member Since',
                                    value: _formatDate(_currentUser!.createdAt),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Strava status + connect / disconnect button
                        if (_stravaUser == null) ...[
                          // Belum connect: tombol Connect
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isConnectingStrava ? null : _connectToStrava,
                              icon: _isConnectingStrava
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Icon(Icons.link),
                              label: Text(_isConnectingStrava ? 'Connecting...' : 'Connect to Strava'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ] else ...[
                          // Sudah connect: indikator + tombol Disconnect
                          Row(
                            children: const [
                              Icon(Icons.check_circle, color: Colors.green),
                              SizedBox(width: 8),
                              Text(
                                'Strava sudah terhubung',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _isDisconnectingStrava ? null : _disconnectFromStrava,
                              icon: _isDisconnectingStrava
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.link_off, color: Colors.red),
                              label: Text(
                                _isDisconnectingStrava ? 'Memutuskan Strava...' : 'Logout Strava',
                                style: const TextStyle(color: Colors.red),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.red),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.orange, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _connectToStrava() async {
    setState(() {
      _isConnectingStrava = true;
    });

    try {
      print('=== CONNECT TO STRAVA START ===');
      
      // Authenticate with Strava
      final tokenData = await _stravaAuth.authenticate(context);
      final accessToken = tokenData['access_token'] as String;
      
      // Get athlete info from Strava
      final athlete = await _stravaAuth.getAthlete(accessToken);
      final stravaId = athlete['id'] as int;
      
      print('Strava ID: $stravaId');
      
      // Update user dengan Strava data
      final userId = _currentUser?.id;
      if (userId == null) {
        throw Exception('User ID not found');
      }

      // Create or update strava_user di tabel strava_users
      await _supabaseService.createOrUpdateStravaUser(
        userId: userId,
        stravaId: stravaId,
        accessToken: accessToken,
        refreshToken: tokenData['refresh_token'] as String? ?? '',
        tokenExpires: tokenData['expires_at'] as int? ?? 0,
      );

      // Sync activities dari Strava
      await _stravaAuth.syncActivitiesToSupabase(
        userId: userId,
        accessToken: accessToken,
      );

      print('=== CONNECT TO STRAVA SUCCESS ===');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully connected to Strava!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        // Reload user data untuk update UI
        await _loadUserData();
      }
    } catch (e) {
      print('=== CONNECT TO STRAVA ERROR ===');
      print('Error: $e');
      print('===============================');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to connect to Strava. Please try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnectingStrava = false;
        });
      }
    }
  }

  Future<void> _changeProfilePicture() async {
    if (_currentUser == null) return;

    try {
      // Pilih file gambar dari device
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        // User batal memilih gambar
        return;
      }

      final file = result.files.first;
      final bytes = file.bytes;

      if (bytes == null) {
        throw Exception('Unable to read image file');
      }

      setState(() {
        _isUploadingAvatar = true;
      });

      final client = _supabaseService.client;

      // Tentukan ekstensi file
      final ext = (file.extension != null && file.extension!.isNotEmpty)
          ? '.${file.extension}'
          : '';

      // Path di storage: Profile/userId/timestamp.ext (folder di dalam bucket event-images)
      final fileName =
          'avatar_${_currentUser!.id}_${DateTime.now().millisecondsSinceEpoch}$ext';
      final storagePath = 'Profile/${_currentUser!.id}/$fileName';

      // Upload ke bucket 'event-images' di folder 'Profile' (pastikan bucket ini sudah dibuat di Supabase dan public)
      await client.storage.from('event-images').uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: 'image/*',
            ),
          );

      // Ambil public URL
      final publicUrl =
          client.storage.from('event-images').getPublicUrl(storagePath);

      // Update kolom profile_picture di tabel users
      await client
          .from('users')
          .update({
            'profile_picture': publicUrl,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', _currentUser!.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated successfully'),
            duration: Duration(seconds: 2),
          ),
        );
        // Reload user untuk update UI
        await _loadUserData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update profile picture. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
        });
      }
    }
  }

  Future<void> _disconnectFromStrava() async {
    if (_currentUser == null || _stravaUser == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout Strava'),
        content: const Text(
          'Strava will be disconnected from your RMR account. Activities already saved in RMR will remain, '
          'but there will be no new synchronization until you connect again.\n\nContinue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout Strava'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isDisconnectingStrava = true;
    });

    try {
      await _supabaseService.disconnectStravaForUser(_currentUser!.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Strava successfully disconnected from your account'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        await _loadUserData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to disconnect Strava. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDisconnectingStrava = false;
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

