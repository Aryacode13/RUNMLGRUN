import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  RealtimeChannel? _realtimeChannel;
  bool _isInitialized = false;
  String? _currentUserId;
  String? _fcmToken;
  
  // Background message handler (called from main.dart top-level function)
  static Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    print('📬 [NotificationService] Processing background message...');
    
    // Show notification when app is killed/closed
    await _showBackgroundNotificationStatic(message);
  }
  
  // Static method to show notification from background handler
  static Future<void> _showBackgroundNotificationStatic(RemoteMessage message) async {
    try {
      print('📱 [BACKGROUND] Initializing local notifications...');
      final notifications = FlutterLocalNotificationsPlugin();
      
      // Initialize notifications
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      
      await notifications.initialize(initSettings);
      print('📱 [BACKGROUND] Local notifications initialized');
      
      // Create notification channel for Android
      const androidChannel = AndroidNotificationChannel(
        'rmr_notifications',
        'RMR Notifications',
        description: 'Notifications from RMR CMS',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );
      
      await notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
      print('📱 [BACKGROUND] Notification channel created');
      
      // Show notification
      const androidDetails = AndroidNotificationDetails(
        'rmr_notifications',
        'RMR Notifications',
        channelDescription: 'Notifications from RMR CMS',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      );
      
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      final notificationTitle = message.notification?.title ?? message.data['title'] ?? 'Notification';
      final notificationBody = message.notification?.body ?? message.data['message'] ?? message.data['body'] ?? '';
      
      print('📱 [BACKGROUND] Showing notification:');
      print('   Title: $notificationTitle');
      print('   Body: $notificationBody');
      
      await notifications.show(
        message.hashCode,
        notificationTitle,
        notificationBody,
        notificationDetails,
        payload: message.data.toString(),
      );
      
      print('✅ [BACKGROUND] Notification shown successfully');
    } catch (e, stackTrace) {
      print('❌ [BACKGROUND] Error showing notification: $e');
      print('Stack trace: $stackTrace');
    }
  }

  /// Initialize notification service
  Future<void> initialize() async {
    if (_isInitialized) {
      print('Notification service already initialized');
      return;
    }

    print('Initializing notification service...');
    
    try {
      // Initialize Firebase if not already initialized
      try {
        await Firebase.initializeApp();
        print('✅ Firebase initialized');
        
        // Background message handler is registered in main.dart (top-level)
        // Don't register here to avoid conflicts
        
        // Get FCM token
        final fcm = FirebaseMessaging.instance;
        _fcmToken = await fcm.getToken();
        print('📱 FCM Token: $_fcmToken');
        
        // Listen for token refresh
        fcm.onTokenRefresh.listen((newToken) {
          _fcmToken = newToken;
          print('🔄 FCM Token refreshed: $newToken');
          _saveFcmTokenToDatabase(newToken);
        });
        
        // Setup foreground message handler
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          print('📬 Foreground message received: ${message.messageId}');
          _handleFcmMessage(message);
        });
        
        // Handle notification tap when app is opened from terminated state
        FirebaseMessaging.instance.getInitialMessage().then((message) {
          if (message != null) {
            print('📬 App opened from notification: ${message.messageId}');
            _handleFcmMessage(message);
          }
        });
        
        // Handle notification tap when app is in background
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          print('📬 Notification tapped (background): ${message.messageId}');
          _handleFcmMessage(message);
        });
        
      } catch (e) {
        print('⚠️ Firebase not configured: $e');
        print('⚠️ FCM push notifications will not work. Please setup Firebase first.');
      }
    } catch (e) {
      print('⚠️ Error initializing Firebase: $e');
    }
    
    // Request notification permission (Android 13+)
    // This is required for POST_NOTIFICATIONS permission
    final status = await Permission.notification.request();
    print('Notification permission status: $status');
    
    if (!status.isGranted) {
      print('⚠️ Notification permission not granted. Push notifications will not work.');
      print('⚠️ Please enable notifications in device settings.');
      // Don't return, still initialize for testing
    } else {
      print('✅ Notification permission granted');
    }

    // Initialize Android settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // Initialize iOS settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    const androidChannel = AndroidNotificationChannel(
      'rmr_notifications',
      'RMR Notifications',
      description: 'Notifications from RMR CMS',
      importance: Importance.high,
      playSound: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    _isInitialized = true;
    print('✅ Notification service initialized successfully');
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
    // You can navigate to notifications page here if needed
  }

  /// Start listening to notifications for a user
  Future<void> startListening(String userId) async {
    print('🔔 Starting to listen for notifications for user: $userId');
    
    if (!_isInitialized) {
      print('Notification service not initialized, initializing now...');
      await initialize();
    }

    _currentUserId = userId;
    
    // Save FCM token to database if available
    if (_fcmToken != null) {
      await _saveFcmTokenToDatabase(_fcmToken!);
    }

    // Stop previous channel if exists
    await stopListening();

    try {
      // Subscribe to notifications table changes
      _realtimeChannel = Supabase.instance.client
          .channel('notifications_$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              print('📬 New notification received via Realtime!');
              print('Payload: ${payload.newRecord}');
              _handleNewNotification(payload);
            },
          )
          .subscribe();
      
      // Wait a bit and check subscription status
      await Future.delayed(const Duration(milliseconds: 500));
      print('✅ Realtime channel subscribed for user: $userId');

      print('✅ Started listening to notifications for user: $userId');
    } catch (e) {
      print('❌ Error starting notification listener: $e');
    }
  }

  /// Stop listening to notifications
  Future<void> stopListening() async {
    if (_realtimeChannel != null) {
      await Supabase.instance.client.removeChannel(_realtimeChannel!);
      _realtimeChannel = null;
      print('Stopped listening to notifications');
    }
  }

  /// Handle new notification from database
  void _handleNewNotification(PostgresChangePayload payload) {
    try {
      print('📨 Handling new notification...');
      final data = payload.newRecord;
      final title = data['title'] as String? ?? 'New Notification';
      final message = data['message'] as String? ?? '';
      final notificationId = data['id'] as String? ?? '';

      print('Notification details:');
      print('  - Title: $title');
      print('  - Message: $message');
      print('  - ID: $notificationId');

      // Check if push notifications are enabled
      _checkAndShowNotification(title, message, notificationId);
    } catch (e) {
      print('❌ Error handling new notification: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  /// Check if push notifications are enabled and show notification
  Future<void> _checkAndShowNotification(
    String title,
    String message,
    String notificationId,
  ) async {
    print('🔍 Checking notification settings...');
    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    final pushNotificationsEnabled = prefs.getBool('push_notifications_enabled') ?? true;

    print('  - Notifications enabled: $notificationsEnabled');
    print('  - Push notifications enabled: $pushNotificationsEnabled');

    if (notificationsEnabled && pushNotificationsEnabled) {
      print('✅ Settings OK, showing notification...');
      await showNotification(
        id: notificationId.hashCode,
        title: title,
        body: message,
        payload: notificationId,
      );
    } else {
      print('⚠️ Push notifications disabled in settings. Notification will not be shown.');
    }
  }

  /// Show a local notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    const androidDetails = AndroidNotificationDetails(
      'rmr_notifications',
      'RMR Notifications',
      channelDescription: 'Notifications from RMR CMS',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notifications.show(
        id,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
      print('✅ Notification shown successfully: $title');
    } catch (e) {
      print('❌ Error showing notification: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  /// Cancel a notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }
  
  /// Save FCM token to database
  Future<void> _saveFcmTokenToDatabase(String token) async {
    if (_currentUserId == null) {
      print('⚠️ Cannot save FCM token: user ID not set');
      return;
    }
    
    try {
      // Try using RPC function first (bypasses RLS, handles device switching)
      try {
        await Supabase.instance.client.rpc(
          'upsert_user_fcm_token',
          params: {
            'p_user_id': _currentUserId,
            'p_fcm_token': token,
            'p_device_info': null, // Can be enhanced later with device info
          },
        );
        print('✅ FCM token saved/updated via RPC for user: $_currentUserId');
        return;
      } catch (rpcError) {
        print('⚠️ RPC function not available, trying direct update: $rpcError');
        // Fallback to direct update if RPC function doesn't exist
      }
      
      // Fallback: Direct update approach
      // First, check if this FCM token already exists with different user_id
      final existingToken = await Supabase.instance.client
          .from('user_fcm_tokens')
          .select('user_id')
          .eq('fcm_token', token)
          .maybeSingle();
      
      if (existingToken != null) {
        final existingUserId = existingToken['user_id'] as String;
        if (existingUserId != _currentUserId) {
          // FCM token exists with different user_id, update it
          print('🔄 FCM token already exists for user $existingUserId, updating to user $_currentUserId');
          await Supabase.instance.client
              .from('user_fcm_tokens')
              .update({
                'user_id': _currentUserId,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('fcm_token', token);
          print('✅ FCM token updated to new user');
          return;
        } else {
          // Token already exists for this user, just update timestamp
          await Supabase.instance.client
              .from('user_fcm_tokens')
              .update({
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('fcm_token', token);
          print('✅ FCM token timestamp updated for user: $_currentUserId');
          return;
        }
      }
      
      // Insert new token if doesn't exist
      await Supabase.instance.client
          .from('user_fcm_tokens')
          .insert({
            'user_id': _currentUserId,
            'fcm_token': token,
            'updated_at': DateTime.now().toIso8601String(),
          });
      print('✅ FCM token inserted for user: $_currentUserId');
    } catch (e) {
      print('❌ Error saving FCM token: $e');
      print('Error details: ${e.toString()}');
      // Table might not exist yet, that's okay
    }
  }
  
  /// Handle FCM message
  void _handleFcmMessage(RemoteMessage message) {
    final title = message.notification?.title ?? 'New Notification';
    final body = message.notification?.body ?? '';
    final data = message.data;
    
    print('📨 Handling FCM message:');
    print('  - Title: $title');
    print('  - Body: $body');
    print('  - Data: $data');
    
    // Show local notification
    if (title.isNotEmpty && body.isNotEmpty) {
      showNotification(
        id: message.hashCode,
        title: title,
        body: body,
        payload: data['notification_id']?.toString(),
      );
    }
  }
  
  /// Get current FCM token
  String? get fcmToken => _fcmToken;
}

