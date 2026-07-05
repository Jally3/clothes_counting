import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/production_record_model.dart';
import '../../models/product_model.dart';
import '../../screens/date_detail_screen.dart';
import '../../screens/production_record_screen.dart';
import '../../shared/dialogs/unit_price_edit_dialog.dart';
import 'dashboard_constants.dart';
import 'dashboard_controller.dart';
import 'dashboard_formatters.dart';
import 'dashboard_models.dart';
import 'dashboard_state.dart';
import 'widgets/dashboard_empty_state.dart';
import 'widgets/dashboard_header_bar.dart';
import 'widgets/dashboard_loading_state.dart';
import 'widgets/dashboard_segmented_nav.dart';
import 'widgets/dashboard_summary_card.dart';
import 'widgets/product_type_section.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key})
      : initialPeriod = DashboardPeriod.today,
        isRoot = true,
        initialWeekDate = null,
        initialMonth = null;

  const DashboardScreen.week({
    super.key,
    this.initialWeekDate,
  })  : initialPeriod = DashboardPeriod.week,
        isRoot = false,
        initialMonth = null;

  const DashboardScreen.month({
    super.key,
    this.initialMonth,
  })  : initialPeriod = DashboardPeriod.month,
        isRoot = false,
        initialWeekDate = null;

  final DashboardPeriod initialPeriod;
  final bool isRoot;
  final DateTime? initialWeekDate;
  final DateTime? initialMonth;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final DashboardController _controller;
  final Map<ProductType, bool> _expandedStates = {};
  final Map<String, bool> _productCodeExpandedStates = {};

  DashboardState get _state => _controller.state;

  @override
  void initState() {
    super.initState();
    _controller = DashboardController();
    _controller.addListener(_handleControllerChanged);
    unawaited(_initialize());
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize(
        widget.initialPeriod,
        initialWeekDate: widget.initialWeekDate,
        initialMonth: widget.initialMonth,
      );
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('加载${_state.periodName}记录失败: $e');
    }
  }

  void _handleControllerChanged() {
    _syncExpansionStates(_state.sections);
    if (mounted) {
      setState(() {});
    }
  }

  void _syncExpansionStates(List<ProductTypeSectionVm> sections) {
    for (final section in sections) {
      _expandedStates.putIfAbsent(section.productType, () => false);
    }
  }

  Future<void> _loadCurrentRecords() async {
    try {
      await _controller.loadCurrentRecords();
    } catch (e) {
      _showLoadError(e);
    }
  }

  Future<void> _switchPeriod(DashboardPeriod period) async {
    try {
      await _controller.switchPeriod(period);
    } catch (e) {
      _showLoadError(e);
    }
  }

  Future<void> _openPeriodPage({
    required DashboardPeriod period,
    DateTime? weekDate,
    DateTime? month,
  }) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) {
          switch (period) {
            case DashboardPeriod.week:
              return DashboardScreen.week(initialWeekDate: weekDate);
            case DashboardPeriod.month:
              return DashboardScreen.month(initialMonth: month);
            case DashboardPeriod.today:
              return const DashboardScreen();
          }
        },
      ),
    );
    if (mounted) {
      await _loadCurrentRecords();
    }
  }

  void _toggleExpanded(ProductType productType) {
    setState(() {
      _expandedStates[productType] = !(_expandedStates[productType] ?? false);
    });
  }

  void _toggleProductCodeExpanded(String expansionKey) {
    setState(() {
      _productCodeExpandedStates[expansionKey] =
          !(_productCodeExpandedStates[expansionKey] ?? false);
    });
  }

  bool _isProductCodeExpanded(String expansionKey) {
    return _productCodeExpandedStates[expansionKey] ?? false;
  }

  Future<void> _editProductCodePrice({
    required ProductType productType,
    required String productCode,
    required double currentPrice,
  }) async {
    final newPrice = await showUnitPriceEditDialog(
      context: context,
      productCode: productCode,
      initialPrice: currentPrice,
    );
    if (!mounted || newPrice == null) return;

    try {
      await _controller.updateProductPrice(
        productType: productType,
        productCode: productCode,
        price: newPrice,
      );
      if (!mounted) return;
      _showSnackBar(
        DashboardTexts.priceUpdated,
        backgroundColor: DashboardColors.success,
      );
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('单价更新失败：$e', backgroundColor: Colors.red);
    }
  }

  Future<void> _editProductTypePrices(ProductTypeSectionVm section) async {
    final productCodes = section.codeGroups
        .map((group) => group.productCode)
        .toSet()
        .toList(growable: false);
    if (productCodes.isEmpty) return;

    final productTypeName =
        productTypeChDisplayNames[section.productType] ?? '其他';
    final newPrice = await showBatchUnitPriceEditDialog(
      context: context,
      productTypeName: productTypeName,
      productCodeCount: productCodes.length,
    );
    if (!mounted || newPrice == null) return;

    try {
      final updatedCount = await _controller.updateProductPrices(
        productType: section.productType,
        productCodes: productCodes,
        price: newPrice,
      );
      if (!mounted) return;
      _showSnackBar(
        '已更新 $updatedCount 个编号单价',
        backgroundColor: DashboardColors.success,
      );
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('批量更新单价失败：$e', backgroundColor: Colors.red);
    }
  }

  void _showDeleteConfirmDialog(ProductionRecord record) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(DashboardTexts.confirmDelete),
          content: Text(
            '确定要删除这条生产记录吗？\n\n时间：${DashboardFormatters.dateTime(record.date)}\n数量：${record.quantity}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(DashboardTexts.cancel),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteRecord(record);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text(DashboardTexts.delete),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteRecord(ProductionRecord record) async {
    try {
      final recordId = record.id;
      if (recordId == null) {
        _showSnackBar(
          DashboardTexts.recordUnsaved,
          backgroundColor: Colors.red,
        );
        return;
      }

      final success = await _controller.deleteRecord(recordId);
      if (!mounted) return;
      if (success) {
        _showSnackBar(
          DashboardTexts.deleteSuccess,
          backgroundColor: DashboardColors.success,
        );
      } else {
        _showSnackBar(
          DashboardTexts.deleteFailed,
          backgroundColor: Colors.red,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('删除出错：$e', backgroundColor: Colors.red);
    }
  }

  Future<void> _openCreateRecord({
    String productCode = '',
    ProductType productType = ProductType.clothes,
  }) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ProductionRecordScreen(
          productCode: productCode,
          productType: productType,
        ),
      ),
    );
    if (!mounted) return;
    if (changed == true || changed == null) {
      await _loadCurrentRecords();
    }
  }

  Future<void> _selectCurrentPeriod() async {
    if (_state.period == DashboardPeriod.today) {
      await _selectDate();
    } else if (_state.period == DashboardPeriod.week) {
      await _selectWeek();
    } else {
      await _selectMonth();
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _state.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('zh', 'CN'),
      helpText: DashboardTexts.selectDateHelp,
    );
    if (!mounted || picked == null) return;

    final pickedDate = DateTime(picked.year, picked.month, picked.day);
    if (DashboardState.isSameDate(pickedDate, DateTime.now())) {
      try {
        await _controller.selectDate(pickedDate);
      } catch (e) {
        _showLoadError(e);
      }
      return;
    }

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => DateDetailScreen(selectedDate: pickedDate),
      ),
    );
    if (mounted) {
      await _loadCurrentRecords();
    }
  }

  Future<void> _selectWeek() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _state.selectedWeekStart,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('zh', 'CN'),
      helpText: DashboardTexts.selectWeekHelp,
    );
    if (!mounted || picked == null) return;

    final pickedWeekStart = DashboardState.weekStartFor(picked);
    if (widget.isRoot &&
        !DashboardState.isSameDate(pickedWeekStart, _state.selectedWeekStart)) {
      await _openPeriodPage(
        period: DashboardPeriod.week,
        weekDate: picked,
      );
      return;
    }

    try {
      await _controller.selectWeekByDate(picked);
    } catch (e) {
      _showLoadError(e);
    }
  }

  Future<void> _selectMonth() async {
    final selectedYear = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(DashboardTexts.selectYear),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: YearPicker(
              firstDate: DateTime(2000),
              lastDate: DateTime(2030),
              selectedDate: _state.selectedMonth,
              onChanged: (dateTime) {
                Navigator.pop(context, dateTime.year);
              },
            ),
          ),
        );
      },
    );
    if (!mounted || selectedYear == null) return;

    final selectedMonthIndex = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('选择 $selectedYear 年的月份'),
          content: SizedBox(
            width: double.maxFinite,
            height: 360,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2.4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                final month = index + 1;
                final isSelected = selectedYear == _state.selectedMonth.year &&
                    month == _state.selectedMonth.month;

                return InkWell(
                  onTap: () => Navigator.pop(context, month),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? DashboardColors.primary
                          : DashboardColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? DashboardColors.primary
                            : DashboardColors.border,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$month月',
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : DashboardColors.textPrimary,
                          fontSize: 16,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
    if (!mounted || selectedMonthIndex == null) return;

    final pickedMonth = DateTime(selectedYear, selectedMonthIndex);
    if (widget.isRoot && !_isSameMonth(pickedMonth, _state.selectedMonth)) {
      await _openPeriodPage(
        period: DashboardPeriod.month,
        month: pickedMonth,
      );
      return;
    }

    try {
      await _controller.selectMonth(
        year: selectedYear,
        month: selectedMonthIndex,
      );
    } catch (e) {
      _showLoadError(e);
    }
  }

  bool _isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  void _showLoadError(Object error) {
    if (!mounted) return;
    _showSnackBar('加载${_state.periodName}记录失败: $error');
  }

  void _showSnackBar(
    String message, {
    Color? backgroundColor,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final headerTitle = _state.period == DashboardPeriod.week ? '周统计' : '月统计';

    return Scaffold(
      backgroundColor: DashboardColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateRecord(),
        backgroundColor: DashboardColors.primary,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        icon: const Icon(Icons.add_rounded, size: 26),
        label: const Text(
          DashboardTexts.addRecord,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: Stack(
        children: [
          const DashboardHeaderBackground(),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadCurrentRecords,
              color: DashboardColors.primary,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        DashboardDimens.headerHorizontalPadding,
                        12,
                        DashboardDimens.headerHorizontalPadding,
                        0,
                      ),
                      child: widget.isRoot
                          ? DashboardHeaderBar(
                              onRefresh: _loadCurrentRecords,
                              onSelectPeriod: _selectCurrentPeriod,
                            )
                          : _DashboardPeriodHeaderBar(
                              title: headerTitle,
                              onBack: () => Navigator.of(context).maybePop(),
                              onRefresh: _loadCurrentRecords,
                              onSelectPeriod: _selectCurrentPeriod,
                            ),
                    ),
                  ),
                  if (widget.isRoot)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          DashboardDimens.headerHorizontalPadding,
                          12,
                          DashboardDimens.headerHorizontalPadding,
                          0,
                        ),
                        child: DashboardSegmentedNav(
                          activePeriod: _state.period,
                          onToday: () => _switchPeriod(DashboardPeriod.today),
                          onWeek: () => _switchPeriod(DashboardPeriod.week),
                          onMonth: () => _switchPeriod(DashboardPeriod.month),
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        DashboardDimens.contentHorizontalPadding,
                        22,
                        DashboardDimens.contentHorizontalPadding,
                        0,
                      ),
                      child: DashboardSummaryCard(
                        title: _state.summaryTitle,
                        periodValue: _state.periodValue,
                        summary: _state.summary,
                        quantityLabel: _state.quantityLabel,
                        priceLabel: _state.priceLabel,
                        onSelectPeriod: _selectCurrentPeriod,
                      ),
                    ),
                  ),
                  if (_state.isLoading)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: DashboardLoadingState(text: _state.loadingText),
                    )
                  else if (_state.sections.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: DashboardEmptyState(text: _state.emptyText),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        DashboardDimens.contentHorizontalPadding,
                        12,
                        DashboardDimens.contentHorizontalPadding,
                        DashboardDimens.listBottomPadding,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final section = _state.sections[index];
                            return ProductTypeSection(
                              section: section,
                              isExpanded:
                                  _expandedStates[section.productType] ?? false,
                              onToggle: () =>
                                  _toggleExpanded(section.productType),
                              isCodeExpanded: _isProductCodeExpanded,
                              onToggleCode: _toggleProductCodeExpanded,
                              onEditPrice: (
                                productType,
                                productCode,
                                currentPrice,
                              ) =>
                                  _editProductCodePrice(
                                productType: productType,
                                productCode: productCode,
                                currentPrice: currentPrice,
                              ),
                              onBatchEditPrice: () =>
                                  _editProductTypePrices(section),
                              onAddRecord: (
                                productCode,
                                productType,
                              ) =>
                                  _openCreateRecord(
                                productCode: productCode,
                                productType: productType,
                              ),
                              onDeleteRecord: _showDeleteConfirmDialog,
                            );
                          },
                          childCount: _state.sections.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardPeriodHeaderBar extends StatelessWidget {
  const _DashboardPeriodHeaderBar({
    required this.title,
    required this.onBack,
    required this.onRefresh,
    required this.onSelectPeriod,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final VoidCallback onSelectPeriod;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            tooltip: '返回',
            onPressed: onBack,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
            icon: const Icon(
              Icons.chevron_left_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                height: 1.0,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: DashboardTexts.refresh,
            onPressed: onRefresh,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
            icon: const Icon(
              Icons.refresh_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: DashboardTexts.selectPeriod,
            onPressed: onSelectPeriod,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
            icon: const Icon(
              Icons.calendar_month_rounded,
              color: Colors.white,
              size: 25,
            ),
          ),
        ],
      ),
    );
  }
}
