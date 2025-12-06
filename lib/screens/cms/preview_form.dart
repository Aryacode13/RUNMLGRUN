import 'package:flutter/material.dart';
import '../../models/project.dart';
import '../../widgets/form_renderer.dart';
import '../../services/cms_service.dart';

class PreviewFormScreen extends StatefulWidget {
  final Project project;

  const PreviewFormScreen({super.key, required this.project});

  @override
  State<PreviewFormScreen> createState() => _PreviewFormScreenState();
}

class _PreviewFormScreenState extends State<PreviewFormScreen> {
  final Map<String, dynamic> _formData = {};
  final CmsService _cmsService = CmsService();
  bool _isSubmitting = false;

  Future<void> _submitForm() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      print('=== SUBMITTING FORM DATA ===');
      print('Project: ${widget.project.name}');
      print('Table Name: ${widget.project.tableName}');
      print('Form Data: $_formData');
      print('===========================');

      // Submit form data to database
      final result = await _cmsService.submitFormData(
        tableName: widget.project.tableName,
        data: _formData,
        projectId: widget.project.id,
      );

      print('✅ Form submitted successfully!');
      print('Result: $result');

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Form berhasil dikirim! Data telah disimpan ke database.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Clear form data after successful submission
        setState(() {
          _formData.clear();
        });

        // Wait a bit for user to see success message, then navigate back to dashboard
        await Future.delayed(const Duration(milliseconds: 1500));

        // Navigate back to dashboard (pop current screen)
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      print('❌ Error submitting form: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error mengirim form: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          'Preview: ${widget.project.name}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          FormRenderer(
            projectId: widget.project.id,
            formData: _formData,
            onFieldChanged: (key, value) {
              setState(() {
                _formData[key] = value;
              });
            },
            readOnly: false, // Enable form editing and submission
            onSubmit: _submitForm,
          ),
          if (_isSubmitting)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Mengirim data...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}



