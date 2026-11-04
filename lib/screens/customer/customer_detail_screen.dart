import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/customer_model.dart';
import '../../models/inventory_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../services/cloudinary_service.dart';
import '../../services/encryption_service.dart';
import '../../services/pdf_bill_service.dart';
import '../../widgets/common/app_progress_bar.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/glass_card.dart';
import '../../widgets/common/loading_overlay.dart';
import '../../widgets/status_badge.dart';

class CustomerDetailScreen extends ConsumerStatefulWidget {
  const CustomerDetailScreen({super.key, required this.customer});

  final CustomerModel customer;

  @override
  ConsumerState<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen> {
  late CustomerModel _customer;
  bool _isUploadingPhotos = false;

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
  }

  Future<Map<String, dynamic>?> _showDeliveryConfirmationDialog() async {
    final picker = ImagePicker();
    final List<File> deliveryFiles = [];
    final costController = TextEditingController(
      text: _customer.totalPrice != null ? _customer.totalPrice!.toStringAsFixed(0) : '',
    );
    final paidNowController = TextEditingController(
      text: _customer.remainingBalance > 0 ? _customer.remainingBalance.toStringAsFixed(0) : '0',
    );
    final unrepairedController = TextEditingController(
      text: _customer.unrepairedIssues ?? '',
    );

    final allInventory = ref.read(inventoryStreamProvider).value ?? [];
    final activeStock = allInventory
        .where((i) => !i.isReturned && (i.quantity > 0 || i.id == _customer.usedPartId))
        .toList();

    String? selectedPartId = _customer.usedPartId;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final double total = double.tryParse(costController.text.trim()) ?? (_customer.totalPrice ?? 0.0);
            final double advance = _customer.advanceAmount;
            final double paidNow = double.tryParse(paidNowController.text.trim()) ?? 0.0;
            final double remainingDue = (total - advance - paidNow).clamp(0.0, double.infinity);

            return AlertDialog(
              title: const Text('Deliver Device & Final Payment'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTextField(
                      label: 'Total Repair Price (₹)',
                      controller: costController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Advance Already Paid: ${Formatters.currency(advance)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.creditGreen, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    AppTextField(
                      label: 'Amount Paid Now at Delivery (₹)',
                      controller: paidNowController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: remainingDue == 0
                            ? AppColors.creditGreen.withValues(alpha: 0.12)
                            : AppColors.debitRed.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            remainingDue == 0 ? 'Payment Status:' : 'Balance Due:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: remainingDue == 0 ? AppColors.creditGreen : AppColors.debitRed,
                            ),
                          ),
                          Text(
                            remainingDue == 0 ? 'FULL PAID' : Formatters.currency(remainingDue),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: remainingDue == 0 ? AppColors.creditGreen : AppColors.debitRed,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Inventory Part Selection (Stock deduction linking)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 16, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 6),
                              const Text(
                                'Spare Part Used (From Stock):',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String?>(
                            isExpanded: true,
                            initialValue: selectedPartId,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            hint: const Text('None / No part used from stock', style: TextStyle(fontSize: 12)),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('None (No part deducted)', style: TextStyle(fontSize: 12)),
                              ),
                              ...activeStock.map((part) {
                                return DropdownMenuItem<String?>(
                                  value: part.id,
                                  child: Text(
                                    '${part.itemName} (Stock: ${part.quantity})',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }),
                            ],
                            onChanged: (val) {
                              setDialogState(() {
                                selectedPartId = val;
                              });
                            },
                          ),
                          if (selectedPartId != null) ...[
                            const SizedBox(height: 4),
                            const Text(
                              '✓ 1 unit will be deducted from inventory upon delivery',
                              style: TextStyle(fontSize: 10, color: AppColors.creditGreen, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    AppTextField(
                      label: 'Unrepaired / Known Defects (Notes for future visits)',
                      hint: 'e.g. Display replaced; customer declined battery repair',
                      controller: unrepairedController,
                    ),
                    const SizedBox(height: 14),
                    const Text('Delivery Documentation Photos:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
                              if (picked != null) {
                                setDialogState(() => deliveryFiles.add(File(picked.path)));
                              }
                            },
                            icon: const Icon(Icons.camera_alt, size: 16),
                            label: const Text('Camera', style: TextStyle(fontSize: 11)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                              if (picked != null) {
                                setDialogState(() => deliveryFiles.add(File(picked.path)));
                              }
                            },
                            icon: const Icon(Icons.photo_library, size: 16),
                            label: const Text('Gallery', style: TextStyle(fontSize: 11)),
                          ),
                        ),
                      ],
                    ),
                    if (deliveryFiles.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('${deliveryFiles.length} photo(s) selected', style: const TextStyle(fontSize: 11, color: AppColors.creditGreen, fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final finalTotal = double.tryParse(costController.text.trim()) ?? total;
                    final paidNowVal = double.tryParse(paidNowController.text.trim()) ?? 0.0;
                    String? partName;
                    if (selectedPartId != null) {
                      final match = activeStock.firstWhere(
                        (i) => i.id == selectedPartId,
                        orElse: () => InventoryModel(
                          id: '',
                          itemName: _customer.usedPartName ?? 'Spare Part',
                          category: '',
                          quantity: 0,
                          purchasePrice: 0,
                          dateAdded: DateTime.now(),
                        ),
                      );
                      partName = match.itemName;
                    }

                    Navigator.of(ctx).pop({
                      'totalPrice': finalTotal,
                      'newAdvance': advance + paidNowVal,
                      'unrepairedIssues': unrepairedController.text.trim(),
                      'photos': deliveryFiles,
                      'usedPartId': selectedPartId,
                      'usedPartName': partName,
                    });
                  },
                  child: const Text('Confirm Delivery'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _updateStatus(String newStatus) async {
    final isDelivering = newStatus == RepairStatus.delivered;
    final deliveredDate = isDelivering ? DateTime.now() : null;
    List<String> updatedImageUrls = List.from(_customer.imageUrls);
    double? newTotalPrice = _customer.totalPrice;
    double newAdvance = _customer.advanceAmount;
    String? newUnrepaired = _customer.unrepairedIssues;
    String? selectedPartId = _customer.usedPartId;
    String? selectedPartName = _customer.usedPartName;

    if (isDelivering) {
      final deliveryResult = await _showDeliveryConfirmationDialog();
      if (deliveryResult == null) return; // User cancelled dialog

      newTotalPrice = deliveryResult['totalPrice'] as double?;
      newAdvance = deliveryResult['newAdvance'] as double;
      final unrepairedText = deliveryResult['unrepairedIssues'] as String?;
      if (unrepairedText != null && unrepairedText.isNotEmpty) {
        newUnrepaired = unrepairedText;
      }

      selectedPartId = deliveryResult['usedPartId'] as String?;
      selectedPartName = deliveryResult['usedPartName'] as String?;

      final photosCaptured = deliveryResult['photos'] as List<File>;
      if (photosCaptured.isNotEmpty) {
        setState(() => _isUploadingPhotos = true);
        try {
          final cloudinary = CloudinaryService();
          final uploadedUrls = await cloudinary.uploadImages(photosCaptured);
          if (uploadedUrls.isNotEmpty) {
            updatedImageUrls.addAll(uploadedUrls);
          } else {
            updatedImageUrls.addAll(photosCaptured.map((f) => f.path));
          }
        } catch (_) {
          updatedImageUrls.addAll(photosCaptured.map((f) => f.path));
        } finally {
          if (mounted) setState(() => _isUploadingPhotos = false);
        }
      }
    }

    try {
      final updatedCustomer = _customer.copyWith(
        status: newStatus,
        dateDelivered: deliveredDate,
        clearDateDelivered: !isDelivering,
        totalPrice: newTotalPrice,
        advanceAmount: newAdvance,
        unrepairedIssues: newUnrepaired,
        imageUrls: updatedImageUrls,
        usedPartId: selectedPartId,
        usedPartName: selectedPartName,
      );

      // FIX: Call updateCustomer instead of addCustomer to prevent creating duplicates!
      await ref.read(customerNotifierProvider.notifier).updateCustomer(updatedCustomer);

      // Stock deduction linking: When delivered, deduct 1 unit of the used part from stock
      if (isDelivering && selectedPartId != null && selectedPartId.isNotEmpty) {
        await ref.read(inventoryNotifierProvider.notifier).decrementStock(selectedPartId, amount: 1);
      }

      setState(() {
        _customer = updatedCustomer;
      });

      if (mounted) {
        final partMsg = (isDelivering && selectedPartName != null && selectedPartName.isNotEmpty)
            ? '\nStock deducted for: $selectedPartName'
            : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated: ${RepairStatus.label(newStatus)}$partMsg'),
            backgroundColor: AppColors.creditGreen,
          ),
        );

        // Automatic PDF generation disabled as requested by user.
        // User can tap "Generate Bill" whenever they wish.
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  Future<void> _reopenOrder() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reopen Order?'),
        content: const Text('Are you sure you want to reopen this delivered order? This will unlock payment recording and status changes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reopen Order'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // If a part was used, restore 1 unit to stock when reopened
      if (_customer.usedPartId != null && _customer.usedPartId!.isNotEmpty) {
        await ref.read(inventoryNotifierProvider.notifier).incrementStock(_customer.usedPartId!, amount: 1);
      }
      await _updateStatus(RepairStatus.inProgress);
    }
  }

  Future<void> _showUpdatePriceDialog() async {
    final controller = TextEditingController(
      text: _customer.totalPrice != null ? _customer.totalPrice!.toStringAsFixed(0) : '',
    );

    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Total Cost'),
        content: AppTextField(
          label: 'Total Cost Amount (₹)',
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text.trim());
              Navigator.of(ctx).pop(val);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        await ref.read(customerNotifierProvider.notifier).updatePayment(
              _customer.id,
              totalPrice: result,
            );
        setState(() {
          _customer = _customer.copyWith(totalPrice: result);
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update price: $e')),
          );
        }
      }
    }
  }

  Future<void> _showAddPaymentDialog() async {
    final controller = TextEditingController();

    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Payment'),
        content: AppTextField(
          label: 'Payment Amount (₹)',
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text.trim());
              Navigator.of(ctx).pop(val);
            },
            child: const Text('Add Payment'),
          ),
        ],
      ),
    );

    if (result != null && result > 0) {
      final newAdvance = _customer.advanceAmount + result;
      try {
        await ref.read(customerNotifierProvider.notifier).updatePayment(
              _customer.id,
              advanceAmount: newAdvance,
            );
        setState(() {
          _customer = _customer.copyWith(advanceAmount: newAdvance);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Recorded payment of ₹${result.toStringAsFixed(0)}'),
              backgroundColor: AppColors.creditGreen,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to record payment: $e')),
          );
        }
      }
    }
  }

  void _generatePdfBill() {
    PdfBillService.instance.generateAndShareBill(_customer);
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersStreamProvider);
    customersAsync.whenData((list) {
      final match = list.where((c) => c.id == _customer.id);
      if (match.isNotEmpty && match.first != _customer) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _customer = match.first);
        });
      }
    });

    final isOwner = ref.watch(isOwnerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDelivered = _customer.status == RepairStatus.delivered;

    return Scaffold(
      appBar: AppBar(
        title: Text(_customer.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'Print / Share Bill (PDF)',
            onPressed: _generatePdfBill,
          ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: _isUploadingPhotos,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─────────────────────────────────────────────────────────────
            // TASK 9: DELIVERED LOCKED BANNER & REOPEN ACTION
            // ─────────────────────────────────────────────────────────────
            if (isDelivered) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.statusDelivered.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.statusDelivered.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_rounded, size: 20, color: AppColors.statusDelivered),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Order Delivered & Finalized',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.statusDelivered,
                            ),
                          ),
                          Text(
                            'Payments and status changes are locked.',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isOwner)
                      TextButton.icon(
                        onPressed: _reopenOrder,
                        icon: const Icon(Icons.lock_open_rounded, size: 14),
                        label: const Text(
                          'Reopen Order',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // ─────────────────────────────────────────────────────────────
            // 1. PAYMENT SUMMARY AT TOP
            // ─────────────────────────────────────────────────────────────
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Payment Summary',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isOwner && !isDelivered)
                        TextButton.icon(
                          onPressed: _showUpdatePriceDialog,
                          icon: const Icon(Icons.edit, size: 14),
                          label: const Text('Update Cost', style: TextStyle(fontSize: 12)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _PaymentColumn(
                          label: 'Total Cost',
                          value: _customer.totalPrice != null
                              ? Formatters.currency(_customer.totalPrice)
                              : 'Pending',
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Expanded(
                        child: _PaymentColumn(
                          label: 'Advance Paid',
                          value: Formatters.currency(_customer.advanceAmount),
                          color: AppColors.statusInProgress,
                        ),
                      ),
                      Expanded(
                        child: _PaymentColumn(
                          label: 'Balance Due',
                          value: Formatters.currency(_customer.remainingBalance),
                          color: _customer.remainingBalance > 0
                              ? AppColors.debitRed
                              : AppColors.creditGreen,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Task 9: Hide/Disable Add Payment when Delivered
                      if (!isDelivered)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _showAddPaymentDialog,
                            icon: const Icon(Icons.add_card_rounded, size: 16),
                            label: const Text('Add Payment', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      if (!isDelivered) const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _generatePdfBill,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.onPrimary,
                          ),
                          icon: const Icon(Icons.receipt_long_rounded, size: 16),
                          label: const Text('Generate Bill', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ─────────────────────────────────────────────────────────────
            // 2. REPAIR STATUS CONTROL (Task 9: Lock when Delivered)
            // ─────────────────────────────────────────────────────────────
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    isDelivered ? Icons.lock_outline_rounded : Icons.build_circle_outlined,
                    color: isDelivered ? AppColors.statusDelivered : theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Status:',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : AppColors.scaffoldBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: theme.colorScheme.outlineVariant),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _customer.status,
                          isExpanded: true,
                          icon: Icon(
                            isDelivered ? Icons.lock_rounded : Icons.arrow_drop_down_rounded,
                            size: isDelivered ? 16 : 24,
                          ),
                          onChanged: isDelivered
                              ? null // Task 9: Disable dropdown when delivered
                              : (val) {
                                  if (val != null && val != _customer.status) {
                                    _updateStatus(val);
                                  }
                                },
                          items: RepairStatus.all.map((status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Row(
                                children: [
                                  StatusBadge(status: status),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ─────────────────────────────────────────────────────────────
            // 3. PHOTOS GALLERY CAROUSEL
            // ─────────────────────────────────────────────────────────────
            if (_customer.imageUrls.isNotEmpty) ...[
              SizedBox(
                height: 150,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _customer.imageUrls.length,
                  itemBuilder: (context, index) {
                    final url = _customer.imageUrls[index];
                    return GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => Dialog(
                            backgroundColor: Colors.transparent,
                            insetPadding: const EdgeInsets.all(12),
                            child: InteractiveViewer(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: CachedNetworkImage(
                                  imageUrl: url,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: 130,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            placeholder: (c, url) => const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: AppProgressBar(),
                              ),
                            ),
                            errorWidget: (c, url, err) => const Center(
                              child: Icon(Icons.broken_image, size: 36),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
            ],

            // ─────────────────────────────────────────────────────────────
            // 4. CUSTOMER & DEVICE DETAILS CARD
            // ─────────────────────────────────────────────────────────────
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customer & Device Details',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _InfoRow(
                    icon: Icons.person_outline,
                    label: 'Customer Name',
                    value: _customer.name,
                  ),
                  _InfoRow(
                    icon: Icons.phone_outlined,
                    label: 'Phone Number',
                    value: _customer.phone.isEmpty || _customer.phone.toLowerCase() == 'add later'
                        ? 'Add Later / Not Provided'
                        : _customer.phone,
                    valueColor: _customer.phone.isEmpty || _customer.phone.toLowerCase() == 'add later'
                        ? AppColors.secondary
                        : null,
                  ),
                  if (_customer.address.isNotEmpty)
                    _InfoRow(
                      icon: Icons.location_on_outlined,
                      label: 'Address',
                      value: _customer.address,
                    ),
                  _InfoRow(
                    icon: Icons.smartphone_outlined,
                    label: 'Device Model',
                    value: _customer.mobileModel,
                  ),
                  _InfoRow(
                    icon: Icons.build_circle_outlined,
                    label: 'Fault Description',
                    value: _customer.issueDescription,
                  ),
                  if (_customer.usedPartName != null && _customer.usedPartName!.isNotEmpty)
                    _InfoRow(
                      icon: Icons.inventory_2_outlined,
                      label: 'Spare Part Used from Stock',
                      value: _customer.usedPartName!,
                      valueColor: AppColors.primary,
                    ),
                  if (_customer.unrepairedIssues != null && _customer.unrepairedIssues!.isNotEmpty)
                    _InfoRow(
                      icon: Icons.warning_amber_rounded,
                      label: 'Unrepaired / Device Notes',
                      value: _customer.unrepairedIssues!,
                      valueColor: AppColors.secondary,
                    ),
                  _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Date Received',
                    value: Formatters.dateTime(_customer.dateReceived),
                  ),
                  _InfoRow(
                    icon: Icons.access_time_rounded,
                    label: 'Added On',
                    value: Formatters.createdAtFull(_customer.createdAt),
                  ),
                  if (_customer.dateDelivered != null)
                    _InfoRow(
                      icon: Icons.task_alt_outlined,
                      label: 'Date Delivered',
                      value: Formatters.dateTime(_customer.dateDelivered!),
                    ),
                  _InfoRow(
                    icon: _customer.hasOnlineLock
                        ? Icons.lock_rounded
                        : Icons.lock_open_rounded,
                    label: 'Online Lock',
                    value: _customer.hasOnlineLock ? '🔒 Yes — Device is online locked' : 'No',
                    valueColor: _customer.hasOnlineLock ? AppColors.debitRed : null,
                  ),
                  if (_customer.imeiEncrypted != null &&
                      _customer.imeiEncrypted!.isNotEmpty)
                    _ImeiRow(encryptedImei: _customer.imeiEncrypted!),
                ],
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Displays a decrypted IMEI with a tap-to-reveal mechanic for visual privacy.
class _ImeiRow extends StatefulWidget {
  const _ImeiRow({required this.encryptedImei});
  final String encryptedImei;

  @override
  State<_ImeiRow> createState() => _ImeiRowState();
}

class _ImeiRowState extends State<_ImeiRow> {
  bool _revealed = false;
  String? _decrypted;
  bool _decryptError = false;

  void _toggle() {
    if (_revealed) {
      setState(() => _revealed = false);
      return;
    }
    try {
      _decrypted = EncryptionService.instance.decrypt(widget.encryptedImei);
      setState(() {
        _revealed = true;
        _decryptError = false;
      });
    } catch (_) {
      setState(() => _decryptError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.sim_card_outlined, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'IMEI Number',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (_decryptError)
                  Text('⚠ Could not decrypt IMEI',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.debitRed,
                      ))
                else if (_revealed && _decrypted != null)
                  Text(
                    _decrypted!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  )
                else
                  Text(
                    '•••• •••• •••• •••',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.subtleText,
                      letterSpacing: 2,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _toggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _revealed ? 'Hide' : 'Show',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentColumn extends StatelessWidget {
  const _PaymentColumn({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
