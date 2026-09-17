import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/customer_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/customer_provider.dart';
import '../../services/cloudinary_service.dart';
import '../../services/encryption_service.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/glass_card.dart';
import '../../widgets/common/loading_overlay.dart';

class AddCustomerScreen extends ConsumerStatefulWidget {
  const AddCustomerScreen({super.key});

  @override
  ConsumerState<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends ConsumerState<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _modelController = TextEditingController();
  final _issueController = TextEditingController();
  final _imeiController = TextEditingController();
  final _totalPriceController = TextEditingController();
  final _advanceController = TextEditingController();
  final _unrepairedController = TextEditingController();

  final List<File> _pickedImages = [];
  final _picker = ImagePicker();
  bool _isUploading = false;
  String _uploadStatus = '';
  bool _hasOnlineLock = false;

  CustomerModel? _matchedPastCustomer;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);
  }

  @override
  void dispose() {
    _phoneController.removeListener(_onPhoneChanged);
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _modelController.dispose();
    _issueController.dispose();
    _imeiController.dispose();
    _totalPriceController.dispose();
    _advanceController.dispose();
    _unrepairedController.dispose();
    super.dispose();
  }

  void _onPhoneChanged() {
    final phone = _phoneController.text.trim();
    if (phone.length >= 10) {
      final allCustomers = ref.read(customersStreamProvider).value ?? [];
      final match = allCustomers.firstWhere(
        (c) => c.phone == phone && c.unrepairedIssues != null && c.unrepairedIssues!.isNotEmpty,
        orElse: () => CustomerModel(
          id: 'none', name: '', phone: '', address: '', mobileModel: '',
          issueDescription: '', imageUrls: [], advanceAmount: 0, status: '',
          dateReceived: DateTime.now(), handledBy: '', createdAt: DateTime.now(),
        ),
      );
      setState(() {
        _matchedPastCustomer = match.id != 'none' ? match : null;
      });
    } else {
      if (_matchedPastCustomer != null) {
        setState(() => _matchedPastCustomer = null);
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_pickedImages.length >= AppConstants.maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 3 photos allowed')),
      );
      return;
    }

    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1200,
      );
      if (picked != null) {
        setState(() {
          _pickedImages.add(File(picked.path));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick photo: $e')),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _pickedImages.removeAt(index);
    });
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isUploading) return; // Prevent double click duplicate submission

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final model = _modelController.text.trim();
    final allCustomers = ref.read(customersStreamProvider).value ?? [];

    // Block 100% exact duplicates: same name + phone + model (case-insensitive)
    final exactDuplicate = allCustomers.any(
      (c) =>
          c.name.toLowerCase() == name.toLowerCase() &&
          c.phone == phone &&
          c.mobileModel.toLowerCase() == model.toLowerCase(),
    );

    if (exactDuplicate) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Duplicate Entry Detected'),
          content: Text(
            'A record already exists for:\n\nName: $name\nPhone: $phone\nModel: $model\n\nThis is a 100% identical entry. Please change at least one field (e.g., issue description or advance amount) if this is a new repair.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Warn about active repair (same phone + model, any name) — but allow continuation
    final activeDuplicate = allCustomers.firstWhere(
      (c) =>
          c.phone == phone &&
          c.mobileModel.toLowerCase() == model.toLowerCase() &&
          c.status != RepairStatus.delivered,
      orElse: () => CustomerModel(
        id: 'none', name: '', phone: '', address: '', mobileModel: '',
        issueDescription: '', imageUrls: [], advanceAmount: 0, status: '',
        dateReceived: DateTime.now(), handledBy: '', createdAt: DateTime.now(),
      ),
    );

    if (activeDuplicate.id != 'none') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Active Repair Order Exists'),
          content: Text(
            'An active repair order already exists for $phone ($model).\n\nDo you want to create another new repair entry for this device?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Create New Order'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }


    setState(() {
      _isUploading = true;
      _uploadStatus = 'Uploading device photos...';
    });

    try {
      List<String> imageUrls = [];
      if (_pickedImages.isNotEmpty) {
        final cloudinary = CloudinaryService();
        imageUrls = await cloudinary.uploadImages(_pickedImages);
      }

      setState(() {
        _uploadStatus = 'Saving customer record...';
      });

      final user = ref.read(currentUserModelProvider).valueOrNull;
      final totalPriceText = _totalPriceController.text.trim();
      final double? totalPrice =
          totalPriceText.isNotEmpty ? double.tryParse(totalPriceText) : null;
      final advanceText = _advanceController.text.trim();
      final double advanceAmount =
          advanceText.isNotEmpty ? (double.tryParse(advanceText) ?? 0.0) : 0.0;

      final rawImei = _imeiController.text.trim();
      final String? imeiEncrypted = rawImei.isNotEmpty
          ? EncryptionService.instance.encrypt(rawImei)
          : null;

      final unrepairedText = _unrepairedController.text.trim();

      final customer = CustomerModel(
        id: '',
        name: name,
        phone: phone,
        address: _addressController.text.trim(),
        mobileModel: model,
        issueDescription: _issueController.text.trim(),
        imageUrls: imageUrls,
        totalPrice: totalPrice,
        advanceAmount: advanceAmount,
        status: RepairStatus.pending,
        dateReceived: DateTime.now(),
        handledBy: user?.uid ?? '',
        createdAt: DateTime.now(),
        imeiEncrypted: imeiEncrypted,
        hasOnlineLock: _hasOnlineLock,
        unrepairedIssues: unrepairedText.isNotEmpty ? unrepairedText : null,
      );

      await ref.read(customerNotifierProvider.notifier).addCustomer(customer);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Customer record added successfully!'),
            backgroundColor: AppColors.creditGreen,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save record: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadStatus = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Customer Record'),
      ),
      body: LoadingOverlay(
        isLoading: _isUploading,
        label: _uploadStatus,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Past History Warning Banner if found
                if (_matchedPastCustomer != null) ...[
                  GlassCard(
                    tintColor: AppColors.secondary,
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.history_edu_rounded, color: AppColors.secondary, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Past Visit Device Note Found:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppColors.secondary,
                                ),
                              ),
                              Text(
                                '${_matchedPastCustomer!.mobileModel}: ${_matchedPastCustomer!.unrepairedIssues}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Section 1: Customer Info
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person_outline, size: 20, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Customer Information',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        label: 'Customer Full Name *',
                        hint: 'e.g. Rahul Sharma',
                        controller: _nameController,
                        prefixIcon: const Icon(Icons.person_outline),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter customer name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        label: 'Mobile Number *',
                        hint: '10-digit phone number',
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        prefixIcon: const Icon(Icons.phone_outlined),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter phone number';
                          }
                          if (val.trim().length < 10) {
                            return 'Please enter a valid 10-digit number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        label: 'Address (Optional)',
                        hint: 'Customer address or locality',
                        controller: _addressController,
                        prefixIcon: const Icon(Icons.location_on_outlined),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Section 2: Device Info
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.smartphone_outlined, size: 20, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Device & Fault Details',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        label: 'Device Model *',
                        hint: 'e.g. Redmi Note 11, iPhone 13 Pro',
                        controller: _modelController,
                        prefixIcon: const Icon(Icons.phone_android_outlined),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter device model';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        label: 'Fault / Issue Description *',
                        hint: 'e.g. Cracked display, battery draining, charging port broken',
                        controller: _issueController,
                        maxLines: 3,
                        prefixIcon: const Icon(Icons.build_outlined),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter issue description';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        label: 'Unrepaired / Known Issues / Remarks (Optional)',
                        hint: 'e.g. Charging port broken but customer declined repair',
                        controller: _unrepairedController,
                        prefixIcon: const Icon(Icons.note_alt_outlined),
                      ),
                      const SizedBox(height: 12),

                      // Online Lock Toggle
                      Container(
                        decoration: BoxDecoration(
                          color: _hasOnlineLock
                              ? AppColors.error.withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _hasOnlineLock
                                ? AppColors.error.withValues(alpha: 0.4)
                                : theme.colorScheme.outline.withValues(alpha: 0.3),
                          ),
                        ),
                        child: SwitchListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          activeThumbColor: AppColors.error,
                          title: Text(
                            'Online / iCloud Lock Present',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _hasOnlineLock ? AppColors.error : null,
                            ),
                          ),
                          subtitle: const Text(
                            'Flag if device has FRP, iCloud or SIM network lock',
                            style: TextStyle(fontSize: 11),
                          ),
                          value: _hasOnlineLock,
                          onChanged: (val) => setState(() => _hasOnlineLock = val),
                        ),
                      ),
                      const SizedBox(height: 12),

                      AppTextField(
                        label: 'Device IMEI Number (Optional - Encrypted)',
                        hint: '15-digit IMEI for security & warranty verification',
                        controller: _imeiController,
                        keyboardType: TextInputType.number,
                        prefixIcon: const Icon(Icons.security_outlined),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Section 3: Costing & Advance
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.payments_outlined, size: 20, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Estimated Cost & Advance Payment',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        label: 'Estimated Total Cost (₹) (Optional)',
                        hint: 'Leave blank if cost to be confirmed later',
                        controller: _totalPriceController,
                        keyboardType: TextInputType.number,
                        prefixIcon: const Icon(Icons.currency_rupee_outlined),
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        label: 'Advance Paid Amount (₹)',
                        hint: '0 if no advance paid',
                        controller: _advanceController,
                        keyboardType: TextInputType.number,
                        prefixIcon: const Icon(Icons.money_outlined),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Section 4: Device Photos
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.photo_camera_outlined, size: 20, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Device Photos (${_pickedImages.length}/${AppConstants.maxImages})',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Capture physical condition (scratches, cracks) for dispute prevention.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_pickedImages.isNotEmpty)
                        SizedBox(
                          height: 100,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _pickedImages.length,
                            itemBuilder: (context, index) {
                              return Stack(
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(right: 10),
                                    width: 100,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      image: DecorationImage(
                                        image: FileImage(_pickedImages[index]),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 14,
                                    child: GestureDetector(
                                      onTap: () => _removeImage(index),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close_rounded,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      if (_pickedImages.length < AppConstants.maxImages) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickImage(ImageSource.camera),
                                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                                label: const Text('Take Photo'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickImage(ImageSource.gallery),
                                icon: const Icon(Icons.photo_library_outlined, size: 18),
                                label: const Text('From Gallery'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                AppButton(
                  label: 'Save Customer Record',
                  onPressed: _isUploading ? null : _saveCustomer,
                  isLoading: _isUploading,
                  icon: Icons.save_rounded,
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
