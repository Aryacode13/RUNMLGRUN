import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';
import '../models/project.dart';
import '../models/category.dart';
import '../models/user.dart';
import '../services/supabase_service.dart';
import '../services/cms_service.dart';
import '../utils/error_handler.dart';

class ReceiptDetailScreen extends StatefulWidget {
  final Event event;
  final Registration registration;

  const ReceiptDetailScreen({
    super.key,
    required this.event,
    required this.registration,
  });

  @override
  State<ReceiptDetailScreen> createState() => _ReceiptDetailScreenState();
}

class _ReceiptDetailScreenState extends State<ReceiptDetailScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final CmsService _cmsService = CmsService();
  bool _isLoading = true;
  User? _user;
  Project? _project;
  Category? _selectedCategory;
  Map<String, dynamic>? _submissionData;
  String? _redeemCodeUsed;
  double? _originalPrice;
  double? _discountAmount;
  double? _finalPrice;

  @override
  void initState() {
    super.initState();
    _loadReceiptData();
  }

  Future<void> _loadReceiptData() async {
    try {
      // Load user data
      final user = await _supabaseService.getUser(widget.registration.userId);
      
      // Load project from event code
      Project? project;
      if (widget.event.eventCode != null && widget.event.eventCode!.isNotEmpty) {
        project = await _cmsService.getProjectByEventCode(widget.event.eventCode!);
      }

      // Load submission data to get category and redeem code
      Map<String, dynamic>? submissionData;
      Category? selectedCategory;
      String? redeemCodeUsed;
      
      if (project != null) {
        try {
          final submissions = await _cmsService.getFormSubmissions(
            project.tableName,
            eventCode: widget.event.eventCode,
          );
          
          // Find submission for this user
          for (var submission in submissions) {
            // Try to match by user_id or username
            if (submission.containsKey('user_id') && 
                submission['user_id']?.toString() == widget.registration.userId) {
              submissionData = submission;
              break;
            }
          }
          
          // If not found by user_id, try to find by matching registration date
          if (submissionData == null) {
            // Get all submissions and try to match
            for (var submission in submissions) {
              // Check if submission has created_at that matches registration date
              if (submission.containsKey('created_at')) {
                try {
                  final submissionDate = DateTime.parse(submission['created_at'].toString());
                  final diff = (submissionDate.difference(widget.registration.registeredAt)).abs();
                  if (diff.inMinutes < 5) { // Within 5 minutes
                    submissionData = submission;
                    break;
                  }
                } catch (e) {
                  // Ignore parse errors
                }
              }
            }
          }
          
          // Extract category and redeem code from submission
          if (submissionData != null) {
            // Find category
            if (project.useCategories) {
              // Look for category_id or category field
              String? categoryId;
              if (submissionData.containsKey('category_id')) {
                categoryId = submissionData['category_id']?.toString();
              } else if (submissionData.containsKey('category')) {
                categoryId = submissionData['category']?.toString();
              }
              
              if (categoryId != null) {
                final categories = await _cmsService.getCategories(project.id);
                try {
                  selectedCategory = categories.firstWhere((c) => c.id == categoryId);
                } catch (e) {
                  // Category not found
                }
              }
            }
            
            // Find redeem code
            if (submissionData.containsKey('redeem_code')) {
              redeemCodeUsed = submissionData['redeem_code']?.toString();
            } else if (submissionData.containsKey('redeem')) {
              redeemCodeUsed = submissionData['redeem']?.toString();
            }
          }
          
          // Load categories if project uses categories
          if (project.useCategories && selectedCategory == null) {
            final categories = await _cmsService.getCategories(project.id);
            // Try to find category from submission data by name
            if (submissionData != null) {
              for (var key in submissionData.keys) {
                if (key.toLowerCase().contains('category')) {
                  final value = submissionData[key]?.toString();
                  if (value != null) {
                    try {
                      selectedCategory = categories.firstWhere(
                        (c) => c.name.toLowerCase() == value.toLowerCase(),
                      );
                      break;
                    } catch (e) {
                      // Not found
                    }
                  }
                }
              }
            }
          }
        } catch (e) {
          print('Error loading submission data: $e');
        }
      }
      
      // Calculate prices
      double? originalPrice;
      double? discountAmount;
      double? finalPrice;
      
      if (project != null) {
        if (project.useCategories && selectedCategory != null) {
          originalPrice = selectedCategory.price;
        } else {
          originalPrice = project.registrationFee;
        }
        
        if (originalPrice != null && originalPrice > 0) {
          // Check if redeem code was used
          bool usedRedeem = redeemCodeUsed != null && 
                           redeemCodeUsed.isNotEmpty &&
                           project.isValidRedeemCode(redeemCodeUsed);
          
          if (usedRedeem && project.redeemDiscountPercentage != null) {
            discountAmount = originalPrice * (project.redeemDiscountPercentage! / 100);
            finalPrice = originalPrice - discountAmount!;
          } else {
            finalPrice = originalPrice;
          }
        } else {
          finalPrice = 0;
        }
      }
      
      if (mounted) {
        setState(() {
          _user = user;
          _project = project;
          _selectedCategory = selectedCategory;
          _submissionData = submissionData;
          _redeemCodeUsed = redeemCodeUsed;
          _originalPrice = originalPrice;
          _discountAmount = discountAmount;
          _finalPrice = finalPrice;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading receipt data: $e');
      if (mounted) {
        ErrorHandler.showError(context, e);
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatPrice(double? price) {
    if (price == null || price == 0) return 'Gratis';
    return 'Rp ${price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Resi Pembayaran',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Receipt Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'RESI PEMBAYARAN',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                      letterSpacing: 1.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'No. ${widget.registration.id.substring(0, 8).toUpperCase()}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade400,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.receipt_long,
                              color: Colors.orange,
                              size: 40,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Divider(color: Colors.grey, height: 1),
                        const SizedBox(height: 24),
                        
                        // Nama Pendaftar
                        _buildReceiptRow(
                          'Nama Pendaftar',
                          widget.registration.username ?? _user?.username ?? 'Tidak diketahui',
                        ),
                        const SizedBox(height: 16),
                        
                        // ID User
                        _buildReceiptRow(
                          'ID User',
                          widget.registration.userId.substring(0, 8).toUpperCase(),
                        ),
                        const SizedBox(height: 16),
                        
                        // Nama Event
                        _buildReceiptRow(
                          'Nama Event',
                          widget.event.title,
                        ),
                        const SizedBox(height: 16),
                        
                        // Category (jika ada)
                        if (_project?.useCategories == true && _selectedCategory != null) ...[
                          _buildReceiptRow(
                            'Category',
                            _selectedCategory!.name,
                          ),
                          const SizedBox(height: 16),
                        ],
                        
                        // Jam Pendaftaran
                        _buildReceiptRow(
                          'Jam Pendaftaran',
                          DateFormat('d MMMM y • HH:mm').format(widget.registration.registeredAt),
                        ),
                        const SizedBox(height: 16),
                        
                        // Jam Event Mulai
                        if (widget.event.startDate != null) ...[
                          _buildReceiptRow(
                            'Jam Event Mulai',
                            DateFormat('d MMMM y • HH:mm').format(widget.event.startDate!),
                          ),
                          const SizedBox(height: 16),
                        ],
                        
                        const Divider(color: Colors.grey, height: 1),
                        const SizedBox(height: 24),
                        
                        // Price Details
                        if (_originalPrice != null && _originalPrice! > 0) ...[
                          _buildReceiptRow(
                            'Harga',
                            _formatPrice(_originalPrice),
                            valueColor: Colors.white,
                          ),
                          const SizedBox(height: 12),
                          
                          // Discount (jika ada)
                          if (_discountAmount != null && _discountAmount! > 0) ...[
                            _buildReceiptRow(
                              'Potongan Harga',
                              '-${_formatPrice(_discountAmount)}',
                              valueColor: Colors.green.shade300,
                            ),
                            if (_redeemCodeUsed != null && _redeemCodeUsed!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Kode: $_redeemCodeUsed',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade400,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                          ],
                          
                          const Divider(color: Colors.grey, height: 1),
                          const SizedBox(height: 16),
                          
                          // Total Harga
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  'Total Harga',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  _formatPrice(_finalPrice),
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  'Total Harga',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  'Gratis',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade300,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        ],
                        
                        // Payment Receipt Image (jika ada)
                        if (widget.registration.paymentReceiptUrl != null &&
                            widget.registration.paymentReceiptUrl!.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          const Divider(color: Colors.grey, height: 1),
                          const SizedBox(height: 24),
                          Text(
                            'Bukti Pembayaran',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              widget.registration.paymentReceiptUrl!,
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  height: 200,
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
                                  height: 200,
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
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade400,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: valueColor ?? Colors.white,
            ),
            textAlign: TextAlign.right,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

