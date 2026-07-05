import 'package:flutter/material.dart';

import '../dashboard_constants.dart';

class DashboardLoadingState extends StatelessWidget {
  const DashboardLoadingState({
    required this.text,
    super.key,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: DashboardColors.primary),
          const SizedBox(height: 16),
          Text(
            text,
            style: const TextStyle(color: DashboardColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
