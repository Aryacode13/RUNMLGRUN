import 'package:flutter/material.dart';
import '../../services/cms_service.dart';
import '../../models/project.dart';
import '../../models/category.dart';
import '../../widgets/form_renderer.dart';

class PublicFormScreen extends StatefulWidget {
  final String eventCode;

  const PublicFormScreen({super.key, required this.eventCode});

  @override
  State<PublicFormScreen> createState() => _PublicFormScreenState();
}

class _PublicFormScreenState extends State<PublicFormScreen> {
  final CmsService _cmsService = CmsService();
  Project? _project;
  List<Category> _categories = [];
  String? _selectedCategoryId; // Single selection
  final Map<String, dynamic> _formData = {};
  final _redeemCodeController = TextEditingController();
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _redeemCodeValid = false;

  @override
  void initState() {
    super.initState();
    _loadProject();
  }

  @override
  void dispose() {
    _redeemCodeController.dispose();
    super.dispose();
  }


  Future<void> _loadProject() async {
    try {
      final project = await _cmsService.getProjectByEventCode(widget.eventCode);
      if (project == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Form not found')),
          );
          Navigator.pop(context);
        }
        return;
      }

      if (project.status != 'published') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This form is not published yet')),
          );
          Navigator.pop(context);
        }
        return;
      }

      // Load categories
      final categories = await _cmsService.getCategories(project.id);

      setState(() {
        _project = project;
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load form. Please try again.')),
        );
      }
    }
  }

  double? _getTotalPrice() {
    if (_project == null) return null;
    
    // If project uses categories, only use category price
    if (_project!.useCategories) {
      if (_selectedCategoryId == null) return null;
      final category = _categories.firstWhere((c) => c.id == _selectedCategoryId);
      return category.price > 0 ? category.price : null;
    }
    
    // If not using categories, use registration fee
    return _project!.registrationFee;
  }

  Category? _getSelectedCategory() {
    if (_categories.isEmpty || _selectedCategoryId == null) return null;
    return _categories.firstWhere((c) => c.id == _selectedCategoryId);
  }

  String _getFormattedPrice() {
    final price = _getTotalPrice();
    if (price == null || price == 0) return 'Gratis';
    
    double finalPrice = price;
    
    // Apply redeem discount if valid
    if (_redeemCodeValid && _project!.redeemDiscountPercentage != null && _project!.redeemDiscountPercentage! > 0) {
      final discount = price * (_project!.redeemDiscountPercentage! / 100);
      finalPrice = price - discount;
    }
    
    return 'Rp ${finalPrice.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}';
  }

  String? _getOriginalFormattedPrice() {
    final price = _getTotalPrice();
    if (price == null || price == 0) return null;
    
    if (_redeemCodeValid && _project!.redeemDiscountPercentage != null && _project!.redeemDiscountPercentage! > 0) {
      return 'Rp ${price.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      )}';
    }
    
    return null;
  }

  double? _getDiscountAmount() {
    final price = _getTotalPrice();
    if (price == null || price == 0) return null;
    if (!_redeemCodeValid || _project!.redeemDiscountPercentage == null || _project!.redeemDiscountPercentage! <= 0) return null;
    return price * (_project!.redeemDiscountPercentage! / 100);
  }

  Future<void> _submitForm() async {
    if (_project == null) return;

    // If project uses categories, require a category to be selected
    if (_project!.useCategories && _categories.isNotEmpty && _selectedCategoryId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Silakan pilih kategori terlebih dahulu'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // Validate redeem code if provided
    if (_redeemCodeController.text.trim().isNotEmpty) {
      if (!_project!.isValidRedeemCode(_redeemCodeController.text.trim())) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid redeem code. Please check and try again.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      // Submit form data (redeem code is only for discount calculation, not stored in form data)
      await _cmsService.submitFormData(
        tableName: _project!.tableName,
        data: _formData,
        projectId: _project!.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Form submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Return true to indicate successful submission
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting form: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Loading Form...',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.blueGrey,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_project == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Form Not Found',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.blueGrey,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Form not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _project!.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      body: _isSubmitting
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Sticky section: Registration fee and redeem code
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Display registration fee or category prices
                      if (_project!.useCategories) ...[
                        // If using categories, show category price when selected
                        if (_selectedCategoryId != null && _getTotalPrice() != null && _getTotalPrice()! > 0)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade200, width: 1.5),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.category,
                                  size: 20,
                                  color: Colors.orange.shade700,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'Biaya: ',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.orange.shade700,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          if (_getSelectedCategory() != null)
                                            Text(
                                              _getSelectedCategory()!.name,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey.shade800,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Text(
                                            _getFormattedPrice(),
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orange.shade900,
                                            ),
                                          ),
                                          if (_getOriginalFormattedPrice() != null) ...[
                                            const SizedBox(width: 6),
                                            Text(
                                              _getOriginalFormattedPrice()!,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade600,
                                                decoration: TextDecoration.lineThrough,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade100,
                                                borderRadius: BorderRadius.circular(3),
                                              ),
                                              child: Text(
                                                '-${_project!.redeemDiscountPercentage!.toStringAsFixed(0)}%',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.green.shade900,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      if (_getDiscountAmount() != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'Hemat Rp ${_getDiscountAmount()!.toStringAsFixed(0).replaceAllMapped(
                                            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                            (Match m) => '${m[1]},',
                                          )}!',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.green.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (_selectedCategoryId == null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200, width: 1.5),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: Colors.blue.shade700,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Pilih kategori untuk melihat harga',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.blue.shade900,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ] else ...[
                        // If not using categories, show regular registration fee
                        if (_getTotalPrice() != null && _getTotalPrice()! > 0)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade200, width: 1.5),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.attach_money,
                                  size: 20,
                                  color: Colors.orange.shade700,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Biaya Pendaftaran',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.orange.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Text(
                                            _getFormattedPrice(),
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.orange.shade900,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (_getOriginalFormattedPrice() != null) ...[
                                            const SizedBox(width: 6),
                                            Text(
                                              _getOriginalFormattedPrice()!,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade600,
                                                decoration: TextDecoration.lineThrough,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade100,
                                                borderRadius: BorderRadius.circular(3),
                                              ),
                                              child: Text(
                                                '-${_project!.redeemDiscountPercentage!.toStringAsFixed(0)}%',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.green.shade900,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      if (_getDiscountAmount() != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'Hemat Rp ${_getDiscountAmount()!.toStringAsFixed(0).replaceAllMapped(
                                            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                            (Match m) => '${m[1]},',
                                          )}!',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.green.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade200, width: 1.5),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 16,
                                  color: Colors.green.shade700,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Pendaftaran Gratis',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green.shade900,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                      // Redeem Code Input (if project has redeem codes)
                      if (_project!.redeemCode != null && _project!.redeemCode!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _redeemCodeValid 
                                  ? Colors.green.shade300 
                                  : Colors.purple.shade200,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.confirmation_number,
                                    size: 16,
                                    color: Colors.purple.shade700,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Kode Redeem (Opsional)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.purple.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _redeemCodeController,
                                      // Teks yang diketik user menjadi hitam
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.black,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Masukkan kode',
                                        hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(6),
                                          borderSide: BorderSide(color: Colors.grey.shade300),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(6),
                                          borderSide: BorderSide(color: Colors.grey.shade300),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(6),
                                          borderSide: BorderSide(color: Colors.purple.shade300),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        suffixIcon: _redeemCodeController.text.isNotEmpty && _redeemCodeValid
                                            ? Icon(
                                                Icons.check_circle,
                                                size: 18,
                                                color: Colors.green,
                                              )
                                            : null,
                                        filled: true,
                                        fillColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      if (_project == null) return;
                                      final code = _redeemCodeController.text.trim();
                                      
                                      if (code.isEmpty) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Masukkan kode redeem terlebih dahulu'),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                        return;
                                      }
                                      
                                      final isValid = _project!.isValidRedeemCode(code);
                                      setState(() {
                                        _redeemCodeValid = isValid;
                                      });
                                      
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              isValid 
                                                  ? 'Kode redeem valid! Diskon ${_project!.redeemDiscountPercentage?.toStringAsFixed(0) ?? 0}% diterapkan.'
                                                  : 'Kode redeem tidak valid. Silakan periksa kembali.',
                                            ),
                                            backgroundColor: isValid ? Colors.green : Colors.red,
                                            duration: const Duration(seconds: 3),
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.verified, size: 14),
                                    label: const Text('Validasi', style: TextStyle(fontSize: 12)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.purple.shade700,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                      minimumSize: const Size(0, 40),
                                    ),
                                  ),
                                ],
                              ),
                              if (_redeemCodeValid && _project!.redeemDiscountPercentage != null && _project!.redeemDiscountPercentage! > 0) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.green.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        size: 14,
                                        color: Colors.green.shade700,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'Kode valid! Diskon ${_project!.redeemDiscountPercentage!.toStringAsFixed(0)}%',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.green.shade900,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                  const SizedBox(height: 8),
                ],
                    ],
                  ),
                ),
                // Form fields (scrollable)
                Expanded(
                  child: FormRenderer(
                    projectId: _project!.id,
                    formData: _formData,
                    onFieldChanged: (key, value) {
                      setState(() {
                        _formData[key] = value;
                      });
                    },
                    onCategoriesChanged: (selectedIds) {
                      setState(() {
                        // Single selection - take first item or null
                        _selectedCategoryId = selectedIds.isNotEmpty ? selectedIds.first : null;
                      });
                    },
                    onSubmit: _submitForm,
                  ),
                ),
              ],
            ),
    );
  }
}



