import 'package:flutter/material.dart';

import '../models/production_record_model.dart';
import '../models/product_model.dart';
import '../repositories/production_repository.dart';
import '../utils/production_grouping.dart';
import '../widgets/unit_price_edit_dialog.dart';
import 'date_detail_screen.dart';
import 'production_record_screen.dart';

enum DashboardPeriod { today, week, month }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key}) : initialPeriod = DashboardPeriod.today;

  const DashboardScreen.week({super.key})
      : initialPeriod = DashboardPeriod.week;

  const DashboardScreen.month({super.key})
      : initialPeriod = DashboardPeriod.month;

  final DashboardPeriod initialPeriod;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ProductionRepository _repository = ProductionRepository.instance;
  List<ProductionRecord> _todayRecords = [];
  Map<ProductType, List<ProductionRecord>> _groupedRecords = {};
  final Map<ProductType, bool> _expandedStates = {};
  final Map<String, bool> _productCodeExpandedStates = {};
  bool _isLoading = true;
  DashboardPeriod _activePeriod = DashboardPeriod.today;
  DateTime selectedDate = DateTime.now();
  DateTime _selectedWeekStart = DateTime.now();
  DateTime _selectedWeekEnd = DateTime.now();
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _activePeriod = widget.initialPeriod;
    _initializeWeek();
    _loadCurrentRecords();
  }

  void _initializeWeek([DateTime? baseDate]) {
    final date = baseDate ?? DateTime.now();
    final weekStart = date.subtract(Duration(days: date.weekday - 1));
    _selectedWeekStart =
        DateTime(weekStart.year, weekStart.month, weekStart.day);
    _selectedWeekEnd = DateTime(
      _selectedWeekStart.year,
      _selectedWeekStart.month,
      _selectedWeekStart.day + 6,
      23,
      59,
      59,
    );
  }

  Future<void> _loadCurrentRecords() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final records = switch (_activePeriod) {
        DashboardPeriod.today =>
          await _repository.getProductionRecordsByDate(selectedDate),
        DashboardPeriod.week => await _repository.getRecordsByDateRange(
            _selectedWeekStart,
            _selectedWeekEnd,
          ),
        DashboardPeriod.month => await _repository.getMonthlyProductionRecords(
            _selectedMonth.year,
            _selectedMonth.month,
          ),
      };
      if (!mounted) return;
      setState(() {
        _todayRecords = records;
        _groupedRecords = groupRecordsByProductType(records);
        for (final productType in _groupedRecords.keys) {
          _expandedStates.putIfAbsent(productType, () => false);
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载$_periodName记录失败: $e')),
      );
    }
  }

  Future<void> _switchPeriod(DashboardPeriod period) async {
    if (_activePeriod == period) {
      await _loadCurrentRecords();
      return;
    }

    setState(() {
      _activePeriod = period;
    });
    await _loadCurrentRecords();
  }

  void _toggleExpanded(ProductType productType) {
    setState(() {
      _expandedStates[productType] = !(_expandedStates[productType] ?? false);
    });
  }

  void _toggleProductCodeExpanded(String productCode) {
    setState(() {
      _productCodeExpandedStates[productCode] =
          !(_productCodeExpandedStates[productCode] ?? false);
    });
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
      await _loadCurrentRecords();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('单价已更新'),
          backgroundColor: _DashboardColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('单价更新失败：$e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDeleteConfirmDialog(ProductionRecord record) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: Text(
            '确定要删除这条生产记录吗？\n\n时间：${_formatDateTime(record.date)}\n数量：${record.quantity}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteRecord(record);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('删除'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('记录尚未保存，无法删除'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final success = await _repository.deleteRecord(recordId);
      if (!mounted) return;
      if (success) {
        await _loadCurrentRecords();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('记录删除成功'),
            backgroundColor: _DashboardColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('删除失败，请重试'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('删除出错：$e'),
          backgroundColor: Colors.red,
        ),
      );
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
    if (changed == true || changed == null) {
      _loadCurrentRecords();
    }
  }

  Future<void> _selectCurrentPeriod() async {
    if (_activePeriod == DashboardPeriod.today) {
      await _selectDate();
    } else if (_activePeriod == DashboardPeriod.week) {
      await _selectWeek();
    } else {
      await _selectMonth();
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('zh', 'CN'),
      helpText: '选择统计日期',
    );
    if (!mounted || picked == null) return;

    final pickedDate = DateTime(picked.year, picked.month, picked.day);
    if (_isSameDate(pickedDate, DateTime.now())) {
      setState(() {
        selectedDate = pickedDate;
      });
      await _loadCurrentRecords();
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DateDetailScreen(selectedDate: pickedDate),
      ),
    );
    if (mounted) {
      await _loadCurrentRecords();
    }
  }

  String get _periodName {
    switch (_activePeriod) {
      case DashboardPeriod.today:
        return _isSameDate(selectedDate, DateTime.now()) ? '今日' : '当日';
      case DashboardPeriod.week:
        return '周';
      case DashboardPeriod.month:
        return '月';
    }
  }

  String get _summaryTitle {
    if (_activePeriod == DashboardPeriod.today &&
        !_isSameDate(selectedDate, DateTime.now())) {
      return '日期概览';
    }
    return '$_periodName概览';
  }

  String get _periodValue {
    switch (_activePeriod) {
      case DashboardPeriod.today:
        return '${selectedDate.year}年${selectedDate.month}月${selectedDate.day}日';
      case DashboardPeriod.week:
        return '${_formatMonthDay(_selectedWeekStart)} - ${_formatMonthDay(_selectedWeekEnd)}';
      case DashboardPeriod.month:
        return '${_selectedMonth.year}年${_selectedMonth.month.toString().padLeft(2, '0')}月';
    }
  }

  String get _quantityLabel => '$_periodName总数量';

  String get _priceLabel => '$_periodName总价';

  String get _loadingText => '正在加载$_periodName数据...';

  String get _emptyText {
    if (_activePeriod == DashboardPeriod.today &&
        !_isSameDate(selectedDate, DateTime.now())) {
      return '该日期暂无记录';
    }
    return '$_periodName暂无记录';
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _selectWeek() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedWeekStart,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('zh', 'CN'),
      helpText: '选择周内任意日期',
    );
    if (!mounted || picked == null) return;

    setState(() {
      _initializeWeek(picked);
    });
    await _loadCurrentRecords();
  }

  Future<void> _selectMonth() async {
    final selectedYear = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('选择年份'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: YearPicker(
              firstDate: DateTime(2000),
              lastDate: DateTime(2030),
              selectedDate: _selectedMonth,
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
                final isSelected = selectedYear == _selectedMonth.year &&
                    month == _selectedMonth.month;

                return InkWell(
                  onTap: () => Navigator.pop(context, month),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _DashboardColors.primary
                          : _DashboardColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? _DashboardColors.primary
                            : _DashboardColors.border,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$month月',
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : _DashboardColors.textPrimary,
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

    setState(() {
      _selectedMonth = DateTime(selectedYear, selectedMonthIndex);
    });
    await _loadCurrentRecords();
  }

  @override
  Widget build(BuildContext context) {
    final todayTotalQuantity =
        _todayRecords.fold<int>(0, (sum, record) => sum + record.quantity);
    final todayTotalPrice = _todayRecords.fold<double>(
      0,
      (sum, record) => sum + record.quantity * record.unitPrice,
    );

    return Scaffold(
      backgroundColor: _DashboardColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateRecord(),
        backgroundColor: _DashboardColors.primary,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        icon: const Icon(Icons.add_rounded, size: 26),
        label: const Text(
          '添加记录',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: Stack(
        children: [
          const _HeaderBackground(),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadCurrentRecords,
              color: _DashboardColors.primary,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                      child: _HeaderBar(
                        onRefresh: _loadCurrentRecords,
                        onSelectPeriod: _selectCurrentPeriod,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                      child: _SegmentedNav(
                        activePeriod: _activePeriod,
                        onToday: () => _switchPeriod(DashboardPeriod.today),
                        onWeek: () => _switchPeriod(DashboardPeriod.week),
                        onMonth: () => _switchPeriod(DashboardPeriod.month),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
                      child: _SummaryCard(
                        title: _summaryTitle,
                        periodValue: _periodValue,
                        totalQuantity: todayTotalQuantity,
                        totalPrice: todayTotalPrice,
                        quantityLabel: _quantityLabel,
                        priceLabel: _priceLabel,
                        formatMoney: _formatMoney,
                        onSelectPeriod: _selectCurrentPeriod,
                      ),
                    ),
                  ),
                  if (_isLoading)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _LoadingState(text: _loadingText),
                    )
                  else if (_groupedRecords.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(text: _emptyText),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 116),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final entry =
                                _groupedRecords.entries.elementAt(index);
                            return _buildProductTypeSection(
                              entry.key,
                              entry.value,
                            );
                          },
                          childCount: _groupedRecords.length,
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

  Widget _buildProductTypeSection(
    ProductType productType,
    List<ProductionRecord> records,
  ) {
    final isExpanded = _expandedStates[productType] ?? false;
    final totalQuantity =
        records.fold<int>(0, (sum, record) => sum + record.quantity);
    final totalPrice = records.fold<double>(
      0,
      (sum, record) => sum + record.quantity * record.unitPrice,
    );
    final recordsByCode = groupRecordsByProductCode(records);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _SurfaceCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _toggleExpanded(productType),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 18, 18),
                child: Row(
                  children: [
                    _SoftIcon(
                      icon: _getProductTypeIcon(productType),
                      color: _DashboardColors.primary,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            productTypeChDisplayNames[productType] ?? '其他',
                            style: const TextStyle(
                              fontSize: 24,
                              height: 1.1,
                              color: _DashboardColors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${records.length} 条记录  ·  ${recordsByCode.length} 个编号',
                            style: const TextStyle(
                              fontSize: 14,
                              color: _DashboardColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '$totalQuantity',
                                style: const TextStyle(
                                  fontSize: 28,
                                  height: 1,
                                  color: _DashboardColors.success,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const TextSpan(
                                text: ' 件',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _DashboardColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '¥${_formatMoney(totalPrice)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            height: 1,
                            color: _DashboardColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: _DashboardColors.textSecondary,
                      size: 28,
                    ),
                  ],
                ),
              ),
            ),
            if (isExpanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    const Divider(
                      height: 1,
                      color: _DashboardColors.divider,
                    ),
                    const SizedBox(height: 12),
                    ...recordsByCode.entries.map(
                      (entry) => _buildProductCodeGroup(
                        entry.key,
                        entry.value,
                        productType,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCodeGroup(
    String productCode,
    List<ProductionRecord> records,
    ProductType productType,
  ) {
    final expansionKey = '${productType.name}:$productCode';
    final isExpanded = _productCodeExpandedStates[expansionKey] ?? false;
    final totalQuantity =
        records.fold<int>(0, (sum, record) => sum + record.quantity);
    final unitPrice = records.isEmpty ? 0.0 : records.first.unitPrice;
    final totalPrice = totalQuantity * unitPrice;
    final hasRework = records.any((record) => record.isRework);
    final latestRecord = records.isEmpty ? null : records.first;

    return Container(
      margin: const EdgeInsets.only(top: 0),
      padding: const EdgeInsets.fromLTRB(16, 16, 10, 16),
      decoration: BoxDecoration(
        color: _DashboardColors.detailSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _DashboardColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                   mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Text(
                          productCode,
                          style: const TextStyle(
                            fontSize: 26,
                            height: 1.1,
                            color: _DashboardColors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (hasRework) ...[
                          const SizedBox(height: 10),
                          const _ReworkBadge(hasRework: true),
                        ],
                      ],
                    ),
                    const SizedBox(height: 18),
                    _CodeStatsPanel(
                      quantity: totalQuantity,
                      totalPrice: totalPrice,
                      formatMoney: _formatMoney,
                    ),
                    const SizedBox(height: 14),
                    _CodeMetaRow(
                      latestRecord: latestRecord,
                      unitPrice: unitPrice,
                      formatMoney: _formatMoney,
                    ),

                  ],
                ),
              ),
              const SizedBox(width: 4),

              Column(
                children: [
                  _ActionButton(
                    icon: Icons.edit_outlined,
                    tooltip: '编辑单价',
                    onTap: () => _editProductCodePrice(
                      productType: productType,
                      productCode: productCode,
                      currentPrice: unitPrice,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ActionButton(
                    icon: Icons.add_rounded,
                    tooltip: '新增记录',
                    onTap: () => _openCreateRecord(
                      productCode: productCode,
                      productType: productType,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ActionButton(
                    icon: isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down,
                    tooltip: isExpanded ? '收起记录' : '展开记录',
                    onTap: () => _toggleProductCodeExpanded(expansionKey),
                  ),
                ],
              ),

            ],
          ),
          if (isExpanded) ...[
            const SizedBox(height: 14),
            Column(
              children: records
                  .map(
                    (record) => _RecordRow(
                  record: record,
                  formatMoney: _formatMoney,
                  syncLabel: _getSyncLabel(record.syncStatus),
                  onDelete: () => _showDeleteConfirmDialog(record),
                ),
              )
                  .toList(),
            ),
          ],

        ],
      ),
    );
  }

  IconData _getProductTypeIcon(ProductType productType) {
    switch (productType) {
      case ProductType.clothes:
        return Icons.checkroom_rounded;
      case ProductType.pants:
        return Icons.dry_cleaning_rounded;
      case ProductType.dress:
        return Icons.woman_rounded;
      case ProductType.hat:
        return Icons.sports_baseball_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  String? _getSyncLabel(SyncStatus status) {
    switch (status) {
      case SyncStatus.pending:
        return '待上传';
      case SyncStatus.failed:
        return '上传失败';
      case SyncStatus.syncing:
        return '上传中';
      case SyncStatus.deletedPending:
        return '待删除';
      case SyncStatus.synced:
        return null;
    }
  }

  String _formatMoney(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  static String _formatTime(DateTime value) {
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  static String _formatDateTime(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day ${_formatTime(value)}';
  }

  static String _formatMonthDay(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$month月$day日';
  }
}

class _HeaderBackground extends StatelessWidget {
  const _HeaderBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 276,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0D7DFF),
            Color(0xFF2563EB),
          ],
        ),
      ),
    );
  }
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({
    required this.onRefresh,
    required this.onSelectPeriod,
  });

  final VoidCallback onRefresh;
  final VoidCallback onSelectPeriod;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Expanded(
            child: Text(
              '统计助手',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                height: 1.0,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: '刷新',
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
            tooltip: '选择统计时间',
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

class _SegmentedNav extends StatelessWidget {
  const _SegmentedNav({
    required this.activePeriod,
    required this.onToday,
    required this.onWeek,
    required this.onMonth,
  });

  final DashboardPeriod activePeriod;
  final VoidCallback onToday;
  final VoidCallback onWeek;
  final VoidCallback onMonth;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentButton(
              label: '今日',
              isActive: activePeriod == DashboardPeriod.today,
              onTap: onToday,
            ),
          ),
          Expanded(
            child: _SegmentButton(
              label: '周',
              isActive: activePeriod == DashboardPeriod.week,
              onTap: onWeek,
            ),
          ),
          Expanded(
            child: _SegmentButton(
              label: '月',
              isActive: activePeriod == DashboardPeriod.month,
              onTap: onMonth,
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? _DashboardColors.primary : Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.periodValue,
    required this.totalQuantity,
    required this.totalPrice,
    required this.quantityLabel,
    required this.priceLabel,
    required this.formatMoney,
    required this.onSelectPeriod,
  });

  final String title;
  final String periodValue;
  final int totalQuantity;
  final double totalPrice;
  final String quantityLabel;
  final String priceLabel;
  final String Function(double value) formatMoney;
  final VoidCallback onSelectPeriod;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _GradientIcon(icon: Icons.bar_chart_rounded),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      height: 1.1,
                      color: _DashboardColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: onSelectPeriod,
                    borderRadius: BorderRadius.circular(8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          periodValue,
                          style: const TextStyle(
                            fontSize: 15,
                            color: _DashboardColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: _DashboardColors.textSecondary,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              Expanded(
                child: _HeroMetric(
                  value: '$totalQuantity',
                  suffix: '件',
                  label: quantityLabel,
                  color: _DashboardColors.success,
                ),
              ),
              Container(
                width: 1,
                height: 64,
                color: _DashboardColors.border,
              ),
              Expanded(
                child: _HeroMetric(
                  value: '¥${formatMoney(totalPrice)}',
                  label: priceLabel,
                  color: _DashboardColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.value,
    required this.label,
    required this.color,
    this.suffix,
  });

  final String value;
  final String? suffix;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: value,
                style: TextStyle(
                  color: color,
                  fontSize: 34,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (suffix != null)
                TextSpan(
                  text: ' $suffix',
                  style: const TextStyle(
                    color: _DashboardColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 9),
        Text(
          label,
          style: const TextStyle(
            color: _DashboardColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _GradientIcon extends StatelessWidget {
  const _GradientIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0D7DFF),
            Color(0xFF2563EB),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _DashboardColors.primary.withOpacity(0.28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 32),
    );
  }
}

class _SoftIcon extends StatelessWidget {
  const _SoftIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Icon(icon, color: color, size: 38),
    );
  }
}

class _CodeStatsPanel extends StatelessWidget {
  const _CodeStatsPanel({
    required this.quantity,
    required this.totalPrice,
    required this.formatMoney,
  });

  final int quantity;
  final double totalPrice;
  final String Function(double value) formatMoney;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _DashboardColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _CodeStatItem(
              value: '$quantity',
              suffix: '件',
              label: '数量',
              color: _DashboardColors.success,
            ),
          ),
          Container(
            width: 1,
            height: 72,
            color: _DashboardColors.divider,
          ),
          Expanded(
            child: _CodeStatItem(
              value: '¥${formatMoney(totalPrice)}',
              label: '总价',
              color: _DashboardColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeStatItem extends StatelessWidget {
  const _CodeStatItem({
    required this.value,
    required this.label,
    required this.color,
    this.suffix,
  });

  final String value;
  final String? suffix;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: color,
                    fontSize: 25,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (suffix != null)
                  TextSpan(
                    text: ' $suffix',
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            maxLines: 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: _DashboardColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CodeMetaRow extends StatelessWidget {
  const _CodeMetaRow({
    required this.latestRecord,
    required this.unitPrice,
    required this.formatMoney,
  });

  final ProductionRecord? latestRecord;
  final double unitPrice;
  final String Function(double value) formatMoney;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (latestRecord != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.access_time_rounded,
                size: 16,
                color: _DashboardColors.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                '记录时间 ${_DashboardScreenState._formatTime(latestRecord!.date)}',
                style: const TextStyle(
                  color: _DashboardColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        Container(
          width: 1,
          height: 18,
          color: _DashboardColors.divider,
        ),
        Text(
          '单价：¥${formatMoney(unitPrice)}',
          style: const TextStyle(
            color: _DashboardColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ReworkBadge extends StatelessWidget {
  const _ReworkBadge({required this.hasRework});

  final bool hasRework;

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: hasRework,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: hasRework
              ? _DashboardColors.warning.withOpacity(0.14)
              : _DashboardColors.background,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: hasRework
                ? _DashboardColors.warning.withOpacity(0.22)
                : _DashboardColors.border,
          ),
        ),
        child: Text(
          hasRework ? '返工' : '无返工',
          style: TextStyle(
            color: hasRework
                ? _DashboardColors.warning
                : _DashboardColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.08),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(icon, color: _DashboardColors.primary, size: 30),
          ),
        ),
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({
    required this.record,
    required this.formatMoney,
    required this.syncLabel,
    required this.onDelete,
  });

  final ProductionRecord record;
  final String Function(double value) formatMoney;
  final String? syncLabel;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final totalPrice = record.quantity * record.unitPrice;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _DashboardColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _SmallTag(
                    label:
                        '时间 ${_DashboardScreenState._formatTime(record.date)}'),
                _SmallTag(label: '数量 ${record.quantity}'),
                _SmallTag(label: '¥${formatMoney(totalPrice)}'),
                if (record.isRework) const _SmallTag(label: '返工'),
                if (syncLabel != null) _SmallTag(label: syncLabel!),
              ],
            ),
          ),
          IconButton(
            tooltip: '删除',
            onPressed: onDelete,
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.redAccent,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallTag extends StatelessWidget {
  const _SmallTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _DashboardColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _DashboardColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: _DashboardColors.primary),
          const SizedBox(height: 16),
          Text(
            text,
            style: const TextStyle(color: _DashboardColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 90),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.inbox_outlined,
              size: 72,
              color: _DashboardColors.textSecondary,
            ),
            const SizedBox(height: 18),
            Text(
              text,
              style: const TextStyle(
                fontSize: 20,
                color: _DashboardColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '点击右下角按钮开始记录',
              style: TextStyle(
                fontSize: 15,
                color: _DashboardColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardColors {
  const _DashboardColors._();

  static const primary = Color(0xFF2563EB);
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFF97316);
  static const background = Color(0xFFF5F7FA);
  static const detailSurface = Color(0xFFF6F9FF);
  static const border = Color(0xFFE2E8F0);
  static const divider = Color(0xFFDCE5F3);
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF64748B);
}
