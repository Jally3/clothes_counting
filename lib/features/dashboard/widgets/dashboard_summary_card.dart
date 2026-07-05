import 'package:flutter/material.dart';

import '../dashboard_constants.dart';
import '../dashboard_formatters.dart';
import '../dashboard_models.dart';
import 'dashboard_surface_card.dart';

class DashboardSummaryCard extends StatelessWidget {
  const DashboardSummaryCard({
    required this.title,
    required this.periodValue,
    required this.summary,
    required this.quantityLabel,
    required this.priceLabel,
    super.key,
    this.onSelectPeriod,
  });

  final String title;
  final String periodValue;
  final DashboardSummaryVm summary;
  final String quantityLabel;
  final String priceLabel;
  final VoidCallback? onSelectPeriod;

  @override
  Widget build(BuildContext context) {
    return DashboardSurfaceCard(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const DashboardGradientIcon(icon: Icons.bar_chart_rounded),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      height: 1.1,
                      color: DashboardColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _PeriodValue(
                    periodValue: periodValue,
                    onSelectPeriod: onSelectPeriod,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _HeroMetric(
                  value: '${summary.totalQuantity}',
                  suffix: '件',
                  label: quantityLabel,
                  color: DashboardColors.success,
                ),
              ),
              Container(
                width: 1,
                height: 64,
                color: DashboardColors.border,
              ),
              Expanded(
                child: _HeroMetric(
                  value: '¥${DashboardFormatters.money(summary.totalPrice)}',
                  label: priceLabel,
                  color: DashboardColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PeriodValue extends StatelessWidget {
  const _PeriodValue({
    required this.periodValue,
    required this.onSelectPeriod,
  });

  final String periodValue;
  final VoidCallback? onSelectPeriod;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          periodValue,
          style: const TextStyle(
            fontSize: 15,
            color: DashboardColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (onSelectPeriod != null) ...[
          const SizedBox(width: 4),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: DashboardColors.textSecondary,
            size: 18,
          ),
        ],
      ],
    );

    if (onSelectPeriod == null) {
      return content;
    }

    return InkWell(
      onTap: onSelectPeriod,
      borderRadius: BorderRadius.circular(8),
      child: content,
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
          textAlign: TextAlign.center,
          TextSpan(
            children: [
              TextSpan(
                text: value,
                style: TextStyle(
                  color: color,
                  fontSize: 32,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (suffix != null)
                TextSpan(
                  text: ' $suffix',
                  style: const TextStyle(
                    color: DashboardColors.textPrimary,
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
            color: DashboardColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
