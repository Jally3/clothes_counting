import '../../models/production_record_model.dart';
import '../../models/product_model.dart';
import '../../utils/production_grouping.dart';

class DashboardSummaryVm {
  const DashboardSummaryVm({
    required this.totalQuantity,
    required this.totalPrice,
  });

  final int totalQuantity;
  final double totalPrice;

  static const empty = DashboardSummaryVm(
    totalQuantity: 0,
    totalPrice: 0,
  );
}

class ProductTypeSectionVm {
  const ProductTypeSectionVm({
    required this.productType,
    required this.totalQuantity,
    required this.totalPrice,
    required this.codeGroups,
  });

  final ProductType productType;
  final int totalQuantity;
  final double totalPrice;
  final List<ProductCodeGroupVm> codeGroups;
}

class ProductCodeGroupVm {
  const ProductCodeGroupVm({
    required this.productType,
    required this.productCode,
    required this.expansionKey,
    required this.totalQuantity,
    required this.unitPrice,
    required this.totalPrice,
    required this.hasRework,
    required this.latestRecord,
    required this.records,
  });

  final ProductType productType;
  final String productCode;
  final String expansionKey;
  final int totalQuantity;
  final double unitPrice;
  final double totalPrice;
  final bool hasRework;
  final ProductionRecord? latestRecord;
  final List<ProductionRecord> records;
}

class DashboardViewModelBuilder {
  const DashboardViewModelBuilder._();

  static DashboardSummaryVm buildSummary(List<ProductionRecord> records) {
    return DashboardSummaryVm(
      totalQuantity: records.fold<int>(
        0,
        (sum, record) => sum + record.quantity,
      ),
      totalPrice: records.fold<double>(
        0,
        (sum, record) => sum + record.quantity * record.unitPrice,
      ),
    );
  }

  static List<ProductTypeSectionVm> buildSections(
    List<ProductionRecord> records,
  ) {
    final groupedByType = groupRecordsByProductType(records);
    return groupedByType.entries.map((entry) {
      final typeRecords = entry.value;
      final groupedByCode = groupRecordsByProductCode(typeRecords);
      return ProductTypeSectionVm(
        productType: entry.key,
        totalQuantity: typeRecords.fold<int>(
          0,
          (sum, record) => sum + record.quantity,
        ),
        totalPrice: typeRecords.fold<double>(
          0,
          (sum, record) => sum + record.quantity * record.unitPrice,
        ),
        codeGroups: groupedByCode.entries.map((codeEntry) {
          final codeRecords = codeEntry.value;
          final totalQuantity = codeRecords.fold<int>(
            0,
            (sum, record) => sum + record.quantity,
          );
          final unitPrice =
              codeRecords.isEmpty ? 0.0 : codeRecords.first.unitPrice;
          return ProductCodeGroupVm(
            productType: entry.key,
            productCode: codeEntry.key,
            expansionKey: '${entry.key.name}:${codeEntry.key}',
            totalQuantity: totalQuantity,
            unitPrice: unitPrice,
            totalPrice: totalQuantity * unitPrice,
            hasRework: codeRecords.any((record) => record.isRework),
            latestRecord: codeRecords.isEmpty ? null : codeRecords.first,
            records: codeRecords,
          );
        }).toList(),
      );
    }).toList();
  }
}
