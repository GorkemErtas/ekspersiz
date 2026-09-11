import 'package:flutter/material.dart';

import '../../profile/screens/profile_screen.dart';
import '../../inspection/screens/inspection_history_screen.dart';
import '../../vehicle/screens/vehicle_list_screen.dart';
import 'home_screen.dart';
import 'dart:async';
import '../../../core/auth/session_manager.dart';
import '../../auth/screens/login_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.fullName,
    required this.email,
    required this.role,
    required this.subscriptionPlan,
  });

  final String fullName;
  final String email;
  final String role;
  final String subscriptionPlan;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const double _desktopBreakpoint = 900;

  StreamSubscription<void>? _sessionSubscription;

  int _selectedIndex = 0;

  void _selectTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  late final List<Widget> _screens = [
    HomeScreen(
      fullName: widget.fullName,
      onOpenVehicles: () => _selectTab(1),
      onOpenInspections: () => _selectTab(2),
    ),
    const VehicleListScreen(),
    const InspectionHistoryScreen(),
    ProfileScreen(
      fullName: widget.fullName,
      email: widget.email,
      role: widget.role,
      subscriptionPlan: widget.subscriptionPlan,
    ),
  ];

  @override
  void initState() {
    super.initState();

    _sessionSubscription =
        SessionManager.unauthorizedStream.listen(
              (_) {
            _handleSessionExpired();
          },
        );
  }

  void _handleSessionExpired() {
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const LoginScreen(),
      ),
          (route) => false,
    );
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop =
            constraints.maxWidth >= _desktopBreakpoint;

        if (isDesktop) {
          return Scaffold(
            body: Row(
              children: [
                SafeArea(
                  child: NavigationRail(
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: _selectTab,
                    labelType: NavigationRailLabelType.all,
                    leading: Padding(
                      padding: const EdgeInsets.only(
                        top: 12,
                        bottom: 24,
                      ),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary,
                          borderRadius:
                          BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.car_crash_rounded,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimary,
                        ),
                      ),
                    ),
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon:
                        Icon(Icons.home_rounded),
                        label: Text('Ana Sayfa'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(
                          Icons.directions_car_outlined,
                        ),
                        selectedIcon: Icon(
                          Icons.directions_car_rounded,
                        ),
                        label: Text('Araçlar'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(
                          Icons.description_outlined,
                        ),
                        selectedIcon: Icon(
                          Icons.description_rounded,
                        ),
                        label: Text('Analizler'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(
                          Icons.person_outline_rounded,
                        ),
                        selectedIcon:
                        Icon(Icons.person_rounded),
                        label: Text('Profil'),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                ),
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: _screens,
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          body: IndexedStack(
            index: _selectedIndex,
            children: _screens,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _selectTab,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon:
                Icon(Icons.home_rounded),
                label: 'Ana Sayfa',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.directions_car_outlined,
                ),
                selectedIcon: Icon(
                  Icons.directions_car_rounded,
                ),
                label: 'Araçlar',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.description_outlined,
                ),
                selectedIcon: Icon(
                  Icons.description_rounded,
                ),
                label: 'Analizler',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.person_outline_rounded,
                ),
                selectedIcon:
                Icon(Icons.person_rounded),
                label: 'Profil',
              ),
            ],
          ),
        );
      },
    );
  }
}