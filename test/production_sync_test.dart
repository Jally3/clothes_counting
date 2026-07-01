import 'package:flutter_test/flutter_test.dart';

import 'package:clothes_counting/models/product_model.dart';
import 'package:clothes_counting/models/production_record_model.dart';
import 'package:clothes_counting/utils/production_grouping.dart';

void main() {
  test('ProductionRecord serializes sync payload', () {
    final record = ProductionRecord(
      id: 1,
      productId: 10,
      productType: ProductType.clothes,
      productCode: '#A100',
      quantity: 12,
      date: DateTime(2026, 7, 1, 9, 30),
      isRework: true,
      clientUuid: 'client-1',
      syncStatus: SyncStatus.pending,
      updatedAt: DateTime(2026, 7, 1, 10),
    );

    final payload = record.toSyncPayload();

    expect(payload['clientUuid'], 'client-1');
    expect(payload['productType'], 'clothes');
    expect(payload['productCode'], '#A100');
    expect(payload['quantity'], 12);
    expect(payload['isRework'], isTrue);
    expect(payload['deletedAt'], isNull);
  });

  test('groupRecordsByProductType groups records without mutating them', () {
    final records = [
      ProductionRecord(
        productId: 1,
        productType: ProductType.clothes,
        productCode: '#A',
        quantity: 3,
        date: DateTime(2026, 7, 1),
      ),
      ProductionRecord(
        productId: 2,
        productType: ProductType.pants,
        productCode: '#B',
        quantity: 5,
        date: DateTime(2026, 7, 1),
      ),
      ProductionRecord(
        productId: 3,
        productType: ProductType.clothes,
        productCode: '#C',
        quantity: 7,
        date: DateTime(2026, 7, 2),
      ),
    ];

    final grouped = groupRecordsByProductType(records);

    expect(grouped[ProductType.clothes], hasLength(2));
    expect(grouped[ProductType.pants], hasLength(1));
    expect(records, hasLength(3));
  });
}
