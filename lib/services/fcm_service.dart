// FCM Service untuk memanggil Supabase Edge Function
// Alternatif: Bisa juga langsung kirim FCM dari Flutter (kurang secure)

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Send FCM notification to a single user
  Future<Map<String, dynamic>> sendNotificationToUser({
    required String userId,
    required String title,
    required String message,
    String? notificationId,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'send-fcm-notification',
        body: {
          'userId': userId,
          'title': title,
          'message': message,
          if (notificationId != null) 'notificationId': notificationId,
        },
      );

      return {
        'success': true,
        'data': response.data,
      };
    } catch (e) {
      print('Error sending FCM notification: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Send FCM notification to multiple users
  Future<Map<String, dynamic>> sendNotificationToAll({
    required String title,
    required String message,
    required List<String> userIds,
    String? notificationId,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'send-fcm-notification',
        body: {
          'userIds': userIds,
          'title': title,
          'message': message,
          if (notificationId != null) 'notificationId': notificationId,
        },
      );

      return {
        'success': true,
        'data': response.data,
      };
    } catch (e) {
      print('Error sending FCM notifications: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}












