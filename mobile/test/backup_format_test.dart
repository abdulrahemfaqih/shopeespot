import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopeespot/core/db/app_database.dart';
import 'package:shopeespot/core/time/clock.dart';
import 'package:shopeespot/features/backup/data/backup_service.dart';
import 'package:shopeespot/features/backup/domain/backup_models.dart';
import 'package:shopeespot/features/orders/data/order_repository.dart';
import 'package:shopeespot/features/spots/data/spot_repository.dart';
import 'package:shopeespot/features/spots/domain/category.dart';
import 'package:shopeespot/features/spots/domain/peak_range.dart';
import 'package:shopeespot/features/spots/domain/spot.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late SpotRepository spotRepo;
  late OrderRepository orderRepo;
  late Clock fixedClock;
  final now = DateTime.utc(2026, 10, 4, 12, 0, 0);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    fixedClock = FixedClock(now);
    spotRepo = SpotRepository(db: db, clock: fixedClock);
    orderRepo = OrderRepository(
      db: db,
      spotRepository: spotRepo,
      clock: fixedClock,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('BackupService Export', () {
    test('exports active spots and orders in exact schema format', () async {
      // Create spot
      final spot = await spotRepo.createSpot(
        id: 'spot-1',
        name: 'Warung Barokah',
        category: Category.shopeefood,
        latitude: -6.2,
        longitude: 106.8,
        notes: 'Pintu timur',
        peakHours: const [
          PeakRange(days: [1, 2, 3], start: 600, end: 720),
        ],
      );

      // Create another spot and soft delete it
      final deletedSpot = await spotRepo.createSpot(
        id: 'spot-del',
        name: 'Spot Terhapus',
        category: Category.spx,
        latitude: -6.3,
        longitude: 106.9,
      );
      await spotRepo.softDeleteSpot(deletedSpot.id);

      // Record order on active spot
      await orderRepo.recordOrder(
        spotId: spot.id,
        id: 'order-1',
        orderedAt: now,
      );

      final service = BackupService(
        spotRepository: spotRepo,
        orderRepository: orderRepo,
        clock: fixedClock,
      );

      final backupMap = await service.buildBackupMap(scope: BackupScope.all);

      expect(backupMap['app'], 'spotshopee');
      expect(backupMap['version'], 1);
      expect(backupMap['exported_at'], now.toIso8601String());

      // Spots: only active spots, deleted spot must NOT be present
      final spots = backupMap['spots'] as List<dynamic>;
      expect(spots.length, 1);
      final s0 = spots.first as Map<String, dynamic>;
      expect(s0['id'], 'spot-1');
      expect(s0['name'], 'Warung Barokah');
      expect(s0['category'], 'shopeefood');
      expect(s0['latitude'], -6.2);
      expect(s0['longitude'], 106.8);
      expect(s0['notes'], 'Pintu timur');
      expect(s0['deleted_at'], isNull);

      // Orders: active order present
      final orders = backupMap['orders'] as List<dynamic>;
      expect(orders.length, 1);
      final o0 = orders.first as Map<String, dynamic>;
      expect(o0['id'], 'order-1');
      expect(o0['spot_id'], 'spot-1');
      expect(o0['deleted_at'], isNull);
    });

    test('scope spotsOnly produces empty orders array', () async {
      await spotRepo.createSpot(
        id: 'spot-1',
        name: 'Hub SPX',
        category: Category.spx,
        latitude: -6.2,
        longitude: 106.8,
      );
      await orderRepo.recordOrder(spotId: 'spot-1', id: 'ord-1');

      final service = BackupService(
        spotRepository: spotRepo,
        orderRepository: orderRepo,
        clock: fixedClock,
      );

      final backupMap = await service.buildBackupMap(
        scope: BackupScope.spotsOnly,
      );
      expect(backupMap['spots'], hasLength(1));
      expect(backupMap['orders'], isEmpty);
    });

    test(
      'generateBackupJson returns valid JSON string with indentation',
      () async {
        await spotRepo.createSpot(
          id: 'spot-1',
          name: 'Spot Indent',
          category: Category.shopeefood,
          latitude: -6.2,
          longitude: 106.8,
        );

        final service = BackupService(
          spotRepository: spotRepo,
          orderRepository: orderRepo,
          clock: fixedClock,
        );

        final jsonStr = await service.generateBackupJson();
        expect(jsonStr.contains('\n  "app": "spotshopee"'), isTrue);
        final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
        expect(decoded['app'], 'spotshopee');
      },
    );
  });

  group('BackupService Import & Merge', () {
    test('restores full data into empty database with dirty = true', () async {
      final service = BackupService(
        spotRepository: spotRepo,
        orderRepository: orderRepo,
        clock: fixedClock,
      );

      final jsonPayload = jsonEncode({
        'app': 'spotshopee',
        'version': 1,
        'exported_at': '2026-10-04T12:00:00Z',
        'spots': [
          {
            'id': 'spot-imported-1',
            'name': 'Ayam Geprek',
            'category': 'shopeefood',
            'latitude': -6.1754,
            'longitude': 106.8272,
            'notes': 'Patokan sebelah Alfamart',
            'peak_hours': [
              {
                'days': [1, 2, 3, 4, 5],
                'start': 660,
                'end': 780,
              },
            ],
            'last_verified_at': '2026-10-04T10:00:00Z',
            'created_at': '2026-10-01T08:00:00Z',
            'updated_at': '2026-10-04T10:00:00Z',
            'deleted_at': null,
          },
        ],
        'orders': [
          {
            'id': 'order-imported-1',
            'spot_id': 'spot-imported-1',
            'ordered_at': '2026-10-04T11:30:00Z',
            'local_dow': 7,
            'local_hour': 18,
            'created_at': '2026-10-04T11:30:00Z',
            'updated_at': '2026-10-04T11:30:00Z',
            'deleted_at': null,
          },
        ],
      });

      final summary = await service.importFromJsonString(jsonPayload);

      expect(summary.spotsAdded, 1);
      expect(summary.spotsUpdated, 0);
      expect(summary.spotsSkipped, 0);
      expect(summary.ordersAdded, 1);
      expect(summary.ordersUpdated, 0);
      expect(summary.ordersSkipped, 0);
      expect(summary.ordersOrphaned, 0);

      // Verify in DB
      final spots = await spotRepo.getActiveSpots();
      expect(spots.length, 1);
      final spot = spots.first;
      expect(spot.id, 'spot-imported-1');
      expect(spot.name, 'Ayam Geprek');
      expect(spot.peakHours.length, 1);
      expect(spot.peakHours.first.start, 660);
      expect(spot.dirty, isTrue, reason: 'Imported data must be marked dirty');

      final orders = await orderRepo.getActiveOrders();
      expect(orders.length, 1);
      final order = orders.first;
      expect(order.id, 'order-imported-1');
      expect(order.spotId, 'spot-imported-1');
      expect(
        order.dirty,
        isTrue,
        reason: 'Imported order must be marked dirty',
      );
    });

    test('merges incoming data according to merge_rules', () async {
      final t1 = DateTime.utc(2026, 10, 4, 10, 0, 0);
      final t2 = DateTime.utc(2026, 10, 4, 11, 0, 0);
      final t3 = DateTime.utc(2026, 10, 4, 12, 0, 0);

      // Local spot with updatedAt = t2
      await spotRepo.upsertSpot(
        Spot(
          id: 'spot-local',
          name: 'Nama Lokal Lama',
          category: Category.shopeefood,
          latitude: -6.2,
          longitude: 106.8,
          createdAt: t1,
          updatedAt: t2,
          dirty: false,
        ),
      );

      // Incoming 1: spot-local with updatedAt = t3 (newer -> should update)
      // Incoming 2: spot-older with updatedAt = t1 (older than local t2 -> should skip)
      // Incoming 3: spot-same with updatedAt = t2 (same as local t2 -> should skip)
      await spotRepo.upsertSpot(
        Spot(
          id: 'spot-same',
          name: 'Spot Same Local',
          category: Category.spx,
          latitude: -6.2,
          longitude: 106.8,
          createdAt: t1,
          updatedAt: t2,
          dirty: false,
        ),
      );

      final jsonPayload = jsonEncode({
        'app': 'spotshopee',
        'version': 1,
        'exported_at': '2026-10-04T12:00:00Z',
        'spots': [
          {
            'id': 'spot-local',
            'name': 'Nama Dari Backup Baru',
            'category': 'shopeefood',
            'latitude': -6.2,
            'longitude': 106.8,
            'created_at': t1.toIso8601String(),
            'updated_at': t3.toIso8601String(),
            'deleted_at': null,
          },
          {
            'id': 'spot-same',
            'name': 'Nama Diabaikan Karena Tidak Lebih Baru',
            'category': 'spx',
            'latitude': -6.2,
            'longitude': 106.8,
            'created_at': t1.toIso8601String(),
            'updated_at': t2.toIso8601String(),
            'deleted_at': null,
          },
        ],
        'orders': [],
      });

      final service = BackupService(
        spotRepository: spotRepo,
        orderRepository: orderRepo,
        clock: fixedClock,
      );

      final summary = await service.importFromJsonString(jsonPayload);

      expect(summary.spotsAdded, 0);
      expect(summary.spotsUpdated, 1);
      expect(summary.spotsSkipped, 1);

      final updatedSpot = await spotRepo.getSpotById('spot-local');
      expect(updatedSpot?.name, 'Nama Dari Backup Baru');
      expect(updatedSpot?.dirty, isTrue);

      final skippedSpot = await spotRepo.getSpotById('spot-same');
      expect(skippedSpot?.name, 'Spot Same Local');
    });

    test(
      'ignores orphaned orders and increments ordersOrphaned in summary',
      () async {
        final t1 = DateTime.utc(2026, 10, 4, 10, 0, 0);

        // DB has spot-1
        await spotRepo.upsertSpot(
          Spot(
            id: 'spot-1',
            name: 'Spot Valid',
            category: Category.shopeefood,
            latitude: -6.2,
            longitude: 106.8,
            createdAt: t1,
            updatedAt: t1,
          ),
        );

        final jsonPayload = jsonEncode({
          'app': 'spotshopee',
          'version': 1,
          'exported_at': '2026-10-04T12:00:00Z',
          'spots': [],
          'orders': [
            {
              'id': 'ord-valid',
              'spot_id': 'spot-1',
              'ordered_at': t1.toIso8601String(),
              'local_dow': 1,
              'local_hour': 10,
              'created_at': t1.toIso8601String(),
              'updated_at': t1.toIso8601String(),
              'deleted_at': null,
            },
            {
              'id': 'ord-orphan',
              'spot_id': 'spot-non-existent',
              'ordered_at': t1.toIso8601String(),
              'local_dow': 1,
              'local_hour': 10,
              'created_at': t1.toIso8601String(),
              'updated_at': t1.toIso8601String(),
              'deleted_at': null,
            },
          ],
        });

        final service = BackupService(
          spotRepository: spotRepo,
          orderRepository: orderRepo,
          clock: fixedClock,
        );

        final summary = await service.importFromJsonString(jsonPayload);

        expect(summary.ordersAdded, 1);
        expect(summary.ordersOrphaned, 1);

        // ord-orphan must not exist in DB
        final orphanOrder = await orderRepo.getOrderById('ord-orphan');
        expect(orphanOrder, isNull);

        final validOrder = await orderRepo.getOrderById('ord-valid');
        expect(validOrder, isNotNull);
      },
    );

    test('validates app name, version, and structure', () async {
      final service = BackupService(
        spotRepository: spotRepo,
        orderRepository: orderRepo,
        clock: fixedClock,
      );

      // Malformed JSON
      expect(
        () => service.importFromJsonString('{not valid json}'),
        throwsA(isA<InvalidBackupException>()),
      );

      // App not spotshopee
      expect(
        () => service.importFromJsonString(
          jsonEncode({'app': 'otherapp', 'version': 1, 'spots': []}),
        ),
        throwsA(isA<InvalidBackupException>()),
      );

      // Version not 1
      expect(
        () => service.importFromJsonString(
          jsonEncode({'app': 'spotshopee', 'version': 2, 'spots': []}),
        ),
        throwsA(isA<InvalidBackupException>()),
      );

      // Spots is not a list
      expect(
        () => service.importFromJsonString(
          jsonEncode({'app': 'spotshopee', 'version': 1, 'spots': 'wrong'}),
        ),
        throwsA(isA<InvalidBackupException>()),
      );

      // Orders is not a list
      expect(
        () => service.importFromJsonString(
          jsonEncode({
            'app': 'spotshopee',
            'version': 1,
            'spots': [],
            'orders': 123,
          }),
        ),
        throwsA(isA<InvalidBackupException>()),
      );
    });

    test('formatSummary outputs correct Indonesian summary', () {
      const summaryWithOrphans = BackupImportSummary(
        spotsAdded: 3,
        spotsUpdated: 1,
        spotsSkipped: 2,
        ordersAdded: 5,
        ordersUpdated: 0,
        ordersSkipped: 1,
        ordersOrphaned: 2,
      );

      final text = summaryWithOrphans.formatSummary();
      expect(
        text.contains('Spot: 3 ditambah, 1 diperbarui, 2 dilewati'),
        isTrue,
      );
      expect(
        text.contains(
          'Order: 5 ditambah, 0 diperbarui, 1 dilewati (2 diabaikan karena spot tidak ada)',
        ),
        isTrue,
      );

      const summaryWithoutOrphans = BackupImportSummary(
        spotsAdded: 1,
        spotsUpdated: 0,
        spotsSkipped: 0,
        ordersAdded: 1,
        ordersUpdated: 0,
        ordersSkipped: 0,
        ordersOrphaned: 0,
      );
      expect(
        summaryWithoutOrphans.formatSummary().contains('diabaikan'),
        isFalse,
      );
    });
  });

  group('BackupService File Operations with Injected Functions', () {
    test('exportAndShare calls shareFn with file path', () async {
      await spotRepo.createSpot(
        id: 'spot-share',
        name: 'Spot Share',
        category: Category.shopeefood,
        latitude: -6.2,
        longitude: 106.8,
      );

      String? sharedFilePath;
      String? sharedFileName;
      final tempDir = Directory.systemTemp.createTempSync('backup_test_');

      final service = BackupService(
        spotRepository: spotRepo,
        orderRepository: orderRepo,
        clock: fixedClock,
        tempDirFn: () async => tempDir,
        shareFn: (filePath, fileName) async {
          sharedFilePath = filePath;
          sharedFileName = fileName;
        },
      );

      await service.exportAndShare();

      expect(sharedFilePath, isNotNull);
      expect(sharedFileName, startsWith('spotshopee_backup_'));
      expect(File(sharedFilePath!).existsSync(), isTrue);

      tempDir.deleteSync(recursive: true);
    });

    test('importFromFile processes picked file content', () async {
      final jsonPayload = jsonEncode({
        'app': 'spotshopee',
        'version': 1,
        'exported_at': '2026-10-04T12:00:00Z',
        'spots': [
          {
            'id': 'spot-picked',
            'name': 'Spot Dari File',
            'category': 'spx',
            'latitude': -6.2,
            'longitude': 106.8,
            'created_at': '2026-10-04T12:00:00Z',
            'updated_at': '2026-10-04T12:00:00Z',
          },
        ],
        'orders': [],
      });

      final service = BackupService(
        spotRepository: spotRepo,
        orderRepository: orderRepo,
        clock: fixedClock,
        pickFileFn: () async => jsonPayload,
      );

      final summary = await service.importFromFile();
      expect(summary, isNotNull);
      expect(summary!.spotsAdded, 1);

      final imported = await spotRepo.getSpotById('spot-picked');
      expect(imported?.name, 'Spot Dari File');
    });

    test('importFromFile returns null if file picking was cancelled', () async {
      final service = BackupService(
        spotRepository: spotRepo,
        orderRepository: orderRepo,
        clock: fixedClock,
        pickFileFn: () async => null,
      );

      final summary = await service.importFromFile();
      expect(summary, isNull);
    });
  });
}
