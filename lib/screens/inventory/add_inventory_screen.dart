import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/inventory_model.dart';
import '../../providers/inventory_provider.dart';
import '../../services/cloudinary_service.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/glass_card.dart';
import '../../widgets/common/loading_overlay.dart';

class AddInventoryScreen extends ConsumerStatefulWidget {
  const AddInventoryScreen({super.key});

  @override
  ConsumerState<AddInventoryScreen> createState() => _AddInventoryScreenState();
}

class _AddInventoryScreenState extends ConsumerState<AddInventoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _priceController = TextEditingController();
  final _supplierController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedCategory = InventoryCategory.screen;
  DateTime _dateAdded = DateTime.now();
  bool _isLoading = false;
  File? _pickedImage;
  final _picker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _supplierController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1000,
      );
      if (picked != null) {
        setState(() {
          _pickedImage = File(picked.path);
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

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateAdded,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dateAdded = picked;
      });
    }
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String? imageUrl;
      if (_pickedImage != null) {
        final cloudinary = CloudinaryService();
        final urls = await cloudinary.uploadImages([_pickedImage!]);
        if (urls.isNotEmpty) {
          imageUrl = urls.first;
        }
      }

      final item = InventoryModel(
        id: '',
        itemName: _nameController.text.trim(),
        category: _selectedCategory,
        quantity: int.parse(_quantityController.text.trim()),
        purchasePrice: double.parse(_priceController.text.trim()),
        supplierName: _supplierController.text.trim(),
        dateAdded: _dateAdded,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        imageUrl: imageUrl,
      );

      await ref.read(inventoryNotifierProvider.notifier).addItem(item);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inventory item added successfully!'),
            backgroundColor: AppColors.creditGreen,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add item: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Spare Part'),
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Spare Part Image Picker Box
              GlassCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Spare Part Photo (Optional)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            builder: (ctx) => SafeArea(
                              child: Wrap(
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.camera_alt),
                                    title: const Text('Take Photo'),
                                    onTap: () {
                                      Navigator.of(ctx).pop();
                                      _pickImage(ImageSource.camera);
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.photo_library),
                                    title: const Text('Choose from Gallery'),
                                    onTap: () {
                                      Navigator.of(ctx).pop();
                                      _pickImage(ImageSource.gallery);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        child: Container(
                          height: 130,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: _pickedImage != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(13),
                                  child: Image.file(_pickedImage!, fit: BoxFit.cover),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_a_photo_outlined,
                                      size: 36,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Tap to upload item photo',
                                      style: theme.textTheme.labelMedium?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 20, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Part Information',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Item Name
                    AppTextField(
                      label: 'Item Name *',
                      hint: 'e.g. iPhone 13 OLED Display (OEM)',
                      controller: _nameController,
                      prefixIcon: const Icon(Icons.inventory_2_outlined),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter item name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Category Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'Category *',
                        prefixIcon: const Icon(Icons.category_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF1E293B)
                            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      ),
                      items: InventoryCategory.all.map((cat) {
                        return DropdownMenuItem(
                          value: cat,
                          child: Text(InventoryCategory.label(cat)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedCategory = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Quantity and Purchase Price
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: 'Quantity (Units) *',
                            controller: _quantityController,
                            keyboardType: TextInputType.number,
                            prefixIcon: const Icon(Icons.numbers_outlined),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Enter quantity';
                              final n = int.tryParse(val.trim());
                              if (n == null || n <= 0) return 'Enter valid quantity';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            label: 'Unit Cost (₹) *',
                            hint: '₹ per unit',
                            controller: _priceController,
                            keyboardType: TextInputType.number,
                            prefixIcon: const Icon(Icons.currency_rupee),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Enter unit price';
                              final p = double.tryParse(val.trim());
                              if (p == null || p < 0) return 'Enter valid price';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Supplier Name
                    AppTextField(
                      label: 'Supplier / Vendor Name *',
                      hint: 'e.g. Apex Spare Parts Hub',
                      controller: _supplierController,
                      prefixIcon: const Icon(Icons.storefront_outlined),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter supplier name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Date Added Selector
                    InkWell(
                      onTap: _selectDate,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                          borderRadius: BorderRadius.circular(10),
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_outlined, color: theme.colorScheme.primary),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Date Received / Added',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  Formatters.date(_dateAdded),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Notes
                    AppTextField(
                      label: 'Notes / Specifications (Optional)',
                      hint: 'e.g. Compatible with A2403 models only',
                      controller: _notesController,
                      maxLines: 2,
                      prefixIcon: const Icon(Icons.note_alt_outlined),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              AppButton(
                label: 'Save Spare Part',
                icon: Icons.save_rounded,
                isLoading: _isLoading,
                onPressed: _saveItem,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    ),
    );
  }
}
