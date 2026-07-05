import 'package:flutter/material.dart';

class DashboardColors {
  const DashboardColors._();

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

class DashboardDimens {
  const DashboardDimens._();

  static const headerHeight = 276.0;
  static const headerHorizontalPadding = 22.0;
  static const contentHorizontalPadding = 18.0;
  static const listBottomPadding = 116.0;
}

class DashboardTexts {
  const DashboardTexts._();

  static const appTitle = '统计助手';
  static const addRecord = '添加记录';
  static const refresh = '刷新';
  static const selectPeriod = '选择统计时间';
  static const selectDateHelp = '选择统计日期';
  static const selectWeekHelp = '选择周内任意日期';
  static const selectYear = '选择年份';
  static const startRecording = '点击右下角按钮开始记录';
  static const delete = '删除';
  static const cancel = '取消';
  static const confirmDelete = '确认删除';
  static const recordUnsaved = '记录尚未保存，无法删除';
  static const deleteSuccess = '记录删除成功';
  static const deleteFailed = '删除失败，请重试';
  static const priceUpdated = '单价已更新';
}
