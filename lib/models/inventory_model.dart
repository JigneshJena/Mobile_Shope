import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a spare-parts inventory item.
class InventoryModel {
  const InventoryModel({
    required this.id,
    required this.itemName,
    required this.category,
    required this.quantity,
    required this.purchasePrice,
    required this.dateAdded,
    this.supplierName,
    this.isReturned = false,
    this.returnDate,
    this.notes,
    this.imageUrl,
  });

  final String id;
  final String itemName;
  final String category;
  final int quantity;
  final double purchasePrice;
  final DateTime dateAdded;
  final String? supplierName;
  final bool isReturned;
  final DateTime? returnDate;
  final String? notes;
  final String? imageUrl; // Optional product/spare part photo URL

  // Aliases for compatibility
  String get name => itemName;
  num get purchasePricePerUnit => purchasePrice;
  String? get supplier => supplierName;
  DateTime? get dateReturned => returnDate;

  /// Total stock value (quantity x price).
  double get totalValue => quantity * purchasePrice;

  factory InventoryModel.fromMap(String id, Map<String, dynamic> map) {
    return InventoryModel(
      id: id,
      itemName: (map['itemName'] ?? map['name']) as String? ?? '',
      category: map['category'] as String? ?? 'other',
      quantity: (map['quantity'] as num? ?? 0).toInt(),
      purchasePrice: ((map['purchasePrice'] ?? map['purchasePricePerUnit']) as num? ?? 0).toDouble(),
      dateAdded: (map['dateAdded'] as Timestamp?)?.toDate() ?? DateTime.now(),
      supplierName: (map['supplierName'] ?? map['supplier']) as String?,
      isReturned: map['isReturned'] as bool? ?? false,
      returnDate: ((map['returnDate'] ?? map['dateReturned']) as Timestamp?)?.toDate(),
      notes: map['notes'] as String?,
      imageUrl: map['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'itemName': itemName,
    'name': itemName,
    'category': category,
    'quantity': quantity,
    'purchasePrice': purchasePrice,
    'purchasePricePerUnit': purchasePrice,
    'dateAdded': Timestamp.fromDate(dateAdded),
    if (supplierName != null) 'supplierName': supplierName,
    if (supplierName != null) 'supplier': supplierName,
    'isReturned': isReturned,
    if (returnDate != null) 'returnDate': Timestamp.fromDate(returnDate!),
    if (returnDate != null) 'dateReturned': Timestamp.fromDate(returnDate!),
    if (notes != null) 'notes': notes,
    if (imageUrl != null) 'imageUrl': imageUrl,
  };

  InventoryModel copyWith({
    String? id,
    String? itemName,
    String? name,
    String? category,
    int? quantity,
    double? purchasePrice,
    num? purchasePricePerUnit,
    DateTime? dateAdded,
    String? supplierName,
    String? supplier,
    bool? isReturned,
    DateTime? returnDate,
    DateTime? dateReturned,
    bool clearReturnDate = false,
    String? notes,
    String? imageUrl,
  }) {
    return InventoryModel(
      id: id ?? this.id,
      itemName: itemName ?? name ?? this.itemName,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      purchasePrice: (purchasePrice ?? purchasePricePerUnit?.toDouble()) ?? this.purchasePrice,
      dateAdded: dateAdded ?? this.dateAdded,
      supplierName: supplierName ?? supplier ?? this.supplierName,
      isReturned: isReturned ?? this.isReturned,
      returnDate: clearReturnDate ? null : (returnDate ?? dateReturned ?? this.returnDate),
      notes: notes ?? this.notes,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
