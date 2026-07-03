import 'package:flutter/material.dart';
import '../extensions/double_extension.dart';
import '../models/production_record_model.dart';
import '../models/product_model.dart';
import '../repositories/production_repository.dart';
import '../utils/production_grouping.dart';
import '../widgets/unit_price_edit_dialog.dart';
import 'production_record_screen.dart';

class DateDetailScreen extends StatefulWidget {
  final DateTime selectedDate;

  const DateDetailScreen({super.key, required this.selectedDate});

  @override
  State<DateDetailScreen> createState() => _DateDetailScreenState();
}

class _DateDetailScreenState extends State<DateDetailScreen> {
  final ProductionRepository _repository = ProductionRepository.instance;
  List<ProductionRecord> _records = [];
  Map<ProductType, List<ProductionRecord>> _groupedRecords = {};
  final Map<ProductType, bool> _expandedStates = {};
  final Map<String, bool> _productCodeExpandedStates = {};
  bool _isLoading = true;

  String get _shortDateTitle =>
      '${widget.selectedDate.month}月${widget.selectedDate.day}日统计';

  String get _fullDateText =>
      '${widget.selectedDate.year}年${widget.selectedDate.month}月${widget.selectedDate.day}日';

  DateTime get _initialRecordDateTime {
    final now = DateTime.now();
    return DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
      now.hour,
      now.minute,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final records =
          await _repository.getProductionRecordsByDate(widget.selectedDate);
      if (!mounted) return;
      _groupRecordsByType(records);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载记录失败: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _groupRecordsByType(List<ProductionRecord> records) {
    _records = records;
    _groupedRecords = groupRecordsByProductType(records);
    for (final productType in _groupedRecords.keys) {
      _expandedStates.putIfAbsent(productType, () => false);
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
      _productCodeExpandedStates[productCode] =
          !(_productCodeExpandedStates[productCode] ?? false);
    });
  }

  Future<void> _editProductCodePrice({
    required ProductType productType,
    required String productCode,
    required double currentPrice,
  }) async {
    final newPrice = await showUnitPriceEditDialog(
      context: context,
      productCode: productCode,
      initialPrice: currentPrice,
    );
    if (!mounted || newPrice == null) return;

    try {
      await _repository.updateProductPrice(
        productType: productType,
        productCode: productCode,
        price: newPrice,
      );
      if (!mounted) return;
      await _loadRecords();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('单价已更新'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('单价更新失败：$e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildRecordItem(ProductionRecord record) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.08),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '时间：${record.date.toString().substring(11, 16)}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Visibility(
            visible: record.isRework,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade50, Colors.blue.shade100],
                ),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Text(
                '返工',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
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
        ],
      ),
    );
  }

  Widget _buildProductCodeGroup(String productCode,
      List<ProductionRecord> records, ProductType productType) {
    final isExpanded = _productCodeExpandedStates[productCode] ?? false;
    final totalQuantity =
        records.fold<int>(0, (sum, record) => sum + record.quantity);
    final unitPrice = records.isEmpty ? 0.0 : records.first.unitPrice;
    final totalPrice = totalQuantity * unitPrice;
    final hasRemark = records.any((e) => e.isRework);

    return Container(
      margin: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
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
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.indigo.shade400,
                            Colors.blue.shade400
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.indigo.withOpacity(0.3),
                            spreadRadius: 0,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.qr_code_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
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
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.amber.shade300),
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
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.green.shade400,
                                      Colors.teal.shade400
                                    ],
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
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.blue.shade200),
                                ),
                                child: Text(
                                  '单价: ¥${_formatMoney(unitPrice)}',
                                  style: TextStyle(
                                    color: Colors.blue.shade700,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.blue.shade300),
                                ),
                                child: Text(
                                  '总价: ¥${_formatMoney(totalPrice)}',
                                  style: TextStyle(
                                    color: Colors.blue.shade800,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: '编辑单价',
                      onPressed: () => _editProductCodePrice(
                        productType: productType,
                        productCode: productCode,
                        currentPrice: unitPrice,
                      ),
                      icon: Icon(
                        Icons.edit_note_rounded,
                        color: Colors.indigo.shade600,
                        size: 24,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: Colors.indigo.shade600,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Visibility(
                      visible: hasRemark,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue.shade50, Colors.blue.shade100],
                          ),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: const Text(
                          '返工',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isExpanded)
            Container(
              padding: const EdgeInsets.only(top: 0, bottom: 0),
              child: Column(
                children: records
                    .map((record) => Padding(
                          padding: const EdgeInsets.only(
                              left: 8, right: 8, bottom: 8),
                          child: _buildRecordItem(record),
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductTypeSection(
      ProductType productType, List<ProductionRecord> records) {
    final isExpanded = _expandedStates[productType] ?? false;
    final totalQuantity =
        records.fold<int>(0, (sum, record) => sum + record.quantity);

    final recordsByCode = groupRecordsByProductCode(records);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.blue.shade500,
                            Colors.indigo.shade500
                          ],
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
                      child: Icon(
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
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade100,
                                  borderRadius: BorderRadius.circular(15),
                                  border:
                                      Border.all(color: Colors.purple.shade300),
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
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(15),
                                  border:
                                      Border.all(color: Colors.orange.shade300),
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
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.green.shade500,
                                      Colors.teal.shade500
                                    ],
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
                      ),
                      child: Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: Colors.blue.shade600,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isExpanded)
            Container(
              padding: const EdgeInsets.only(top: 0, bottom: 0),
              child: Column(
                children: recordsByCode.entries
                    .map((entry) => _buildProductCodeGroup(
                        entry.key, entry.value, productType))
                    .toList(),
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
      case ProductType.hat:
        return Icons.local_laundry_service_rounded;
      case ProductType.dress:
        return Icons.woman_rounded;

      case ProductType.unknown:
        return Icons.category_rounded;
    }
  }

  String _formatMoney(double value) {
    return value.toTrimmedPriceString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.blue.shade800,
        title: Text(
          _shortDateTitle,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade800,
          ),
        ),
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: Colors.blue.shade700),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [Colors.blue.shade500, Colors.indigo.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  spreadRadius: 0,
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.calendar_today_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '日期概览',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _fullDateText,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.82),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
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
                            '总数量: ${_records.fold<int>(0, (sum, record) => sum + record.quantity)}',
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
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.blue.shade500),
                            strokeWidth: 3,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          '正在加载数据...',
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
                              padding: const EdgeInsets.all(16),
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
                              '该日期暂无记录',
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 100),
                        children: _groupedRecords.entries
                            .map((entry) => _buildProductTypeSection(
                                entry.key, entry.value))
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
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProductionRecordScreen(
                  initialDateTime: _initialRecordDateTime,
                ),
              ),
            );
            if (mounted) {
              _loadRecords();
            }
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
