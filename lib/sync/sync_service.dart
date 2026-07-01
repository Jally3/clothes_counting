import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../api/production_api_client.dart';
import '../models/production_record_model.dart';
import '../services/database_service.dart';

class SyncService {
  SyncService({
    DatabaseService? databaseService,
    ProductionApiClient? apiClient,
  })  : _databaseService = databaseService ?? DatabaseService.instance,
        _apiClient = apiClient ?? ProductionApiClient();

  static final SyncService instance = SyncService();

  final DatabaseService _databaseService;
  final ProductionApiClient _apiClient;
  bool _isSyncing = false;

  Future<void> syncPendingRecords() async {
    if (_isSyncing || !_apiClient.isConfigured) return;
    _isSyncing = true;

    try {
      final records = await _databaseService.getRecordsNeedingSync();
      if (records.isEmpty) return;

      final clientUuids = records
          .map((record) => record.clientUuid)
          .whereType<String>()
          .toList();
      await _databaseService.markRecordsSyncing(clientUuids);

      final deviceId = await _databaseService.getDeviceId();
      final results = await _apiClient.syncProductionRecords(
        deviceId: deviceId,
        records: records,
      );

      final resultByClientUuid = {
        for (final result in results) result.clientUuid: result,
      };

      for (final record in records) {
        final clientUuid = record.clientUuid;
        if (clientUuid == null) continue;

        final result = resultByClientUuid[clientUuid];
        if (result == null) {
          await _databaseService.markRecordSyncFailed(
            clientUuid: clientUuid,
            error: '同步响应缺少该记录结果',
          );
          continue;
        }

        if (result.status == SyncStatus.synced.name || result.status == 'ok') {
          await _databaseService.markRecordSynced(
            clientUuid: clientUuid,
            serverId: result.serverId,
          );
        } else {
          await _databaseService.markRecordSyncFailed(
            clientUuid: clientUuid,
            error: result.errorMessage ?? '服务器拒绝同步',
          );
        }
      }
    } on DioException catch (e) {
      await _markCurrentBatchFailed(e.message ?? e.type.name);
    } catch (e, stackTrace) {
      debugPrint('同步生产记录失败: $e\n$stackTrace');
      await _markCurrentBatchFailed(e.toString());
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _markCurrentBatchFailed(String error) async {
    await _databaseService.markSyncingRecordsFailed(error);
  }
}
