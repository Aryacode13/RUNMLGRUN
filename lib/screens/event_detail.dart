import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/cms_service.dart';
import '../models/event.dart';
import '../models/user.dart';
import '../models/project.dart';
import '../models/category.dart';
import 'public/public_form.dart';
import 'package:intl/intl.dart';

class EventDetailPage extends StatefulWidget {
  final Event event;

  const EventDetailPage({
    super.key,
    required this.event,
  });

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  final SupabaseService _supabaseService = SupabaseService();
  final CmsService _cmsService = CmsService();
  bool _isLoading = false;
  bool _isRegistered = false;
  User? _currentUser;
  Event? _currentEvent;
  Project? _registrationForm;
  List<Category> _categories = [];

  @override
  void initState() {
    super.initState();
    _currentEvent = widget.event;
    _checkRegistration();
    _loadRegistrationForm();
  }

  Future<void> _loadRegistrationForm() async {
    if (_currentEvent?.eventCode == null || _currentEvent!.eventCode!.isEmpty) {
      return;
    }

    try {
      final project = await _cmsService.getProjectByEventCode(_currentEvent!.eventCode!);
      if (mounted) {
        setState(() {
          _registrationForm = project;
        });
        
        // Load categories if project uses categories
        if (project != null && project.useCategories) {
          final categories = await _cmsService.getCategories(project.id);
          if (mounted) {
            setState(() {
              _categories = categories;
            });
          }
        }
      }
    } catch (e) {
      print('Error loading registration form: $e');
    }
  }

  Future<void> _checkRegistration() async {
    try {
      final user = await _supabaseService.getCurrentUser();
      if (user != null) {
        _currentUser = user;
        final registered = await _supabaseService.isRegistered(
          widget.event.id,
          user.id,
        );
        setState(() {
          _isRegistered = registered;
        });
      }

      // Refresh event data to get latest stats
      final updatedEvent = await _supabaseService.getEvent(widget.event.id);
      if (updatedEvent != null) {
        setState(() {
          _currentEvent = updatedEvent;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _register() async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login first')),
      );
      return;
    }

    if (_currentEvent == null || !_currentEvent!.canRegister) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot register for this event')),
      );
      return;
    }

    // Mulai sekarang: event WAJIB punya event_code yang valid
    if (_currentEvent!.eventCode == null || _currentEvent!.eventCode!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Event ini belum terhubung ke form pendaftaran'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Event punya event_code yang valid, arahkan ke form pendaftaran
    try {
      // Cek apakah form dengan event_code ini ada
      final project = await _cmsService.getProjectByEventCode(_currentEvent!.eventCode!);
      if (project == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Form pendaftaran tidak ditemukan'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (project.status != 'published') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Form pendaftaran belum dipublish'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Navigate ke form pendaftaran
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PublicFormScreen(eventCode: _currentEvent!.eventCode!),
        ),
      );

      // Setelah kembali dari form, refresh event data
      if (mounted && result == true) {
        await _checkRegistration();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _unregister() async {
    if (_currentUser == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _supabaseService.unregisterFromEvent(
        _currentEvent!.id,
        _currentUser!.id,
      );
      await _checkRegistration();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully unregistered'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to unregister: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Check if registration button should be disabled
  bool _shouldDisableRegister() {
    final event = _currentEvent ?? widget.event;
    
    // Basic checks: loading, event not active, or event full
    if (_isLoading || !event.canRegister) {
      return true; // Disable button
    }

    // Mulai sekarang: event WAJIB terhubung ke form (punya event_code)
    if (event.eventCode == null || event.eventCode!.isEmpty) {
      return true; // Disable button - belum terhubung ke form
    }
    
    // If event has event_code, form must be available and published
    if (event.eventCode != null && event.eventCode!.isNotEmpty) {
      if (_registrationForm == null) {
        return true; // Disable button - form not found
      }
      if (_registrationForm!.status != 'published') {
        return true; // Disable button - form not published
      }
    }
    
    // All checks passed, button can be enabled
    return false; // Enable button
  }

  /// Get the text for the register button
  String _getRegisterButtonText() {
    final event = _currentEvent ?? widget.event;
    
    if (event.isFull) {
      return 'Event Full';
    }

    // Jika event belum terhubung ke form
    if (event.eventCode == null || event.eventCode!.isEmpty) {
      return 'Pendaftaran belum dibuka';
    }
    
    // If event has event_code but form is not available
    if (event.eventCode != null && 
        event.eventCode!.isNotEmpty && 
        _registrationForm == null) {
      return 'Daftar';
    }
    
    // If event has event_code but form is not published
    if (event.eventCode != null && 
        event.eventCode!.isNotEmpty && 
        _registrationForm != null &&
        _registrationForm!.status != 'published') {
      return 'Daftar';
    }
    
    return 'Daftar';
  }

  @override
  Widget build(BuildContext context) {
    final event = _currentEvent ?? widget.event;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Event Details',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: event.isActive
                          ? Colors.green.shade100
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      event.isActive ? 'ACTIVE' : 'INACTIVE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: event.isActive
                            ? Colors.green.shade900
                            : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Event Schedule (if active and has startDate)
              if (event.isActive && event.startDate != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange, width: 2),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event,
                        size: 28,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Event Schedule',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('EEEE, d MMMM y').format(event.startDate!),
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('HH:mm WIB').format(event.startDate!),
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              // Registration Fee or Categories
              if (_registrationForm != null) ...[
                // If using categories, show categories with prices
                if (_registrationForm!.useCategories && _categories.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200, width: 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.category,
                              size: 28,
                              color: Colors.orange.shade700,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Biaya Pendaftaran per Category',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ..._categories.map((category) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade100,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(
                                        Icons.label,
                                        size: 16,
                                        color: Colors.orange.shade700,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      category.name,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  category.formattedPrice,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade900,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ]
                // If not using categories, show regular registration fee
                else if (!_registrationForm!.useCategories) ...[
                  if (_registrationForm!.registrationFee != null && 
                      _registrationForm!.registrationFee! > 0) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200, width: 2),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.attach_money,
                            size: 32,
                            color: Colors.orange.shade700,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Biaya Pendaftaran',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.orange.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _registrationForm!.formattedPrice,
                                  style: TextStyle(
                                    fontSize: 20,
                                    color: Colors.orange.shade900,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 24,
                            color: Colors.green.shade700,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Pendaftaran Gratis',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.green.shade900,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ],
              ],
              // Redeem Code Info (if event has registration form with redeem codes)
              if (_registrationForm != null && 
                  _registrationForm!.redeemCode != null && 
                  _registrationForm!.redeemCode!.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.confirmation_number,
                        size: 24,
                        color: Colors.purple.shade700,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kode Redeem Tersedia',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.purple.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _registrationForm!.redeemDiscountPercentage != null && _registrationForm!.redeemDiscountPercentage! > 0
                                  ? 'Gunakan kode redeem untuk mendapatkan diskon ${_registrationForm!.redeemDiscountPercentage!.toStringAsFixed(0)}%'
                                  : 'Gunakan kode redeem saat pendaftaran',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.purple.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              if (event.description != null && event.description!.isNotEmpty) ...[
                const Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  event.description!,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 24),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Quota',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${event.totalRegistered ?? 0} / ${event.quota}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Remaining',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${event.remainingQuota ?? event.quota}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: event.isFull
                                  ? Colors.red
                                  : Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Created: ${DateFormat('MMMM d, y • h:mm a').format(event.createdAt)}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 32),
              // Pesan permanen di bawah detail:
              // - Jika event BELUM dihubungkan ke form (event_code kosong)
              // - Jika event sudah punya event_code tapi form belum ada
              // - Jika event sudah punya form tapi belum dipublish
              if (event.eventCode == null || event.eventCode!.isEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.link_off,
                        size: 24,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Form pendaftaran belum dihubungkan',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else if (event.eventCode != null && event.eventCode!.isNotEmpty) ...[
                if (_registrationForm == null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning,
                          size: 24,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Form pendaftaran belum tersedia',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else if (_registrationForm != null &&
                    _registrationForm!.status != 'published') ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 24,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Form pendaftaran belum dibuka',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
              SizedBox(
                width: double.infinity,
                height: 50,
                child: _isRegistered
                    ? OutlinedButton(
                        onPressed: _isLoading ? null : _unregister,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text(
                                'Unregister',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      )
                    : ElevatedButton(
                        onPressed: _shouldDisableRegister()
                            ? null
                            : _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
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
                            : Text(
                                _getRegisterButtonText(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

