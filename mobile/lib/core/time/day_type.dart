enum DayType {
  weekday,
  weekend;

  /// ISO day of week: 1 = Monday ... 5 = Friday (weekday), 6 = Saturday, 7 = Sunday (weekend)
  static DayType fromDow(int dow) {
    if (dow >= 6) {
      return DayType.weekend;
    }
    return DayType.weekday;
  }

  static DayType fromDateTime(DateTime dateTime) {
    return fromDow(dateTime.weekday);
  }
}
