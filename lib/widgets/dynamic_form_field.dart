import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/form_field.dart';
import '../services/cms_service.dart';

class DynamicFormField extends StatefulWidget {
  final FormFieldModel field;
  final dynamic value;
  final Function(dynamic) onChanged;
  final bool readOnly;

  const DynamicFormField({
    super.key,
    required this.field,
    this.value,
    required this.onChanged,
    this.readOnly = false,
  });

  @override
  State<DynamicFormField> createState() => _DynamicFormFieldState();
}

class _DynamicFormFieldState extends State<DynamicFormField> {
  final CmsService _cmsService = CmsService();
  String? _selectedFileName;

  @override
  void initState() {
    super.initState();
    if (widget.field.fieldType == FieldType.file && widget.value != null) {
      _selectedFileName = widget.value.toString().split('/').last;
    }
  }

  String? _validateField(dynamic value) {
    if (widget.field.isRequired && (value == null || value.toString().isEmpty)) {
      return 'This field is required';
    }

    switch (widget.field.fieldType) {
      case FieldType.email:
        if (value != null && value.toString().isNotEmpty) {
          final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
          if (!emailRegex.hasMatch(value.toString())) {
            return 'Please enter a valid email address';
          }
        }
        break;
      case FieldType.url:
        if (value != null && value.toString().isNotEmpty) {
          final urlRegex = RegExp(r'^https?://');
          if (!urlRegex.hasMatch(value.toString())) {
            return 'Please enter a valid URL';
          }
        }
        break;
      case FieldType.number:
        if (value != null && value.toString().isNotEmpty) {
          if (double.tryParse(value.toString()) == null) {
            return 'Please enter a valid number';
          }
        }
        break;
      default:
        break;
    }

    return null;
  }

  Future<void> _pickFile() async {
    final fileData = await _cmsService.pickFile();
    if (fileData != null) {
      setState(() {
        _selectedFileName = fileData['name'] as String;
      });
      widget.onChanged(fileData);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use fieldLabel directly for label (title), placeholder is separate
    final label = widget.field.fieldLabel.isNotEmpty 
        ? widget.field.fieldLabel + (widget.field.isRequired ? ' *' : '')
        : widget.field.displayName + (widget.field.isRequired ? ' *' : '');

    switch (widget.field.fieldType) {
      case FieldType.text:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: widget.value?.toString(),
              decoration: InputDecoration(
                hintText: widget.field.placeholder ?? '',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.text_fields),
              ),
              enabled: !widget.readOnly,
              validator: _validateField,
              onChanged: (value) => widget.onChanged(value.isEmpty ? null : value),
            ),
          ],
        );

      case FieldType.textarea:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: widget.value?.toString(),
              decoration: InputDecoration(
                hintText: widget.field.placeholder ?? '',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.notes),
              ),
              enabled: !widget.readOnly,
              maxLines: 5,
              validator: _validateField,
              onChanged: (value) => widget.onChanged(value.isEmpty ? null : value),
            ),
          ],
        );

      case FieldType.email:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: widget.value?.toString(),
              decoration: InputDecoration(
                hintText: widget.field.placeholder ?? 'example@email.com',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.email),
              ),
              enabled: !widget.readOnly,
              keyboardType: TextInputType.emailAddress,
              validator: _validateField,
              onChanged: (value) => widget.onChanged(value.isEmpty ? null : value),
            ),
          ],
        );

      case FieldType.number:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: widget.value?.toString(),
              decoration: InputDecoration(
                hintText: widget.field.placeholder ?? '',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.numbers),
              ),
              enabled: !widget.readOnly,
              keyboardType: TextInputType.number,
              validator: _validateField,
              onChanged: (value) {
                final numValue = double.tryParse(value);
                widget.onChanged(numValue);
              },
            ),
          ],
        );

      case FieldType.phone:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: widget.value?.toString(),
              decoration: InputDecoration(
                hintText: widget.field.placeholder ?? '+1234567890',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.phone),
              ),
              enabled: !widget.readOnly,
              keyboardType: TextInputType.phone,
              validator: _validateField,
              onChanged: (value) => widget.onChanged(value.isEmpty ? null : value),
            ),
          ],
        );

      case FieldType.date:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: widget.readOnly ? null : () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: widget.value != null
                      ? DateTime.parse(widget.value.toString())
                      : DateTime.now(),
                  firstDate: DateTime(1900),
                  lastDate: DateTime(2100),
                );
                if (date != null) {
                  widget.onChanged(DateFormat('yyyy-MM-dd').format(date));
                }
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  hintText: widget.field.placeholder ?? 'Select date',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.calendar_today),
                  suffixIcon: widget.readOnly ? null : const Icon(Icons.arrow_drop_down),
                ),
                child: Text(
                  widget.value != null
                      ? DateFormat('dd/MM/yyyy').format(DateTime.parse(widget.value.toString()))
                      : widget.field.placeholder ?? 'Select date',
                  style: TextStyle(
                    color: widget.value != null ? Colors.black87 : Colors.grey,
                  ),
                ),
              ),
            ),
          ],
        );

      case FieldType.radio:
        return FormField<String>(
          initialValue: widget.value?.toString(),
          validator: _validateField,
          builder: (fieldState) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.field.fieldLabel.isNotEmpty 
                      ? widget.field.fieldLabel + (widget.field.isRequired ? ' *' : '')
                      : label,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                ...widget.field.options.asMap().entries.map((entry) {
                  final option = entry.value;
                  return RadioListTile<String>(
                    title: Text(option),
                    value: option,
                    groupValue: widget.value?.toString(),
                    onChanged: widget.readOnly
                        ? null
                        : (value) {
                            widget.onChanged(value);
                            fieldState.didChange(value);
                          },
                  );
                }),
                if (fieldState.hasError)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 4),
                    child: Text(
                      fieldState.errorText!,
                      style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                    ),
                  ),
              ],
            );
          },
        );

      case FieldType.dropdown:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: widget.value?.toString(),
              decoration: InputDecoration(
                hintText: widget.field.placeholder ?? 'Select an option',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.arrow_drop_down_circle),
              ),
              items: widget.field.options.map((option) {
                return DropdownMenuItem(
                  value: option,
                  child: Text(option),
                );
              }).toList(),
              validator: _validateField,
              onChanged: widget.readOnly ? null : (value) => widget.onChanged(value),
            ),
          ],
        );

      case FieldType.checkbox:
        return CheckboxListTile(
          title: Text(label),
          value: widget.value == true,
          onChanged: widget.readOnly
              ? null
              : (value) => widget.onChanged(value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
        );

      case FieldType.url:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: widget.value?.toString(),
              decoration: InputDecoration(
                hintText: widget.field.placeholder ?? 'https://example.com',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.link),
              ),
              enabled: !widget.readOnly,
              keyboardType: TextInputType.url,
              validator: _validateField,
              onChanged: (value) => widget.onChanged(value.isEmpty ? null : value),
            ),
          ],
        );

      case FieldType.file:
        return FormField<Map<String, dynamic>>(
          initialValue: widget.value is Map ? widget.value as Map<String, dynamic> : null,
          validator: (value) {
            if (widget.field.isRequired && value == null) {
              return 'Please select a file';
            }
            return null;
          },
          builder: (fieldState) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.field.fieldLabel.isNotEmpty 
                      ? widget.field.fieldLabel + (widget.field.isRequired ? ' *' : '')
                      : label,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: widget.readOnly ? null : _pickFile,
                  icon: const Icon(Icons.attach_file),
                  label: Text(_selectedFileName ?? 'Select File'),
                ),
                if (_selectedFileName != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Selected: $_selectedFileName',
                      style: TextStyle(color: Colors.green.shade700, fontSize: 12),
                    ),
                  ),
                if (fieldState.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      fieldState.errorText!,
                      style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                    ),
                  ),
              ],
            );
          },
        );
    }
  }
}

