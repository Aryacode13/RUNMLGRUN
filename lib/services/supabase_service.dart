import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart' as models;
import '../models/activity.dart';
import '../models/event.dart';
import '../models/admin.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  late SupabaseClient _client;

  SupabaseClient get client => _client;

  Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
    _client = Supabase.instance.client;
  }

  // User operations
  Future<models.User?> getCurrentUser() async {
    try {
      // 1) Cek dulu dari Supabase Auth (email / Google login)
      try {
        final authUser = _client.auth.currentUser;
        if (authUser != null && authUser.id.isNotEmpty) {
          final response = await _client
              .from('users')
              .select('id, username, firstname, lastname, profile_picture, email_users, role, is_active, created_at, updated_at')
              .eq('id', authUser.id)
              .maybeSingle();

          if (response != null) {
            print('=== GET CURRENT USER FROM USERS TABLE (BY AUTH USER) ===');
            print('Auth User ID: ${authUser.id}');
            print('Profile User ID: ${response['id']}');
            print('Username: ${response['username']}');
            print('First Name: ${response['firstname']}');
            print('Last Name: ${response['lastname']}');
            print('Profile Picture: ${response['profile_picture']}');
            print('Email Users: ${response['email_users']}');
            print('=========================================================');
            return models.User.fromJson(response);
          }
        }
      } catch (e) {
        print('Error getting current user from auth/users: $e');
      }

      // 2) Fallback lama: Strava OAuth dengan SharedPreferences
      //    (dipertahankan sementara untuk kompatibilitas)
      final prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('current_user_id');
      
      print('getCurrentUser: Looking for user with ID from SharedPreferences: $userId');
      
      // Method 1: Try to get user by ID from SharedPreferences
      if (userId != null && userId.isNotEmpty) {
        final response = await _client
            .from('users')
            .select('id, username, firstname, lastname, profile_picture, email_users, role, is_active, created_at, updated_at')
            .eq('id', userId)
            .eq('is_active', true) // User must be active (logged in)
            .maybeSingle();

        if (response != null) {
          print('=== GET CURRENT USER FROM USERS TABLE (BY ID) ===');
          print('User ID: ${response['id']}');
          print('Username: ${response['username']}');
          print('First Name: ${response['firstname']}');
          print('Last Name: ${response['lastname']}');
          print('Profile Picture: ${response['profile_picture']}');
          print('Email Users: ${response['email_users']}');
          print('==================================================');
          return models.User.fromJson(response);
        } else {
          print('getCurrentUser: User not found with ID: $userId, trying fallback...');
          // Clear invalid user ID
          await prefs.remove('current_user_id');
        }
      }
      
      // Method 2: REMOVED - Don't use "most recent active user" as fallback
      // This causes security issue: if user X logs in on device A, 
      // device B will auto-login as user X if no auth user exists
      // Instead, return null if no user found
      
      print('getCurrentUser: No user found in database');
      return null;
    } catch (e) {
      print('Error in getCurrentUser: $e');
      print('Stack trace: ${StackTrace.current}');
      return null;
    }
  }
  
  // Save current user ID to SharedPreferences
  Future<void> setCurrentUserId(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final success = await prefs.setString('current_user_id', userId);
      print('=== SAVE USER ID TO SHARED PREFERENCES ===');
      print('User ID: $userId');
      print('Success: $success');
      // Verify it was saved
      final savedId = prefs.getString('current_user_id');
      print('Verified saved ID: $savedId');
      print('===========================================');
    } catch (e) {
      print('Error saving user ID to SharedPreferences: $e');
    }
  }
  
  // Clear current user ID from SharedPreferences (on logout)
  Future<void> clearCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user_id');
    print('Cleared current user ID from SharedPreferences');
  }
  
  // Set user as logged out (is_active = false)
  Future<void> setUserLoggedOut(String userId) async {
    try {
      print('=== SET USER LOGGED OUT ===');
      print('User ID: $userId');
      
      final response = await _client
          .from('users')
          .update({'is_active': false})
          .eq('id', userId)
          .select('id, is_active')
          .maybeSingle();
      
      if (response != null) {
        print('Update successful - User ID: ${response['id']}');
        print('Update successful - Is Active: ${response['is_active']}');
      } else {
        print('WARNING: Update returned null - user might not exist');
      }
      
      print('============================');
    } catch (e) {
      print('=== ERROR SETTING USER LOGGED OUT ===');
      print('Error: $e');
      print('Stack trace: ${StackTrace.current}');
      print('=====================================');
      rethrow; // Re-throw to let caller handle the error
    }
  }
  
  // Get user by name (for test login)
  Future<models.User?> getUser(String userId) async {
    final response = await _client
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (response == null) return null;
    return models.User.fromJson(response);
  }

  Future<models.User?> getUserByName(String firstname, String lastname) async {
    try {
      // Try exact match first
      var response = await _client
          .from('users')
          .select('id, username, firstname, lastname, profile_picture, email_users, role, is_active, created_at, updated_at')
          .ilike('firstname', firstname)
          .ilike('lastname', lastname)
          .maybeSingle();
      
      if (response != null) {
        print('=== FOUND USER BY NAME ===');
        print('Firstname: ${response['firstname']}');
        print('Lastname: ${response['lastname']}');
        print('User ID: ${response['id']}');
        print('=========================');
        return models.User.fromJson(response);
      }
      
      // If not found, try to find by partial match on lastname
      final responseList = await _client
          .from('users')
          .select('id, username, firstname, lastname, profile_picture, email_users, role, is_active, created_at, updated_at')
          .ilike('firstname', firstname)
          .ilike('lastname', '%$lastname%')
          .limit(1);
      
      if (responseList.isNotEmpty) {
        final userData = responseList[0] as Map<String, dynamic>;
        print('=== FOUND USER BY PARTIAL MATCH ===');
        print('Firstname: ${userData['firstname']}');
        print('Lastname: ${userData['lastname']}');
        print('User ID: ${userData['id']}');
        print('===================================');
        return models.User.fromJson(userData);
      }
      
      print('User not found with name: $firstname $lastname');
      return null;
    } catch (e) {
      print('Error getting user by name: $e');
      return null;
    }
  }

  // Set user as logged in (is_active = true)
  Future<void> setUserLoggedIn(String userId) async {
    try {
      await _client
          .from('users')
          .update({'is_active': true})
          .eq('id', userId);
      print('Set user as logged in (is_active = true) for user: $userId');
    } catch (e) {
      print('Error setting user as logged in: $e');
    }
  }

  Future<models.User?> getUserByStravaId(int stravaId) async {
    // Get user from strava_users and join with users
    final stravaUser = await _client
        .from('strava_users')
        .select('user_id')
        .eq('strava_id', stravaId)
        .maybeSingle();

    if (stravaUser == null) return null;

    final userId = stravaUser['user_id'] as String;
    final response = await _client
        .from('users')
        .select('id, username, firstname, lastname, profile_picture, email_users, role, is_active, created_at, updated_at')
        .eq('id', userId)
        .maybeSingle();

    if (response == null) return null;
    return models.User.fromJson(response);
  }

  Future<models.User> createOrUpdateUser({
    required int stravaId,
    required String username,
    required String firstname,
    required String lastname,
    String? profilePicture,
    required String accessToken,
    required String refreshToken,
    required int tokenExpires,
  }) async {
    // Check if strava_user exists first
    final existingStravaUser = await _client
        .from('strava_users')
        .select('user_id')
        .eq('strava_id', stravaId)
        .maybeSingle();

    String userId;
    
    if (existingStravaUser != null) {
      // Strava user exists - get user_id
      userId = existingStravaUser['user_id'] as String;
      
      // Update user profile
      final userData = {
        'username': username,
        'firstname': firstname,
        'lastname': lastname,
        'profile_picture': profilePicture,
        'is_active': true,
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      await _client
          .from('users')
          .update(userData)
          .eq('id', userId);
      
      // Update strava_users
      final stravaData = {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'token_expires': tokenExpires,
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      await _client
          .from('strava_users')
          .update(stravaData)
          .eq('strava_id', stravaId);
      
      // Get updated user
      final response = await _client
          .from('users')
          .select('id, username, firstname, lastname, profile_picture, email_users, role, is_active, created_at, updated_at')
          .eq('id', userId)
          .single();
      
      return models.User.fromJson(response);
    } else {
      // Strava user doesn't exist - CREATE new user and strava_user
      final userData = {
        'username': username,
        'firstname': firstname,
        'lastname': lastname,
        'profile_picture': profilePicture,
        'role': 'user',
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      // Create user first
      final userResponse = await _client
          .from('users')
          .insert(userData)
          .select('id')
          .single();
      
      userId = userResponse['id'] as String;
      
      // Create strava_user
      final stravaData = {
        'user_id': userId,
        'strava_id': stravaId,
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'token_expires': tokenExpires,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      await _client
          .from('strava_users')
          .insert(stravaData);
      
      // Get created user
      final response = await _client
          .from('users')
          .select('id, username, firstname, lastname, profile_picture, email_users, role, is_active, created_at, updated_at')
          .eq('id', userId)
          .single();
      
      return models.User.fromJson(response);
    }
  }

  // Activity operations
  Future<List<Activity>> getActivities({String? userId}) async {
    var query = _client.from('activities').select();

    if (userId != null && userId.isNotEmpty) {
      query = query.eq('user_id', userId);
    }

    final response = await query.order('start_date', ascending: false);
    return (response as List)
        .map((json) => Activity.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Activity?> getActivityByStravaId(int stravaActivityId) async {
    final response = await _client
        .from('activities')
        .select()
        .eq('strava_activity_id', stravaActivityId)
        .maybeSingle();

    if (response == null) return null;
    return Activity.fromJson(response);
  }

  Future<Activity> createActivity(Activity activity) async {
    // Supabase will generate UUID for id, so jangan kirim id kosong
    final data = activity.toJson();
    final idValue = data['id'];
    if (idValue == null || (idValue is String && idValue.isEmpty)) {
      data.remove('id');
    }

    final response = await _client
        .from('activities')
        .insert(data)
        .select()
        .single();
    return Activity.fromJson(response);
  }

  Future<void> deleteActivity(String activityId) async {
    await _client.from('activities').delete().eq('id', activityId);
  }

  Future<void> syncActivitiesFromStrava({
    required String accessToken,
    required String userId,
  }) async {
    // This will be called from StravaAuthService after fetching activities
    // Implementation handled in strava_auth_service.dart
  }

  // Event operations
  Future<List<Event>> getEvents({bool? isActive}) async {
    try {
      // Use event_stats view but add updated_at from events table
      var query = _client.from('event_stats').select();

      if (isActive != null) {
        query = query.eq('is_active', isActive);
      }

      final response = await query.order('created_at', ascending: false);
      
      // Transform response to add updated_at if missing
      return (response as List).map((json) {
        final eventData = Map<String, dynamic>.from(json as Map<String, dynamic>);
        
        // If updated_at is missing, use created_at as fallback
        if (!eventData.containsKey('updated_at') || eventData['updated_at'] == null) {
          eventData['updated_at'] = eventData['created_at'];
        }
        
        return Event.fromJson(eventData);
      }).toList();
    } catch (e) {
      print('Error in getEvents: $e');
      rethrow;
    }
  }

  Future<Event?> getEvent(String eventId) async {
    try {
      final response = await _client
          .from('event_stats')
          .select()
          .eq('id', eventId)
          .maybeSingle();

      if (response == null) return null;
      
      // Add updated_at if missing
      final eventData = Map<String, dynamic>.from(response as Map<String, dynamic>);
      if (!eventData.containsKey('updated_at') || eventData['updated_at'] == null) {
        eventData['updated_at'] = eventData['created_at'];
      }
      
      return Event.fromJson(eventData);
    } catch (e) {
      print('Error in getEvent: $e');
      return null;
    }
  }

  Future<Event> createEvent({
    required String title,
    String? description,
    required int quota,
    String? createdBy,
    String? eventCode,
    DateTime? startDate,
    bool isActive = true,
    String? imageUrl,
  }) async {
    final eventData = {
      'title': title,
      'description': description,
      'quota': quota,
      'created_by': createdBy,
      'event_code': eventCode,
      'start_date': startDate?.toIso8601String(),
      'is_active': isActive,
      'image_url': imageUrl,
    };

    print('=== CREATING EVENT ===');
    print('Title: $title');
    print('Image URL: $imageUrl');
    print('Event data: $eventData');
    print('=====================');

    final response = await _client
        .from('events')
        .insert(eventData)
        .select()
        .single();
    
    print('=== EVENT CREATED ===');
    print('Response: $response');
    print('Image URL in response: ${response['image_url']}');
    print('====================');
    
    return Event.fromJson(response);
  }

  Future<String> uploadEventImage({
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    try {
      // Validate inputs
      if (imageBytes.isEmpty) {
        throw Exception('Image bytes is empty');
      }
      if (fileName.isEmpty) {
        throw Exception('File name is empty');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sanitizedFileName = fileName.replaceAll(RegExp(r'[^\w\s.-]'), '_');
      final path = 'events/${timestamp}_$sanitizedFileName';

      // Determine content type from file extension
      String contentType = 'image/jpeg';
      if (fileName.toLowerCase().endsWith('.png')) {
        contentType = 'image/png';
      } else if (fileName.toLowerCase().endsWith('.gif')) {
        contentType = 'image/gif';
      } else if (fileName.toLowerCase().endsWith('.webp')) {
        contentType = 'image/webp';
      }

      print('=== UPLOAD EVENT IMAGE DETAILS ===');
      print('Bucket: event-images');
      print('Path: $path');
      print('Content type: $contentType');
      print('File size: ${imageBytes.length} bytes');
      print('File name: $fileName');
      print('==================================');

      // Check if bucket exists by trying to list it
      try {
        await _client.storage.from('event-images').list();
        print('Bucket "event-images" exists');
      } catch (e) {
        print('=== BUCKET CHECK ERROR ===');
        print('Error checking bucket: $e');
        print('==========================');
        throw Exception(
          'Storage bucket "event-images" tidak ditemukan. '
          'Pastikan bucket sudah dibuat di Supabase Storage dengan nama "event-images" dan set sebagai Public.'
        );
      }

      // Upload the file
      await _client.storage.from('event-images').uploadBinary(
        path,
        imageBytes,
        fileOptions: FileOptions(
          contentType: contentType,
          upsert: false,
        ),
      );

      print('File uploaded to storage successfully');

      // Get public URL
      final url = _client.storage.from('event-images').getPublicUrl(path);
      print('=== UPLOAD SUCCESS ===');
      print('Public URL: $url');
      print('=====================');
      return url;
    } catch (e, stackTrace) {
      print('=== UPLOAD EVENT IMAGE ERROR ===');
      print('Error type: ${e.runtimeType}');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      print('================================');
      rethrow; // Re-throw error so caller can handle it
    }
  }

  Future<Event> updateEvent({
    required String eventId,
    String? title,
    String? description,
    int? quota,
    String? eventCode,
    DateTime? startDate, // Can be null to clear the date
    bool? isActive,
    bool clearStartDate = false, // Flag to explicitly clear start_date
    String? imageUrl,
    bool clearImage = false, // Flag to explicitly clear image_url
    bool clearEventCode = false, // Flag to explicitly clear event_code
  }) async {
    final eventData = <String, dynamic>{};
    
    if (title != null) eventData['title'] = title;
    if (description != null) eventData['description'] = description;
    if (quota != null) eventData['quota'] = quota;
    // Handle eventCode: if clearEventCode is true, set to null
    // Otherwise, if eventCode is provided, use it
    if (clearEventCode) {
      eventData['event_code'] = null;
    } else if (eventCode != null) {
      eventData['event_code'] = eventCode;
    }
    
    // Handle startDate: if clearStartDate is true, set to null
    // Otherwise, if startDate is provided, use it
    if (clearStartDate) {
      eventData['start_date'] = null;
    } else if (startDate != null) {
      eventData['start_date'] = startDate.toIso8601String();
    }
    
    if (isActive != null) eventData['is_active'] = isActive;
    
    // Handle imageUrl: if clearImage is true, set to null
    // Otherwise, if imageUrl is provided, use it
    if (clearImage) {
      eventData['image_url'] = null;
    } else if (imageUrl != null) {
      eventData['image_url'] = imageUrl;
    }

    final response = await _client
        .from('events')
        .update(eventData)
        .eq('id', eventId)
        .select()
        .single();
    return Event.fromJson(response);
  }

  Future<void> deleteEvent(String eventId) async {
    // Delete event (cascade will delete registrations)
    await _client.from('events').delete().eq('id', eventId);
  }

  // Registration operations
  Future<bool> isRegistered(String eventId, String userId) async {
    final response = await _client
        .from('registrations')
        .select()
        .eq('event_id', eventId)
        .eq('user_id', userId)
        .maybeSingle();

    return response != null;
  }

  Future<Registration> registerForEvent(String eventId, String userId, {String? paymentReceiptUrl}) async {
    // Get user's username
    String? username;
    try {
      final userResponse = await _client
          .from('users')
          .select('username')
          .eq('id', userId)
          .maybeSingle();
      
      if (userResponse != null) {
        username = userResponse['username']?.toString();
      }
    } catch (e) {
      print('⚠️ Error fetching username for registration: $e');
      // Continue without username if fetch fails
    }

    final registrationData = {
      'event_id': eventId,
      'user_id': userId,
      'username': username,
      if (paymentReceiptUrl != null) 'payment_receipt_url': paymentReceiptUrl,
    };

    final response = await _client
        .from('registrations')
        .insert(registrationData)
        .select()
        .single();
    return Registration.fromJson(response);
  }

  Future<void> updateRegistrationReceipt(String eventId, String userId, String paymentReceiptUrl) async {
    await _client
        .from('registrations')
        .update({'payment_receipt_url': paymentReceiptUrl})
        .eq('event_id', eventId)
        .eq('user_id', userId);
  }

  Future<void> unregisterFromEvent(String eventId, String userId) async {
    await _client
        .from('registrations')
        .delete()
        .eq('event_id', eventId)
        .eq('user_id', userId);
  }

  Future<List<Registration>> getUserRegistrations(String userId) async {
    final response = await _client
        .from('registrations')
        .select()
        .eq('user_id', userId)
        .order('registered_at', ascending: false);

    return (response as List)
        .map((json) => Registration.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  // Admin operations (Strava OAuth based)
  Future<Admin?> getAdminByEmail(String email) async {
    final response = await _client
        .from('admins')
        .select()
        .eq('email', email.toLowerCase().trim())
        .eq('is_active', true)
        .maybeSingle();

    if (response == null) return null;
    return Admin.fromJson(response);
  }

  Future<bool> isAdminEmail(String email) async {
    final admin = await getAdminByEmail(email);
    return admin != null;
  }

  Future<Admin?> createOrUpdateAdmin({
    required String email,
    String? fullName,
    int? stravaId,
  }) async {
    // Check if admin exists
    final existingAdmin = await getAdminByEmail(email);
    
    final adminData = {
      'email': email.toLowerCase().trim(),
      'full_name': fullName,
      'strava_id': stravaId,
    };

    if (existingAdmin != null) {
      // Update existing admin
      final response = await _client
          .from('admins')
          .update(adminData)
          .eq('email', email.toLowerCase().trim())
          .select()
          .single();
      return Admin.fromJson(response);
    } else {
      // Create new admin (should not happen if email is pre-registered)
      final response = await _client
          .from('admins')
          .insert(adminData)
          .select()
          .single();
      return Admin.fromJson(response);
    }
  }

  Future<void> updateAdminLastLogin(String adminId) async {
    await _client
        .from('admins')
        .update({'last_login': DateTime.now().toIso8601String()})
        .eq('id', adminId);
  }

  // Store admin session in local storage (simple approach)
  // In production, use proper session management
  Future<void> setAdminSession(Admin admin) async {
    // Store admin ID in Supabase auth metadata or local storage
    // For simplicity, we'll use a custom approach
    await _client.from('admins')
        .update({'last_login': DateTime.now().toIso8601String()})
        .eq('id', admin.id);
  }

  Future<void> clearAdminSession() async {
    // Clear admin session
    // Implementation depends on your session management approach
  }

  // Get user by email_users (for Email/Google login)
  Future<models.User?> getUserByEmail(String email) async {
    final response = await _client
        .from('users')
        .select('id, username, firstname, lastname, profile_picture, email_users, role, is_active, created_at, updated_at')
        .eq('email_users', email.toLowerCase().trim())
        .maybeSingle();

    if (response == null) return null;
    return models.User.fromJson(response);
  }

  // Strava Users operations
  Future<Map<String, dynamic>?> getStravaUserByUserId(String userId) async {
    final response = await _client
        .from('strava_users')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    return response as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>?> getStravaUserByStravaId(int stravaId) async {
    final response = await _client
        .from('strava_users')
        .select()
        .eq('strava_id', stravaId)
        .maybeSingle();

    return response as Map<String, dynamic>?;
  }

  Future<void> createOrUpdateStravaUser({
    required String userId,
    required int stravaId,
    required String accessToken,
    required String refreshToken,
    required int tokenExpires,
  }) async {
    final existing = await getStravaUserByUserId(userId);
    
    final data = {
      'user_id': userId,
      'strava_id': stravaId,
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'token_expires': tokenExpires,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (existing != null) {
      // Update existing
      await _client
          .from('strava_users')
          .update(data)
          .eq('user_id', userId);
    } else {
      // Create new
      data['created_at'] = DateTime.now().toIso8601String();
      await _client
          .from('strava_users')
          .insert(data);
    }
  }

  /// Disconnect Strava from a user by deleting row in strava_users
  /// Also deletes all activities associated with this user
  Future<void> disconnectStravaForUser(String userId) async {
    try {
      // Delete all activities for this user (activities from Strava)
      final deleteActivitiesResult = await _client
          .from('activities')
          .delete()
          .eq('user_id', userId);
      print('Deleted activities for user: $userId');
      
      // Delete Strava connection
      await _client
          .from('strava_users')
          .delete()
          .eq('user_id', userId);
      print('Strava disconnected for user: $userId');
    } catch (e) {
      print('Error disconnecting Strava for user $userId: $e');
      rethrow;
    }
  }
}

