import 'package:flutter/material.dart';

import '../../../models/production_record_model.dart';
import '../dashboard_formatters.dart';
import 'dashboard_surface_card.dart';
import '../dashboard_constants.dart';

class DashboardRecordRow extends StatelessWidget {
  const DashboardRecordRow({
    required this.record,
    required this.syncLabel,
    required this.onDelete,
    super.key,
  });

  final ProductionRecord record;
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
        border: Border.all(color: DashboardColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DashboardSmallTag(
                  label: '时间 ${DashboardFormatters.time(record.date)}',
                ),
                DashboardSmallTag(label: '数量 ${record.quantity}'),
                DashboardSmallTag(
                  label: '¥${DashboardFormatters.money(totalPrice)}',
                ),
                if (record.isRework) const DashboardSmallTag(label: '返工'),
                if (syncLabel != null) DashboardSmallTag(label: syncLabel!),
              ],
            ),
          ),
          IconButton(
            tooltip: DashboardTexts.delete,
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
