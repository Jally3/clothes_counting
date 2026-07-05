import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/dashboard/dashboard_constants.dart';
import '../features/dashboard/dashboard_formatters.dart';
import '../features/dashboard/dashboard_models.dart';
import '../features/dashboard/widgets/dashboard_empty_state.dart';
import '../features/dashboard/widgets/dashboard_header_bar.dart';
import '../features/dashboard/widgets/dashboard_loading_state.dart';
import '../features/dashboard/widgets/dashboard_summary_card.dart';
import '../features/dashboard/widgets/product_type_section.dart';
import '../models/product_model.dart';
import '../models/production_record_model.dart';
import '../repositories/production_repository.dart';
import '../shared/dialogs/unit_price_edit_dialog.dart';
import 'production_record_screen.dart';

class DateDetailScreen extends StatefulWidget {
  const DateDetailScreen({super.key, required this.selectedDate});

  final DateTime selectedDate;

  @override
  State<DateDetailScreen> createState() => _DateDetailScreenState();
}

class _DateDetailScreenState extends State<DateDetailScreen> {
  final ProductionRepository _repository = ProductionRepository.instance;
  final Map<ProductType, bool> _expandedStates = {};
  final Map<String, bool> _productCodeExpandedStates = {};

  List<ProductionRecord> _records = [];
  bool _isLoading = true;

  String get _shortDateTitle =>
      '${widget.selectedDate.month}月${widget.selectedDate.day}日统计';

  String get _fullDateText =>
      '${widget.selectedDate.year}年${widget.selectedDate.month}月${widget.selectedDate.day}日';

  DateTime get _initialRecordDateTime {
    final now = DateTime.now();
    return DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
      now.hour,
      now.minute,
    );
  }

  DashboardSummaryVm get _summary =>
      DashboardViewModelBuilder.buildSummary(_records);

  List<ProductTypeSectionVm> get _sections =>
      DashboardViewModelBuilder.buildSections(_records);

  @override
  void initState() {
    super.initState();
    unawaited(_loadRecords());
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final records =
          await _repository.getProductionRecordsByDate(widget.selectedDate);
      if (!mounted) return;
      setState(() {
        _records = records;
        _syncExpansionStates(_sections);
      });
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('加载记录失败: $e', backgroundColor: Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _syncExpansionStates(List<ProductTypeSectionVm> sections) {
    for (final section in sections) {
      _expandedStates.putIfAbsent(section.productType, () => false);
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
      await _repository.updateProductPrice(
        productType: productType,
        productCode: productCode,
        price: newPrice,
      );
      if (!mounted) return;
      await _loadRecords();
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
      final updatedCount = await _repository.updateProductPrices(
        productType: section.productType,
        productCodes: productCodes,
        price: newPrice,
      );
      if (!mounted) return;
      await _loadRecords();
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
          initialDateTime: _initialRecordDateTime,
        ),
      ),
    );
    if (!mounted) return;
    if (changed == true || changed == null) {
      await _loadRecords();
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
                unawaited(_deleteRecord(record));
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

      final success = await _repository.deleteRecord(recordId);
      if (!mounted) return;
      if (success) {
        await _loadRecords();
        if (!mounted) return;
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
    final sections = _sections;

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
              onRefresh: _loadRecords,
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
                      child: _DateDetailHeaderBar(
                        title: _shortDateTitle,
                        onBack: () => Navigator.of(context).maybePop(),
                        onRefresh: _loadRecords,
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
                        title: '日期概览',
                        periodValue: _fullDateText,
                        summary: _summary,
                        quantityLabel: '当日总数量',
                        priceLabel: '当日总价',
                      ),
                    ),
                  ),
                  if (_isLoading)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: DashboardLoadingState(text: '正在加载数据...'),
                    )
                  else if (sections.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: DashboardEmptyState(text: '该日期暂无记录'),
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
                            final section = sections[index];
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
                          childCount: sections.length,
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

class _DateDetailHeaderBar extends StatelessWidget {
  const _DateDetailHeaderBar({
    required this.title,
    required this.onBack,
    required this.onRefresh,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: DashboardColors.primary,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: SizedBox(
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
          ],
        ),
      ),
    );
  }
}
