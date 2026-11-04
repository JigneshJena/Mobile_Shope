import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/inventory_model.dart';
import '../services/firestore_service.dart';
import 'customer_provider.dart'; // re-exports firestoreServiceProvider

// ---------------------------------------------------------------------------
// Stream of all inventory items
// ---------------------------------------------------------------------------

final inventoryStreamProvider =
    StreamProvider<List<InventoryModel>>((ref) {
  return ref.watch(firestoreServiceProvider).streamInventory();
});

// ---------------------------------------------------------------------------
// Category filter state (null = all categories)
// ---------------------------------------------------------------------------

final inventoryCategoryFilterProvider = StateProvider<String?>((ref) => null);

// ---------------------------------------------------------------------------
// Filtered inventory (derived)
// ---------------------------------------------------------------------------

final filteredInventoryProvider =
    Provider<AsyncValue<List<InventoryModel>>>((ref) {
  final allItems = ref.watch(inventoryStreamProvider);
  final cat = ref.watch(inventoryCategoryFilterProvider);

  return allItems.whenData((items) {
    if (cat == null) return items;
    return items.where((i) => i.category == cat).toList();
  });
});

// ---------------------------------------------------------------------------
// InventoryNotifier - add item and mark as returned
// ---------------------------------------------------------------------------

class InventoryNotifier extends StateNotifier<AsyncValue<void>> {
  InventoryNotifier(this._firestore) : super(const AsyncValue.data(null));

  final FirestoreService _firestore;

  /// Adds a new inventory [item] to Firestore.
  Future<void> addItem(InventoryModel item) async {
    state = const AsyncValue.loading();
    try {
      await _firestore.addInventory(item);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Marks the inventory item with [itemId] as returned to the supplier.
  Future<void> markReturned(String itemId) async {
    state = const AsyncValue.loading();
    try {
      await _firestore.markItemReturned(itemId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Deducts quantity from an inventory stock item when used in a repair.
  Future<void> decrementStock(String itemId, {int amount = 1}) async {
    try {
      await _firestore.decrementInventoryStock(itemId, amount: amount);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Restores quantity to an inventory stock item if repair is reopened.
  Future<void> incrementStock(String itemId, {int amount = 1}) async {
    try {
      await _firestore.incrementInventoryStock(itemId, amount: amount);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final inventoryNotifierProvider =
    StateNotifierProvider<InventoryNotifier, AsyncValue<void>>(
  (ref) => InventoryNotifier(ref.watch(firestoreServiceProvider)),
);
