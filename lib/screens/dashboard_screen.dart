import 'package:clothes_counting/screens/production_record_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../models/production_record_model.dart';
import 'monthly_stats_screen.dart'; // 导入 MonthlyStatsScreen

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DatabaseService _databaseService = DatabaseService.instance;
  late Future<List<ProductionRecord>> _todayRecords;
   DateTime selectedDate = DateTime.now(); // 添加这一行来跟踪选择的日期

  @override
  void initState() {
    super.initState();
    _loadTodayRecords();
  }

  void _loadTodayRecords() {
    setState(() {
      // 使用 _selectedDate 来加载记录
      _todayRecords = _databaseService.getProductionRecordsByDate(selectedDate);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('生产统计助手'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month), // 月度统计图标
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MonthlyStatsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Summary for: ${DateFormat.yMMMd().format(selectedDate)}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          Expanded(
            child: FutureBuilder<List<ProductionRecord>>(
              future: _todayRecords,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No production data for this day.'));
                }

                final records = snapshot.data!;

                return ListView.builder(
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final record = records[index];
            
                    String productName = record.productStyleCode ?? ''; // 假设的字段
                    int quantity = record.quantity;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: ListTile(
                        title: Text(productName), // 使用 productName
                        trailing: Text('数量: $quantity', style: Theme.of(context).textTheme.titleMedium),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Navigate and refresh data when returning
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ProductionRecordScreen()),
          );
          // If ProductionRecordScreen indicates data was saved, or just refresh always
          // For simplicity, we refresh every time.
          // _loadDailySummary();
        },
        tooltip: 'Record Production',
        child: const Icon(Icons.add),
      ),
    );
  }
}
