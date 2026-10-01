import '../../data/models/models.dart';

/// Turns dynamic `details` into display strings using the type definition.
abstract final class PropertyFacts {
  static List<String> keyFacts(Property p, PropertyType type) {
    final out = <String>[];
    for (final fact in type.keyFacts) {
      String? value;
      if (fact.fieldKey == '_units') {
        value = p.availableUnits <= 0 ? null : '${p.availableUnits}';
        if (value == null) {
          out.add('Full');
          continue;
        }
      } else {
        final raw = p.details[fact.fieldKey];
        if (raw == null || (raw is String && raw.isEmpty)) continue;
        value = formatValue(raw);
        if (fact.unitFrom != null && p.details[fact.unitFrom] != null) {
          value = '$value ${p.details[fact.unitFrom]}';
        }
      }
      var text = fact.template.replaceAll('{v}', value);
      if (value == '1') text = text.replaceAll('seats', 'seat').replaceAll('rooms', 'room');
      out.add(text);
    }
    return out;
  }

  static String formatValue(dynamic raw, {String? unit}) {
    final String text;
    if (raw is bool) {
      text = raw ? 'Yes' : 'No';
    } else if (raw is num) {
      text = raw % 1 == 0 ? raw.toInt().toString() : raw.toString();
    } else if (raw is List) {
      text = raw.join(', ');
    } else {
      text = raw.toString();
    }
    return unit == null ? text : '$text $unit';
  }

  /// Groups of (label, value) rows for the detail page, following the order
  /// the admin defined for the type.
  static Map<String, List<(PropertyField, dynamic)>> grouped(Property p, PropertyType type) {
    final out = <String, List<(PropertyField, dynamic)>>{};
    for (final f in type.fields) {
      final v = p.details[f.key];
      if (v == null) continue;
      if (v is List && v.isEmpty) continue;
      if (v is String && v.isEmpty) continue;
      out.putIfAbsent(f.group, () => []).add((f, v));
    }
    return out;
  }

  /// Required fields that are still missing (validation before submit).
  static List<PropertyField> missingRequired(Map<String, dynamic> details, PropertyType type) {
    return type.fields.where((f) {
      if (!f.required) return false;
      final v = details[f.key];
      if (v == null) return true;
      if (v is String && v.trim().isEmpty) return true;
      if (v is List && v.isEmpty) return true;
      return false;
    }).toList();
  }
}
