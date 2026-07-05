import 'package:flutter/material.dart';

import '../dashboard_constants.dart';

class DashboardHeaderBackground extends StatelessWidget {
  const DashboardHeaderBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: DashboardDimens.headerHeight,
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

class DashboardHeaderBar extends StatelessWidget {
  const DashboardHeaderBar({
    required this.onRefresh,
    required this.onSelectPeriod,
    super.key,
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
              DashboardTexts.appTitle,
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
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
