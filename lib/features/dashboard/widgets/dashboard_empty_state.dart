import 'package:flutter/material.dart';

import '../dashboard_constants.dart';

class DashboardEmptyState extends StatelessWidget {
  const DashboardEmptyState({
    required this.text,
    super.key,
  });

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
              color: DashboardColors.textSecondary,
            ),
            const SizedBox(height: 18),
            Text(
              text,
              style: const TextStyle(
                fontSize: 20,
                color: DashboardColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              DashboardTexts.startRecording,
              style: TextStyle(
                fontSize: 15,
                color: DashboardColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
