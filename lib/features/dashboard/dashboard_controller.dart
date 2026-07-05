import 'package:flutter/foundation.dart';

import '../../models/production_record_model.dart';
import '../../models/product_model.dart';
import '../../repositories/production_repository.dart';
import 'dashboard_models.dart';
import 'dashboard_state.dart';

class DashboardController extends ChangeNotifier {
  DashboardController({
    ProductionRepository? repository,
  }) : _repository = repository ?? ProductionRepository.instance;

  final ProductionRepository _repository;
  DashboardState _state = DashboardState.initial();
  int _loadRequestId = 0;

  DashboardState get state => _state;

  Future<void> initialize(
    DashboardPeriod initialPeriod, {
    DateTime? initialWeekDate,
    DateTime? initialMonth,
  }) async {
    var nextState = _state.copyWith(period: initialPeriod);
    if (initialWeekDate != null) {
      final weekStart = DashboardState.weekStartFor(initialWeekDate);
      nextState = nextState.copyWith(
        selectedWeekStart: weekStart,
        selectedWeekEnd: DashboardState.weekEndFor(weekStart),
      );
    }
    if (initialMonth != null) {
      nextState = nextState.copyWith(
        selectedMonth: DateTime(initialMonth.year, initialMonth.month),
      );
    }
    _state = nextState;
    await loadCurrentRecords();
  }

  Future<void> loadCurrentRecords() async {
    final requestId = ++_loadRequestId;
    _setState(_state.copyWith(isLoading: true, errorMessage: null));

    try {
      final records = await _fetchRecords(_state);
      if (requestId != _loadRequestId) return;

      _setState(
        _state.copyWith(
          isLoading: false,
          records: records,
          sections: DashboardViewModelBuilder.buildSections(records),
          summary: DashboardViewModelBuilder.buildSummary(records),
          errorMessage: null,
        ),
      );
    } catch (e) {
      if (requestId != _loadRequestId) return;
      _setState(
        _state.copyWith(
          isLoading: false,
          errorMessage: e.toString(),
        ),
      );
      rethrow;
    }
  }

  Future<void> switchPeriod(DashboardPeriod period) async {
    if (_state.period == period) {
      await loadCurrentRecords();
      return;
    }

    _setState(_state.copyWith(period: period));
    await loadCurrentRecords();
  }

  Future<void> selectDate(DateTime date) async {
    _setState(_state.copyWith(selectedDate: date));
    await loadCurrentRecords();
  }

  Future<void> selectWeekByDate(DateTime date) async {
    final weekStart = DashboardState.weekStartFor(date);
    _setState(
      _state.copyWith(
        selectedWeekStart: weekStart,
        selectedWeekEnd: DashboardState.weekEndFor(weekStart),
      ),
    );
    await loadCurrentRecords();
  }

  Future<void> selectMonth({
    required int year,
    required int month,
  }) async {
    _setState(_state.copyWith(selectedMonth: DateTime(year, month)));
    await loadCurrentRecords();
  }

  Future<bool> deleteRecord(int recordId) async {
    final success = await _repository.deleteRecord(recordId);
    if (success) {
      await loadCurrentRecords();
    }
    return success;
  }

  Future<void> updateProductPrice({
    required ProductType productType,
    required String productCode,
    required double price,
  }) async {
    await _repository.updateProductPrice(
      productType: productType,
      productCode: productCode,
      price: price,
    );
    await loadCurrentRecords();
  }

  Future<int> updateProductPrices({
    required ProductType productType,
    required List<String> productCodes,
    required double price,
  }) async {
    final updatedCount = await _repository.updateProductPrices(
      productType: productType,
      productCodes: productCodes,
      price: price,
    );
    await loadCurrentRecords();
    return updatedCount;
  }

  Future<List<ProductionRecord>> _fetchRecords(DashboardState state) {
    switch (state.period) {
      case DashboardPeriod.today:
        return _repository.getProductionRecordsByDate(state.selectedDate);
      case DashboardPeriod.week:
        return _repository.getRecordsByDateRange(
          state.selectedWeekStart,
          state.selectedWeekEnd,
        );
      case DashboardPeriod.month:
        return _repository.getMonthlyProductionRecords(
          state.selectedMonth.year,
          state.selectedMonth.month,
        );
    }
  }

  void _setState(DashboardState state) {
    _state = state;
    notifyListeners();
  }
}
