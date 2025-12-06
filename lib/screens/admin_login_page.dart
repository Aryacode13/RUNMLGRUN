import 'package:flutter/material.dart';
import '../services/admin_auth_service.dart';
import '../models/admin.dart';
import 'admin_dashboard_page.dart';
import 'login_page.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _loginWithStrava() async {
    if (_isLoading) {
      // Prevent multiple simultaneous login attempts
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final adminAuth = AdminAuthService();
      
      // Login dengan Strava - email akan dicocokkan otomatis dari tabel admins
      Admin? admin = await adminAuth.loginWithStrava(context);
      
      if (admin != null) {
        // Login successful
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const AdminDashboardPage(),
            ),
          );
        }
        return;
      }
      
      // Login failed - Strava ID tidak terdaftar sebagai admin
      // Tapi jangan tampilkan error jika user membatalkan login
      if (mounted) {
        setState(() {
          _errorMessage = 'Your Strava account is not registered as an admin. Please contact the administrator for access.';
          _isLoading = false;
        });
      }
    } catch (e) {
      // Check if error is due to user cancellation
      final errorString = e.toString().toLowerCase();
      final isCancelled = errorString.contains('cancel') || 
                         errorString.contains('dismiss') ||
                         errorString.contains('user cancelled') ||
                         errorString.contains('user canceled') ||
                         errorString.contains('navigation') ||
                         errorString.contains('pop');
      
      print('=== ADMIN LOGIN ERROR ===');
      print('Error: $e');
      print('Is cancelled: $isCancelled');
      print('=======================');
      
      if (mounted) {
        setState(() {
          // Don't show error if user cancelled the login
          if (isCancelled) {
            _errorMessage = null;
          } else {
            _errorMessage = 'Login failed: ${e.toString()}';
          }
          // Always reset loading state in catch block too
          _isLoading = false;
        });
      }
    } finally {
      // Always reset loading state, even if user cancels
      // This is a safety net in case catch block doesn't execute
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      print('=== ADMIN LOGIN FINALLY ===');
      print('Loading state reset to: false');
      print('===========================');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.orange.shade400,
              Colors.orange.shade600,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo/Icon
                      const Icon(
                        Icons.admin_panel_settings,
                        size: 64,
                        color: Colors.orange,
                      ),
                      const SizedBox(height: 16),
                      
                      // Title
                      Text(
                        'Admin Login',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Login with Strava to access admin panel',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      // Error message
                      if (_errorMessage != null)
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
                              Icon(Icons.error_outline, color: Colors.red.shade700),
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

                      // Login with Strava button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _loginWithStrava,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.login),
                                    SizedBox(width: 8),
                                    Text(
                                      'Login with Strava',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),

                      // Back to user login
                      TextButton(
                        onPressed: () {
                          // Pindah ke halaman login user dan bersihkan semua route admin
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const LoginPage(),
                            ),
                            (route) => false,
                          );
                        },
                        child: Text(
                          'Back to User Login',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
