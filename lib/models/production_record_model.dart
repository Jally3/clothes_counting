import './product_model.dart'; // 引入产品模型

class ProductionRecord {
  final int? id; // 记录的唯一ID，通常由数据库生成，改为int?
  final int productId; // 关联的产品ID，改为int
  final ProductType productType; // 产品类型，冗余存储方便查询，或从Product获取
  final String productStyleCode; // 产品编号/款式，冗余存储方便查询
  final int quantity; // 完成数量
  final DateTime date; // 记录日期
  // 可以添加其他记录相关属性，如记录人、班次等

  ProductionRecord({
    this.id, // id现在是可选的
    required this.productId,
    required this.productType,
    required this.productStyleCode,
    required this.quantity,
    required this.date,
  });

  // 便捷获取产品类型的显示名称
  String get productTypeDisplayName => productTypeDisplayNames[productType] ?? '未知';

  // 将ProductionRecord对象转换为Map，以便存入数据库
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'productType': productType.toString().split('.').last, // 将枚举转换为字符串存储
      'productStyleCode': productStyleCode,
      'quantity': quantity,
      'date': date.toIso8601String(), // 将DateTime转换为ISO 8601字符串存储
    };
  }

  // 从Map创建ProductionRecord对象
  factory ProductionRecord.fromMap(Map<String, dynamic> map) {
    return ProductionRecord(
      id: map['id'] as int?,
      productId: map['productId'] as int,
      productType: productTypeFromString(map['productType'] as String),
      productStyleCode: map['productStyleCode'] as String,
      quantity: map['quantity'] as int,
      date: DateTime.parse(map['date'] as String), // 从字符串解析DateTime
    );
  }

  // 用于创建ProductionRecord副本，通常用于更新id
  ProductionRecord copy({int? id}) {
    return ProductionRecord(
      id: id ?? this.id,
      productId: this.productId,
      productType: this.productType,
      productStyleCode: this.productStyleCode,
      quantity: this.quantity,
      date: this.date,
    );
  }
}