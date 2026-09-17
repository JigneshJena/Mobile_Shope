import 'package:cloud_firestore/cloud_firestore.dart';

class WeeklyReportModel {
  final String id;
  final DateTime weekStart;
  final DateTime weekEnd;
  final double totalPurchaseAmount;
  final double totalReturnAmount;
  final String paymentStatus; // 'pending' | 'paid'

  const WeeklyReportModel({
    required this.id,
    required this.weekStart,
    required this.weekEnd,
    required this.totalPurchaseAmount,
    required this.totalReturnAmount,
    required this.paymentStatus,
  });

  /// Net amount payable after subtracting returned items.
  double get netPayable => totalPurchaseAmount - totalReturnAmount;

  factory WeeklyReportModel.fromMap(String id, Map<String, dynamic> map) {
    return WeeklyReportModel(
      id: id,
      weekStart: (map['weekStart'] as Timestamp).toDate(),
      weekEnd: (map['weekEnd'] as Timestamp).toDate(),
      totalPurchaseAmount:
          (map['totalPurchaseAmount'] as num?)?.toDouble() ?? 0.0,
      totalReturnAmount:
          (map['totalReturnAmount'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: map['paymentStatus'] ?? 'pending',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'weekStart': Timestamp.fromDate(weekStart),
      'weekEnd': Timestamp.fromDate(weekEnd),
      'totalPurchaseAmount': totalPurchaseAmount,
      'totalReturnAmount': totalReturnAmount,
      'paymentStatus': paymentStatus,
    };
  }

  WeeklyReportModel copyWith({
    String? id,
    DateTime? weekStart,
    DateTime? weekEnd,
    double? totalPurchaseAmount,
    double? totalReturnAmount,
    String? paymentStatus,
  }) {
    return WeeklyReportModel(
      id: id ?? this.id,
      weekStart: weekStart ?? this.weekStart,
      weekEnd: weekEnd ?? this.weekEnd,
      totalPurchaseAmount: totalPurchaseAmount ?? this.totalPurchaseAmount,
      totalReturnAmount: totalReturnAmount ?? this.totalReturnAmount,
      paymentStatus: paymentStatus ?? this.paymentStatus,
    );
  }
}
