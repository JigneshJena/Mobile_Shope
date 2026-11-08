import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/customer_model.dart';
import '../services/firestore_service.dart';
import 'auth_provider.dart';

// ---------------------------------------------------------------------------
// Service instance provider
// ---------------------------------------------------------------------------

final firestoreServiceProvider =
    Provider<FirestoreService>((ref) => FirestoreService());

// ---------------------------------------------------------------------------
// Stream of all customers (only active when logged in)
// ---------------------------------------------------------------------------

final customersStreamProvider =
    StreamProvider<List<CustomerModel>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const Stream.empty();
  return ref.watch(firestoreServiceProvider).streamCustomers();
});

// ---------------------------------------------------------------------------
// Stream filtered by status
// ---------------------------------------------------------------------------

final customersByStatusProvider =
    StreamProvider.family<List<CustomerModel>, String>((ref, status) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const Stream.empty();
  return ref.watch(firestoreServiceProvider).streamCustomersByStatus(status);
});

// ---------------------------------------------------------------------------
// Search query state
// ---------------------------------------------------------------------------

final customerSearchQueryProvider = StateProvider<String>((ref) => '');

// ---------------------------------------------------------------------------
// Status filter state (null = all)
// ---------------------------------------------------------------------------

final customerStatusFilterProvider = StateProvider<String?>((ref) => null);

// ---------------------------------------------------------------------------
// Filtered customers (derived from search + status filter)
// ---------------------------------------------------------------------------

final filteredCustomersProvider =
    Provider<AsyncValue<List<CustomerModel>>>((ref) {
  final allCustomers = ref.watch(customersStreamProvider);
  final query = ref.watch(customerSearchQueryProvider).toLowerCase();
  final statusFilter = ref.watch(customerStatusFilterProvider);

  return allCustomers.whenData((customers) {
    var filtered = customers;

    if (statusFilter != null) {
      filtered = filtered.where((c) => c.status == statusFilter).toList();
    }

    if (query.isNotEmpty) {
      filtered = filtered
          .where((c) =>
              c.name.toLowerCase().contains(query) ||
              c.phone.contains(query) ||
              c.mobileModel.toLowerCase().contains(query))
          .toList();
    }

    return filtered;
  });
});

// ---------------------------------------------------------------------------
// CustomerNotifier - add, update, status change, payment update
// ---------------------------------------------------------------------------

class CustomerNotifier extends StateNotifier<AsyncValue<void>> {
  CustomerNotifier(this._firestore) : super(const AsyncValue.data(null));

  final FirestoreService _firestore;

  /// Adds a new customer job record to Firestore.
  Future<void> addCustomer(CustomerModel customer) async {
    state = const AsyncValue.loading();
    try {
      await _firestore.addCustomer(customer);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Updates the repair [status] for a given customer.
  ///
  /// Pass [deliveredDate] when the status transitions to 'delivered'.
  Future<void> updateStatus(
    String customerId,
    String status, {
    DateTime? deliveredDate,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _firestore.updateCustomerStatus(
        customerId,
        status,
        deliveredDate: deliveredDate,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Updates the [totalPrice] and/or [advanceAmount] for a customer job.
  Future<void> updatePayment(
    String customerId, {
    double? totalPrice,
    double? advanceAmount,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _firestore.updateCustomerPayment(
        customerId,
        totalPrice: totalPrice,
        advanceAmount: advanceAmount,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Replaces the full customer document with an updated [CustomerModel].
  Future<void> updateCustomer(CustomerModel customer) async {
    state = const AsyncValue.loading();
    try {
      await _firestore.updateCustomer(customer);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final customerNotifierProvider =
    StateNotifierProvider<CustomerNotifier, AsyncValue<void>>(
  (ref) => CustomerNotifier(ref.watch(firestoreServiceProvider)),
);
