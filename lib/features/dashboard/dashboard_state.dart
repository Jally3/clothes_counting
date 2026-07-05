import '../../models/production_record_model.dart';
import 'dashboard_formatters.dart';
import 'dashboard_models.dart';

enum DashboardPeriod { today, week, month }

const _unset = Object();

class DashboardState {
  const DashboardState({
    required this.isLoading,
    required this.period,
    required this.selectedDate,
    required this.selectedWeekStart,
    required this.selectedWeekEnd,
    required this.selectedMonth,
    required this.records,
    required this.sections,
    required this.summary,
    this.errorMessage,
  });

  factory DashboardState.initial() {
    final now = DateTime.now();
    final weekStart = _weekStartFor(now);
    return DashboardState(
      isLoading: true,
      period: DashboardPeriod.today,
      selectedDate: now,
      selectedWeekStart: weekStart,
      selectedWeekEnd: _weekEndFor(weekStart),
      selectedMonth: DateTime(now.year, now.month),
      records: const [],
      sections: const [],
      summary: DashboardSummaryVm.empty,
    );
  }

  final bool isLoading;
  final DashboardPeriod period;
  final DateTime selectedDate;
  final DateTime selectedWeekStart;
  final DateTime selectedWeekEnd;
  final DateTime selectedMonth;
  final List<ProductionRecord> records;
  final List<ProductTypeSectionVm> sections;
  final DashboardSummaryVm summary;
  final String? errorMessage;

  String get periodName {
    switch (period) {
      case DashboardPeriod.today:
        return _isSameDate(selectedDate, DateTime.now()) ? '今日' : '当日';
      case DashboardPeriod.week:
        return '周';
      case DashboardPeriod.month:
        return '月';
    }
  }

  String get summaryTitle {
    if (period == DashboardPeriod.today &&
        !_isSameDate(selectedDate, DateTime.now())) {
      return '日期概览';
    }
    return '$periodName概览';
  }

  String get periodValue {
    switch (period) {
      case DashboardPeriod.today:
        return '${selectedDate.year}年${selectedDate.month}月${selectedDate.day}日';
      case DashboardPeriod.week:
        return '${DashboardFormatters.monthDay(selectedWeekStart)} - ${DashboardFormatters.monthDay(selectedWeekEnd)}';
      case DashboardPeriod.month:
        return '${selectedMonth.year}年${selectedMonth.month.toString().padLeft(2, '0')}月';
    }
  }

  String get quantityLabel => '$periodName总数量';

  String get priceLabel => '$periodName总价';

  String get loadingText => '正在加载$periodName数据...';

  String get emptyText {
    if (period == DashboardPeriod.today &&
        !_isSameDate(selectedDate, DateTime.now())) {
      return '该日期暂无记录';
    }
    return '$periodName暂无记录';
  }

  DashboardState copyWith({
    bool? isLoading,
    DashboardPeriod? period,
    DateTime? selectedDate,
    DateTime? selectedWeekStart,
    DateTime? selectedWeekEnd,
    DateTime? selectedMonth,
    List<ProductionRecord>? records,
    List<ProductTypeSectionVm>? sections,
    DashboardSummaryVm? summary,
    Object? errorMessage = _unset,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      period: period ?? this.period,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedWeekStart: selectedWeekStart ?? this.selectedWeekStart,
      selectedWeekEnd: selectedWeekEnd ?? this.selectedWeekEnd,
      selectedMonth: selectedMonth ?? this.selectedMonth,
      records: records ?? this.records,
      sections: sections ?? this.sections,
      summary: summary ?? this.summary,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

  static DateTime weekStartFor(DateTime date) => _weekStartFor(date);

  static DateTime weekEndFor(DateTime weekStart) => _weekEndFor(weekStart);

  static bool isSameDate(DateTime a, DateTime b) => _isSameDate(a, b);

  static DateTime _weekStartFor(DateTime date) {
    final weekStart = date.subtract(Duration(days: date.weekday - 1));
    return DateTime(weekStart.year, weekStart.month, weekStart.day);
  }

  static DateTime _weekEndFor(DateTime weekStart) {
    return DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day + 6,
      23,
      59,
      59,
    );
  }

  static bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
