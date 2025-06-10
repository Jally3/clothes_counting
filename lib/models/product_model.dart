// 定义产品类型枚举，方便管理和使用
enum ProductType {
  clothes,    // 衣服
  pants,      // 裤子
  dress,      // 连衣裙
  hat,        // 帽子
  unknown     // 未知类型，用于兼容或错误处理
}

// 产品类型到显示名称的映射
const Map<ProductType, String> productTypeDisplayNames = {
  ProductType.clothes: '衣服',
  ProductType.pants: '裤子',
  ProductType.dress: '连衣裙',
  ProductType.hat: '帽子',
  ProductType.unknown: '未知',
};

// 显示名称到产品类型的映射 (用于从字符串转换)
ProductType productTypeFromString(String typeString) {
  return productTypeDisplayNames.entries
      .firstWhere((entry) => entry.value == typeString, orElse: () => const MapEntry(ProductType.unknown, '未知'))
      .key;
}

class Product {
  final int? id; // 将id改为int?类型，因为数据库是INTEGER PRIMARY KEY AUTOINCREMENT
  final ProductType type;
  final String styleCode; // 产品编号/款式
  // 可以添加其他产品相关属性，如颜色、尺码等

  Product({
    this.id, // id现在是可选的
    required this.type,
    required this.styleCode,
  });

  // 便捷获取产品类型的显示名称
  String get typeDisplayName => productTypeDisplayNames[type] ?? '未知';

  // 将Product对象转换为Map，以便存入数据库
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productType': type.toString().split('.').last, // 将枚举转换为字符串存储
      'productCode': styleCode, // 数据库中是productCode，这里对应styleCode
      'style': styleCode, // 数据库中是style，这里也对应styleCode，如果需要区分，请调整
    };
  }

  // 从Map创建Product对象
  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      type: productTypeFromString(map['productType'] as String),
      styleCode: map['productCode'] as String, // 从productCode字段读取
    );
  }

  // 用于创建Product副本，通常用于更新id
  Product copy({int? id}) {
    return Product(
      id: id ?? this.id,
      type: type,
      styleCode: styleCode,
    );
  }
}