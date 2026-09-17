import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/customer_model.dart';
import '../models/inventory_model.dart';
import '../models/manual_ledger_model.dart';
import '../models/weekly_report_model.dart';


/// Provides all Firestore read/write operations for the app.
///
/// Organised into three logical sections:
///   1. Customers
///   2. Inventory
///   3. Weekly Reports
///   4. Daily Ledger (computed aggregate)
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ────────────────────────────────────────────────────────────────
  // CUSTOMERS
  // ────────────────────────────────────────────────────────────────

  /// Adds a new customer document.  Returns the generated document ID.
  Future<String> addCustomer(CustomerModel customer) async {
    final ref = await _db.collection('customers').add(customer.toMap());
    return ref.id;
  }

  /// Overwrites the customer document identified by [customer.id].
  Future<void> updateCustomer(CustomerModel customer) async {
    await _db
        .collection('customers')
        .doc(customer.id)
        .update(customer.toMap());
  }

  /// Updates only the [status] field (and optionally [dateDelivered]).
  Future<void> updateCustomerStatus(
    String customerId,
    String status, {
    DateTime? deliveredDate,
  }) async {
    final data = <String, dynamic>{'status': status};
    if (deliveredDate != null) {
      data['dateDelivered'] = Timestamp.fromDate(deliveredDate);
    }
    await _db.collection('customers').doc(customerId).update(data);
  }

  /// Updates the payment fields ([totalPrice] and/or [advanceAmount]).
  Future<void> updateCustomerPayment(
    String customerId, {
    double? totalPrice,
    double? advanceAmount,
  }) async {
    final data = <String, dynamic>{};
    if (totalPrice != null) data['totalPrice'] = totalPrice;
    if (advanceAmount != null) data['advanceAmount'] = advanceAmount;
    if (data.isEmpty) return;
    await _db.collection('customers').doc(customerId).update(data);
  }

  /// Real-time stream of all customers, newest first.
  Stream<List<CustomerModel>> streamCustomers() {
    return _db
        .collection('customers')
        .orderBy('dateReceived', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => CustomerModel.fromMap(d.id, d.data())).toList());
  }

  /// Fetches a single customer by [customerId].  Returns `null` if not found.
  Future<CustomerModel?> getCustomer(String customerId) async {
    final doc = await _db.collection('customers').doc(customerId).get();
    if (!doc.exists || doc.data() == null) return null;
    return CustomerModel.fromMap(doc.id, doc.data()!);
  }

  /// Real-time stream of customers filtered by [status].
  Stream<List<CustomerModel>> streamCustomersByStatus(String status) {
    return _db
        .collection('customers')
        .where('status', isEqualTo: status)
        .orderBy('dateReceived', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => CustomerModel.fromMap(d.id, d.data())).toList());
  }

  /// Returns customers whose [dateReceived] falls within [[start], [end]).
  Future<List<CustomerModel>> getCustomersByDateRange(
      DateTime start, DateTime end) async {
    final snap = await _db
        .collection('customers')
        .where('dateReceived',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('dateReceived', isLessThan: Timestamp.fromDate(end))
        .get();
    return snap.docs.map((d) => CustomerModel.fromMap(d.id, d.data())).toList();
  }

  // ────────────────────────────────────────────────────────────────
  // INVENTORY
  // ────────────────────────────────────────────────────────────────

  /// Adds a new inventory item.  Returns the generated document ID.
  Future<String> addInventory(InventoryModel item) async {
    final ref = await _db.collection('inventory').add(item.toMap());
    return ref.id;
  }

  /// Marks an inventory item as returned and records the [returnDate].
  Future<void> markItemReturned(String itemId, [DateTime? returnDate]) async {
    final date = returnDate ?? DateTime.now();
    await _db.collection('inventory').doc(itemId).update({
      'isReturned': true,
      'returnDate': Timestamp.fromDate(date),
    });
  }

  /// Real-time stream of all inventory items, newest first.
  Stream<List<InventoryModel>> streamInventory() {
    return _db
        .collection('inventory')
        .orderBy('dateAdded', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => InventoryModel.fromMap(d.id, d.data())).toList());
  }

  /// Real-time stream of inventory items filtered by [category].
  Stream<List<InventoryModel>> streamInventoryByCategory(String category) {
    return _db
        .collection('inventory')
        .where('category', isEqualTo: category)
        .orderBy('dateAdded', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => InventoryModel.fromMap(d.id, d.data())).toList());
  }

  /// Returns inventory items whose [dateAdded] falls within [[start], [end]).
  Future<List<InventoryModel>> getInventoryByDateRange(
      DateTime start, DateTime end) async {
    final snap = await _db
        .collection('inventory')
        .where('dateAdded', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('dateAdded', isLessThan: Timestamp.fromDate(end))
        .get();
    return snap.docs.map((d) => InventoryModel.fromMap(d.id, d.data())).toList();
  }

  // ────────────────────────────────────────────────────────────────
  // WEEKLY REPORTS
  // ────────────────────────────────────────────────────────────────

  /// Creates or replaces a weekly report document (upsert by [report.id]).
  Future<void> saveWeeklyReport(WeeklyReportModel report) async {
    await _db
        .collection('weeklyReports')
        .doc(report.id)
        .set(report.toMap(), SetOptions(merge: true));
  }

  /// Real-time stream of all weekly reports, most recent first.
  Stream<List<WeeklyReportModel>> streamWeeklyReports() {
    return _db
        .collection('weeklyReports')
        .orderBy('weekStart', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => WeeklyReportModel.fromMap(d.id, d.data()))
            .toList());
  }

  /// Updates only the [paymentStatus] field of a weekly report.
  Future<void> updateReportPaymentStatus(
      String reportId, String status) async {
    await _db
        .collection('weeklyReports')
        .doc(reportId)
        .update({'paymentStatus': status});
  }

  // ────────────────────────────────────────────────────────────────
  // DAILY LEDGER (computed aggregate)
  // ────────────────────────────────────────────────────────────────

  /// Computes an aggregated daily ledger for [date].
  ///
  /// Returned map keys:
  /// - `date` – the queried [DateTime]
  /// - `newCustomersCount` – customers received on this day
  /// - `advanceCollected` – sum of advance amounts from new customers
  /// - `deliveredCount` – jobs delivered on this day
  /// - `totalCollected` – sum of totalPrice for all jobs delivered today
  /// - `totalStockReceivedValue` – purchase value of non-returned stock received today
  /// - `stockItemsCount` – count of non-returned stock items received today
  Future<Map<String, dynamic>> getDailyLedger(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    // Run both queries concurrently for performance.
    final results = await Future.wait([
      getCustomersByDateRange(start, end),
      getInventoryByDateRange(start, end),
      _getDeliveredByDateRange(start, end),
    ]);

    final customers = results[0] as List<CustomerModel>;
    final inventory = results[1] as List<InventoryModel>;
    final allDelivered = results[2] as List<CustomerModel>;

    final newCustomersCount = customers.length;

    final advanceCollected = customers.fold<double>(
      0.0,
      (total, c) => total + c.advanceAmount,
    );

    final totalCollected = allDelivered.fold<double>(
      0.0,
      (total, c) => total + (c.totalPrice ?? 0.0),
    );

    final activeInventory = inventory.where((i) => !i.isReturned).toList();

    final stockValue = activeInventory.fold<double>(
      0.0,
      (acc, i) => acc + i.totalValue,
    );

    return {
      'date': date,
      'newCustomersCount': newCustomersCount,
      'advanceCollected': advanceCollected,
      'deliveredCount': allDelivered.length,
      'totalCollected': totalCollected,
      'totalStockReceivedValue': stockValue,
      'stockItemsCount': activeInventory.length,
    };
  }

  /// Returns customers whose [dateDelivered] falls within [[start], [end]).
  Future<List<CustomerModel>> _getDeliveredByDateRange(
      DateTime start, DateTime end) async {
    final snap = await _db
        .collection('customers')
        .where('dateDelivered',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('dateDelivered', isLessThan: Timestamp.fromDate(end))
        .get();
    return snap.docs.map((d) => CustomerModel.fromMap(d.id, d.data())).toList();
  }

  // ────────────────────────────────────────────────────────────────
  // MANUAL SPREADSHEET LEDGER
  // ────────────────────────────────────────────────────────────────

  /// Real-time stream of manual ledger entries for [date].
  Stream<List<ManualLedgerEntry>> streamManualLedgerByDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return _db
        .collection('manualLedger')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ManualLedgerEntry.fromMap(d.id, d.data()))
            .toList());
  }

  /// Adds a new manual spreadsheet ledger entry.
  Future<String> addManualLedgerEntry(ManualLedgerEntry entry) async {
    final ref = await _db.collection('manualLedger').add(entry.toMap());
    return ref.id;
  }

  /// Updates an existing manual spreadsheet ledger entry.
  Future<void> updateManualLedgerEntry(ManualLedgerEntry entry) async {
    await _db
        .collection('manualLedger')
        .doc(entry.id)
        .update(entry.toMap());
  }

  /// Deletes a manual spreadsheet ledger entry by [id].
  Future<void> deleteManualLedgerEntry(String id) async {
    await _db.collection('manualLedger').doc(id).delete();
  }
}





