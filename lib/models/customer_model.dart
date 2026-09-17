import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerModel {
  final String id;
  final String name;
  final String phone;
  final String address;
  final String mobileModel;
  final String issueDescription;
  final List<String> imageUrls;
  final double? totalPrice; // null = price not yet determined
  final double advanceAmount;
  final String status; // pending | in_progress | repaired | delivered
  final DateTime dateReceived;
  final DateTime? dateDelivered;
  final String handledBy; // uid of the employee/owner

  // ── Auto-generated audit fields ──────────────────────────────────────────
  final DateTime createdAt;

  // ── Security & Notes fields ──────────────────────────────────────────────
  final String? imeiEncrypted;
  final bool hasOnlineLock;

  /// Unrepaired defects, declined services, or customer remarks stored for future visits.
  final String? unrepairedIssues;

  const CustomerModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.mobileModel,
    required this.issueDescription,
    required this.imageUrls,
    this.totalPrice,
    required this.advanceAmount,
    required this.status,
    required this.dateReceived,
    this.dateDelivered,
    required this.handledBy,
    required this.createdAt,
    this.imeiEncrypted,
    this.hasOnlineLock = false,
    this.unrepairedIssues,
  });

  /// Amount still owed by the customer after the advance payment.
  double get remainingBalance => (totalPrice ?? 0) - advanceAmount;

  factory CustomerModel.fromMap(String id, Map<String, dynamic> map) {
    return CustomerModel(
      id: id,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      mobileModel: map['mobileModel'] ?? '',
      issueDescription: map['issueDescription'] ?? '',
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      totalPrice: map['totalPrice'] != null
          ? (map['totalPrice'] as num).toDouble()
          : null,
      advanceAmount: (map['advanceAmount'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] ?? 'pending',
      dateReceived:
          (map['dateReceived'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dateDelivered: (map['dateDelivered'] as Timestamp?)?.toDate(),
      handledBy: map['handledBy'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ??
          (map['dateReceived'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      imeiEncrypted: map['imeiEncrypted'] as String?,
      hasOnlineLock: (map['hasOnlineLock'] as bool?) ?? false,
      unrepairedIssues: map['unrepairedIssues'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'address': address,
      'mobileModel': mobileModel,
      'issueDescription': issueDescription,
      'imageUrls': imageUrls,
      'totalPrice': totalPrice,
      'advanceAmount': advanceAmount,
      'status': status,
      'dateReceived': Timestamp.fromDate(dateReceived),
      'dateDelivered':
          dateDelivered != null ? Timestamp.fromDate(dateDelivered!) : null,
      'handledBy': handledBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'imeiEncrypted': imeiEncrypted,
      'hasOnlineLock': hasOnlineLock,
      'unrepairedIssues': unrepairedIssues,
    };
  }

  CustomerModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    String? mobileModel,
    String? issueDescription,
    List<String>? imageUrls,
    double? totalPrice,
    bool clearTotalPrice = false,
    double? advanceAmount,
    String? status,
    DateTime? dateReceived,
    DateTime? dateDelivered,
    bool clearDateDelivered = false,
    String? handledBy,
    DateTime? createdAt,
    String? imeiEncrypted,
    bool clearImei = false,
    bool? hasOnlineLock,
    String? unrepairedIssues,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      mobileModel: mobileModel ?? this.mobileModel,
      issueDescription: issueDescription ?? this.issueDescription,
      imageUrls: imageUrls ?? this.imageUrls,
      totalPrice: clearTotalPrice ? null : (totalPrice ?? this.totalPrice),
      advanceAmount: advanceAmount ?? this.advanceAmount,
      status: status ?? this.status,
      dateReceived: dateReceived ?? this.dateReceived,
      dateDelivered: clearDateDelivered
          ? null
          : (dateDelivered ?? this.dateDelivered),
      handledBy: handledBy ?? this.handledBy,
      createdAt: createdAt ?? this.createdAt,
      imeiEncrypted: clearImei ? null : (imeiEncrypted ?? this.imeiEncrypted),
      hasOnlineLock: hasOnlineLock ?? this.hasOnlineLock,
      unrepairedIssues: unrepairedIssues ?? this.unrepairedIssues,
    );
  }
}
