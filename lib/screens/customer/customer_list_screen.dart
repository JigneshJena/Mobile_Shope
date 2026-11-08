import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/customer_model.dart';
import '../../providers/customer_provider.dart';
import '../../services/pdf_bill_service.dart';
import '../../widgets/common/app_progress_bar.dart';
import '../../widgets/common/glass_card.dart';
import '../../widgets/customer_grid_card.dart';
import 'add_customer_screen.dart';
import 'customer_detail_screen.dart';

class CustomerListScreen extends ConsumerStatefulWidget {
  const CustomerListScreen({super.key});

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  final _searchController = TextEditingController();
  bool _isSelectionMode = false;
  final Set<String> _selectedCustomerIds = {};
  bool _isGeneratingPdf = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openAddCustomer() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, anim, secAnim) => const AddCustomerScreen(),
        transitionsBuilder: (context, anim, secAnim, child) {
          return FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.05),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  Future<void> _generateBillsForSelected(List<CustomerModel> allCustomers) async {
    final selectedList =
        allCustomers.where((c) => _selectedCustomerIds.contains(c.id)).toList();

    if (selectedList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least 1 customer to generate bill(s)')),
      );
      return;
    }

    setState(() {
      _isGeneratingPdf = true;
    });

    try {
      if (selectedList.length == 1) {
        await PdfBillService.instance.generateAndShareBill(selectedList.first);
      } else {
        await PdfBillService.instance.generateAndShareMultipleBills(selectedList);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Generated bill(s) for ${selectedList.length} customer${selectedList.length > 1 ? 's' : ''}'),
            backgroundColor: AppColors.creditGreen,
          ),
        );
        setState(() {
          _isSelectionMode = false;
          _selectedCustomerIds.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF bills: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingPdf = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredCustomersAsync = ref.watch(filteredCustomersProvider);
    final currentFilter = ref.watch(customerStatusFilterProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Cancel Selection',
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedCustomerIds.clear();
                  });
                },
              )
            : null,
        title: Text(
          _isSelectionMode
              ? '${_selectedCustomerIds.length} Selected'
              : 'Customers & Repairs',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (!_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.checklist_rounded),
              tooltip: 'Select Bills to Print / Export',
              onPressed: () {
                setState(() {
                  _isSelectionMode = true;
                });
              },
            ),
          if (_isSelectionMode) ...[
            filteredCustomersAsync.maybeWhen(
              data: (customers) => IconButton(
                icon: Icon(
                  customers.isNotEmpty && _selectedCustomerIds.length == customers.length
                      ? Icons.deselect_rounded
                      : Icons.select_all_rounded,
                ),
                tooltip: customers.isNotEmpty && _selectedCustomerIds.length == customers.length
                    ? 'Deselect All'
                    : 'Select All',
                onPressed: () {
                  setState(() {
                    if (_selectedCustomerIds.length == customers.length) {
                      _selectedCustomerIds.clear();
                    } else {
                      _selectedCustomerIds.addAll(customers.map((c) => c.id));
                    }
                  });
                },
              ),
              orElse: () => const SizedBox.shrink(),
            ),
            filteredCustomersAsync.maybeWhen(
              data: (customers) => IconButton(
                icon: const Icon(Icons.picture_as_pdf_rounded),
                tooltip: 'Generate PDF Bills',
                onPressed: _isGeneratingPdf
                    ? null
                    : () => _generateBillsForSelected(customers),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // 1. Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, phone or model...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(customerSearchQueryProvider.notifier).state = '';
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
              ),
              onChanged: (val) {
                ref.read(customerSearchQueryProvider.notifier).state = val;
                setState(() {});
              },
            ),
          ),

          // 2. Status Filter Dropdown
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _StatusDropdown(
              currentFilter: currentFilter,
              onChanged: (val) =>
                  ref.read(customerStatusFilterProvider.notifier).state = val,
              theme: theme,
              isDark: isDark,
            ),
          ),

          // 3. Customer Grid View
          Expanded(
            child: filteredCustomersAsync.when(
              data: (customers) {
                if (customers.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_search_outlined,
                            size: 64,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No customer records found',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tap the button at the bottom to add a customer.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(customersStreamProvider);
                  },
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;

                      return GridView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 110), // Bottom padding for FAB space
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent: 220,
                        ),
                        itemCount: customers.length,
                        itemBuilder: (context, index) {
                          final customer = customers[index];
                          final isSelected = _selectedCustomerIds.contains(customer.id);
                          return AnimatedEntrance(
                            delay: Duration(milliseconds: (index % 8) * 35),
                            child: CustomerGridCard(
                              customer: customer,
                              isSelectionMode: _isSelectionMode,
                              isSelected: isSelected,
                              onLongPress: () {
                                if (!_isSelectionMode) {
                                  setState(() {
                                    _isSelectionMode = true;
                                    _selectedCustomerIds.add(customer.id);
                                  });
                                }
                              },
                              onTap: () {
                                if (_isSelectionMode) {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedCustomerIds.remove(customer.id);
                                      if (_selectedCustomerIds.isEmpty) {
                                        _isSelectionMode = false;
                                      }
                                    } else {
                                      _selectedCustomerIds.add(customer.id);
                                    }
                                  });
                                } else {
                                  Navigator.of(context).push(
                                    PageRouteBuilder(
                                      pageBuilder: (context, anim, secAnim) =>
                                          CustomerDetailScreen(customer: customer),
                                      transitionsBuilder: (context, anim, secAnim, child) {
                                        return FadeTransition(
                                          opacity: anim,
                                          child: SlideTransition(
                                            position: Tween<Offset>(
                                              begin: const Offset(0.04, 0),
                                              end: Offset.zero,
                                            ).animate(anim),
                                            child: child,
                                          ),
                                        );
                                      },
                                      transitionDuration:
                                          const Duration(milliseconds: 250),
                                    ),
                                  );
                                }
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: AppProgressBar(),
                ),
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text('Error loading customer list: $err'),
                ),
              ),
            ),
          ),
        ],
      ),
      // Sleek FAB: In selection mode, allows 1-click batch PDF generation; otherwise adds customer
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 95, right: 6),
        child: _isSelectionMode
            ? FloatingActionButton.extended(
                heroTag: 'customer_selection_pdf_fab',
                onPressed: _isGeneratingPdf
                    ? null
                    : () {
                        filteredCustomersAsync.whenData((customers) {
                          _generateBillsForSelected(customers);
                        });
                      },
                elevation: 4,
                backgroundColor: AppColors.secondary,
                foregroundColor: AppColors.onSecondary,
                icon: _isGeneratingPdf
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.picture_as_pdf_rounded, size: 22),
                label: Text(
                  _selectedCustomerIds.isEmpty
                      ? 'Select Bills'
                      : 'Print / Share Bills (${_selectedCustomerIds.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              )
            : FloatingActionButton(
                heroTag: 'customer_add_bottom_fab',
                onPressed: _openAddCustomer,
                elevation: 4,
                backgroundColor: AppColors.secondary,
                foregroundColor: AppColors.onSecondary,
                tooltip: 'Add Customer',
                child: const Icon(Icons.person_add_rounded, size: 24),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status filter dropdown widget
// ─────────────────────────────────────────────────────────────────────────────
class _StatusDropdown extends StatelessWidget {
  const _StatusDropdown({
    required this.currentFilter,
    required this.onChanged,
    required this.theme,
    required this.isDark,
  });

  final String? currentFilter;
  final ValueChanged<String?> onChanged;
  final ThemeData theme;
  final bool isDark;

  static const _statusColors = {
    RepairStatus.pending: AppColors.statusPending,
    RepairStatus.inProgress: AppColors.statusInProgress,
    RepairStatus.repaired: AppColors.statusRepaired,
    RepairStatus.delivered: AppColors.creditGreen,
  };

  String _label(String? s) =>
      s == null ? 'All Status' : RepairStatus.label(s);

  Color _dotColor(String? s) =>
      s == null ? AppColors.primary : (_statusColors[s] ?? AppColors.primary);

  @override
  Widget build(BuildContext context) {
    final dotColor = _dotColor(currentFilter);
    final fillColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45);

    return GestureDetector(
      onTap: () async {
        final box = context.findRenderObject() as RenderBox;
        final offset = box.localToGlobal(Offset.zero);
        final size = box.size;
        final allOptions = <String?>[null, ...RepairStatus.all];

        final chosen = await showMenu<String?>(
          context: context,
          position: RelativeRect.fromLTRB(
            offset.dx,
            offset.dy + size.height + 4,
            offset.dx + size.width,
            offset.dy + size.height + 4 + 48.0 * allOptions.length,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 4,
          items: allOptions.map((opt) {
            final c = _dotColor(opt);
            final isSelected = currentFilter == opt;
            return PopupMenuItem<String?>(
              value: opt,
              height: 44,
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _label(opt),
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 13,
                      color: isSelected ? c : theme.colorScheme.onSurface,
                    ),
                  ),
                  if (isSelected) ...[
                    const Spacer(),
                    Icon(Icons.check_rounded, size: 16, color: c),
                  ],
                ],
              ),
            );
          }).toList(),
        );

        if (chosen != currentFilter) {
          onChanged(chosen);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                  color: dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              _label(currentFilter),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 20, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
