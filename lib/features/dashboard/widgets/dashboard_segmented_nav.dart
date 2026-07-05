import 'package:flutter/material.dart';

import '../dashboard_constants.dart';
import '../dashboard_state.dart';

class DashboardSegmentedNav extends StatelessWidget {
  const DashboardSegmentedNav({
    required this.activePeriod,
    required this.onToday,
    required this.onWeek,
    required this.onMonth,
    super.key,
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
              color: isActive ? DashboardColors.primary : Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
