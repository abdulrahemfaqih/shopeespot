import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopeespot/app/theme/app_theme.dart';
import 'package:shopeespot/core/db/app_database.dart';
import 'package:shopeespot/features/auth/data/token_store.dart';
import 'package:shopeespot/features/auth/domain/session_state.dart';
import 'package:shopeespot/features/auth/presentation/auth_controller.dart';
import 'package:shopeespot/features/settings/presentation/settings_screen.dart';
import 'package:shopeespot/features/spots/data/spot_dao.dart';
import 'package:shopeespot/features/spots/presentation/spots_providers.dart';
import 'package:shopeespot/features/sync/data/sync_api.dart';
import 'package:shopeespot/features/sync/data/sync_state_store.dart';
import 'package:shopeespot/features/sync/domain/sync_models.dart';
import 'package:shopeespot/features/sync/presentation/sync_providers.dart';

import 'auth_test.dart';
import 'login_test.dart';

class MockSyncApiForUi implements ISyncApi {
  bool syncCalled = false;
  bool shouldFail = false;

  @override
  Future<SyncResponseDto> sync(SyncRequestDto request) async {
    syncCalled = true;
    if (shouldFail) {
      throw Exception('Network error');
    }
    return SyncResponseDto(
      cursors: const SyncCursors(spots: 1, orders: 1),
      spots: const [],
      orders: const [],
      hasMore: false,
      serverTime: DateTime.utc(2026, 10, 4, 14, 30),
    );
  }
}

class FakeSyncStateStoreForUi implements ISyncStateStore {
  SyncCursors cursors = const SyncCursors();
  DateTime? lastSyncedAt;

  @override
  Future<SyncCursors> getCursors() async => cursors;

  @override
  Future<void> saveCursors(SyncCursors cursors) async {
    this.cursors = cursors;
  }

  @override
  Future<DateTime?> getLastSyncedAt() async => lastSyncedAt;

  @override
  Future<void> saveLastSyncedAt(DateTime timestamp) async {
    lastSyncedAt = timestamp;
  }

  @override
  Future<void> clear() async {
    cursors = const SyncCursors();
    lastSyncedAt = null;
  }
}

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('T-30 Settings Sync and Account', () {
    testWidgets(
      'renders initial state: Belum pernah sinkron, Sinkronkan sekarang, user email, Keluar',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());

        final tokenStore = FakeTokenStore()
          ..accessToken = 'valid-token'
          ..refreshToken = 'valid-refresh'
          ..userId = 'user-1'
          ..userEmail = 'driver@example.com';

        final stateStore = FakeSyncStateStoreForUi();
        final syncApi = MockSyncApiForUi();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              totalDirtyCountProvider.overrideWithValue(0),
              tokenStoreProvider.overrideWithValue(tokenStore),
              syncStateStoreProvider.overrideWithValue(stateStore),
              syncApiProvider.overrideWithValue(syncApi),
              sessionStateProvider.overrideWith(
                (ref) => SessionNotifier(
                  tokenStore,
                  MockAuthApi(),
                  initialState: const SessionState.authenticated(
                    userId: 'user-1',
                    userEmail: 'driver@example.com',
                  ),
                ),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const SettingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Sinkronisasi'), findsOneWidget);
        expect(find.text('Belum pernah sinkron'), findsOneWidget);
        expect(find.text('Sinkronkan sekarang'), findsOneWidget);

        expect(find.text('Akun'), findsOneWidget);
        expect(find.text('driver@example.com'), findsOneWidget);
        expect(find.text('Keluar'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await db.close();
      },
    );

    testWidgets(
      'displays formatted Terakhir sinkron and N perubahan menunggu when dirty spots exist',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        final now = DateTime.now();

        final stateStore = FakeSyncStateStoreForUi()
          ..lastSyncedAt = DateTime(now.year, now.month, now.day, 14, 30);

        final tokenStore = FakeTokenStore()
          ..accessToken = 'valid'
          ..refreshToken = 'valid-refresh';

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              totalDirtyCountProvider.overrideWithValue(1),
              tokenStoreProvider.overrideWithValue(tokenStore),
              syncStateStoreProvider.overrideWithValue(stateStore),
              sessionStateProvider.overrideWith(
                (ref) => SessionNotifier(
                  tokenStore,
                  MockAuthApi(),
                  initialState: const SessionState.authenticated(
                    userId: 'user-1',
                    userEmail: 'driver@example.com',
                  ),
                ),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const SettingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Terakhir sinkron: 14:30 · 1 perubahan menunggu'),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await db.close();
      },
    );

    testWidgets(
      'tapping Sinkronkan sekarang runs sync and shows success feedback',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());

        final tokenStore = FakeTokenStore()
          ..accessToken = 'valid'
          ..refreshToken = 'valid-refresh';
        final stateStore = FakeSyncStateStoreForUi();
        final syncApi = MockSyncApiForUi();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              totalDirtyCountProvider.overrideWithValue(0),
              tokenStoreProvider.overrideWithValue(tokenStore),
              syncStateStoreProvider.overrideWithValue(stateStore),
              syncApiProvider.overrideWithValue(syncApi),
              sessionStateProvider.overrideWith(
                (ref) => SessionNotifier(
                  tokenStore,
                  MockAuthApi(),
                  initialState: const SessionState.authenticated(
                    userId: 'user-1',
                    userEmail: 'driver@example.com',
                  ),
                ),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const SettingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Sinkronkan sekarang'));
        await tester.pumpAndSettle();

        expect(syncApi.syncCalled, isTrue);
        expect(find.text('Sinkronisasi selesai'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await db.close();
      },
    );

    testWidgets(
      'session expired displays ajakan masuk lagi and Masuk lagi button',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());

        final tokenStore = FakeTokenStore();
        final stateStore = FakeSyncStateStoreForUi();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              totalDirtyCountProvider.overrideWithValue(0),
              tokenStoreProvider.overrideWithValue(tokenStore),
              syncStateStoreProvider.overrideWithValue(stateStore),
              sessionStateProvider.overrideWith(
                (ref) => SessionNotifier(
                  tokenStore,
                  MockAuthApi(),
                  initialState: const SessionState.expired(
                    userId: 'user-1',
                    userEmail: 'driver@example.com',
                  ),
                ),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const SettingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Sesi berakhir. Masuk lagi untuk sinkronisasi.'),
          findsOneWidget,
        );
        expect(find.text('Masuk lagi'), findsOneWidget);
        expect(find.text('driver@example.com · Sesi berakhir'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await db.close();
      },
    );

    testWidgets(
      'tapping Keluar with dirty data shows unsynced changes warning dialog',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        final spotDao = SpotDao(db);
        final now = DateTime.now();

        // 2 dirty spots in SQLite
        await spotDao.insertSpot(
          SpotsCompanion.insert(
            id: 'spot-1',
            name: 'Spot A',
            category: 'shopeefood',
            latitude: -6.2,
            longitude: 106.8,
            dirty: const Value(true),
            createdAt: now,
            updatedAt: now,
          ),
        );
        await spotDao.insertSpot(
          SpotsCompanion.insert(
            id: 'spot-2',
            name: 'Spot B',
            category: 'spx',
            latitude: -6.21,
            longitude: 106.81,
            dirty: const Value(true),
            createdAt: now,
            updatedAt: now,
          ),
        );

        final tokenStore = FakeTokenStore()
          ..accessToken = 'valid'
          ..refreshToken = 'valid-refresh'
          ..userEmail = 'driver@example.com';

        final sessionNotifier = SessionNotifier(
          tokenStore,
          MockAuthApi(),
          initialState: const SessionState.authenticated(
            userId: 'user-1',
            userEmail: 'driver@example.com',
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              totalDirtyCountProvider.overrideWithValue(2),
              tokenStoreProvider.overrideWithValue(tokenStore),
              sessionStateProvider.overrideWith((ref) => sessionNotifier),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const SettingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap Keluar button
        await tester.tap(find.text('Keluar'));
        await tester.pumpAndSettle();

        // Dialog opened with warning about unsynced changes
        expect(find.text('Keluar akun'), findsOneWidget);
        expect(
          find.textContaining('Ada 2 perubahan yang belum tersinkron'),
          findsOneWidget,
        );

        // Cancel dismissal
        await tester.tap(find.text('Batal'));
        await tester.pumpAndSettle();

        expect(find.text('Keluar akun'), findsNothing);
        expect(sessionNotifier.state.isAuthenticated, isTrue);

        // Tap Keluar again and confirm
        await tester.tap(find.text('Keluar'));
        await tester.pumpAndSettle();

        // Tap Keluar in dialog
        final dialogConfirmButton = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Keluar'),
        );
        await tester.tap(dialogConfirmButton);
        await tester.pumpAndSettle();

        // Session is unauthenticated now
        expect(sessionNotifier.state.isAuthenticated, isFalse);

        // Verify local SQLite data is NOT deleted!
        final spotsAfterLogout = await spotDao.getActiveSpots();
        expect(spotsAfterLogout.length, 2);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await db.close();
      },
    );

    testWidgets(
      'tapping Keluar with 0 dirty data shows standard confirmation dialog',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());

        final tokenStore = FakeTokenStore()
          ..accessToken = 'valid'
          ..refreshToken = 'valid-refresh'
          ..userEmail = 'driver@example.com';

        final sessionNotifier = SessionNotifier(
          tokenStore,
          MockAuthApi(),
          initialState: const SessionState.authenticated(
            userId: 'user-1',
            userEmail: 'driver@example.com',
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              totalDirtyCountProvider.overrideWithValue(0),
              tokenStoreProvider.overrideWithValue(tokenStore),
              sessionStateProvider.overrideWith((ref) => sessionNotifier),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const SettingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Keluar'));
        await tester.pumpAndSettle();

        expect(find.text('Keluar akun'), findsOneWidget);
        expect(
          find.text(
            'Keluar dari akun driver@example.com? Data lokal akan tetap tersimpan di perangkat ini.',
          ),
          findsOneWidget,
        );

        final dialogConfirmButton = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Keluar'),
        );
        await tester.tap(dialogConfirmButton);
        await tester.pumpAndSettle();

        expect(sessionNotifier.state.isAuthenticated, isFalse);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await db.close();
      },
    );
  });
}
