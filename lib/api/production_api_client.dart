import 'package:dio/dio.dart';

import '../models/production_record_model.dart';

class SyncRecordResult {
  final String clientUuid;
  final String? serverId;
  final String status;
  final String? errorMessage;

  const SyncRecordResult({
    required this.clientUuid,
    required this.status,
    this.serverId,
    this.errorMessage,
  });

  factory SyncRecordResult.fromMap(Map<String, dynamic> map) {
    return SyncRecordResult(
      clientUuid: map['clientUuid'] as String,
      serverId: map['serverId'] as String?,
      status: map['status'] as String? ?? 'synced',
      errorMessage: map['errorMessage'] as String?,
    );
  }
}

class ProductionApiClient {
  ProductionApiClient({
    Dio? dio,
    String? baseUrl,
  })  : baseUrl = baseUrl ?? const String.fromEnvironment('API_BASE_URL'),
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl:
                    baseUrl ?? const String.fromEnvironment('API_BASE_URL'),
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 12),
                sendTimeout: const Duration(seconds: 12),
              ),
            );

  final Dio _dio;
  final String baseUrl;

  bool get isConfigured => baseUrl.trim().isNotEmpty;

  Future<List<SyncRecordResult>> syncProductionRecords({
    required String deviceId,
    required List<ProductionRecord> records,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/production-records/sync',
      data: {
        'deviceId': deviceId,
        'records': records.map((record) => record.toSyncPayload()).toList(),
      },
    );

    final data = response.data;
    final rows = data?['records'];
    if (rows is! List) {
      throw StateError('同步接口响应缺少 records 数组');
    }

    return rows
        .whereType<Map<String, dynamic>>()
        .map(SyncRecordResult.fromMap)
        .toList();
  }
}
