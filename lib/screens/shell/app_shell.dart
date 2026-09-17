import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/floating_nav_bar.dart';
import '../customer/customer_list_screen.dart';
import '../daily_hisaab/daily_hisaab_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../inventory/inventory_list_screen.dart';
import '../settings/settings_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isOwner = ref.watch(isOwnerProvider);

    final items = <FloatingNavItem>[
      const FloatingNavItem(
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard_rounded,
        label: 'Dashboard',
      ),
      const FloatingNavItem(
        icon: Icons.people_outline_rounded,
        selectedIcon: Icons.people_rounded,
        label: 'Customers',
      ),
      const FloatingNavItem(
        icon: Icons.inventory_2_outlined,
        selectedIcon: Icons.inventory_2_rounded,
        label: 'Inventory',
      ),
      if (isOwner)
        const FloatingNavItem(
          icon: Icons.account_balance_wallet_outlined,
          selectedIcon: Icons.account_balance_wallet_rounded,
          label: 'Ledger',
        ),
      const FloatingNavItem(
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings_rounded,
        label: 'Settings',
      ),
    ];

    final screens = <Widget>[
      const DashboardScreen(),
      const CustomerListScreen(),
      const InventoryListScreen(),
      if (isOwner) const DailyHisaabScreen(),
      const SettingsScreen(),
    ];

    final activeIndex = _selectedIndex >= screens.length ? 0 : _selectedIndex;

    return Scaffold(
      extendBody: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.02, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey<int>(activeIndex),
          child: IndexedStack(
            index: activeIndex,
            children: screens,
          ),
        ),
      ),
      bottomNavigationBar: FloatingNavigationBar(
        selectedIndex: activeIndex,
        items: items,
        onTap: (idx) {
          setState(() {
            _selectedIndex = idx;
          });
        },
      ),
    );
  }
}
