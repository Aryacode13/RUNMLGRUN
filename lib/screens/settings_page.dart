import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_service.dart';
import '../services/notification_service.dart';
import 'profile_page.dart';
import 'notifications_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _pushNotificationsEnabled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _pushNotificationsEnabled = prefs.getBool('push_notifications_enabled') ?? true;
      _isLoading = false;
    });
  }

  Future<void> _saveNotificationSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    setState(() {
      if (key == 'notifications_enabled') {
        _notificationsEnabled = value;
      } else if (key == 'push_notifications_enabled') {
        _pushNotificationsEnabled = value;
      }
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Account Section
                  _buildSection(
                    title: 'Account',
                    children: [
                      _buildSettingsTile(
                        icon: Icons.person,
                        title: 'Profile',
                        subtitle: 'Manage your profile information',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ProfilePage(),
                            ),
                          );
                        },
                      ),
                      _buildSettingsTile(
                        icon: Icons.notifications,
                        title: 'Notifications',
                        subtitle: 'View your notifications',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const NotificationsPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  // Notifications Section
                  _buildSection(
                    title: 'Notifications',
                    children: [
                      _buildSwitchTile(
                        icon: Icons.notifications_active,
                        title: 'Enable Notifications',
                        subtitle: 'Receive notifications from the app',
                        value: _notificationsEnabled,
                        onChanged: (value) {
                          _saveNotificationSetting('notifications_enabled', value);
                        },
                      ),
                      if (_notificationsEnabled) ...[
                        _buildSwitchTile(
                          icon: Icons.phone_android,
                          title: 'Push Notifications',
                          subtitle: 'Receive push notifications on your device',
                          value: _pushNotificationsEnabled,
                          onChanged: (value) {
                            _saveNotificationSetting('push_notifications_enabled', value);
                          },
                        ),
                        _buildSettingsTile(
                          icon: Icons.notifications_active,
                          title: 'Test Notification',
                          subtitle: 'Send a test notification to verify it works',
                          onTap: () async {
                            await NotificationService().showNotification(
                              id: 999,
                              title: 'Test Notification',
                              body: 'If you see this, push notifications are working!',
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Test notification sent'),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ],
                  ),

                  // Privacy & Security Section
                  _buildSection(
                    title: 'Privacy & Security',
                    children: [
                      _buildSettingsTile(
                        icon: Icons.lock,
                        title: 'Privacy Policy',
                        subtitle: 'Read our privacy policy',
                        onTap: () {
                          _showComingSoonDialog('Privacy Policy');
                        },
                      ),
                      _buildSettingsTile(
                        icon: Icons.security,
                        title: 'Terms of Service',
                        subtitle: 'Read our terms of service',
                        onTap: () {
                          _showComingSoonDialog('Terms of Service');
                        },
                      ),
                    ],
                  ),

                  // About Section
                  _buildSection(
                    title: 'About',
                    children: [
                      _buildSettingsTile(
                        icon: Icons.info,
                        title: 'App Version',
                        subtitle: 'Version 1.0.0',
                        onTap: null,
                      ),
                      _buildSettingsTile(
                        icon: Icons.help,
                        title: 'Help & Support',
                        subtitle: 'Get help and contact support',
                        onTap: () {
                          _showComingSoonDialog('Help & Support');
                        },
                      ),
                      _buildSettingsTile(
                        icon: Icons.feedback,
                        title: 'Send Feedback',
                        subtitle: 'Share your feedback with us',
                        onTap: () {
                          _showComingSoonDialog('Send Feedback');
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade400,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: children,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: Colors.orange,
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.grey.shade400,
          fontSize: 13,
        ),
      ),
      trailing: onTap != null
          ? Icon(
              Icons.chevron_right,
              color: Colors.grey.shade600,
            )
          : null,
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: Colors.orange,
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.grey.shade400,
          fontSize: 13,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: Colors.orange,
        activeThumbColor: Colors.white,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Future<void> _showComingSoonDialog(String feature) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Text(
          feature,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'This feature is coming soon.',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

