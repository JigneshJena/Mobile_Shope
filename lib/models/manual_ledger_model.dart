import 'package:cloud_firestore/cloud_firestore.dart';

class ManualLedgerEntry {
  final String id;
  final String model;
  final String work;
  final double cashAmount;
  final double onlineAmount;
  final DateTime date;
  final DateTime createdAt;

  ManualLedgerEntry({
    required this.id,
    required this.model,
    required this.work,
    required this.cashAmount,
    required this.onlineAmount,
    DateTime? date,
    DateTime? createdAt,
  })  : date = date ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  double get totalAmount => cashAmount + onlineAmount;

  factory ManualLedgerEntry.fromMap(String id, Map<String, dynamic> map) {
    return ManualLedgerEntry(
      id: id,
      model: map['model'] ?? '',
      work: map['work'] ?? '',
      cashAmount: (map['cashAmount'] as num? ?? 0.0).toDouble(),
      onlineAmount: (map['onlineAmount'] as num? ?? 0.0).toDouble(),
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'model': model,
      'work': work,
      'cashAmount': cashAmount,
      'onlineAmount': onlineAmount,
      'date': Timestamp.fromDate(date),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  ManualLedgerEntry copyWith({
    String? id,
    String? model,
    String? work,
    double? cashAmount,
    double? onlineAmount,
    DateTime? date,
    DateTime? createdAt,
  }) {
    return ManualLedgerEntry(
      id: id ?? this.id,
      model: model ?? this.model,
      work: work ?? this.work,
      cashAmount: cashAmount ?? this.cashAmount,
      onlineAmount: onlineAmount ?? this.onlineAmount,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

