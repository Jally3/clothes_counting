import 'package:flutter/material.dart';

import '../../../models/production_record_model.dart';
import '../../../models/product_model.dart';
import '../dashboard_constants.dart';
import '../dashboard_formatters.dart';
import '../dashboard_models.dart';
import 'dashboard_surface_card.dart';
import 'product_code_group.dart';

class ProductTypeSection extends StatelessWidget {
  const ProductTypeSection({
    required this.section,
    required this.isExpanded,
    required this.onToggle,
    required this.isCodeExpanded,
    required this.onToggleCode,
    required this.onEditPrice,
    required this.onBatchEditPrice,
    required this.onAddRecord,
    required this.onDeleteRecord,
    super.key,
  });

  final ProductTypeSectionVm section;
  final bool isExpanded;
  final VoidCallback onToggle;
  final bool Function(String expansionKey) isCodeExpanded;
  final void Function(String expansionKey) onToggleCode;
  final void Function(ProductType productType, String productCode, double price)
      onEditPrice;
  final VoidCallback onBatchEditPrice;
  final void Function(String productCode, ProductType productType) onAddRecord;
  final void Function(ProductionRecord record) onDeleteRecord;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DashboardSurfaceCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    DashboardSoftIcon(
                      icon: _getProductTypeIcon(section.productType),
                      color: DashboardColors.primary,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            productTypeChDisplayNames[section.productType] ??
                                '其他',
                            style: const TextStyle(
                              fontSize: 24,
                              height: 1.1,
                              color: DashboardColors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${section.codeGroups.length} 个编号',
                            style: const TextStyle(
                              fontSize: 12,
                              color: DashboardColors.textSecondary,
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
                                text: '${section.totalQuantity}',
                                style: const TextStyle(
                                  fontSize: 28,
                                  height: 1,
                                  color: DashboardColors.success,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const TextSpan(
                                text: ' 件',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: DashboardColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '¥${DashboardFormatters.money(section.totalPrice)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            height: 1,
                            color: DashboardColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    DashboardActionButton(
                      icon: Icons.price_change_outlined,
                      tooltip: '批量修改单价',
                      onTap: onBatchEditPrice,
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: DashboardColors.textSecondary,
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
                      color: DashboardColors.divider,
                    ),
                    const SizedBox(height: 12),
                    ...section.codeGroups.map(
                      (group) => ProductCodeGroup(
                        group: group,
                        isExpanded: isCodeExpanded(group.expansionKey),
                        onEditPrice: onEditPrice,
                        onAddRecord: onAddRecord,
                        onToggle: () => onToggleCode(group.expansionKey),
                        onDeleteRecord: onDeleteRecord,
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
}
