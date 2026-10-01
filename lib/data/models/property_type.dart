import 'package:flutter/material.dart';

import 'enums.dart';

enum FieldType { number, text, toggle, select, multiSelect }

/// One dynamic form field of a property type. The owner form, the detail
/// page and the key-facts row are all rendered from these definitions, so an
/// admin can add a new type or field without shipping new app code.
class PropertyField {
  const PropertyField({
    required this.key,
    required this.label,
    required this.group,
    required this.type,
    this.options = const [],
    this.required = false,
    this.unit,
    this.hint,
    this.money = false,
  });

  final String key;
  final String label;
  final String group;
  final FieldType type;
  final List<String> options;
  final bool required;
  final String? unit;
  final String? hint;

  /// Value is an amount in the listing's currency.
  final bool money;

  factory PropertyField.fromJson(Map<String, dynamic> json) => PropertyField(
    key: json['key'] as String,
    label: json['label'] as String,
    group: json['group'] as String,
    type: FieldType.values.byName(json['type'] as String),
    options: (json['options'] as List?)?.cast<String>() ?? const [],
    required: json['required'] as bool? ?? false,
    unit: json['unit'] as String?,
    hint: json['hint'] as String?,
    money: json['money'] as bool? ?? false,
  );
}

/// A key fact shown on pins, popups and list cards (for example "Seats 4").
class KeyFact {
  const KeyFact(this.fieldKey, this.template, {this.unitFrom});

  /// Field key, or `_units` for the available seats/units counter.
  final String fieldKey;

  /// Display template where `{v}` is replaced by the value.
  final String template;

  /// Optional field whose value is appended as the unit (e.g. size + unit).
  final String? unitFrom;
}

class PropertyType {
  const PropertyType({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.purposes,
    required this.defaultPeriod,
    required this.fields,
    required this.keyFacts,
    this.includedOptions = const [],
    this.usesUnits = false,
    this.unitsLabel = 'Units',
    this.minPhotos = 3,
    this.forcedGender,
    this.safetyHighlighted = false,
  });

  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final List<ListingPurpose> purposes;
  final PricePeriod defaultPeriod;
  final List<PropertyField> fields;
  final List<KeyFact> keyFacts;

  /// Options for "What is included in the price" (utilities, services...).
  final List<String> includedOptions;

  /// Hostels track seats; the listing turns FULL when available units hit 0.
  final bool usesUnits;
  final String unitsLabel;
  final int minPhotos;
  final GenderRule? forcedGender;

  /// Girls hostel: safety features are shown prominently.
  final bool safetyHighlighted;

  List<String> get groups {
    final seen = <String>[];
    for (final f in fields) {
      if (!seen.contains(f.group)) seen.add(f.group);
    }
    return seen;
  }

  PropertyField? field(String key) {
    for (final f in fields) {
      if (f.key == key) return f;
    }
    return null;
  }
}
