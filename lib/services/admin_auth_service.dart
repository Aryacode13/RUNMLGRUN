import 'package:flutter/material.dart';
import 'supabase_service.dart';
import '../models/admin.dart';
import '../services/strava_auth_service.dart';

class AdminAuthService {
  static final AdminAuthService _instance = AdminAuthService._internal();
  factory AdminAuthService() => _instance;
  AdminAuthService._internal();

  final SupabaseService _supabaseService = SupabaseService();
  final StravaAuthService _stravaAuth = StravaAuthService();
  Admin? _currentAdmin;

  Admin? get currentAdmin => _currentAdmin;
  bool get isAuthenticated => _currentAdmin != null;

  /// Login admin menggunakan Strava OAuth
  /// Validasi: setelah login Strava, langsung cek apakah strava_id ada di tabel admins
  /// Jika ada, langsung login. Jika tidak ada, cek semua admin aktif dan coba cocokkan
  /// berdasarkan strava_id atau email (jika ada di tabel users)
  Future<Admin?> loginWithStrava(BuildContext context) async {
    try {
      // Authenticate with Strava
      final tokenData = await _stravaAuth.authenticate(context);

      final accessToken = tokenData['access_token'] as String;

      // Get athlete info from Strava
      final athlete = await _stravaAuth.getAthlete(accessToken);
      
      final stravaId = athlete['id'] as int;
      final firstName = athlete['firstname'] as String? ?? '';
      final lastName = athlete['lastname'] as String? ?? '';
      final fullName = '$firstName $lastName'.trim();
      
      // Step 1: Check if this Strava ID is already linked to an admin
      final adminByStravaId = await _supabaseService.client
          .from('admins')
          .select()
          .eq('strava_id', stravaId)
          .eq('is_active', true)
          .maybeSingle();
      
      if (adminByStravaId != null) {
        // Admin found by Strava ID - already linked, langsung login
        final admin = Admin.fromJson(adminByStravaId);
        
        // Update last login and Strava info
        await _supabaseService.updateAdminLastLogin(admin.id);
        await _supabaseService.createOrUpdateAdmin(
          email: admin.email,
          fullName: fullName,
          stravaId: stravaId,
        );
        
        _currentAdmin = admin;
        return admin;
      }
      
      // Step 2: Strava ID not linked, cek apakah ada user dengan strava_id ini
      // Jika ada, ambil email dari user (jika ada) dan cek apakah email tersebut ada di tabel admins
      final user = await _supabaseService.getUserByStravaId(stravaId);
      
      if (user != null) {
        // User exists, cek apakah ada admin dengan email yang sama
        // Tapi karena tabel users tidak punya kolom email, kita perlu pendekatan lain
        
        // Cek semua admin aktif untuk melihat apakah ada yang belum punya strava_id
        // dan cocokkan berdasarkan kriteria lain (misalnya nama atau username)
        final allAdminsResponse = await _supabaseService.client
            .from('admins')
            .select()
            .eq('is_active', true);
        
        // Filter di aplikasi untuk admin yang belum punya strava_id
        final allAdmins = (allAdminsResponse as List)
            .where((admin) => admin['strava_id'] == null)
            .toList();
        
        if (allAdmins.isNotEmpty) {
          // Ada admin yang belum punya strava_id
          // Untuk keamanan, kita hanya link jika admin sudah dikonfigurasi sebelumnya
          // Atau kita bisa menggunakan pendekatan: link ke admin pertama yang belum punya strava_id
          // Tapi ini tidak aman, jadi kita akan return null dan minta admin dikonfigurasi terlebih dahulu
          debugPrint('Found ${allAdmins.length} admin(s) without strava_id, but cannot auto-link for security.');
          return null;
        }
      }
      
      // Step 3: Tidak ada admin yang cocok
      debugPrint('Strava ID $stravaId is not linked to any admin.');
      debugPrint('Please configure admin by linking strava_id to admin email in database.');
      return null;
      
    } catch (e) {
      debugPrint('Admin Strava login error: $e');
      // Re-throw cancellation errors so they can be handled in UI
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('user cancelled') || 
          errorString.contains('user canceled') ||
          errorString.contains('cancel')) {
        rethrow; // Let the UI handle cancellation
      }
      return null;
    }
  }


  Future<void> logout() async {
    _currentAdmin = null;
  }

  Future<Admin?> getCurrentAdmin() async {
    if (_currentAdmin != null) {
      return _currentAdmin;
    }
    return null;
  }
}

