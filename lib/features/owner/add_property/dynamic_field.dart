import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/models/models.dart';

/// Renders one admin-defined [PropertyField] as the right input control.
class DynamicFieldInput extends StatelessWidget {
  const DynamicFieldInput({super.key, required this.field, required this.value, required this.onChanged, this.showError = false});

  final PropertyField field;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;
  final bool showError;

  bool get _missing {
    if (!field.required) return false;
    final v = value;
    return v == null || (v is String && v.trim().isEmpty) || (v is List && v.isEmpty);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = '${field.label}${field.required ? ' *' : ''}';
    final error = showError && _missing ? 'Required' : null;

    Widget titled(Widget child) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        if (field.hint != null) Text(field.hint!, style: TextStyle(color: scheme.outline, fontSize: 12)),
        const SizedBox(height: 8),
        child,
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(error, style: TextStyle(color: scheme.error, fontSize: 12)),
          ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: switch (field.type) {
        FieldType.number => TextFormField(
          key: ValueKey('f_${field.key}'),
          initialValue: value == null ? '' : _num(value),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          decoration: InputDecoration(labelText: label, suffixText: field.unit, helperText: field.hint, errorText: error),
          onChanged: (v) {
            final n = num.tryParse(v);
            onChanged(n == null ? null : (n % 1 == 0 ? n.toInt() : n));
          },
        ),
        FieldType.text => TextFormField(
          key: ValueKey('f_${field.key}'),
          initialValue: value as String? ?? '',
          decoration: InputDecoration(labelText: label, helperText: field.hint, errorText: error),
          onChanged: onChanged,
        ),
        FieldType.toggle => SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(field.label, style: const TextStyle(fontWeight: FontWeight.w600)),
          value: value == true,
          onChanged: onChanged,
        ),
        FieldType.select => titled(
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final o in field.options) ChoiceChip(label: Text(o), selected: value == o, onSelected: (on) => onChanged(on ? o : null))],
          ),
        ),
        FieldType.multiSelect => titled(
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in field.options)
                FilterChip(
                  label: Text(o),
                  selected: (value as List?)?.contains(o) ?? false,
                  onSelected: (on) {
                    final list = [...?(value as List?)?.cast<String>()];
                    on ? list.add(o) : list.remove(o);
                    onChanged(list);
                  },
                ),
            ],
          ),
        ),
      },
    );
  }

  static String _num(dynamic v) => v is num ? (v % 1 == 0 ? v.toInt().toString() : v.toString()) : v.toString();
}
