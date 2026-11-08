import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/manual_ledger_model.dart';
import '../models/weekly_report_model.dart';
import '../services/firestore_service.dart';
import '../services/excel_export_service.dart';
import 'auth_provider.dart';
import 'customer_provider.dart'; // re-exports firestoreServiceProvider

// ---------------------------------------------------------------------------
// Selected date for daily hisaab (defaults to today)
// ---------------------------------------------------------------------------

final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

// ---------------------------------------------------------------------------
// Daily ledger data (keyed by date)
// ---------------------------------------------------------------------------

final dailyLedgerProvider =
    FutureProvider.family<Map<String, dynamic>, DateTime>((ref, date) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return {};
  return ref.watch(firestoreServiceProvider).getDailyLedger(date);
});

// ---------------------------------------------------------------------------
// Manual spreadsheet ledger stream (by date)
// ---------------------------------------------------------------------------

final manualLedgerStreamProvider =
    StreamProvider.family<List<ManualLedgerEntry>, DateTime>((ref, date) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const Stream.empty();
  return ref.watch(firestoreServiceProvider).streamManualLedgerByDate(date);
});


// ---------------------------------------------------------------------------
// Weekly reports stream
// ---------------------------------------------------------------------------

final weeklyReportsProvider =
    StreamProvider<List<WeeklyReportModel>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const Stream.empty();
  return ref.watch(firestoreServiceProvider).streamWeeklyReports();
});

// ---------------------------------------------------------------------------
// Excel export service
// ---------------------------------------------------------------------------

final excelExportServiceProvider =
    Provider<ExcelExportService>((ref) => ExcelExportService());

// ---------------------------------------------------------------------------
// WeeklyReportNotifier - save report and mark paid
// ---------------------------------------------------------------------------

class WeeklyReportNotifier extends StateNotifier<AsyncValue<void>> {
  WeeklyReportNotifier(this._firestore) : super(const AsyncValue.data(null));

  final FirestoreService _firestore;

  /// Saves a new or updated [WeeklyReportModel] to Firestore.
  Future<void> saveReport(WeeklyReportModel report) async {
    state = const AsyncValue.loading();
    try {
      await _firestore.saveWeeklyReport(report);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Marks the weekly report identified by [reportId] as paid.
  Future<void> markPaid(String reportId) async {
    state = const AsyncValue.loading();
    try {
      await _firestore.updateReportPaymentStatus(reportId, 'paid');
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final weeklyReportNotifierProvider =
    StateNotifierProvider<WeeklyReportNotifier, AsyncValue<void>>(
  (ref) => WeeklyReportNotifier(ref.watch(firestoreServiceProvider)),
);
