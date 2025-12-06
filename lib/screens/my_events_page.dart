import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/cms_service.dart';
import '../models/event.dart';
import '../models/project.dart';
import '../utils/error_handler.dart';
import 'event_detail.dart';
import 'receipt_detail_screen.dart';
import 'package:intl/intl.dart';

class MyEventsPage extends StatefulWidget {
  const MyEventsPage({super.key});

  @override
  State<MyEventsPage> createState() => _MyEventsPageState();
}

class _MyEventsPageState extends State<MyEventsPage> {
  final SupabaseService _supabaseService = SupabaseService();
  final CmsService _cmsService = CmsService();
  List<Event> _myEvents = [];
  List<Registration> _registrations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMyEvents();
  }

  Future<void> _loadMyEvents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _supabaseService.getCurrentUser();
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please login to view your events'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Get user registrations
      final registrations = await _supabaseService.getUserRegistrations(user.id);
      
      if (registrations.isEmpty) {
        setState(() {
          _registrations = [];
          _myEvents = [];
          _isLoading = false;
        });
        return;
      }

      // Get event details for each registration
      final List<Event> events = [];
      for (final registration in registrations) {
        try {
          final event = await _supabaseService.getEvent(registration.eventId);
          if (event != null) {
            events.add(event);
          }
        } catch (e) {
          print('Error loading event ${registration.eventId}: $e');
        }
      }

      // Sort by registered date (most recent first)
      events.sort((a, b) {
        final regA = registrations.firstWhere((r) => r.eventId == a.id);
        final regB = registrations.firstWhere((r) => r.eventId == b.id);
        return regB.registeredAt.compareTo(regA.registeredAt);
      });

      setState(() {
        _registrations = registrations;
        _myEvents = events;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading my events: $e');
      if (mounted) {
        ErrorHandler.showError(context, e);
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  DateTime? _getRegisteredDate(String eventId) {
    try {
      final registration = _registrations.firstWhere((r) => r.eventId == eventId);
      return registration.registeredAt;
    } catch (e) {
      return null;
    }
  }

  Registration? _getRegistration(String eventId) {
    try {
      return _registrations.firstWhere((r) => r.eventId == eventId);
    } catch (e) {
      return null;
    }
  }

  Future<String?> _getTotalPricePaid(Event event, Registration registration) async {
    try {
      if (event.eventCode == null || event.eventCode!.isEmpty) return null;
      
      final project = await _cmsService.getProjectByEventCode(event.eventCode!);
      if (project == null) return null;
      
      // Get submission data
      final submissions = await _cmsService.getFormSubmissions(
        project.tableName,
        eventCode: event.eventCode,
      );
      
      // Find submission for this user
      Map<String, dynamic>? submissionData;
      for (var submission in submissions) {
        if (submission.containsKey('user_id') && 
            submission['user_id']?.toString() == registration.userId) {
          submissionData = submission;
          break;
        }
      }
      
      // If not found, try to match by date
      if (submissionData == null) {
        for (var submission in submissions) {
          if (submission.containsKey('created_at')) {
            try {
              final submissionDate = DateTime.parse(submission['created_at'].toString());
              final diff = (submissionDate.difference(registration.registeredAt)).abs();
              if (diff.inMinutes < 5) {
                submissionData = submission;
                break;
              }
            } catch (e) {
              // Ignore
            }
          }
        }
      }
      
      // Calculate price
      double? originalPrice;
      if (project.useCategories) {
        // Find category from submission
        String? categoryId;
        if (submissionData != null) {
          if (submissionData.containsKey('category_id')) {
            categoryId = submissionData['category_id']?.toString();
          } else if (submissionData.containsKey('category')) {
            categoryId = submissionData['category']?.toString();
          }
        }
        
        if (categoryId != null) {
          final categories = await _cmsService.getCategories(project.id);
          try {
            final category = categories.firstWhere((c) => c.id == categoryId);
            originalPrice = category.price;
          } catch (e) {
            // Category not found
          }
        }
      } else {
        originalPrice = project.registrationFee;
      }
      
      if (originalPrice == null || originalPrice == 0) return 'Gratis';
      
      // Check for redeem code
      String? redeemCodeUsed;
      if (submissionData != null) {
        if (submissionData.containsKey('redeem_code')) {
          redeemCodeUsed = submissionData['redeem_code']?.toString();
        } else if (submissionData.containsKey('redeem')) {
          redeemCodeUsed = submissionData['redeem']?.toString();
        }
      }
      
      bool usedRedeem = redeemCodeUsed != null && 
                       redeemCodeUsed.isNotEmpty &&
                       project.isValidRedeemCode(redeemCodeUsed);
      
      double finalPrice = originalPrice;
      if (usedRedeem && project.redeemDiscountPercentage != null) {
        final discount = originalPrice * (project.redeemDiscountPercentage! / 100);
        finalPrice = originalPrice - discount;
      }
      
      return 'Rp ${finalPrice.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      )}';
    } catch (e) {
      print('Error getting total price: $e');
      // Don't show error for price calculation, just return null
      return null;
    }
  }

  void _showReceiptDialog(String receiptUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Bukti Pembayaran',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  receiptUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 300,
                      color: Colors.grey.shade900,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 300,
                      color: Colors.grey.shade900,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, color: Colors.red, size: 48),
                            SizedBox(height: 8),
                            Text(
                              'Gagal memuat gambar',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Open URL in browser
                    // url_launcher can be used here if needed
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Tutup',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.41,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Events',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _myEvents.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Belum ada event yang diikuti',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Daftar event yang Anda ikuti akan muncul di sini',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadMyEvents,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _myEvents.length,
                    itemBuilder: (context, index) {
                      final event = _myEvents[index];
                      final registeredDate = _getRegisteredDate(event.id);
                      final registration = _getRegistration(event.id);
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Event Banner/Image (Top - Full Width)
                            ClipRRect(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
                              ),
                              child: event.imageUrl != null && event.imageUrl!.isNotEmpty
                                  ? Image.network(
                                      event.imageUrl!,
                                      width: double.infinity,
                                      height: 150,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          width: double.infinity,
                                          height: 150,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade800,
                                          ),
                                          child: Icon(
                                            Icons.event,
                                            color: Colors.grey.shade600,
                                            size: 40,
                                          ),
                                        );
                                      },
                                    )
                                  : Container(
                                      width: double.infinity,
                                      height: 150,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.green.shade700,
                                            Colors.green.shade900,
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      child: Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: Text(
                                            event.title.toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                            // Event Details and Button (Bottom)
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Event Details (Left)
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'event start date: ${event.startDate != null ? DateFormat('d MMM y • HH:mm').format(event.startDate!) : '-'}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade400,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Id pendaftan: ${registration != null ? registration.id.substring(0, 8).toUpperCase() : '-'}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade400,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        FutureBuilder<String?>(
                                          future: registration != null
                                              ? _getTotalPricePaid(event, registration)
                                              : Future.value(null),
                                          builder: (context, snapshot) {
                                            final totalPrice = snapshot.data ?? '-';
                                            return Text(
                                              'Total: $totalPrice',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade400,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Cek Resi Button (Right)
                                  if (registration != null)
                                    SizedBox(
                                      width: 80,
                                      child: ElevatedButton(
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => ReceiptDetailScreen(
                                                event: event,
                                                registration: registration,
                                              ),
                                            ),
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.black,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: const Text(
                                          'cek resi',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

