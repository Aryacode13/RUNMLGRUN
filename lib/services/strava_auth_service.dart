import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'supabase_service.dart';
import '../models/activity.dart';
import '../widgets/strava_oauth_webview.dart';
import '../utils/web_url_helper.dart';

class StravaAuthService {
  static final StravaAuthService _instance = StravaAuthService._internal();
  factory StravaAuthService() => _instance;
  StravaAuthService._internal();

  final SupabaseService _supabaseService = SupabaseService();

  // Strava OAuth configuration
  static const String stravaAuthUrl = 'https://www.strava.com/oauth/authorize';
  static const String stravaTokenUrl = 'https://www.strava.com/oauth/token';
  static const String stravaApiUrl = 'https://www.strava.com/api/v3';

  // These should be set from environment or config
  String? _clientId;
  String? _clientSecret;
  String? _redirectUri;

  void configure({
    required String clientId,
    required String clientSecret,
    required String redirectUri,
  }) {
    _clientId = clientId;
    _clientSecret = clientSecret;
    _redirectUri = redirectUri;
  }

  Future<Map<String, dynamic>> authenticate(BuildContext? context) async {
    if (_clientId == null || _redirectUri == null) {
      throw Exception('Strava OAuth not configured. Call configure() first.');
    }

    // Build authorization URL
    // For web, use the actual app URL (e.g., http://localhost:8080)
    // For mobile, Strava requires redirect_uri to match Authorization Callback Domain
    // Since domain is "localhost", redirect_uri should be "http://localhost"
    // BUT Strava mobile apps might need different format - try without protocol
    String stravaRedirectUri;
    if (kIsWeb) {
      stravaRedirectUri = WebUrlHelper.getAppOrigin();  // Get actual app URL (e.g., http://localhost:8080)
    } else {
      // For mobile: Try using 127.0.0.1 instead of localhost
      // Strava Authorization Callback Domain should be: 127.0.0.1 (without http://)
      // redirect_uri in request: http://127.0.0.1
      stravaRedirectUri = 'http://127.0.0.1';
    }
    
    print('=== STRAVA OAUTH DEBUG ===');
    print('Platform: ${kIsWeb ? "Web" : "Mobile"}');
    print('Client ID: $_clientId');
    print('Redirect URI: $stravaRedirectUri');
    
    final authUrl = Uri.parse(stravaAuthUrl).replace(
      queryParameters: {
        'client_id': _clientId!,
        'redirect_uri': stravaRedirectUri,
        'response_type': 'code',
        'scope': 'read,activity:read_all',
        'approval_prompt': 'force', // Force re-approval (user must approve again)
        // Add state parameter to prevent CSRF attacks
        'state': 'rmr_cms_auth',
      },
    );
    
    print('Full Auth URL: ${authUrl.toString()}');
    print('==========================');

    // For web, use flutter_web_auth_2
    // For mobile, use WebView with proper User-Agent to avoid Google OAuth block
    if (kIsWeb) {
      // Web platform - use flutter_web_auth_2
      try {
        final result = await FlutterWebAuth2.authenticate(
          url: authUrl.toString(),
          callbackUrlScheme: 'http',
          options: const FlutterWebAuth2Options(
            windowName: '_self',
          ),
        );
        
        // Parse the result URL
        final callbackUri = Uri.parse(result);
        final code = callbackUri.queryParameters['code'];
        final error = callbackUri.queryParameters['error'];

        if (error != null) {
          throw Exception('OAuth error: $error');
        }

        if (code == null) {
          // Try to extract from URL string if parsing fails
          if (result.contains('code=')) {
            final codeMatch = RegExp(r'[?&]code=([^&]+)').firstMatch(result);
            if (codeMatch != null) {
              final extractedCode = Uri.decodeComponent(codeMatch.group(1)!);
              return await exchangeCodeForTokens(extractedCode);
            }
          }
          throw Exception('No authorization code received. URL: $result');
        }

        return await exchangeCodeForTokens(code);
      } catch (e) {
        rethrow;
      }
    } else {
      // Mobile platform - use WebView with proper User-Agent
      final completer = Completer<String>();
      
      if (context == null) {
        throw Exception('Context is required for OAuth flow on mobile');
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => StravaOAuthWebView(
            authorizationUrl: authUrl.toString(),
            redirectUri: stravaRedirectUri,
            onCodeReceived: (code) {
              if (!completer.isCompleted) {
                completer.complete(code);
              }
            },
            onError: (error) {
              if (!completer.isCompleted) {
                completer.completeError(Exception(error));
              }
            },
          ),
        ),
      );

      try {
        final code = await completer.future;
        
        // Exchange code for tokens
        return await exchangeCodeForTokens(code);
      } catch (e) {
        rethrow;
      }
    }
  }

  Future<Map<String, dynamic>> exchangeCodeForTokens(String code) async {
    if (_clientId == null || _clientSecret == null) {
      throw Exception('Strava OAuth not configured');
    }
    
    // Use actual app URL for web, http://127.0.0.1 for mobile
    // IMPORTANT: Must match EXACTLY with redirect_uri used in authorization request
    final redirectUri = kIsWeb 
        ? WebUrlHelper.getAppOrigin()  // Get actual app URL (e.g., http://localhost:8080)
        : 'http://127.0.0.1';  // Use http://127.0.0.1 for mobile (must match auth request)

    print('=== TOKEN EXCHANGE DEBUG ===');
    print('Platform: ${kIsWeb ? "Web" : "Mobile"}');
    print('Redirect URI: $redirectUri');
    print('Code length: ${code.length}');
    print('Code (first 50 chars): ${code.substring(0, code.length > 50 ? 50 : code.length)}...');
    print('Code (last 20 chars): ...${code.length > 20 ? code.substring(code.length - 20) : code}');
    print('Full code: $code');
    print('Code contains slash: ${code.contains('/')}');
    print('Code contains dash: ${code.contains('-')}');
    print('============================');

    // Clean code - remove any whitespace, but preserve the code as-is
    // Strava codes are case-sensitive and must be exact
    final cleanCode = code.trim();
    
    // Validate code format (Strava codes are typically alphanumeric)
    if (cleanCode.isEmpty) {
      throw Exception('Authorization code is empty');
    }
    
    if (cleanCode.length < 20) {
      throw Exception('Authorization code seems too short: ${cleanCode.length} characters');
    }
    
    print('=== FINAL CODE VALIDATION ===');
    print('Code: $cleanCode');
    print('Code length: ${cleanCode.length}');
    print('Redirect URI: $redirectUri');
    print('=============================');
    
    final requestBody = {
      'client_id': _clientId!,
      'client_secret': _clientSecret!,
      'code': cleanCode,
      'grant_type': 'authorization_code',
      'redirect_uri': redirectUri,
    };
    
    print('Token exchange request body (without secret):');
    print('  client_id: ${requestBody['client_id']}');
    print('  code: ${requestBody['code']?.substring(0, 20)}...');
    print('  grant_type: ${requestBody['grant_type']}');
    print('  redirect_uri: ${requestBody['redirect_uri']}');
    print('Token exchange URL: $stravaTokenUrl');
    
    final response = await http.post(
      Uri.parse(stravaTokenUrl),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: requestBody,
    );

    print('=== TOKEN EXCHANGE RESPONSE ===');
    print('Status Code: ${response.statusCode}');
    print('Response Body: ${response.body}');
    print('===============================');
    
    if (response.statusCode != 200) {
      // Try to parse error message
      try {
        final errorJson = json.decode(response.body) as Map<String, dynamic>;
        final message = errorJson['message'] ?? 'Unknown error';
        final errors = errorJson['errors'] as List<dynamic>?;
        if (errors != null && errors.isNotEmpty) {
          final firstError = errors[0] as Map<String, dynamic>;
          final field = firstError['field'] ?? 'unknown';
          final code = firstError['code'] ?? 'unknown';
          throw Exception('Failed to exchange code: $message (field: $field, code: $code)');
        }
      } catch (e) {
        // If parsing fails, use raw response
      }
      throw Exception('Failed to exchange code (${response.statusCode}): ${response.body}');
    }

    final tokenData = json.decode(response.body) as Map<String, dynamic>;
    return tokenData;
  }

  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    if (_clientSecret == null) {
      throw Exception('Strava OAuth not configured');
    }

    final response = await http.post(
      Uri.parse(stravaTokenUrl),
      body: {
        'client_id': _clientId,
        'client_secret': _clientSecret,
        'refresh_token': refreshToken,
        'grant_type': 'refresh_token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to refresh token: ${response.body}');
    }

    return json.decode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAthlete(String accessToken) async {
    final response = await http.get(
      Uri.parse('$stravaApiUrl/athlete'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to get athlete: ${response.body}');
    }

    return json.decode(response.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getActivities(
    String accessToken, {
    int perPage = 30,
    int page = 1,
  }) async {
    final response = await http.get(
      Uri.parse('$stravaApiUrl/athlete/activities').replace(
        queryParameters: {
          'per_page': perPage.toString(),
          'page': page.toString(),
        },
      ),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to get activities: ${response.body}');
    }

    return List<Map<String, dynamic>>.from(json.decode(response.body));
  }

  /// Revoke access token to disconnect athlete from app
  /// This will free up quota slot for new athletes
  /// After revoking, athlete needs to login again
  Future<void> revokeAccess(String accessToken) async {
    try {
      final response = await http.post(
        Uri.parse('https://www.strava.com/oauth/deauthorize'),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to revoke access: ${response.body}');
      }

      print('✅ Access revoked successfully - athlete disconnected from app');
    } catch (e) {
      print('Error revoking access: $e');
      rethrow;
    }
  }

  /// Get app info including connected athletes count
  /// Note: This requires admin access or the app owner's token
  /// Strava doesn't provide a direct API to get connected athletes count
  /// You need to check manually at: https://www.strava.com/settings/apps
  Future<void> checkAppInfo() async {
    print('=== STRAVA APP INFO ===');
    print('Client ID: $_clientId');
    print('Redirect URI: $_redirectUri');
    print('');
    print('⚠️ IMPORTANT: Strava tidak menyediakan API untuk cek jumlah connected athletes');
    print('Cara cek manual:');
    print('1. Login ke: https://www.strava.com/settings/apps');
    print('2. Cari aplikasi Anda (Client ID: $_clientId)');
    print('3. Klik aplikasi → Lihat daftar athlete yang terhubung');
    print('4. Hitung jumlah athlete yang terhubung');
    print('');
    print('💡 TIP: Setiap kali login (bahkan jika gagal), mungkin terhitung sebagai connected athlete');
    print('Pastikan hapus koneksi yang tidak aktif di Strava settings');
    print('========================');
  }

  Future<void> syncActivitiesToSupabase({
    required String userId,
    required String accessToken,
  }) async {
    try {
      // Ambil daftar aktivitas terbaru dari Strava
      final stravaActivities = await getActivities(accessToken, perPage: 100);

      // Kumpulkan semua ID aktivitas Strava yang masih ada
      final currentStravaIds = <int>{};

      // 1) Tambah aktivitas baru yang belum ada di Supabase
      for (final stravaActivity in stravaActivities) {
        final stravaActivityId = stravaActivity['id'] as int;
        currentStravaIds.add(stravaActivityId);

        // Cek apakah aktivitas sudah ada di Supabase
        final existing = await _supabaseService.getActivityByStravaId(stravaActivityId);
        if (existing != null) continue;

        // Buat aktivitas baru di Supabase
        final activity = Activity(
          id: '', // Akan dibuat oleh Supabase (UUID)
          userId: userId,
          stravaActivityId: stravaActivityId,
          name: stravaActivity['name'] as String?,
          distance: (stravaActivity['distance'] as num?)?.toDouble(),
          movingTime: stravaActivity['moving_time'] as int?,
          elapsedTime: stravaActivity['elapsed_time'] as int?,
          type: stravaActivity['type'] as String?,
          startDate: stravaActivity['start_date_local'] != null
              ? DateTime.parse(stravaActivity['start_date_local'] as String)
              : null,
          mapPolyline: stravaActivity['map']?['summary_polyline'] as String?,
          createdAt: DateTime.now(),
        );

        await _supabaseService.createActivity(activity);
      }

      // 2) Hapus aktivitas di Supabase yang sudah DIHAPUS di Strava
      //    (aktivitas user ini dengan strava_activity_id yang tidak ada di currentStravaIds)
      final existingActivities = await _supabaseService.getActivities(userId: userId);
      for (final existing in existingActivities) {
        final stravaId = existing.stravaActivityId;
        if (stravaId != null && !currentStravaIds.contains(stravaId)) {
          // Aktivitas ini sudah tidak ada lagi di Strava → hapus di Supabase
          await _supabaseService.deleteActivity(existing.id);
        }
      }
    } catch (e) {
      throw Exception('Failed to sync activities: $e');
    }
  }
}

