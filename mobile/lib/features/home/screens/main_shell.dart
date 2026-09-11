import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/auth/session_manager.dart';
import '../../../core/theme/app_theme.dart';

import '../../auth/screens/login_screen.dart';
import '../../inspection/screens/inspection_history_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../vehicle/screens/vehicle_list_screen.dart';

import 'home_screen.dart';

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
  State<MainShell> createState() =>
      _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const double _desktopBreakpoint =
  900;

  StreamSubscription<void>?
  _sessionSubscription;

  int _selectedIndex = 0;

  void _selectTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  late final List<Widget> _screens = [
    HomeScreen(
      fullName: widget.fullName,
      onOpenVehicles: () =>
          _selectTab(1),
      onOpenInspections: () =>
          _selectTab(2),
    ),

    const VehicleListScreen(),

    const InspectionHistoryScreen(),

    ProfileScreen(
      fullName: widget.fullName,
      email: widget.email,
      role: widget.role,
      subscriptionPlan:
      widget.subscriptionPlan,
    ),
  ];

  @override
  void initState() {
    super.initState();

    _sessionSubscription =
        SessionManager
            .unauthorizedStream
            .listen(
              (_) {
            _handleSessionExpired();
          },
        );
  }

  void _handleSessionExpired() {
    if (!mounted) {
      return;
    }

    Navigator.of(context)
        .pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) =>
        const LoginScreen(),
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
      builder: (
          context,
          constraints,
          ) {
        final isDesktop =
            constraints.maxWidth >=
                _desktopBreakpoint;

        if (isDesktop) {
          return _DesktopShell(
            selectedIndex:
            _selectedIndex,

            onDestinationSelected:
            _selectTab,

            screens:
            _screens,
          );
        }

        return _MobileShell(
          selectedIndex:
          _selectedIndex,

          onDestinationSelected:
          _selectTab,

          screens:
          _screens,
        );
      },
    );
  }
}

class _MobileShell extends StatelessWidget {
  const _MobileShell({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.screens,
  });

  final int selectedIndex;

  final ValueChanged<int>
  onDestinationSelected;

  final List<Widget> screens;

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Scaffold(
      extendBody: true,

      body: IndexedStack(
        index: selectedIndex,
        children: screens,
      ),

      bottomNavigationBar:
      SafeArea(
        minimum:
        const EdgeInsets.fromLTRB(
          14,
          0,
          14,
          12,
        ),

        child: Container(
          height: 76,

          decoration:
          BoxDecoration(
            color:
            colorScheme.surface,

            borderRadius:
            BorderRadius.circular(
              24,
            ),

            border:
            Border.all(
              color:
              colorScheme
                  .outlineVariant,
            ),

            boxShadow:
            AppTheme
                .elevatedShadow,
          ),

          child: Row(
            children: [
              Expanded(
                child:
                _NavigationItem(
                  index: 0,
                  selectedIndex:
                  selectedIndex,
                  icon:
                  Icons
                      .home_outlined,
                  selectedIcon:
                  Icons
                      .home_rounded,
                  label:
                  'Ana Sayfa',
                  onTap:
                  onDestinationSelected,
                ),
              ),

              Expanded(
                child:
                _NavigationItem(
                  index: 1,
                  selectedIndex:
                  selectedIndex,
                  icon:
                  Icons
                      .directions_car_outlined,
                  selectedIcon:
                  Icons
                      .directions_car_filled_rounded,
                  label:
                  'Araçlar',
                  onTap:
                  onDestinationSelected,
                ),
              ),

              Expanded(
                child:
                _NavigationItem(
                  index: 2,
                  selectedIndex:
                  selectedIndex,
                  icon:
                  Icons
                      .description_outlined,
                  selectedIcon:
                  Icons
                      .description_rounded,
                  label:
                  'Analizler',
                  onTap:
                  onDestinationSelected,
                ),
              ),

              Expanded(
                child:
                _NavigationItem(
                  index: 3,
                  selectedIndex:
                  selectedIndex,
                  icon:
                  Icons
                      .person_outline_rounded,
                  selectedIcon:
                  Icons
                      .person_rounded,
                  label:
                  'Profil',
                  onTap:
                  onDestinationSelected,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationItem
    extends StatelessWidget {
  const _NavigationItem({
    required this.index,
    required this.selectedIndex,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.onTap,
  });

  final int index;
  final int selectedIndex;

  final IconData icon;
  final IconData selectedIcon;

  final String label;

  final ValueChanged<int> onTap;

  bool get isSelected =>
      index == selectedIndex;

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return InkWell(
      onTap: () {
        onTap(index);
      },

      borderRadius:
      BorderRadius.circular(
        20,
      ),

      child: AnimatedContainer(
        duration:
        const Duration(
          milliseconds: 220,
        ),

        curve:
        Curves.easeOutCubic,

        margin:
        const EdgeInsets.all(
          6,
        ),

        padding:
        const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 5,
        ),

        decoration:
        BoxDecoration(
          color:
          isSelected
              ? colorScheme
              .primaryContainer
              : Colors
              .transparent,

          borderRadius:
          BorderRadius.circular(
            18,
          ),
        ),

        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,

          children: [
            AnimatedSwitcher(
              duration:
              const Duration(
                milliseconds: 180,
              ),

              child: Icon(
                isSelected
                    ? selectedIcon
                    : icon,

                key:
                ValueKey(
                  isSelected,
                ),

                size:
                isSelected
                    ? 23
                    : 22,

                color:
                isSelected
                    ? colorScheme
                    .primary
                    : colorScheme
                    .onSurfaceVariant,
              ),
            ),

            const SizedBox(
              height: 4,
            ),

            Text(
              label,

              maxLines: 1,

              style: TextStyle(
                fontSize: 10.5,
                height: 1.0,
                fontWeight:
                isSelected
                    ? FontWeight.w800
                    : FontWeight.w500,
                color:
                isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopShell
    extends StatelessWidget {
  const _DesktopShell({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.screens,
  });

  final int selectedIndex;

  final ValueChanged<int>
  onDestinationSelected;

  final List<Widget> screens;

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Scaffold(
      body: Row(
        children: [
          SafeArea(
            child: Padding(
              padding:
              const EdgeInsets.all(
                12,
              ),

              child: Container(
                width: 96,

                decoration:
                BoxDecoration(
                  color:
                  colorScheme
                      .surface,

                  borderRadius:
                  BorderRadius
                      .circular(
                    AppTheme
                        .radiusLarge,
                  ),

                  border:
                  Border.all(
                    color:
                    colorScheme
                        .outlineVariant,
                  ),

                  boxShadow:
                  AppTheme
                      .softShadow,
                ),

                child:
                NavigationRail(
                  selectedIndex:
                  selectedIndex,

                  onDestinationSelected:
                  onDestinationSelected,

                  backgroundColor:
                  Colors
                      .transparent,

                  labelType:
                  NavigationRailLabelType
                      .all,

                  groupAlignment:
                  -0.75,

                  leading:
                  Padding(
                    padding:
                    const EdgeInsets
                        .only(
                      top: 18,
                      bottom: 22,
                    ),

                    child:
                    Container(
                      width: 50,
                      height: 50,

                      decoration:
                      BoxDecoration(
                        gradient:
                        const LinearGradient(
                          colors: [
                            AppTheme
                                .primaryColor,
                            AppTheme
                                .secondaryColor,
                          ],

                          begin:
                          Alignment
                              .topLeft,

                          end:
                          Alignment
                              .bottomRight,
                        ),

                        borderRadius:
                        BorderRadius
                            .circular(
                          16,
                        ),

                        boxShadow:
                        AppTheme
                            .primaryShadow,
                      ),

                      child:
                      const Icon(
                        Icons
                            .car_crash_rounded,

                        color:
                        Colors
                            .white,

                        size:
                        26,
                      ),
                    ),
                  ),

                  destinations:
                  const [
                    NavigationRailDestination(
                      icon:
                      Icon(
                        Icons
                            .home_outlined,
                      ),
                      selectedIcon:
                      Icon(
                        Icons
                            .home_rounded,
                      ),
                      label:
                      Text(
                        'Ana Sayfa',
                      ),
                    ),

                    NavigationRailDestination(
                      icon:
                      Icon(
                        Icons
                            .directions_car_outlined,
                      ),
                      selectedIcon:
                      Icon(
                        Icons
                            .directions_car_filled_rounded,
                      ),
                      label:
                      Text(
                        'Araçlar',
                      ),
                    ),

                    NavigationRailDestination(
                      icon:
                      Icon(
                        Icons
                            .description_outlined,
                      ),
                      selectedIcon:
                      Icon(
                        Icons
                            .description_rounded,
                      ),
                      label:
                      Text(
                        'Analizler',
                      ),
                    ),

                    NavigationRailDestination(
                      icon:
                      Icon(
                        Icons
                            .person_outline_rounded,
                      ),
                      selectedIcon:
                      Icon(
                        Icons
                            .person_rounded,
                      ),
                      label:
                      Text(
                        'Profil',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: IndexedStack(
              index:
              selectedIndex,

              children:
              screens,
            ),
          ),
        ],
      ),
    );
  }
}