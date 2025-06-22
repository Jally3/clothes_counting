import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../models/production_record_model.dart';
import '../models/product_model.dart';
import 'monthly_stats_screen.dart';
import 'production_record_screen.dart';
 import 'weekly_stats_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DatabaseService _databaseService = DatabaseService.instance;
  List<ProductionRecord> _todayRecords = [];
  Map<ProductType, List<ProductionRecord>> _groupedRecords = {};
  Map<ProductType, bool> _expandedStates = {};
  Map<String, bool> _productCodeExpandedStates = {};
  bool _isLoading = true;
  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadTodayRecords();
  }

  Future<void> _loadTodayRecords() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final records = await _databaseService.getTodayProductionRecords();
      _groupRecordsByType(records);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载今日记录失败: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 显示删除确认弹窗
  void _showDeleteConfirmDialog(ProductionRecord record) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: Text('确定要删除这条生产记录吗？\n\n时间：${record.date.toString().substring(0, 16)}\n数量：${record.quantity}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteRecord(record);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }

  /// 删除生产记录
  void _deleteRecord(ProductionRecord record) async {
    try {
      final success = await _databaseService.deleteProductionRecord(record.id!);
      if (success) {
        // 删除成功，刷新数据
        _loadTodayRecords();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('记录删除成功'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // 删除失败
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('删除失败，请重试'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // 异常处理
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('删除出错：$e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _groupRecordsByType(List<ProductionRecord> records) {
    _todayRecords = records;
    _groupedRecords.clear();
    
    // 按ProductType分组
    for (final record in records) {
      if (!_groupedRecords.containsKey(record.productType)) {
        _groupedRecords[record.productType] = [];
        _expandedStates[record.productType] = false; // 默认收起
      }
      _groupedRecords[record.productType]!.add(record);
    }
    
    setState(() {});
  }

  void _toggleExpanded(ProductType productType) {
    setState(() {
      _expandedStates[productType] = !(_expandedStates[productType] ?? false);
    });
  }

  void _toggleProductCodeExpanded(String productCode) {
    setState(() {
      _productCodeExpandedStates[productCode] = !(_productCodeExpandedStates[productCode] ?? false);
    });
  }

  Widget _buildRecordItem(ProductionRecord record) {
    return Container(
      padding: const EdgeInsets.all(6), // 减少内边距
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 0,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child:Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.black)
            ),
            child: Text(
              '时间：${record.date.toString().substring(11, 16)}',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade50, Colors.blue.shade100],
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Text(
              '数量: ${record.quantity}',
              style: TextStyle(
                color: Colors.blue.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // 删除按钮
          IconButton(
            onPressed: () => _showDeleteConfirmDialog(record),
            icon: Icon(
              Icons.delete_outline,
              color: Colors.red.shade400,
              size: 20,
            ),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
          ),
        ],
      )
    );
  }

  Widget _buildProductCodeGroup(String productCode, List<ProductionRecord> records,ProductType productType) {
    final isExpanded = _productCodeExpandedStates[productCode] ?? false;
    final totalQuantity = records.fold<int>(0, (sum, record) => sum + record.quantity);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [Colors.indigo.shade50, Colors.blue.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.indigo.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _toggleProductCodeExpanded(productCode),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            productCode,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.indigo.shade800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.amber.shade300),
                                ),
                                child: Text(
                                  '${records.length}条记录',
                                  style: TextStyle(
                                    color: Colors.amber.shade800,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.green.shade400, Colors.teal.shade400],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withOpacity(0.3),
                                      spreadRadius: 0,
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '总量: $totalQuantity',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: (){
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) =>  ProductionRecordScreen(productCode: productCode,productType: productType,)),
                        ).then((a) =>
                            _loadTodayRecords());;
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                         Icons.add,
                          color: Colors.indigo.shade600,
                          size: 24,
                        ),
                      ),
                    ),  Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: const BorderRadius.all(Radius.circular(8)),
                      ),
                      child: Icon(
                        isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        color: Colors.indigo.shade600,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isExpanded)
            Column(
              children: records.map((record) => Padding(
                padding: const EdgeInsets.only(left: 8, right: 8, bottom: 6),
                child: _buildRecordItem(record),
              )).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildProductTypeSection(ProductType productType, List<ProductionRecord> records) {
    final isExpanded = _expandedStates[productType] ?? false;
    final totalQuantity = records.fold<int>(0, (sum, record) => sum + record.quantity);
    
    // 按产品编号分组
    final Map<String, List<ProductionRecord>> recordsByCode = {};
    for (final record in records) {
      if (!recordsByCode.containsKey(record.productCode)) {
        recordsByCode[record.productCode] = [];
      }
      recordsByCode[record.productCode]!.add(record);
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [Colors.white, Colors.blue.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.blue.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.15),
            spreadRadius: 0,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _toggleExpanded(productType),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade500, Colors.indigo.shade500],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.4),
                            spreadRadius: 0,
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child:  Icon(
                        _getProductTypeIcon(productType),
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            productTypeChDisplayNames[productType] ?? '其他',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            runSpacing: 10,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade100,
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(color: Colors.purple.shade300),
                                ),
                                child: Text(
                                  '${recordsByCode.length}个编号',
                                  style: TextStyle(
                                    color: Colors.purple.shade700,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(color: Colors.orange.shade300),
                                ),
                                child: Text(
                                  '${records.length}条记录',
                                  style: TextStyle(
                                    color: Colors.orange.shade700,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.green.shade500, Colors.teal.shade500],
                                  ),
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withOpacity(0.3),
                                      spreadRadius: 0,
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '总量: $totalQuantity',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Icon(
                        isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        size: 28,
                        color: Colors.blue.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: recordsByCode.entries.map((entry) => 
                  _buildProductCodeGroup(entry.key, entry.value,productType)
                ).toList(),
              ),
            ),
        ],
      ),
    );
  }

  IconData _getProductTypeIcon(ProductType productType) {
    switch (productType) {
      case ProductType.clothes:
        return Icons.checkroom_rounded;
      case ProductType.pants:
        return Icons.dry_cleaning_rounded;
      case ProductType.dress:
        return Icons.woman_rounded;
      case ProductType.hat:
        return Icons.sports_baseball_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          '统计助手',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade600, Colors.indigo.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        // 在文件顶部添加导入
        
        // 在AppBar的actions中添加周概览按钮（在月度统计按钮之前）
        actions: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _loadTodayRecords,
          tooltip: '刷新数据',
          ),
        ),
        Container(
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        ),
        child: TextButton(
          child: const Text('周',style: TextStyle(fontSize: 20,fontWeight:FontWeight.bold,color: Colors.white),),
        // icon: const Icon(Icons.calendar_view_week_rounded),
        onPressed: () {
        Navigator.push(
        context,
        MaterialPageRoute(
        builder: (context) => const WeeklyStatsScreen(),
        ),
        );
        },
        // tooltip: '周统计',
        ),
        ),
        Container(
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        ),
        child: TextButton(
          child: const Text('月',style: TextStyle(fontSize: 20,fontWeight:FontWeight.bold,color: Colors.white),),
        onPressed: () {
        Navigator.push(
        context,
        MaterialPageRoute(
        builder: (context) => const MonthlyStatsScreen(),
        ),
        );
        },
        ),
        ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16.0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, Colors.blue.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.blue.shade200,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.15),
                  spreadRadius: 0,
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade500, Colors.indigo.shade500],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.4),
                            spreadRadius: 0,
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.dashboard_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '今日概览｜',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    Text(
                      '${selectedDate.year}年${selectedDate.month}月${selectedDate.day}日',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade500, Colors.teal.shade500],
                    ),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.4),
                        spreadRadius: 0,
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.production_quantity_limits_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '总数量: ${_todayRecords.fold<int>(0, (sum, record) => sum + record.quantity)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.1),
                                spreadRadius: 0,
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade500),
                            strokeWidth: 3,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          '正在加载今日数据...',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : _groupedRecords.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.1),
                                    spreadRadius: 0,
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.inbox_outlined,
                                size: 80,
                                color: Colors.blue.shade300,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              '今日暂无记录',
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '点击右下角按钮开始记录',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 80), // 减少底部padding
                        children: _groupedRecords.entries
                            .map((entry) => _buildProductTypeSection(entry.key, entry.value))
                            .toList(),
                      ),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.3),
              spreadRadius: 0,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () async {
           Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProductionRecordScreen()),
            ).then((a) =>
               _loadTodayRecords());

          },
          icon: const Icon(Icons.add_rounded, size: 24),
          label: const Text(
            '添加记录',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          backgroundColor: Colors.blue.shade600,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
    );
  }
}
