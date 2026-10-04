/// Pure merge action decision.
enum MergeAction { insert, update, skip }

/// Decides how an incoming entity from server sync or backup import
/// should be merged with an existing local entity.
///
/// Rules (ARCHITECTURE.md Section 8):
/// - local does not exist (`localUpdatedAt == null`): insert
/// - incoming.updated_at > local.updated_at: update
/// - incoming.updated_at <= local.updated_at: keep local (skip)
MergeAction decideMerge({
  required DateTime? localUpdatedAt,
  required bool localDirty,
  required DateTime incomingUpdatedAt,
}) {
  if (localUpdatedAt == null) {
    return MergeAction.insert;
  }

  final incomingUtc = incomingUpdatedAt.toUtc();
  final localUtc = localUpdatedAt.toUtc();

  if (incomingUtc.isAfter(localUtc)) {
    return MergeAction.update;
  }

  return MergeAction.skip;
}
