import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/sync/merge_rules.dart';
import '../../../core/time/clock.dart';
import '../../orders/data/order_repository.dart';
import '../../orders/domain/order_log.dart';
import '../../spots/data/spot_repository.dart';
import '../../spots/domain/spot.dart';
import '../domain/backup_models.dart';

typedef ShareFileFn = Future<void> Function(String filePath, String fileName);
typedef PickFileFn = Future<String?> Function();
typedef TempDirFn = Future<Directory> Function();

class BackupService {
  BackupService({
    required SpotRepository spotRepository,
    required OrderRepository orderRepository,
    Clock clock = const SystemClock(),
    ShareFileFn? shareFn,
    PickFileFn? pickFileFn,
    TempDirFn? tempDirFn,
  }) : _spotRepository = spotRepository,
       _orderRepository = orderRepository,
       _clock = clock,
       _shareFn = shareFn,
       _pickFileFn = pickFileFn,
       _tempDirFn = tempDirFn;

  final SpotRepository _spotRepository;
  final OrderRepository _orderRepository;
  final Clock _clock;
  final ShareFileFn? _shareFn;
  final PickFileFn? _pickFileFn;
  final TempDirFn? _tempDirFn;

  bool get hasCustomShareFn => _shareFn != null;

  /// Builds the raw JSON map for the backup per ARCHITECTURE.md Section 11.
  Future<Map<String, dynamic>> buildBackupMap({
    BackupScope scope = BackupScope.all,
  }) async {
    final spots = await _spotRepository.getActiveSpots();
    final List<OrderLog> orders;
    if (scope == BackupScope.all) {
      orders = await _orderRepository.getActiveOrders();
    } else {
      orders = const <OrderLog>[];
    }

    return <String, dynamic>{
      'app': 'spotshopee',
      'version': 1,
      'exported_at': _clock.now().toUtc().toIso8601String(),
      'spots': spots.map((s) => s.toJson()).toList(),
      'orders': orders.map((o) => o.toJson()).toList(),
    };
  }

  /// Generates the indented JSON string.
  Future<String> generateBackupJson({
    BackupScope scope = BackupScope.all,
  }) async {
    final map = await buildBackupMap(scope: scope);
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  /// Writes backup JSON to a temporary file.
  Future<File> writeBackupToTempFile({
    BackupScope scope = BackupScope.all,
  }) async {
    final jsonContent = await generateBackupJson(scope: scope);
    final tempDir = _tempDirFn != null
        ? await _tempDirFn()
        : await getTemporaryDirectory();

    final timestamp = _clock
        .now()
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final fileName = 'spotshopee_backup_$timestamp.json';
    final file = File('${tempDir.path}/$fileName');
    file.writeAsStringSync(jsonContent);
    return file;
  }

  /// Exports backup to a file and triggers the share sheet.
  Future<void> exportAndShare({BackupScope scope = BackupScope.all}) async {
    final file = await writeBackupToTempFile(scope: scope);
    final fileName = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : 'spotshopee_backup.json';

    if (_shareFn != null) {
      await _shareFn(file.path, fileName);
    } else {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: 'Cadangan SpotShopee'),
      );
    }
  }

  /// Imports and merges data from a JSON string.
  Future<BackupImportSummary> importFromJsonString(String jsonContent) async {
    dynamic decoded;
    try {
      decoded = jsonDecode(jsonContent);
    } catch (_) {
      throw const InvalidBackupException('Format JSON tidak valid.');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const InvalidBackupException('Format berkas tidak valid.');
    }

    if (decoded['app'] != 'spotshopee') {
      throw const InvalidBackupException(
        'Berkas ini bukan cadangan SpotShopee.',
      );
    }

    if (decoded['version'] != 1) {
      throw const InvalidBackupException('Versi cadangan tidak didukung.');
    }

    final rawSpots = decoded['spots'];
    if (rawSpots is! List) {
      throw const InvalidBackupException('Data spot tidak valid.');
    }

    final rawOrders = decoded['orders'];
    if (rawOrders != null && rawOrders is! List) {
      throw const InvalidBackupException('Data order tidak valid.');
    }

    var spotsAdded = 0;
    var spotsUpdated = 0;
    var spotsSkipped = 0;

    for (final raw in rawSpots) {
      if (raw is! Map<String, dynamic>) {
        throw const InvalidBackupException('Format data spot tidak valid.');
      }
      final incoming = Spot.fromJson(raw, dirty: true);
      final local = await _spotRepository.getSpotById(incoming.id);
      final action = decideMerge(
        localUpdatedAt: local?.updatedAt,
        localDirty: local?.dirty ?? false,
        incomingUpdatedAt: incoming.updatedAt,
      );

      switch (action) {
        case MergeAction.insert:
          await _spotRepository.upsertSpot(incoming.copyWith(dirty: true));
          spotsAdded++;
          break;
        case MergeAction.update:
          await _spotRepository.upsertSpot(incoming.copyWith(dirty: true));
          spotsUpdated++;
          break;
        case MergeAction.skip:
          spotsSkipped++;
          break;
      }
    }

    var ordersAdded = 0;
    var ordersUpdated = 0;
    var ordersSkipped = 0;
    var ordersOrphaned = 0;

    if (rawOrders != null) {
      for (final raw in rawOrders) {
        if (raw is! Map<String, dynamic>) {
          throw const InvalidBackupException('Format data order tidak valid.');
        }
        final incoming = OrderLog.fromJson(raw, dirty: true);

        // Orphan check: spot must exist
        final parentSpot = await _spotRepository.getSpotById(incoming.spotId);
        if (parentSpot == null) {
          ordersOrphaned++;
          continue;
        }

        final local = await _orderRepository.getOrderById(incoming.id);
        final action = decideMerge(
          localUpdatedAt: local?.updatedAt,
          localDirty: local?.dirty ?? false,
          incomingUpdatedAt: incoming.updatedAt,
        );

        switch (action) {
          case MergeAction.insert:
            await _orderRepository.upsertOrder(incoming.copyWith(dirty: true));
            ordersAdded++;
            break;
          case MergeAction.update:
            await _orderRepository.upsertOrder(incoming.copyWith(dirty: true));
            ordersUpdated++;
            break;
          case MergeAction.skip:
            ordersSkipped++;
            break;
        }
      }
    }

    return BackupImportSummary(
      spotsAdded: spotsAdded,
      spotsUpdated: spotsUpdated,
      spotsSkipped: spotsSkipped,
      ordersAdded: ordersAdded,
      ordersUpdated: ordersUpdated,
      ordersSkipped: ordersSkipped,
      ordersOrphaned: ordersOrphaned,
    );
  }

  /// Opens the file picker and imports data.
  Future<BackupImportSummary?> importFromFile() async {
    final content = _pickFileFn != null
        ? await _pickFileFn()
        : await _defaultPickFile();

    if (content == null || content.trim().isEmpty) {
      return null;
    }

    return importFromJsonString(content);
  }

  Future<String?> _defaultPickFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (files.isEmpty) {
      return null;
    }

    final picked = files.first;
    return picked.xFile.readAsString();
  }
}
