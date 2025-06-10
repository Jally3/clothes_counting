import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import '../services/database_service.dart';

class MonthlyStatsScreen extends StatefulWidget {
  const MonthlyStatsScreen({super.key});

  @override
  State<MonthlyStatsScreen> createState() => _MonthlyStatsScreenState();
}

class _MonthlyStatsScreenState extends State<MonthlyStatsScreen> {
  final DatabaseService _dbService = DatabaseService.instance;
  late Future<List<Map<String, dynamic>>> _monthlySummaryFuture;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month); // Default to current month

  @override
  void initState() {
    super.initState();
    _loadMonthlySummary();
  }

  void _loadMonthlySummary() {
    setState(() {
      _monthlySummaryFuture = _dbService.getMonthlySummary(_selectedMonth.year, _selectedMonth.month);
    });
  }

  Future<void> _selectMonth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      initialDatePickerMode: DatePickerMode.year, // Start with year selection
    );

    if (picked != null) {
      // We only care about year and month from the picker
      final newSelectedMonth = DateTime(picked.year, picked.month);
      if (newSelectedMonth != _selectedMonth) {
        setState(() {
          _selectedMonth = newSelectedMonth;
          _loadMonthlySummary();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Statistics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectMonth(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Summary for: ${DateFormat.yMMMM().format(_selectedMonth)}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _monthlySummaryFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No production data for this month.'));
                }

                final summaryData = snapshot.data!;

                return ListView.builder(
                  itemCount: summaryData.length,
                  itemBuilder: (context, index) {
                    final item = summaryData[index];
                    String productType = item['productType']?.toString() ?? 'N/A';
                    String productCode = item['productCode']?.toString() ?? 'N/A';
                    String style = item['style']?.toString() ?? 'N/A';
                    int totalQuantity = (item['totalQuantity'] as num?)?.toInt() ?? 0;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: ListTile(
                        title: Text('$productCode - $style ($productType)'),
                        trailing: Text('总数 : $totalQuantity', style: Theme.of(context).textTheme.titleMedium),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}