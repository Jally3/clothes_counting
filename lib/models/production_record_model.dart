import './product_model.dart'; // 引入产品模型

enum SyncStatus {
  pending,
  syncing,
  synced,
  failed,
  deletedPending,
}

SyncStatus syncStatusFromString(String? value) {
  return SyncStatus.values.firstWhere(
    (status) => status.name == value,
    orElse: () => SyncStatus.pending,
  );
}

class ProductionRecord {
  final int? id; // 记录的唯一ID，通常由数据库生成，改为int?
  final int productId; // 关联的产品ID，改为int
  final ProductType productType; // 产品类型，冗余存储方便查询，或从Product获取
  final String productCode; // 产品编号/款式，冗余存储方便查询
  final int quantity; // 完成数量
  final double unitPrice; // 编号单价，来自产品表，方便列表展示和同步
  final DateTime date; // 记录日期
  final bool isRework; // 是否为返工，默认为false
  final String? clientUuid;
  final String? serverId;
  final SyncStatus syncStatus;
  final DateTime? lastSyncAt;
  final String? syncError;
  final int retryCount;
  final DateTime? deletedAt;
  final DateTime? updatedAt;
  // 可以添加其他记录相关属性，如记录人、班次等

  ProductionRecord({
    this.id, // id现在是可选的
    required this.productId,
    required this.productType,
    required this.productCode,
    required this.quantity,
    this.unitPrice = 0,
    required this.date,
    this.isRework = false, // 默认为false
    this.clientUuid,
    this.serverId,
    this.syncStatus = SyncStatus.pending,
    this.lastSyncAt,
    this.syncError,
    this.retryCount = 0,
    this.deletedAt,
    this.updatedAt,
  });

  // 便捷获取产品类型的显示名称
  String get productTypeDisplayName =>
      productTypeChDisplayNames[productType] ?? '未知';

  // 将ProductionRecord对象转换为Map，以便存入数据库
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'quantity': quantity,
      'date': date.toIso8601String(), // 将DateTime转换为ISO 8601字符串存储
      'isRework': isRework ? 1 : 0, // 将bool转换为int存储
      'clientUuid': clientUuid,
      'serverId': serverId,
      'syncStatus': syncStatus.name,
      'lastSyncAt': lastSyncAt?.toIso8601String(),
      'syncError': syncError,
      'retryCount': retryCount,
      'deletedAt': deletedAt?.toIso8601String(),
      'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
    };
  }

  // 从Map创建ProductionRecord对象
  factory ProductionRecord.fromMap(Map<String, dynamic> map) {
    DateTime? parseOptionalDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value as String);
    }

    return ProductionRecord(
      id: map['id'] as int?,
      productId: map['productId'] as int,
      productType: productTypeFromString(map['productType'] as String),
      productCode: map['productCode'] as String,
      quantity: map['quantity'] as int,
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ??
          (map['price'] as num?)?.toDouble() ??
          0,
      date: DateTime.parse(map['date'] as String), // 从字符串解析DateTime
      isRework: (map['isRework'] as int?) == 1, // 从int转换为bool
      clientUuid: map['clientUuid'] as String?,
      serverId: map['serverId'] as String?,
      syncStatus: syncStatusFromString(map['syncStatus'] as String?),
      lastSyncAt: parseOptionalDate(map['lastSyncAt']),
      syncError: map['syncError'] as String?,
      retryCount: (map['retryCount'] as int?) ?? 0,
      deletedAt: parseOptionalDate(map['deletedAt']),
      updatedAt: parseOptionalDate(map['updatedAt']),
    );
  }

  // 用于创建ProductionRecord副本，通常用于更新id
  ProductionRecord copy({
    int? id,
    String? clientUuid,
    String? serverId,
    SyncStatus? syncStatus,
    DateTime? lastSyncAt,
    String? syncError,
    int? retryCount,
    DateTime? deletedAt,
    DateTime? updatedAt,
    double? unitPrice,
  }) {
    return ProductionRecord(
      id: id ?? this.id,
      productId: productId,
      productType: productType,
      productCode: productCode,
      quantity: quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      date: date,
      isRework: isRework,
      clientUuid: clientUuid ?? this.clientUuid,
      serverId: serverId ?? this.serverId,
      syncStatus: syncStatus ?? this.syncStatus,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      syncError: syncError ?? this.syncError,
      retryCount: retryCount ?? this.retryCount,
      deletedAt: deletedAt ?? this.deletedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toSyncPayload() {
    return {
      'clientUuid': clientUuid,
      'productType': productTypeDisplayNames[productType],
      'productCode': productCode,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'date': date.toIso8601String(),
      'isRework': isRework,
      'updatedAt': (updatedAt ?? date).toIso8601String(),
      'deletedAt': deletedAt?.toIso8601String(),
    };
  }
}
