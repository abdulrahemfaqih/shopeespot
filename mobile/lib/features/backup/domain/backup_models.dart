enum BackupScope { all, spotsOnly }

class InvalidBackupException implements Exception {
  const InvalidBackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BackupImportSummary {
  const BackupImportSummary({
    this.spotsAdded = 0,
    this.spotsUpdated = 0,
    this.spotsSkipped = 0,
    this.ordersAdded = 0,
    this.ordersUpdated = 0,
    this.ordersSkipped = 0,
    this.ordersOrphaned = 0,
  });

  final int spotsAdded;
  final int spotsUpdated;
  final int spotsSkipped;
  final int ordersAdded;
  final int ordersUpdated;
  final int ordersSkipped;
  final int ordersOrphaned;

  int get totalSpots => spotsAdded + spotsUpdated + spotsSkipped;
  int get totalOrders =>
      ordersAdded + ordersUpdated + ordersSkipped + ordersOrphaned;

  String formatSummary() {
    final buffer = StringBuffer('Impor selesai.\n\n');
    buffer.writeln(
      'Spot: $spotsAdded ditambah, $spotsUpdated diperbarui, $spotsSkipped dilewati',
    );
    if (ordersOrphaned > 0) {
      buffer.write(
        'Order: $ordersAdded ditambah, $ordersUpdated diperbarui, $ordersSkipped dilewati ($ordersOrphaned diabaikan karena spot tidak ada)',
      );
    } else {
      buffer.write(
        'Order: $ordersAdded ditambah, $ordersUpdated diperbarui, $ordersSkipped dilewati',
      );
    }
    return buffer.toString();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BackupImportSummary) return false;
    return other.spotsAdded == spotsAdded &&
        other.spotsUpdated == spotsUpdated &&
        other.spotsSkipped == spotsSkipped &&
        other.ordersAdded == ordersAdded &&
        other.ordersUpdated == ordersUpdated &&
        other.ordersSkipped == ordersSkipped &&
        other.ordersOrphaned == ordersOrphaned;
  }

  @override
  int get hashCode => Object.hash(
    spotsAdded,
    spotsUpdated,
    spotsSkipped,
    ordersAdded,
    ordersUpdated,
    ordersSkipped,
    ordersOrphaned,
  );
}
