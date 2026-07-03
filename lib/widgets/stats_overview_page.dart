import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../extensions/double_extension.dart';
import '../models/production_record_model.dart';
import '../models/product_model.dart';
import '../utils/production_grouping.dart';

enum StatsTab { today, week, month }

typedef StatsAddRecordCallback = void Function({
  required String productCode,
  required ProductType productType,
});

class StatsOverviewPage extends StatelessWidget {
  const StatsOverviewPage({
    super.key,
    required this.activeTab,
    required this.summaryTitle,
    required this.periodLabel,
    required this.periodValue,
    required this.records,
    required this.groupedRecords,
    required this.expandedStates,
    required this.productCodeExpandedStates,
    required this.isLoading,
    required this.loadingText,
    required this.emptyText,
    required this.onRefresh,
    required this.onSelectPeriod,
    required this.onToday,
    required this.onWeek,
    required this.onMonth,
    required this.onAddRecord,
    required this.onToggleType,
    required this.onToggleProductCode,
    required this.onEditProductCodePrice,
  });

  final StatsTab activeTab;
  final String summaryTitle;
  final String periodLabel;
  final String periodValue;
  final List<ProductionRecord> records;
  final Map<ProductType, List<ProductionRecord>> groupedRecords;
  final Map<ProductType, bool> expandedStates;
  final Map<String, bool> productCodeExpandedStates;
  final bool isLoading;
  final String loadingText;
  final String emptyText;
  final Future<void> Function() onRefresh;
  final VoidCallback onSelectPeriod;
  final VoidCallback onToday;
  final VoidCallback onWeek;
  final VoidCallback onMonth;
  final StatsAddRecordCallback onAddRecord;
  final ValueChanged<ProductType> onToggleType;
  final ValueChanged<String> onToggleProductCode;
  final void Function({
    required ProductType productType,
    required String productCode,
    required double currentPrice,
  }) onEditProductCodePrice;

  int get _totalQuantity =>
      records.fold<int>(0, (sum, record) => sum + record.quantity);

  double get _totalPrice => records.fold<double>(
        0,
        (sum, record) => sum + record.quantity * record.unitPrice,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _StatsColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => onAddRecord(
          productCode: '',
          productType: ProductType.clothes,
        ),
        backgroundColor: _StatsColors.primary,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
              onRefresh: onRefresh,
              color: _StatsColors.primary,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
                      child: _HeaderBar(
                        onRefresh: onRefresh,
                        onSelectPeriod: onSelectPeriod,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
                      child: _SegmentedNav(
                        activeTab: activeTab,
                        onToday: onToday,
                        onWeek: onWeek,
                        onMonth: onMonth,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                      child: _SummaryCard(
                        title: summaryTitle,
                        periodLabel: periodLabel,
                        periodValue: periodValue,
                        totalQuantity: _totalQuantity,
                        totalPrice: _totalPrice,
                        onSelectPeriod: onSelectPeriod,
                      ),
                    ),
                  ),
                  if (isLoading)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _LoadingState(text: loadingText),
                    )
                  else if (groupedRecords.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(text: emptyText),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 116),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final entry =
                                groupedRecords.entries.elementAt(index);
                            return _ProductTypeSection(
                              productType: entry.key,
                              records: entry.value,
                              isExpanded: expandedStates[entry.key] ?? false,
                              productCodeExpandedStates:
                                  productCodeExpandedStates,
                              onToggleType: onToggleType,
                              onToggleProductCode: onToggleProductCode,
                              onEditProductCodePrice: onEditProductCodePrice,
                              onAddRecord: onAddRecord,
                            );
                          },
                          childCount: groupedRecords.length,
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

class _HeaderBackground extends StatelessWidget {
  const _HeaderBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 268,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D7DFF), Color(0xFF2563EB)],
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

  final Future<void> Function() onRefresh;
  final VoidCallback onSelectPeriod;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            '统计助手',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              height: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        _TopIconButton(
          icon: Icons.refresh_rounded,
          tooltip: '刷新',
          onTap: onRefresh,
        ),
        const SizedBox(width: 10),
        _TopIconButton(
          icon: Icons.calendar_month_rounded,
          tooltip: '选择统计区间',
          onTap: onSelectPeriod,
        ),
      ],
    );
  }
}

class _TopIconButton extends StatelessWidget {
  const _TopIconButton({
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
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}

class _SegmentedNav extends StatelessWidget {
  const _SegmentedNav({
    required this.activeTab,
    required this.onToday,
    required this.onWeek,
    required this.onMonth,
  });

  final StatsTab activeTab;
  final VoidCallback onToday;
  final VoidCallback onWeek;
  final VoidCallback onMonth;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          _SegmentButton(
            label: '今日',
            isActive: activeTab == StatsTab.today,
            onTap: onToday,
          ),
          _SegmentButton(
            label: '周',
            isActive: activeTab == StatsTab.week,
            onTap: onWeek,
          ),
          _SegmentButton(
            label: '月',
            isActive: activeTab == StatsTab.month,
            onTap: onMonth,
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: isActive ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? _StatsColors.primary : Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
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
    required this.periodLabel,
    required this.periodValue,
    required this.totalQuantity,
    required this.totalPrice,
    required this.onSelectPeriod,
  });

  final String title;
  final String periodLabel;
  final String periodValue;
  final int totalQuantity;
  final double totalPrice;
  final VoidCallback onSelectPeriod;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _GradientIcon(icon: Icons.bar_chart_rounded),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        color: _StatsColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      periodLabel,
                      style: const TextStyle(
                        color: _StatsColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 5),
                    InkWell(
                      onTap: onSelectPeriod,
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            periodValue,
                            style: const TextStyle(
                              color: _StatsColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: _StatsColors.textSecondary,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _HeroMetric(
                  value: '$totalQuantity',
                  suffix: '件',
                  label: title.startsWith('周') ? '周总数量' : '月总数量',
                  color: _StatsColors.success,
                ),
              ),
              Container(width: 1, height: 64, color: _StatsColors.border),
              Expanded(
                child: _HeroMetric(
                  value: '¥${_formatMoney(totalPrice)}',
                  label: title.startsWith('周') ? '周总价' : '月总价',
                  color: _StatsColors.primary,
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
                  fontSize: 28,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (suffix != null)
                TextSpan(
                  text: ' $suffix',
                  style: const TextStyle(
                    color: _StatsColors.textPrimary,
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
            color: _StatsColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ProductTypeSection extends StatelessWidget {
  const _ProductTypeSection({
    required this.productType,
    required this.records,
    required this.isExpanded,
    required this.productCodeExpandedStates,
    required this.onToggleType,
    required this.onToggleProductCode,
    required this.onEditProductCodePrice,
    required this.onAddRecord,
  });

  final ProductType productType;
  final List<ProductionRecord> records;
  final bool isExpanded;
  final Map<String, bool> productCodeExpandedStates;
  final ValueChanged<ProductType> onToggleType;
  final ValueChanged<String> onToggleProductCode;
  final void Function({
    required ProductType productType,
    required String productCode,
    required double currentPrice,
  }) onEditProductCodePrice;
  final StatsAddRecordCallback onAddRecord;

  @override
  Widget build(BuildContext context) {
    final totalQuantity =
        records.fold<int>(0, (sum, record) => sum + record.quantity);
    final totalPrice = records.fold<double>(
      0,
      (sum, record) => sum + record.quantity * record.unitPrice,
    );
    final recordsByCode = groupRecordsByProductCode(records);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _SurfaceCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onToggleType(productType),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Row(
                  children: [
                    _SoftIcon(icon: _getProductTypeIcon(productType)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            productTypeChDisplayNames[productType] ?? '其他',
                            style: const TextStyle(
                              fontSize: 18,
                              color: _StatsColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${records.length} 条记录  ·  ${recordsByCode.length} 个编号',
                            style: const TextStyle(
                              fontSize: 13,
                              color: _StatsColors.textSecondary,
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
                                  color: _StatsColors.success,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const TextSpan(
                                text: ' 件',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _StatsColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '¥${_formatMoney(totalPrice)}',
                          style: const TextStyle(
                            color: _StatsColors.primary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.chevron_right_rounded,
                      color: _StatsColors.textSecondary,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
            if (isExpanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  children: recordsByCode.entries
                      .map(
                        (entry) => _ProductCodeCard(
                          productType: productType,
                          productCode: entry.key,
                          records: entry.value,
                          isExpanded:
                              productCodeExpandedStates[entry.key] ?? false,
                          onToggle: () => onToggleProductCode(entry.key),
                          onEditProductCodePrice: onEditProductCodePrice,
                          onAddRecord: onAddRecord,
                        ),
                      )
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProductCodeCard extends StatelessWidget {
  const _ProductCodeCard({
    required this.productType,
    required this.productCode,
    required this.records,
    required this.isExpanded,
    required this.onToggle,
    required this.onEditProductCodePrice,
    required this.onAddRecord,
  });

  final ProductType productType;
  final String productCode;
  final List<ProductionRecord> records;
  final bool isExpanded;
  final VoidCallback onToggle;
  final void Function({
    required ProductType productType,
    required String productCode,
    required double currentPrice,
  }) onEditProductCodePrice;
  final StatsAddRecordCallback onAddRecord;

  @override
  Widget build(BuildContext context) {
    final totalQuantity =
        records.fold<int>(0, (sum, record) => sum + record.quantity);
    final unitPrice = records.isEmpty ? 0.0 : records.first.unitPrice;
    final totalPrice = totalQuantity * unitPrice;
    final hasRework = records.any((record) => record.isRework);
    final latestRecord = records.isEmpty ? null : records.first;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 12),
      decoration: BoxDecoration(
        color: _StatsColors.detailSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _StatsColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      productCode,
                      style: const TextStyle(
                        fontSize: 18,
                        color: _StatsColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    _QuantityChip(label: '$totalQuantity 件'),
                  ],
                ),
                const SizedBox(height: 10),
                if (latestRecord != null)
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 15,
                        color: _StatsColors.textSecondary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '记录时间 ${DateFormat('HH:mm').format(latestRecord.date)}',
                        style: const TextStyle(
                          color: _StatsColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: _PrimaryAmount(
                        totalPrice: totalPrice,
                        unitPrice: unitPrice,
                      ),
                    ),
                    _ReworkBadge(hasRework: hasRework),
                  ],
                ),
                if (isExpanded) ...[
                  const SizedBox(height: 12),
                  Column(
                    children: records
                        .map((record) => _RecordRow(record: record))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            children: [
              _ActionButton(
                icon: Icons.edit_outlined,
                tooltip: '编辑单价',
                onTap: () => onEditProductCodePrice(
                  productType: productType,
                  productCode: productCode,
                  currentPrice: unitPrice,
                ),
              ),
              const SizedBox(height: 10),
              _ActionButton(
                icon: Icons.add_rounded,
                tooltip: '新增记录',
                onTap: () => onAddRecord(
                  productCode: productCode,
                  productType: productType,
                ),
              ),
              const SizedBox(height: 10),
              _ActionButton(
                icon: isExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.chevron_right_rounded,
                tooltip: isExpanded ? '收起记录' : '展开记录',
                onTap: onToggle,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PrimaryAmount extends StatelessWidget {
  const _PrimaryAmount({
    required this.totalPrice,
    required this.unitPrice,
  });

  final double totalPrice;
  final double unitPrice;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '总价',
          style: TextStyle(
            color: _StatsColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          '¥${_formatMoney(totalPrice)}',
          style: const TextStyle(
            color: _StatsColors.textPrimary,
            fontSize: 20,
            height: 1,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          '单价  ¥${_formatMoney(unitPrice)}',
          style: const TextStyle(
            color: _StatsColors.textSecondary,
            fontSize: 12,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: hasRework
            ? _StatsColors.warning.withOpacity(0.14)
            : _StatsColors.background,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: hasRework
              ? _StatsColors.warning.withOpacity(0.22)
              : _StatsColors.border,
        ),
      ),
      child: Text(
        hasRework ? '返工' : '无返工',
        style: TextStyle(
          color: hasRework ? _StatsColors.warning : _StatsColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.record});

  final ProductionRecord record;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _StatsColors.border),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _SmallTag(label: DateFormat('MM-dd HH:mm').format(record.date)),
          _SmallTag(label: '数量 ${record.quantity}'),
          _SmallTag(
              label: '¥${_formatMoney(record.quantity * record.unitPrice)}'),
          if (record.isRework) const _SmallTag(label: '返工'),
        ],
      ),
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
        borderRadius: BorderRadius.circular(16),
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
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D7DFF), Color(0xFF2563EB)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: Colors.white, size: 26),
    );
  }
}

class _SoftIcon extends StatelessWidget {
  const _SoftIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: _StatsColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: _StatsColors.primary, size: 28),
    );
  }
}

class _QuantityChip extends StatelessWidget {
  const _QuantityChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _StatsColors.success.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _StatsColors.success,
          fontSize: 13,
          fontWeight: FontWeight.w700,
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
        elevation: 3,
        shadowColor: Colors.black.withOpacity(0.08),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, color: _StatsColors.primary, size: 25),
          ),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _StatsColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _StatsColors.textSecondary,
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
          const CircularProgressIndicator(color: _StatsColors.primary),
          const SizedBox(height: 16),
          Text(
            text,
            style: const TextStyle(color: _StatsColors.textSecondary),
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
        child: Text(
          text,
          style: const TextStyle(
            color: _StatsColors.textSecondary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
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

String _formatMoney(double value) {
  return value.toTrimmedPriceString();
}

class _StatsColors {
  const _StatsColors._();

  static const primary = Color(0xFF2563EB);
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFF97316);
  static const background = Color(0xFFF5F7FA);
  static const detailSurface = Color(0xFFF6F9FF);
  static const border = Color(0xFFE2E8F0);
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
}
