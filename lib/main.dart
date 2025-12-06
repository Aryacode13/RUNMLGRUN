import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/supabase_service.dart';
import 'services/strava_auth_service.dart';
import 'services/cms_service.dart';
import 'services/notification_service.dart';
import 'screens/login_page.dart';
import 'screens/dashboard_page.dart';
import 'screens/splash_screen.dart';
import 'screens/create_profile_page.dart';

// Background message handler MUST be top-level function
// This handles FCM messages when app is in background or terminated
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase in background isolate
  await Firebase.initializeApp();
  
  print('📬 [BACKGROUND] Message received: ${message.messageId}');
  print('📬 [BACKGROUND] Title: ${message.notification?.title}');
  print('📬 [BACKGROUND] Body: ${message.notification?.body}');
  print('📬 [BACKGROUND] Data: ${message.data}');
  
  // Show notification using static method
  await NotificationService.firebaseMessagingBackgroundHandler(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Lock orientation to portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  try {
    // Initialize Supabase
    final supabaseUrl = 'https://icphxtjmdmwesduxkxvx.supabase.co';
    final supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImljcGh4dGptZG13ZXNkdXhreHZ4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQzMDg2NzYsImV4cCI6MjA3OTg4NDY3Nn0.ZjwHCZSm27qbPBJPxfolEmeimhQrM0IQrXs7LuNlnYU';

    final supabaseService = SupabaseService();
    await supabaseService.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );

    // Initialize CMS Service
    CmsService().initialize(supabaseService.client);

    // Configure Strava OAuth
    final stravaClientId = '187485';
    final stravaClientSecret = '6d6dee26c3d13bf69f5108152a9602723fbd59fe';

    StravaAuthService().configure(
      clientId: stravaClientId,
      clientSecret: stravaClientSecret,
      redirectUri: 'http://localhost', // Must match Strava settings
    );

    // Initialize Firebase FIRST (required for FCM)
    try {
      await Firebase.initializeApp();
      print('✅ Firebase initialized in main()');
      
      // Register background message handler BEFORE runApp()
      // This MUST be done at top-level, before runApp()
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      print('✅ Background message handler registered');
    } catch (e) {
      print('⚠️ Firebase initialization error: $e');
    }

    // Initialize Notification Service
    // Note: Firebase must be initialized first for FCM to work
    // If Firebase is not configured, local notifications will still work
    await NotificationService().initialize();
  } catch (e) {
    print('Error initializing app: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RMR CMS',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF000000),
        canvasColor: const Color(0xFF000000),
        cardColor: const Color(0xFF1C1C1E), // iOS dark gray
        primaryColor: Colors.orange,
        // iOS-style AppBar
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF000000).withOpacity(0.8),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.41,
          ),
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange,
          brightness: Brightness.dark,
          primary: Colors.orange,
          secondary: Colors.orangeAccent,
          background: const Color(0xFF000000),
          surface: const Color(0xFF1C1C1E),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onBackground: Colors.white,
          onSurface: Colors.white,
        ),
        // iOS-style Typography
        textTheme: const TextTheme(
          bodyLarge: TextStyle(
            color: Colors.white,
            fontSize: 17,
            letterSpacing: -0.41,
            height: 1.29,
          ),
          bodyMedium: TextStyle(
            color: Color(0xFFEBEBF5),
            fontSize: 15,
            letterSpacing: -0.24,
            height: 1.33,
          ),
          bodySmall: TextStyle(
            color: Color(0xFFEBEBF5),
            fontSize: 13,
            letterSpacing: -0.08,
            height: 1.38,
          ),
          titleLarge: TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.37,
            height: 1.12,
          ),
          titleMedium: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.36,
            height: 1.14,
          ),
          titleSmall: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.35,
            height: 1.27,
          ),
          labelLarge: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.41,
          ),
        ),
        // iOS-style Buttons (more rounded)
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14), // iOS style
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            textStyle: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.41,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.orange,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.41,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.orange,
            side: const BorderSide(color: Colors.orange, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            textStyle: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.41,
            ),
          ),
        ),
        // iOS-style Input Fields
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1C1C1E),
          labelStyle: const TextStyle(
            color: Color(0xFF8E8E93),
            fontSize: 17,
            letterSpacing: -0.41,
          ),
          hintStyle: const TextStyle(
            color: Color(0xFF8E8E93),
            fontSize: 17,
            letterSpacing: -0.41,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.orange, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        iconTheme: const IconThemeData(
          color: Colors.orange,
        ),
        // iOS-style Card
        cardTheme: CardThemeData(
          color: const Color(0xFF1C1C1E),
          elevation: 0,
          shadowColor: Colors.black.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16), // iOS style
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        // iOS-style Chip
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFF1C1C1E),
          selectedColor: Colors.orange,
          disabledColor: const Color(0xFF2C2C2E),
          labelStyle: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.08,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        // iOS-style ListTile
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          minVerticalPadding: 0,
        ),
        // iOS-style Divider
        dividerTheme: DividerThemeData(
          color: const Color(0xFF38383A),
          thickness: 0.5,
          space: 1,
        ),
      ),
      home: const SplashScreen(
        nextScreen: AuthWrapper(),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = true;
  Widget? _target;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    try {
      final client = _supabaseService.client;
      final authUser = client.auth.currentUser;

      // Jika tidak ada auth user, coba pakai is_active di tabel users
      if (authUser == null) {
        print('=== AUTH CHECK (NO AUTH USER) ===');
        print('No auth user from Supabase Auth, trying is_active users...');

        // Gunakan SupabaseService.getCurrentUser()
        // Fungsi ini sudah menggunakan kolom is_active dan SharedPreferences
        final activeUser = await _supabaseService.getCurrentUser();

        if (activeUser != null && activeUser.isActive) {
          // Jika ada user dengan is_active = true → langsung ke Dashboard
          print('Found active user via is_active: ${activeUser.id}, go to Dashboard');
          setState(() {
            _target = const DashboardPage();
            _isLoading = false;
          });
          return;
        }

        print('No active user found, go to LoginPage');
        setState(() {
          _target = const LoginPage();
          _isLoading = false;
        });
        return;
      }

      // Jika ada auth user, cek apakah profil sudah ada di database
      // Flow yang benar: LoginPage >> Login Email >> OTP >> Validasi Database >> Dashboard atau Create Profile
      // Catatan: CreateProfilePage HANYA diakses setelah OTP berhasil, bukan dari AuthWrapper
      final profile = await client
          .from('users')
          .select(
              'id, username, firstname, lastname, profile_picture, email_users, role, is_active, created_at, updated_at')
          .eq('id', authUser.id)
          .maybeSingle();

      print('=== AUTH CHECK ===');
      print('Auth User ID: ${authUser.id}');
      print('Email: ${authUser.email}');
      print('Email Verified: ${authUser.emailConfirmedAt != null}');
      print('Profile exists in database: ${profile != null}');
      print('is_active (from users): ${profile != null ? profile['is_active'] : null}');
      print('==================');

      // Jika profil belum ada di database → arahkan ke CreateProfilePage
      // Berlaku untuk user baru (email OTP atau Google) yang belum melengkapi profil
      if (profile == null) {
        print('Profile not found, redirecting to CreateProfilePage');
        setState(() {
          _target = const CreateProfilePage();
          _isLoading = false;
        });
        return;
      }

      // Jika profil ada tapi is_active = false, perlakukan sebagai logout
      if (profile['is_active'] == false) {
        print('User profile found but is_active = false. Signing out and redirecting to LoginPage');
        try {
          // Set is_active = false (untuk memastikan konsistensi)
          await _supabaseService.setUserLoggedOut(authUser.id);
          await client.auth.signOut();
        } catch (e) {
          print('Auth signout error (ignored): $e');
        }

        setState(() {
          _target = const LoginPage();
          _isLoading = false;
        });
        return;
      }

      setState(() {
        // Jika profil sudah ada di database dan is_active = true → DashboardPage
        print('Profile found and active, redirecting to DashboardPage');
        _target = const DashboardPage();
        _isLoading = false;
      });
    } catch (e) {
      print('Error checking auth: $e');
      setState(() {
        _target = const LoginPage();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return _target ?? const LoginPage();
  }
}

