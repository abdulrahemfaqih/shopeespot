/// Formats a distance in kilometers according to DESIGN.md rules:
/// - Under 1 km: formatted in meters rounded to nearest 10 (e.g. "350 m", "0 m").
///   If rounding reaches 1000 m (e.g. 999 m), formatted as "1,0 km".
/// - 1 km and above: formatted with 1 decimal place using a comma (e.g. "1,0 km", "1,2 km", "1,3 km").
String formatDistance(double km) {
  if (km < 0) {
    km = 0;
  }
  final meters = km * 1000.0;
  final roundedMeters = (meters / 10.0).round() * 10;

  if (roundedMeters < 1000) {
    return '$roundedMeters m';
  }

  // 1 km or more (including values like 999 m rounded up to 1000 m)
  final kmValue = roundedMeters >= 1000 && km < 1.0 ? 1.0 : km;
  final formatted = kmValue.toStringAsFixed(1).replaceAll('.', ',');
  return '$formatted km';
}

/// Convenience function to format distance given in meters.
String formatDistanceMeters(double meters) {
  return formatDistance(meters / 1000.0);
}
