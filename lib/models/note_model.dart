import 'package:cloud_firestore/cloud_firestore.dart';

class NoteModel {
  final String id;
  final String title;
  final String body;
  final DateTime? reminderDate; // null = no reminder
  final DateTime createdAt;
  final String createdBy; // uid

  const NoteModel({
    required this.id,
    required this.title,
    required this.body,
    this.reminderDate,
    required this.createdAt,
    required this.createdBy,
  });

  bool get hasReminder => reminderDate != null;
  bool get isReminderDue =>
      reminderDate != null && reminderDate!.isBefore(DateTime.now());
  bool get isReminderUpcoming =>
      reminderDate != null && reminderDate!.isAfter(DateTime.now());

  Map<String, dynamic> toMap() => {
    'title': title,
    'body': body,
    'reminderDate': reminderDate != null ? Timestamp.fromDate(reminderDate!) : null,
    'createdAt': Timestamp.fromDate(createdAt),
    'createdBy': createdBy,
  };

  factory NoteModel.fromMap(String id, Map<String, dynamic> map) => NoteModel(
    id: id,
    title: map['title'] as String? ?? '',
    body: map['body'] as String? ?? '',
    reminderDate: map['reminderDate'] != null
        ? (map['reminderDate'] as Timestamp).toDate()
        : null,
    createdAt: map['createdAt'] != null
        ? (map['createdAt'] as Timestamp).toDate()
        : DateTime.now(),
    createdBy: map['createdBy'] as String? ?? '',
  );

  NoteModel copyWith({
    String? id,
    String? title,
    String? body,
    Object? reminderDate = _sentinel,
    DateTime? createdAt,
    String? createdBy,
  }) {
    return NoteModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      reminderDate: reminderDate == _sentinel
          ? this.reminderDate
          : reminderDate as DateTime?,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}

const _sentinel = Object();
