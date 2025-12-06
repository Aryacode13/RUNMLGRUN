import 'package:flutter/material.dart';
import '../../services/cms_service.dart';
import '../../services/supabase_service.dart';
import '../../models/category.dart';
import '../../models/project.dart';
import '../../utils/slug_generator.dart';
import '../../utils/error_handler.dart';

class CreateProjectScreen extends StatefulWidget {
  final Project? project;
  
  const CreateProjectScreen({super.key, this.project});

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _tableNameController = TextEditingController();
  final _eventCodeController = TextEditingController();
  final _registrationFeeController = TextEditingController();
  final _redeemCodeController = TextEditingController();
  final _redeemDiscountController = TextEditingController();
  final CmsService _cmsService = CmsService();
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = false;
  bool _useCategories = false;
  bool _useRedeem = false;
  List<CategoryInput> _categories = [];

  @override
  void initState() {
    super.initState();
    if (widget.project != null) {
      _nameController.text = widget.project!.name;
      _tableNameController.text = widget.project!.tableName;
      _eventCodeController.text = widget.project!.eventCode ?? '';
      _registrationFeeController.text = widget.project!.registrationFee?.toString() ?? '';
      _redeemCodeController.text = widget.project!.redeemCode ?? '';
      _redeemDiscountController.text = widget.project!.redeemDiscountPercentage?.toString() ?? '';
      _useCategories = widget.project!.useCategories ?? false;
      _useRedeem = widget.project!.redeemCode != null && widget.project!.redeemCode!.isNotEmpty;
      // Load categories if useCategories is true
      if (_useCategories) {
        _loadCategories();
      }
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _cmsService.getCategories(widget.project!.id);
      setState(() {
        _categories = categories.map((cat) {
          final nameController = TextEditingController(text: cat.name);
          final priceController = TextEditingController(text: cat.price.toString());
          return CategoryInput(
            nameController: nameController,
            priceController: priceController,
          );
        }).toList();
      });
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _tableNameController.dispose();
    _eventCodeController.dispose();
    _registrationFeeController.dispose();
    _redeemCodeController.dispose();
    _redeemDiscountController.dispose();
    for (var cat in _categories) {
      cat.nameController.dispose();
      cat.priceController.dispose();
    }
    super.dispose();
  }

  void _generateTableName() {
    if (_nameController.text.isNotEmpty) {
      _tableNameController.text = SlugGenerator.generateColumnName(_nameController.text);
    }
  }

  void _addCategory() {
    setState(() {
      _categories.add(CategoryInput());
    });
  }

  void _removeCategory(int index) {
    setState(() {
      _categories[index].nameController.dispose();
      _categories[index].priceController.dispose();
      _categories.removeAt(index);
    });
  }

  Future<void> _createProject() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate event code is required
    if (_eventCodeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Event code harus diisi'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate redeem code and discount if useRedeem is true
    if (_useRedeem) {
      if (_redeemCodeController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kode redeem harus diisi jika redeem diaktifkan'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (_redeemDiscountController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Diskon redeem harus diisi jika redeem diaktifkan'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Validate categories if useCategories is true
    if (_useCategories) {
      if (_categories.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Jika menggunakan categories, minimal harus ada 2 categories'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Validate all categories have name and price
      for (int i = 0; i < _categories.length; i++) {
        final cat = _categories[i];
        if (cat.nameController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Category ${i + 1}: Nama kategori harus diisi'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        if (cat.priceController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Category ${i + 1}: Harga harus diisi'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
    } else {
      // If not using categories, registration fee is required
      if (_registrationFeeController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Harga pendaftaran harus diisi jika tidak menggunakan categories'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final registrationFee = _useCategories
          ? null // Don't use registration fee if using categories
          : (_registrationFeeController.text.trim().isEmpty
              ? null
              : double.tryParse(_registrationFeeController.text.trim().replaceAll(',', '')));

      final redeemCode = _useRedeem && _redeemCodeController.text.trim().isNotEmpty
          ? _redeemCodeController.text.trim()
          : null;

      final redeemDiscount = _useRedeem && _redeemDiscountController.text.trim().isNotEmpty
          ? double.tryParse(_redeemDiscountController.text.trim().replaceAll(',', '.'))
          : null;

      if (widget.project != null) {
        // Save old event code before update
        final oldEventCode = widget.project!.eventCode;
        final newEventCode = _eventCodeController.text.trim();
        
        // Update project (table_name cannot be changed after creation)
        await _cmsService.updateProject(
          widget.project!.id,
          {
            'name': _nameController.text.trim(),
            'event_code': newEventCode,
            'registration_fee': registrationFee,
            'redeem_code': redeemCode,
            'redeem_discount_percentage': redeemDiscount,
            'use_categories': _useCategories,
          },
        );

        // If event code changed, update events that use the old event code
        if (oldEventCode != newEventCode && oldEventCode != null && oldEventCode.isNotEmpty) {
          try {
            final events = await _supabaseService.getEvents();
            for (final event in events) {
              if (event.eventCode == oldEventCode) {
                await _supabaseService.updateEvent(
                  eventId: event.id,
                  eventCode: newEventCode,
                );
                print('Updated event ${event.id} with new event code: $newEventCode');
              }
            }
          } catch (e) {
            print('Error updating events with new event code: $e');
            // Don't fail the whole operation if event update fails
          }
        }

        // Delete existing categories and create new ones if useCategories is true
        if (_useCategories) {
          final existingCategories = await _cmsService.getCategories(widget.project!.id);
          for (final cat in existingCategories) {
            await _cmsService.deleteCategory(cat.id);
          }
          for (final cat in _categories) {
            final price = double.tryParse(cat.priceController.text.trim().replaceAll(',', '')) ?? 0;
            await _cmsService.createCategory(
              projectId: widget.project!.id,
              name: cat.nameController.text.trim(),
              price: price,
            );
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Project updated successfully')),
          );
          Navigator.pop(context, true);
        }
      } else {
        // Create project
        final project = await _cmsService.createProject(
          name: _nameController.text.trim(),
          tableName: _tableNameController.text.trim(),
          eventCode: _eventCodeController.text.trim(),
          registrationFee: registrationFee,
          redeemCode: redeemCode,
          redeemDiscountPercentage: redeemDiscount,
          useCategories: _useCategories,
        );

        // Create categories if useCategories is true
        if (_useCategories && _categories.isNotEmpty) {
          for (final cat in _categories) {
            final price = double.tryParse(cat.priceController.text.trim().replaceAll(',', '')) ?? 0;
            await _cmsService.createCategory(
              projectId: project.id,
              name: cat.nameController.text.trim(),
              price: price,
            );
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Project created successfully')),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ErrorHandler.showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.project != null ? 'Edit Project' : 'Create New Project',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Project Name *',
                  hintText: 'e.g., Event Registration Form',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                onChanged: (_) {
                  _generateTableName();
                },
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter project name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tableNameController,
                enabled: widget.project == null,
                decoration: InputDecoration(
                  labelText: 'Table Name *',
                  hintText: 'e.g., event_registration_form',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.table_chart),
                  helperText: widget.project != null 
                      ? 'Table name cannot be changed after creation'
                      : 'Database table name (lowercase, underscores only)',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter table name';
                  }
                  if (!SlugGenerator.isValidTableName(value.trim())) {
                    return 'Invalid table name format';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _eventCodeController,
                decoration: const InputDecoration(
                  labelText: 'Event Code *',
                  hintText: 'e.g., EVENT001 (untuk menghubungkan dengan event)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.event),
                  helperText: 'Kode event untuk menghubungkan form dengan event dan menghitung kuota',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Event code harus diisi';
                  }
                  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value.trim())) {
                    return 'Event code hanya boleh mengandung huruf, angka, dan underscore';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Use Categories Toggle
              Card(
                elevation: 2,
                color: Colors.grey.shade900,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.orange.shade700),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade900,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.category, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Gunakan Categories',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Aktifkan untuk mengatur harga per category',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _useCategories,
                            onChanged: (value) {
                              setState(() {
                                _useCategories = value;
                                if (!value) {
                                  // Clear categories when disabled
                                  for (var cat in _categories) {
                                    cat.nameController.dispose();
                                    cat.priceController.dispose();
                                  }
                                  _categories.clear();
                                }
                              });
                            },
                            activeColor: Colors.orange,
                          ),
                        ],
                      ),
                      if (_useCategories)
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade900.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade700),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.orange.shade300, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Minimal 2 categories diperlukan. Harga akan diatur per category, bukan harga global.',
                                  style: TextStyle(
                                    color: Colors.orange.shade200,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Registration Fee (only if not using categories)
              if (!_useCategories) ...[
                TextFormField(
                  controller: _registrationFeeController,
                  decoration: const InputDecoration(
                    labelText: 'Harga Pendaftaran (Rp) *',
                    hintText: 'e.g., 50000 (kosongkan jika gratis)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.attach_money),
                    helperText: 'Biaya pendaftaran dalam Rupiah. Kosongkan jika gratis.',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Harga pendaftaran harus diisi jika tidak menggunakan categories';
                    }
                    final fee = double.tryParse(value.trim().replaceAll(',', ''));
                    if (fee == null) {
                      return 'Masukkan angka yang valid';
                    }
                    if (fee < 0) {
                      return 'Harga tidak boleh negatif';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],
            // Categories (only if using categories)
            if (_useCategories) ...[
              Card(
                color: Colors.black,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade900,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.category, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Categories',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Tentukan nama dan harga untuk setiap kategori',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                            ElevatedButton.icon(
                              onPressed: _addCategory,
                              icon: const Icon(Icons.add, size: 20),
                              label: const Text('Tambah'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_categories.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(24.0),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade900,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade700),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.category_outlined, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                const Text(
                                  'Belum ada category',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Klik \"Tambah Category\" untuk menambahkan.\nMinimal 2 categories diperlukan.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ...List.generate(_categories.length, (index) {
                            final cat = _categories[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade100,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            Icons.category,
                                            color: Colors.orange.shade700,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Category ${index + 1}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: cat.nameController,
                                      decoration: const InputDecoration(
                                        labelText: 'Nama Category *',
                                        hintText: 'e.g., 10K, 5K, 7K',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.label_outline),
                                        helperText: 'Nama kategori wajib diisi',
                                      ),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            controller: cat.priceController,
                                            decoration: const InputDecoration(
                                              labelText: 'Harga (Rp) *',
                                              hintText: 'e.g., 100000',
                                              border: OutlineInputBorder(),
                                              prefixIcon: Icon(Icons.attach_money),
                                              helperText: 'Harga kategori wajib diisi',
                                            ),
                                            keyboardType: TextInputType.number,
                                            style: const TextStyle(fontSize: 14),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: IconButton(
                                            icon: Icon(Icons.delete_outline, color: Colors.red.shade700),
                                            onPressed: () => _removeCategory(index),
                                            tooltip: 'Hapus Category',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        if (_categories.length < 2 && _categories.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.orange.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Minimal 2 categories diperlukan untuk menggunakan fitur categories',
                                    style: TextStyle(
                                      color: Colors.orange.shade900,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // Redeem Code Toggle
              Card(
                color: Colors.grey.shade900,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.confirmation_number,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gunakan Redeem Code',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Aktifkan untuk menggunakan kode redeem/promo',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _useRedeem,
                        onChanged: (value) {
                          setState(() {
                            _useRedeem = value;
                            if (!value) {
                              // Clear fields when toggle off
                              _redeemCodeController.clear();
                              _redeemDiscountController.clear();
                            }
                          });
                        },
                        activeColor: Colors.orange,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Redeem Code Field (only show if toggle is ON)
              if (_useRedeem) ...[
                TextFormField(
                  controller: _redeemCodeController,
                  decoration: const InputDecoration(
                    labelText: 'Kode Redeem *',
                    hintText: 'e.g., 43738, 26238 (pisahkan dengan koma jika multiple)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.confirmation_number),
                    helperText: 'Kode redeem/promo untuk pendaftaran. Pisahkan dengan koma jika ada multiple codes.',
                  ),
                  validator: (value) {
                    if (_useRedeem) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Kode redeem harus diisi';
                      }
                      final codes = value.trim().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                      for (final code in codes) {
                        if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(code)) {
                          return 'Kode redeem hanya boleh mengandung huruf dan angka';
                        }
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _redeemDiscountController,
                  decoration: const InputDecoration(
                    labelText: 'Diskon Redeem (%) *',
                    hintText: 'e.g., 10 (untuk 10% diskon)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.percent),
                    helperText: 'Persentase diskon jika menggunakan kode redeem (0-100)',
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (_useRedeem) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Diskon redeem harus diisi';
                      }
                      final discount = double.tryParse(value.trim().replaceAll(',', '.'));
                      if (discount == null) {
                        return 'Masukkan angka yang valid';
                      }
                      if (discount < 0 || discount > 100) {
                        return 'Diskon harus antara 0-100%';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 32),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createProject,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
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
                      : Text(
                          widget.project != null ? 'Update Project' : 'Create Project',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

class CategoryInput {
  final TextEditingController nameController;
  final TextEditingController priceController;
  
  CategoryInput({
    TextEditingController? nameController,
    TextEditingController? priceController,
  }) : nameController = nameController ?? TextEditingController(),
       priceController = priceController ?? TextEditingController(text: '0');
}
