import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../models/user.dart' as models;
import 'dashboard_page.dart';

class CreateProfilePage extends StatefulWidget {
  const CreateProfilePage({super.key});

  @override
  State<CreateProfilePage> createState() => _CreateProfilePageState();
}

class _CreateProfilePageState extends State<CreateProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _isSaving = false;

  final SupabaseService _supabaseService = SupabaseService();

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      print('=== CREATE PROFILE START ===');
      final authUser = Supabase.instance.client.auth.currentUser;
      if (authUser == null) {
        print('ERROR: Auth user is null');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Session expired, please login again'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      print('Auth User ID: ${authUser.id}');
      print('Auth User Email: ${authUser.email}');
      final now = DateTime.now().toIso8601String();

      // Jika username diisi, cek dulu apakah sudah dipakai user lain
      final rawUsername = _usernameController.text.trim();
      final username =
          rawUsername.isEmpty ? null : rawUsername.toLowerCase(); // pakai lower-case untuk konsistensi

      if (username != null) {
        print('Checking username uniqueness: $username');
        final existing = await _supabaseService.client
            .from('users')
            .select('id, username')
            .ilike('username', username)
            .neq('id', authUser.id)
            .maybeSingle();

        if (existing != null) {
          // Username sudah dipakai user lain
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Username sudah dipakai, silakan pilih username lain'),
                backgroundColor: Colors.red,
              ),
            );
          }
          setState(() => _isSaving = false);
          return;
        }
      }

      final data = {
        'id': authUser.id,
        'username': username,
        'firstname': _firstNameController.text.trim(),
        'lastname': _lastNameController.text.trim(),
        'profile_picture': authUser.userMetadata?['avatar_url'],
        'email_users': authUser.email?.toLowerCase().trim(), // Email untuk login email/Google
        'role': 'user',
        'is_active': true,
        'created_at': now,
        'updated_at': now,
      };

      print('Profile data to upsert: $data');

      // Upsert supaya aman kalau row sudah ada setengah jalan
      print('Calling upsert...');
      final response = await _supabaseService.client
          .from('users')
          .upsert(data, onConflict: 'id')
          .select()
          .single();

      print('Upsert response: $response');

      print('Parsing User from JSON...');
      final profile = models.User.fromJson(response);
      print('Profile parsed successfully: ${profile.id}');

      // Simpan juga ke SharedPreferences untuk kompatibilitas lama
      print('Saving user ID to SharedPreferences...');
      await _supabaseService.setCurrentUserId(profile.id);
      print('User ID saved to SharedPreferences');

      if (!mounted) {
        print('Widget not mounted, returning');
        return;
      }

      print('Navigating to DashboardPage...');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DashboardPage()),
        (route) => false,
      );
      print('=== CREATE PROFILE SUCCESS ===');
    } catch (e, stackTrace) {
      print('=== CREATE PROFILE ERROR ===');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      print('=============================');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save profile: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                const Text(
                  'Complete Your Profile',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This data will be used on your dashboard and event registrations.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(
                    labelText: 'First Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _lastNameController,
                  decoration: const InputDecoration(
                    labelText: 'Last Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveProfile,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Save Profile',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


