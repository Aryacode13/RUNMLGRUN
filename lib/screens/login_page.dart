import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/supabase_service.dart';
import 'admin_login_page.dart';
import 'admin_dashboard_page.dart';
import 'otp_verification_page.dart';
import 'dashboard_page.dart';
import 'create_profile_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;
  String? _errorMessage;
  bool _logoPrecached = false;
  int _adminTapCount = 0;
  DateTime? _lastAdminTapAt;

  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final SupabaseService _supabaseService = SupabaseService();

  // Web Client ID Google OAuth (harus sama dengan yang dikonfigurasi di Supabase Provider)
  static const String _googleWebClientId =
      '573601398098-f0rcraakac6n1c4ib5id1rjeobuta12l.apps.googleusercontent.com';

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_logoPrecached) {
      precacheImage(const AssetImage('lib/assets/RMR_W.png'), context);
      _logoPrecached = true;
    }
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();

      final client = Supabase.instance.client;
      await client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: true,
        data: {},
      );

      if (!mounted) return;

      // Navigate to OTP verification page
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpVerificationPage(email: email),
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to send verification code. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }


  Future<void> _loginWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Login ke Google secara native (tanpa redirect_uri)
      final googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        serverClientId: _googleWebClientId,
      );

      // Paksa selalu tampil pilihan akun dengan cara signOut dulu
      // supaya session Google sebelumnya tidak otomatis dipakai
      await googleSignIn.signOut();

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        // User batal memilih akun
        return;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('Unable to get ID token from Google');
      }

      // 2. Kirim ID token ke Supabase (signInWithIdToken)
      final client = Supabase.instance.client;
      final res = await client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: googleAuth.accessToken,
      );

      final authUser = res.user;
      if (authUser == null) {
        throw Exception('Google login successful, but Supabase user not found');
      }

      // Set user sebagai aktif dan simpan id (kompatibel dengan flow email OTP)
      await _supabaseService.setUserLoggedIn(authUser.id);
      await _supabaseService.setCurrentUserId(authUser.id);

      if (!mounted) return;

      // 3. Cek apakah profil user sudah ada di tabel users
      final profile = await client
          .from('users')
          .select('id, firstname, lastname, email_users')
          .eq('id', authUser.id)
          .maybeSingle();

      debugPrint('=== GOOGLE LOGIN SUCCESS ===');
      debugPrint('Auth User ID: ${authUser.id}');
      debugPrint('Email: ${authUser.email}');
      debugPrint('Profile exists in database: ${profile != null}');
      debugPrint('===========================');

      if (profile == null) {
        // User baru → arahkan ke CreateProfilePage untuk melengkapi profil
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const CreateProfilePage()),
          (route) => false,
        );
      } else {
        // User lama → langsung ke Dashboard
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const DashboardPage()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Google login failed';
      });
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
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App logo (tap 7x cepat untuk membuka admin login)
                GestureDetector(
                  onTap: () {
                    final now = DateTime.now();
                    // Reset hitungan jika jeda tap lebih dari 2 detik
                    if (_lastAdminTapAt == null ||
                        now.difference(_lastAdminTapAt!) >
                            const Duration(seconds: 2)) {
                      _adminTapCount = 0;
                    }
                    _lastAdminTapAt = now;
                    _adminTapCount++;

                    if (_adminTapCount >= 7) {
                      _adminTapCount = 0;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AdminLoginPage(),
                        ),
                      );
                    }
                  },
                  child: Image.asset(
                    'lib/assets/RMR_W.png',
                    height: 80,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'RUNMLGRUN!!',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 48),
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Email is required';
                          }
                          if (!v.contains('@')) {
                            return 'Invalid email format';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _loginWithGoogle,
                    icon: const Icon(Icons.login),
                    label: const Text(
                      'Sign in with Google',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const AdminDashboardPage(),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.admin_panel_settings,
                        size: 16,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Go to Admin Dashboard (Test)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Tombol-tombol test lama dihapus supaya flow lebih bersih
              ],
            ),
          ),
        ),
      ),
    );
  }
}

