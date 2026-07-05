import 'package:flutter/material.dart';

import '../../../models/production_record_model.dart';
import '../../../models/product_model.dart';
import '../dashboard_constants.dart';
import '../dashboard_formatters.dart';
import '../dashboard_models.dart';
import 'dashboard_surface_card.dart';
import 'record_row.dart';

class ProductCodeGroup extends StatelessWidget {
  const ProductCodeGroup({
    required this.group,
    required this.isExpanded,
    required this.onEditPrice,
    required this.onAddRecord,
    required this.onToggle,
    required this.onDeleteRecord,
    super.key,
  });

  final ProductCodeGroupVm group;
  final bool isExpanded;
  final void Function(ProductType productType, String productCode, double price)
      onEditPrice;
  final void Function(String productCode, ProductType productType) onAddRecord;
  final VoidCallback onToggle;
  final void Function(ProductionRecord record) onDeleteRecord;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 0, bottom: 8),
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
      decoration: BoxDecoration(
        color: DashboardColors.detailSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DashboardColors.border),
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            group.productCode,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 22,
                              height: 1.1,
                              color: DashboardColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        if (group.hasRework) ...[
                          const DashboardReworkBadge(hasRework: true),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    _CodeStatsPanel(
                      quantity: group.totalQuantity,
                      totalPrice: group.totalPrice,
                    ),
                    const SizedBox(height: 12),
                    _CodeMetaRow(
                      latestRecord: group.latestRecord,
                      unitPrice: group.unitPrice,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Column(
                children: [
                  DashboardActionButton(
                    icon: Icons.edit_outlined,
                    tooltip: '编辑单价',
                    onTap: () => onEditPrice(
                      group.productType,
                      group.productCode,
                      group.unitPrice,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DashboardActionButton(
                    icon: Icons.add_rounded,
                    tooltip: '新增记录',
                    onTap: () => onAddRecord(
                      group.productCode,
                      group.productType,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DashboardActionButton(
                    icon: isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down,
                    tooltip: isExpanded ? '收起记录' : '展开记录',
                    badgeLabel: group.records.length > 1
                        ? DashboardFormatters.recordCountBadge(
                            group.records.length,
                          )
                        : null,
                    onTap: onToggle,
                  ),
                ],
              ),
            ],
          ),
          if (isExpanded) ...[
            const SizedBox(height: 14),
            Column(
              children: group.records
                  .map(
                    (record) => DashboardRecordRow(
                      record: record,
                      syncLabel: _getSyncLabel(record.syncStatus),
                      onDelete: () => onDeleteRecord(record),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
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
}

class _CodeStatsPanel extends StatelessWidget {
  const _CodeStatsPanel({
    required this.quantity,
    required this.totalPrice,
  });

  final int quantity;
  final double totalPrice;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DashboardColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _CodeStatItem(
              value: '$quantity',
              suffix: '件',
              label: '数量',
              color: DashboardColors.success,
            ),
          ),
          Container(
            width: 1,
            height: 58,
            color: DashboardColors.divider,
          ),
          Expanded(
            child: _CodeStatItem(
              value: '¥${DashboardFormatters.money(totalPrice)}',
              label: '总价',
              color: DashboardColors.primary,
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
                    fontSize: 18,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (suffix != null)
                  TextSpan(
                    text: ' $suffix',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            maxLines: 1,
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
  });

  final ProductionRecord? latestRecord;
  final double unitPrice;

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
                color: DashboardColors.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                '记录时间 ${DashboardFormatters.time(latestRecord!.date)}',
                style: const TextStyle(
                  color: DashboardColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        Container(
          width: 1,
          height: 18,
          color: DashboardColors.divider,
        ),
        Text(
          '单价：¥${DashboardFormatters.money(unitPrice)}',
          style: const TextStyle(
            color: DashboardColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
