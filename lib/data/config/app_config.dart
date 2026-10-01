import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../models/models.dart';

/// Platform configuration. In production this is served by the backend
/// (`GET /config`) and editable from the admin dashboard; it is bundled here
/// so the app runs out of the box. Nothing in the UI hard-codes countries,
/// cities, currencies, radius limits, units or property type fields.
class AppConfig {
  const AppConfig({
    required this.countries,
    required this.cities,
    required this.propertyTypes,
    this.showFullListingsWithBadge = false,
    this.arrivalThresholdMeters = 100,
    this.staleListingDays = 30,
    this.visitRequestExpiryHours = 48,
    this.freeListingLimit = 3,
    this.maxPhotos = 15,
  });

  final List<Country> countries;
  final List<City> cities;
  final List<PropertyType> propertyTypes;

  /// When a hostel is FULL: hide from map (false) or show with "Full" badge.
  final bool showFullListingsWithBadge;
  final double arrivalThresholdMeters;
  final int staleListingDays;
  final int visitRequestExpiryHours;
  final int freeListingLimit;
  final int maxPhotos;

  Country country(String id) => countries.firstWhere((c) => c.id == id);
  City city(String id) => cities.firstWhere((c) => c.id == id);
  PropertyType type(String id) => propertyTypes.firstWhere((t) => t.id == id, orElse: () => propertyTypes.last);
  List<City> citiesOf(String countryId) => cities.where((c) => c.countryId == countryId && c.enabled).toList();
  Country countryByCurrency(String code) => countries.firstWhere((c) => c.currencyCode == code, orElse: () => countries.first);

  static final AppConfig defaults = AppConfig(
    countries: const [
      Country(
        id: 'pk',
        name: 'Pakistan',
        flag: '🇵🇰',
        dialCode: '+92',
        currencyCode: 'PKR',
        currencySymbol: 'Rs.',
        distanceUnit: DistanceUnit.km,
        areaUnits: ['marla', 'kanal', 'sq ft', 'sq yd', 'acre'],
        emergencyNumber: '15',
      ),
      Country(
        id: 'ae',
        name: 'United Arab Emirates',
        flag: '🇦🇪',
        dialCode: '+971',
        currencyCode: 'AED',
        currencySymbol: 'AED',
        distanceUnit: DistanceUnit.km,
        areaUnits: ['sq ft', 'sq m', 'acre', 'hectare'],
        emergencyNumber: '999',
      ),
      Country(
        id: 'gb',
        name: 'United Kingdom',
        flag: '🇬🇧',
        dialCode: '+44',
        currencyCode: 'GBP',
        currencySymbol: '£',
        distanceUnit: DistanceUnit.miles,
        areaUnits: ['sq ft', 'sq m', 'acre', 'hectare'],
        emergencyNumber: '999',
      ),
    ],
    cities: const [
      City(id: 'lhr', countryId: 'pk', name: 'Lahore', center: LatLng(31.5204, 74.3587), maxRadiusKm: 25, defaultRadiusKm: 5),
      City(id: 'isb', countryId: 'pk', name: 'Islamabad', center: LatLng(33.6844, 73.0479), maxRadiusKm: 25, defaultRadiusKm: 5),
      City(id: 'khi', countryId: 'pk', name: 'Karachi', center: LatLng(24.8607, 67.0011), maxRadiusKm: 30, defaultRadiusKm: 5),
      City(id: 'dxb', countryId: 'ae', name: 'Dubai', center: LatLng(25.2048, 55.2708), maxRadiusKm: 30, defaultRadiusKm: 5),
      City(id: 'lon', countryId: 'gb', name: 'London', center: LatLng(51.5072, -0.1276), maxRadiusKm: 20, defaultRadiusKm: 3),
    ],
    propertyTypes: _propertyTypes,
  );
}

// ---------------------------------------------------------------------------
// Property types and their dynamic fields (spec section 4).
// ---------------------------------------------------------------------------

const _furnishing = ['Furnished', 'Semi-furnished', 'Unfurnished'];
const _tenantType = ['Family only', 'Bachelor allowed', 'Anyone'];
const _sizeUnits = ['sq ft', 'sq m', 'marla', 'kanal', 'sq yd'];
const _floors = ['Basement', 'Ground', 'First', 'Second', 'Third or above'];

const _hostelIncluded = ['Electricity', 'Gas', 'Water', 'Wi-Fi', 'Laundry', 'Cleaning', 'Generator / UPS backup'];

List<PropertyField> _hostelFields({required bool girls}) => [
  const PropertyField(key: 'total_rooms', label: 'Total rooms', group: 'Rooms and seats', type: FieldType.number, required: true),
  const PropertyField(
    key: 'room_types',
    label: 'Room types',
    group: 'Rooms and seats',
    type: FieldType.multiSelect,
    options: ['Single', 'Double', 'Triple', 'Four-seater', 'Dormitory'],
    required: true,
  ),
  const PropertyField(key: 'price_per_room', money: true, label: 'Price per whole room', group: 'Rooms and seats', type: FieldType.number, hint: 'Optional'),
  const PropertyField(key: 'meals', label: 'Meals provided', group: 'Meals', type: FieldType.multiSelect, options: ['Breakfast', 'Lunch', 'Dinner']),
  const PropertyField(key: 'meals_price', money: true, label: 'Meals price per month', group: 'Meals', type: FieldType.number, hint: '0 if included'),
  const PropertyField(
    key: 'kitchen',
    label: 'Kitchen',
    group: 'Kitchen',
    type: FieldType.select,
    options: ['Attached to room', 'Common kitchen', 'No kitchen'],
    required: true,
  ),
  const PropertyField(key: 'fridge_allowed', label: 'Fridge allowed', group: 'Kitchen', type: FieldType.toggle),
  const PropertyField(key: 'cooking_allowed', label: 'Cooking allowed', group: 'Kitchen', type: FieldType.toggle),
  const PropertyField(
    key: 'bathroom',
    label: 'Bathroom',
    group: 'Bathroom',
    type: FieldType.select,
    options: ['Attached bathroom', 'Common bathroom'],
    required: true,
  ),
  const PropertyField(key: 'hot_water', label: 'Hot water available', group: 'Bathroom', type: FieldType.toggle),
  const PropertyField(
    key: 'furniture',
    label: 'Furniture and comfort',
    group: 'Furniture and comfort',
    type: FieldType.multiSelect,
    options: ['Bed', 'Mattress', 'Cupboard', 'Study table', 'Chair', 'Fan', 'AC', 'Heater', 'Curtains'],
  ),
  const PropertyField(key: 'entry_timing', label: 'Entry / exit timing', group: 'Rules', type: FieldType.text, hint: 'e.g. 6:00 AM – 11:00 PM'),
  const PropertyField(
    key: 'visitor_policy',
    label: 'Visitor policy',
    group: 'Rules',
    type: FieldType.select,
    options: ['Not allowed', 'Lobby only', 'Allowed with permission'],
  ),
  const PropertyField(key: 'smoking', label: 'Smoking', group: 'Rules', type: FieldType.select, options: ['Not allowed', 'Designated area', 'Allowed']),
  const PropertyField(key: 'min_stay_months', label: 'Minimum stay', group: 'Rules', type: FieldType.number, unit: 'months'),
  const PropertyField(key: 'notice_days', label: 'Notice period', group: 'Rules', type: FieldType.number, unit: 'days'),
  PropertyField(
    key: 'safety',
    label: 'Safety features',
    group: 'Safety',
    type: FieldType.multiSelect,
    required: girls,
    options: ['CCTV', 'Security guard', 'Biometric / gate entry', 'Fire safety', 'ID check at gate', if (girls) 'Women-only floor'],
  ),
  PropertyField(key: 'warden_name', label: 'Warden name', group: 'Safety', type: FieldType.text, required: girls),
  const PropertyField(key: 'floors', label: 'Floors', group: 'Other', type: FieldType.number),
  const PropertyField(
    key: 'facilities',
    label: 'Facilities',
    group: 'Other',
    type: FieldType.multiSelect,
    options: ['Lift', 'Parking', 'Laundry area', 'Prayer area', 'Common lounge', 'Study room'],
  ),
  const PropertyField(
    key: 'age_group',
    label: 'Suitable for',
    group: 'Other',
    type: FieldType.select,
    options: ['Students', 'Working professionals', 'Anyone'],
  ),
];

final _propertyTypes = <PropertyType>[
  PropertyType(
    id: 'boys_hostel',
    name: 'Boys Hostel',
    icon: Icons.bed_rounded,
    color: const Color(0xFF3F51B5),
    purposes: const [ListingPurpose.perSeat, ListingPurpose.rent],
    defaultPeriod: PricePeriod.perSeatMonth,
    usesUnits: true,
    unitsLabel: 'Seats',
    forcedGender: GenderRule.male,
    includedOptions: _hostelIncluded,
    fields: _hostelFields(girls: false),
    keyFacts: const [KeyFact('_units', '{v} seats left'), KeyFact('kitchen', '{v}')],
  ),
  PropertyType(
    id: 'girls_hostel',
    name: 'Girls Hostel',
    icon: Icons.bedroom_child_rounded,
    color: const Color(0xFFD81B60),
    purposes: const [ListingPurpose.perSeat, ListingPurpose.rent],
    defaultPeriod: PricePeriod.perSeatMonth,
    usesUnits: true,
    unitsLabel: 'Seats',
    forcedGender: GenderRule.female,
    safetyHighlighted: true,
    includedOptions: _hostelIncluded,
    fields: _hostelFields(girls: true),
    keyFacts: const [KeyFact('_units', '{v} seats left'), KeyFact('kitchen', '{v}')],
  ),
  const PropertyType(
    id: 'flat',
    name: 'Flat / Apartment',
    icon: Icons.apartment_rounded,
    color: Color(0xFF00897B),
    purposes: [ListingPurpose.rent, ListingPurpose.sale],
    defaultPeriod: PricePeriod.perMonth,
    includedOptions: ['Gas bill', 'Electricity bill', 'Water bill', 'Maintenance', 'Internet'],
    fields: [
      PropertyField(key: 'bedrooms', label: 'Bedrooms', group: 'Layout', type: FieldType.number, required: true),
      PropertyField(key: 'bathrooms', label: 'Bathrooms', group: 'Layout', type: FieldType.number, required: true),
      PropertyField(key: 'kitchen_type', label: 'Kitchen', group: 'Layout', type: FieldType.select, options: ['Open kitchen', 'Closed kitchen', 'No kitchen']),
      PropertyField(key: 'drawing_room', label: 'Lounge / drawing room', group: 'Layout', type: FieldType.toggle),
      PropertyField(key: 'size', label: 'Size', group: 'Layout', type: FieldType.number, required: true),
      PropertyField(key: 'size_unit', label: 'Size unit', group: 'Layout', type: FieldType.select, options: _sizeUnits, required: true),
      PropertyField(key: 'floor', label: 'Floor number', group: 'Building', type: FieldType.number),
      PropertyField(key: 'total_floors', label: 'Total floors', group: 'Building', type: FieldType.number),
      PropertyField(key: 'lift', label: 'Lift', group: 'Building', type: FieldType.toggle),
      PropertyField(key: 'building_age', label: 'Age of building', group: 'Building', type: FieldType.number, unit: 'years'),
      PropertyField(key: 'furnishing', label: 'Furnishing', group: 'Living', type: FieldType.select, options: _furnishing, required: true),
      PropertyField(key: 'tenant_type', label: 'Who can live', group: 'Living', type: FieldType.select, options: _tenantType),
      PropertyField(key: 'pets', label: 'Pets allowed', group: 'Living', type: FieldType.toggle),
      PropertyField(key: 'maintenance', money: true, label: 'Maintenance charges / month', group: 'Costs', type: FieldType.number),
      PropertyField(
        key: 'features',
        label: 'Features',
        group: 'Features',
        type: FieldType.multiSelect,
        options: ['Parking', 'Generator', 'Security', 'Balcony', 'Gym', 'Swimming pool', 'Central AC'],
      ),
    ],
    keyFacts: [KeyFact('bedrooms', '{v} bed'), KeyFact('floor', 'Floor {v}')],
  ),
  const PropertyType(
    id: 'house',
    name: 'House / Portion / Room',
    icon: Icons.house_rounded,
    color: Color(0xFFF57C00),
    purposes: [ListingPurpose.rent, ListingPurpose.sale],
    defaultPeriod: PricePeriod.perMonth,
    includedOptions: ['Gas bill', 'Electricity bill', 'Water bill', 'Internet'],
    fields: [
      PropertyField(
        key: 'portion',
        label: 'What is offered',
        group: 'Layout',
        type: FieldType.select,
        options: ['Whole house', 'Upper portion', 'Lower portion', 'Single room', 'Shared room', 'Guest house'],
        required: true,
      ),
      PropertyField(key: 'plot_size', label: 'Plot size', group: 'Layout', type: FieldType.number, required: true),
      PropertyField(key: 'plot_unit', label: 'Plot unit', group: 'Layout', type: FieldType.select, options: _sizeUnits, required: true),
      PropertyField(key: 'covered_area', label: 'Covered area', group: 'Layout', type: FieldType.number, unit: 'sq ft'),
      PropertyField(key: 'floors', label: 'Floors', group: 'Layout', type: FieldType.number),
      PropertyField(key: 'bedrooms', label: 'Bedrooms', group: 'Layout', type: FieldType.number, required: true),
      PropertyField(key: 'bathrooms', label: 'Bathrooms', group: 'Layout', type: FieldType.number, required: true),
      PropertyField(key: 'kitchens', label: 'Kitchens', group: 'Layout', type: FieldType.number),
      PropertyField(key: 'separate_gate', label: 'Separate gate', group: 'Access and meters', type: FieldType.toggle),
      PropertyField(key: 'separate_meters', label: 'Separate gas & electricity meter', group: 'Access and meters', type: FieldType.toggle),
      PropertyField(key: 'furnishing', label: 'Furnishing', group: 'Living', type: FieldType.select, options: _furnishing),
      PropertyField(key: 'tenant_type', label: 'Who can live', group: 'Living', type: FieldType.select, options: _tenantType),
      PropertyField(
        key: 'features',
        label: 'Features',
        group: 'Features',
        type: FieldType.multiSelect,
        options: ['Lounge', 'Drawing room', 'Garage', 'Garden', 'Roof access', 'Servant quarter'],
      ),
    ],
    keyFacts: [
      KeyFact('bedrooms', '{v} bed'),
      KeyFact('plot_size', '{v}', unitFrom: 'plot_unit'),
    ],
  ),
  const PropertyType(
    id: 'shop',
    name: 'Shop',
    icon: Icons.storefront_rounded,
    color: Color(0xFF8E24AA),
    purposes: [ListingPurpose.rent, ListingPurpose.sale, ListingPurpose.lease],
    defaultPeriod: PricePeriod.perMonth,
    includedOptions: ['Electricity bill', 'Water bill', 'Security', 'Maintenance'],
    fields: [
      PropertyField(
        key: 'shop_kind',
        label: 'Shop kind',
        group: 'Space',
        type: FieldType.select,
        options: ['Market shop', 'Plaza shop', 'Kiosk'],
        required: true,
      ),
      PropertyField(key: 'size', label: 'Size', group: 'Space', type: FieldType.number, required: true),
      PropertyField(key: 'size_unit', label: 'Size unit', group: 'Space', type: FieldType.select, options: ['sq ft', 'sq m'], required: true),
      PropertyField(key: 'floor', label: 'Floor', group: 'Space', type: FieldType.select, options: _floors, required: true),
      PropertyField(key: 'frontage', label: 'Frontage width', group: 'Space', type: FieldType.number, unit: 'ft'),
      PropertyField(key: 'road_type', label: 'Road type', group: 'Location', type: FieldType.select, options: ['Main road', 'Market', 'Inside street']),
      PropertyField(key: 'corner', label: 'Corner shop', group: 'Location', type: FieldType.toggle),
      PropertyField(key: 'pagri', money: true, label: 'Advance / pagri / goodwill', group: 'Terms', type: FieldType.number),
      PropertyField(key: 'lease_years', label: 'Lease length', group: 'Terms', type: FieldType.number, unit: 'years'),
      PropertyField(key: 'allowed_business', label: 'Allowed business types', group: 'Terms', type: FieldType.text, hint: 'e.g. Clothing, pharmacy, food'),
      PropertyField(
        key: 'features',
        label: 'Features',
        group: 'Features',
        type: FieldType.multiSelect,
        options: ['Electricity meter', 'Shutter', 'Washroom', 'Parking', 'Storage'],
      ),
    ],
    keyFacts: [
      KeyFact('size', '{v}', unitFrom: 'size_unit'),
      KeyFact('floor', '{v} floor'),
    ],
  ),
  const PropertyType(
    id: 'office',
    name: 'Office / Commercial',
    icon: Icons.business_center_rounded,
    color: Color(0xFF455A64),
    purposes: [ListingPurpose.rent, ListingPurpose.lease, ListingPurpose.sale],
    defaultPeriod: PricePeriod.perMonth,
    includedOptions: ['Electricity bill', 'Internet', 'Maintenance', 'Security', 'Cleaning'],
    fields: [
      PropertyField(
        key: 'office_kind',
        label: 'Space kind',
        group: 'Space',
        type: FieldType.select,
        options: ['Office', 'Co-working desk', 'Warehouse', 'Showroom'],
        required: true,
      ),
      PropertyField(key: 'size', label: 'Size', group: 'Space', type: FieldType.number, required: true),
      PropertyField(key: 'size_unit', label: 'Size unit', group: 'Space', type: FieldType.select, options: ['sq ft', 'sq m'], required: true),
      PropertyField(key: 'floor', label: 'Floor', group: 'Space', type: FieldType.select, options: _floors),
      PropertyField(key: 'desks', label: 'Desks', group: 'Space', type: FieldType.number),
      PropertyField(key: 'meeting_rooms', label: 'Meeting rooms', group: 'Space', type: FieldType.number),
      PropertyField(key: 'lease_years', label: 'Lease length', group: 'Terms', type: FieldType.number, unit: 'years'),
      PropertyField(
        key: 'features',
        label: 'Office extras',
        group: 'Features',
        type: FieldType.multiSelect,
        options: ['Internet', 'Reception', 'Backup power', 'Air-conditioning', 'Loading access', 'Parking', 'Washroom', 'Kitchenette'],
      ),
    ],
    keyFacts: [
      KeyFact('size', '{v}', unitFrom: 'size_unit'),
      KeyFact('office_kind', '{v}'),
    ],
  ),
  const PropertyType(
    id: 'land',
    name: 'Land / Plot',
    icon: Icons.landscape_rounded,
    color: Color(0xFF689F38),
    purposes: [ListingPurpose.sale, ListingPurpose.lease],
    defaultPeriod: PricePeriod.oneTime,
    minPhotos: 3,
    fields: [
      PropertyField(
        key: 'land_type',
        label: 'Land type',
        group: 'Plot',
        type: FieldType.select,
        options: ['Residential', 'Commercial', 'Agricultural', 'Industrial'],
        required: true,
      ),
      PropertyField(key: 'size', label: 'Size', group: 'Plot', type: FieldType.number, required: true),
      PropertyField(
        key: 'size_unit',
        label: 'Size unit',
        group: 'Plot',
        type: FieldType.select,
        options: ['marla', 'kanal', 'acre', 'sq ft', 'sq yd', 'hectare'],
        required: true,
      ),
      PropertyField(key: 'price_per_unit', money: true, label: 'Price per unit', group: 'Plot', type: FieldType.number),
      PropertyField(key: 'road_width', label: 'Road width', group: 'Plot', type: FieldType.number, unit: 'ft'),
      PropertyField(key: 'corner', label: 'Corner plot', group: 'Plot', type: FieldType.toggle),
      PropertyField(key: 'boundary_wall', label: 'Boundary wall', group: 'Plot', type: FieldType.toggle),
      PropertyField(
        key: 'utilities',
        label: 'Utilities available',
        group: 'Utilities',
        type: FieldType.multiSelect,
        options: ['Gas', 'Electricity', 'Water', 'Sewerage'],
      ),
      PropertyField(key: 'possession', label: 'Possession', group: 'Legal', type: FieldType.select, options: ['Ready', 'Under development']),
      PropertyField(key: 'scheme_name', label: 'Approved scheme / society', group: 'Legal', type: FieldType.text),
      PropertyField(
        key: 'document_type',
        label: 'Ownership document',
        group: 'Legal',
        type: FieldType.select,
        options: ['Registry', 'Fard', 'Allotment letter', 'Title deed'],
        required: true,
        hint: 'The document photo is visible only to admin',
      ),
    ],
    keyFacts: [
      KeyFact('size', '{v}', unitFrom: 'size_unit'),
      KeyFact('land_type', '{v}'),
    ],
  ),
  const PropertyType(
    id: 'other',
    name: 'Other',
    icon: Icons.holiday_village_rounded,
    color: Color(0xFF00ACC1),
    purposes: [ListingPurpose.rent],
    defaultPeriod: PricePeriod.perDay,
    includedOptions: ['Wi-Fi', 'Electricity', 'Meals', 'Cleaning'],
    fields: [
      PropertyField(
        key: 'stay_kind',
        label: 'Kind',
        group: 'Details',
        type: FieldType.select,
        options: ['PG', 'Short-term stay', 'Guest room', 'Serviced apartment'],
        required: true,
      ),
      PropertyField(key: 'rooms', label: 'Rooms', group: 'Details', type: FieldType.number),
      PropertyField(
        key: 'features',
        label: 'Features',
        group: 'Details',
        type: FieldType.multiSelect,
        options: ['AC', 'Parking', 'Attached bath', 'Kitchen access', 'TV'],
      ),
    ],
    keyFacts: [KeyFact('stay_kind', '{v}'), KeyFact('rooms', '{v} rooms')],
  ),
];
