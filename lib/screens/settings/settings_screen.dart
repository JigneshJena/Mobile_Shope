import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/glass_card.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _empFormKey = GlobalKey<FormState>();
  final _empNameController = TextEditingController();
  final _empPhoneController = TextEditingController();
  final _empEmailController = TextEditingController();
  final _empPasswordController = TextEditingController();
  bool _isCreatingEmp = false;

  @override
  void dispose() {
    _empNameController.dispose();
    _empPhoneController.dispose();
    _empEmailController.dispose();
    _empPasswordController.dispose();
    super.dispose();
  }

  Future<void> _createEmployeeAccount() async {
    if (!_empFormKey.currentState!.validate()) return;

    setState(() => _isCreatingEmp = true);

    try {
      await ref.read(authNotifierProvider.notifier).createEmployee(
            name: _empNameController.text.trim(),
            phone: _empPhoneController.text.trim(),
            email: _empEmailController.text.trim(),
            password: _empPasswordController.text.trim(),
            role: UserRole.employee,
          );

      _empNameController.clear();
      _empPhoneController.clear();
      _empEmailController.clear();
      _empPasswordController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Staff account created successfully!'),
            backgroundColor: AppColors.creditGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AuthService.getReadableErrorMessage(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreatingEmp = false);
    }
  }

  Future<void> _confirmSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out?'),
        content: const Text('Are you sure you want to sign out from the app?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(authNotifierProvider.notifier).signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final userModelAsync = ref.watch(currentUserModelProvider);
    final userModel = userModelAsync.valueOrNull;
    final isOwner = ref.watch(isOwnerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. User Profile Card
            AnimatedEntrance(
              delay: const Duration(milliseconds: 50),
              child: GlassCard(
                padding: const EdgeInsets.all(18.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: isOwner
                          ? AppColors.secondary
                          : AppColors.primary,
                      child: Text(
                        (userModel?.name.isNotEmpty ?? false)
                            ? userModel!.name[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: AppColors.onSecondary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userModel?.name.isNotEmpty ?? false
                                ? userModel!.name
                                : 'User',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            userModel?.phone ?? '',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: isOwner
                                  ? AppColors.secondary.withValues(alpha: 0.15)
                                  : AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isOwner ? '👑 OWNER' : '👤 STAFF',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isOwner
                                    ? AppColors.secondary
                                    : AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. Appearance Card (Dark / Light theme)
            AnimatedEntrance(
              delay: const Duration(milliseconds: 100),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 10.0),
                child: Row(
                  children: [
                    Icon(
                      themeMode == ThemeMode.dark
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dark Mode',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            themeMode == ThemeMode.dark
                                ? 'Enabled'
                                : 'Disabled',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: themeMode == ThemeMode.dark,
                      onChanged: (val) {
                        ref.read(themeModeProvider.notifier).state =
                            val ? ThemeMode.dark : ThemeMode.light;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 3. Owner Only: Create Staff Account Section
            if (isOwner) ...[
              AnimatedEntrance(
                delay: const Duration(milliseconds: 150),
                child: GlassCard(
                  padding: const EdgeInsets.all(4.0),
                  child: Theme(
                    data: theme.copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      leading: const Icon(Icons.person_add_alt_1_outlined),
                      title: const Text(
                        'Create Staff Account',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                          'Register new login access for shop staff'),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Form(
                            key: _empFormKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Divider(),
                                const SizedBox(height: 8),
                                AppTextField(
                                  label: 'Staff Member Name *',
                                  hint: 'e.g. Ramesh Patel',
                                  controller: _empNameController,
                                  prefixIcon: const Icon(Icons.person_outline),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? 'Please enter name'
                                          : null,
                                ),
                                const SizedBox(height: 12),
                                AppTextField(
                                  label: 'Mobile Number *',
                                  hint: '10 digit number',
                                  controller: _empPhoneController,
                                  keyboardType: TextInputType.phone,
                                  prefixIcon: const Icon(Icons.phone_outlined),
                                  validator: (v) =>
                                      (v == null || v.trim().length < 10)
                                          ? 'Please enter valid phone number'
                                          : null,
                                ),
                                const SizedBox(height: 12),
                                AppTextField(
                                  label: 'Staff Login Email *',
                                  hint: 'ramesh@spmobile.com',
                                  controller: _empEmailController,
                                  keyboardType: TextInputType.emailAddress,
                                  prefixIcon: const Icon(Icons.email_outlined),
                                  validator: (v) =>
                                      (v == null || !v.contains('@'))
                                          ? 'Please enter valid email'
                                          : null,
                                ),
                                const SizedBox(height: 12),
                                AppTextField(
                                  label: 'Initial Password *',
                                  hint: 'Minimum 6 characters',
                                  controller: _empPasswordController,
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  validator: (v) =>
                                      (v == null || v.trim().length < 6)
                                          ? 'Password must be at least 6 characters'
                                          : null,
                                ),
                                const SizedBox(height: 16),
                                AppButton(
                                  label: 'Create Staff Account',
                                  icon: Icons.check,
                                  isLoading: _isCreatingEmp,
                                  onPressed: _createEmployeeAccount,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 4. Logout Card
            AnimatedEntrance(
              delay: const Duration(milliseconds: 200),
              child: GlassCard(
                onTap: _confirmSignOut,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 14.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.logout_rounded,
                          color: Colors.red, size: 22),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Sign Out',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            'Sign out of your session',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // App branding & version
            Center(
              child: Column(
                children: [
                  Text(
                    AppConstants.appName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Version 1.0.0 (Build 1)',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
