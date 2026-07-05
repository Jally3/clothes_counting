import 'dart:async';

import '../models/product_model.dart';
import '../models/production_record_model.dart';
import '../services/database_service.dart';
import '../sync/sync_service.dart';

class ProductionRepository {
  ProductionRepository({
    DatabaseService? databaseService,
    SyncService? syncService,
  })  : _databaseService = databaseService ?? DatabaseService.instance,
        _syncService = syncService ?? SyncService.instance;

  static final ProductionRepository instance = ProductionRepository();

  final DatabaseService _databaseService;
  final SyncService _syncService;

  Future<ProductionRecord> createRecord({
    required ProductType productType,
    required String productCode,
    required int quantity,
    required double unitPrice,
    required DateTime date,
    required bool isRework,
  }) async {
    final record = await _databaseService.createProductionRecordWithProduct(
      productType: productType,
      productCode: productCode,
      quantity: quantity,
      unitPrice: unitPrice,
      date: date,
      isRework: isRework,
    );
    unawaited(_syncService.syncPendingRecords());
    return record;
  }

  Future<bool> deleteRecord(int recordId) async {
    final success = await _databaseService.deleteProductionRecord(recordId);
    if (success) {
      unawaited(_syncService.syncPendingRecords());
    }
    return success;
  }

  Future<List<ProductionRecord>> getTodayProductionRecords() {
    unawaited(_syncService.syncPendingRecords());
    return _databaseService.getTodayProductionRecords();
  }

  Future<List<ProductionRecord>> getProductionRecordsByDate(DateTime date) {
    unawaited(_syncService.syncPendingRecords());
    return _databaseService.getProductionRecordsByDate(date);
  }

  Future<List<ProductionRecord>> getRecordsByDateRange(
      DateTime startDate, DateTime endDate) {
    unawaited(_syncService.syncPendingRecords());
    return _databaseService.getRecordsByDateRange(startDate, endDate);
  }

  Future<List<ProductionRecord>> getMonthlyProductionRecords(
      int year, int month) {
    unawaited(_syncService.syncPendingRecords());
    return _databaseService.getMonthlyProductionRecords(year, month);
  }

  Future<Product?> getProductByCode(
      String productCode, ProductType productType) {
    return _databaseService.getProductByCode(productCode, productType);
  }

  Future<void> updateProductPrice({
    required ProductType productType,
    required String productCode,
    required double price,
  }) async {
    await _databaseService.updateProductPriceByCode(
      productType: productType,
      productCode: productCode,
      price: price,
    );
    unawaited(_syncService.syncPendingRecords());
  }

  Future<int> updateProductPrices({
    required ProductType productType,
    required List<String> productCodes,
    required double price,
  }) async {
    final updatedCount = await _databaseService.updateProductPricesByCodes(
      productType: productType,
      productCodes: productCodes,
      price: price,
    );
    if (updatedCount > 0) {
      unawaited(_syncService.syncPendingRecords());
    }
    return updatedCount;
  }
}
