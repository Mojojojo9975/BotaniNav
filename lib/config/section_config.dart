// lib/config/section_config.dart
//
// All known indoor greenhouse section labels from Section_Layer.geojson.
// The API returns sections as "A-12" (with dash) — we normalise by stripping
// the dash before checking, so both "A12" and "A-12" are handled.

abstract final class SectionConfig {
  /// Indoor section labels without dashes (as in the GeoJSON).
  static const Set<String> indoorSections = {
    'A1',  'A2',  'A3',  'A6',  'A7',  'A8',  'A9',
    'A10', 'A11', 'A12', 'A13', 'A15', 'A16', 'A17',
    'B1',  'B2',  'B3',  'B4',  'B5',  'B6',
    'D1',  'D2',  'D3',  'D5',  'D7',  'D8',  'D9',  'D10',
    'E1',  'E2',  'E4',  'E5',  'E6',  'E7',
    'F1',  'F2',  'F3',  'F4',
  };

  /// Returns true if [section] matches a known indoor section.
  /// Strips dashes and is case-insensitive — handles both "A12" and "A-12".
  static bool isIndoor(String? section) {
    if (section == null || section.isEmpty) return false;
    final normalised = section.replaceAll('-', '').trim().toUpperCase();
    return indoorSections.contains(normalised);
  }

  /// Normalise "A-12" → "A12" for map marker lookup.
  static String normalise(String section) =>
      section.replaceAll('-', '').trim().toUpperCase();
}
