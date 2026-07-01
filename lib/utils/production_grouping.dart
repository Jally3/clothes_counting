import '../models/product_model.dart';
import '../models/production_record_model.dart';

Map<ProductType, List<ProductionRecord>> groupRecordsByProductType(
  List<ProductionRecord> records,
) {
  final groupedRecords = <ProductType, List<ProductionRecord>>{};
  for (final record in records) {
    groupedRecords.putIfAbsent(record.productType, () => []).add(record);
  }
  return groupedRecords;
}

Map<String, List<ProductionRecord>> groupRecordsByProductCode(
  List<ProductionRecord> records,
) {
  final groupedRecords = <String, List<ProductionRecord>>{};
  for (final record in records) {
    groupedRecords.putIfAbsent(record.productCode, () => []).add(record);
  }
  return groupedRecords;
}
