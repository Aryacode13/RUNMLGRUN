import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/strava_auth_service.dart';
import '../models/activity.dart';
import '../models/user.dart';
import '../widgets/activity_card.dart';
import '../widgets/shimmer_loading.dart';

class ActivitiesPage extends StatefulWidget {
  const ActivitiesPage({super.key});

  @override
  State<ActivitiesPage> createState() => _ActivitiesPageState();
}

class _ActivitiesPageState extends State<ActivitiesPage> {
  final SupabaseService _supabaseService = SupabaseService();
  final StravaAuthService _stravaAuth = StravaAuthService();
  bool _isLoading = true;
  List<Activity> _activities = [];

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    setState(() => _isLoading = true);
    try {
      final User? user = await _supabaseService.getCurrentUser();
      if (user == null) {
        setState(() {
          _activities = [];
          _isLoading = false;
        });
        return;
      }

      // 1) Sync ulang dari Strava ke Supabase (jika punya Strava connection)
      try {
        final stravaUser = await _supabaseService.getStravaUserByUserId(user.id);
        if (stravaUser != null && stravaUser['access_token'] != null) {
          final accessToken = stravaUser['access_token'] as String;
          await _stravaAuth.syncActivitiesToSupabase(
            userId: user.id,
            accessToken: accessToken,
          );
        }
      } catch (e) {
        // Jangan blok UI kalau sync gagal, cukup log / snackbar ringan
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to sync activities from Strava. Please try again.'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }

      // 2) Setelah sync, ambil data terbaru dari Supabase
      final activities = await _supabaseService.getActivities(userId: user.id);
      setState(() {
        _activities = activities;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load activities. Please try again.')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Activities',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadActivities,
        child: _isLoading
            ? const ActivitiesShimmerList()
            : _activities.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 80),
                      Center(child: Text('Belum ada aktivitas')),
                    ],
                  )
                : ListView.builder(
                    itemCount: _activities.length,
                    itemBuilder: (context, index) {
                      return ActivityCard(activity: _activities[index]);
                    },
                  ),
      ),
    );
  }
}



