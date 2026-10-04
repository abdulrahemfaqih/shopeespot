import 'package:flutter_test/flutter_test.dart';
import 'package:shopeespot/core/sync/merge_rules.dart';

void main() {
  group('decideMerge', () {
    final t1 = DateTime.utc(2026, 10, 4, 10, 0, 0);
    final t2 = DateTime.utc(2026, 10, 4, 11, 0, 0);
    final t3 = DateTime.utc(2026, 10, 4, 12, 0, 0);

    test(
      'returns insert when local does not exist (localUpdatedAt == null)',
      () {
        final actionDirtyFalse = decideMerge(
          localUpdatedAt: null,
          localDirty: false,
          incomingUpdatedAt: t2,
        );
        expect(actionDirtyFalse, MergeAction.insert);

        final actionDirtyTrue = decideMerge(
          localUpdatedAt: null,
          localDirty: true,
          incomingUpdatedAt: t2,
        );
        expect(actionDirtyTrue, MergeAction.insert);
      },
    );

    test('returns update when incoming is newer than local (clean local)', () {
      final action = decideMerge(
        localUpdatedAt: t1,
        localDirty: false,
        incomingUpdatedAt: t2,
      );
      expect(action, MergeAction.update);
    });

    test('returns update when incoming is newer than local (dirty local)', () {
      final action = decideMerge(
        localUpdatedAt: t1,
        localDirty: true,
        incomingUpdatedAt: t2,
      );
      expect(action, MergeAction.update);
    });

    test('returns skip when incoming is older than local (clean local)', () {
      final action = decideMerge(
        localUpdatedAt: t3,
        localDirty: false,
        incomingUpdatedAt: t2,
      );
      expect(action, MergeAction.skip);
    });

    test('returns skip when incoming is older than local (dirty local)', () {
      final action = decideMerge(
        localUpdatedAt: t3,
        localDirty: true,
        incomingUpdatedAt: t2,
      );
      expect(action, MergeAction.skip);
    });

    test('returns skip when incoming has exact same timestamp as local', () {
      final actionClean = decideMerge(
        localUpdatedAt: t2,
        localDirty: false,
        incomingUpdatedAt: t2,
      );
      expect(actionClean, MergeAction.skip);

      final actionDirty = decideMerge(
        localUpdatedAt: t2,
        localDirty: true,
        incomingUpdatedAt: t2,
      );
      expect(actionDirty, MergeAction.skip);
    });

    test('correctly normalizes UTC and local DateTime differences', () {
      // t2 in UTC and equivalent local time
      final t2Local = t2.toLocal();
      final action = decideMerge(
        localUpdatedAt: t1.toLocal(),
        localDirty: false,
        incomingUpdatedAt: t2Local,
      );
      expect(action, MergeAction.update);

      final actionSame = decideMerge(
        localUpdatedAt: t2Local,
        localDirty: false,
        incomingUpdatedAt: t2,
      );
      expect(actionSame, MergeAction.skip);
    });
  });
}
