import 'package:mobile/core/localization/app_text.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/auth/session_manager.dart';
import '../../../core/workspace/workspace_session.dart';
import '../../../core/workspace/workspace_switcher.dart';
import '../../auth/services/auth_service.dart';
import '../../../core/notifications/push_notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_navigation_bar.dart';

import '../../auth/screens/login_screen.dart';
import '../../auth/models/business_account.dart';
import '../../inspection/screens/inspection_history_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../vehicle/screens/vehicle_list_screen.dart';
import 'home_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.fullName,
    required this.email,
    required this.subscriptionPlan,
    this.businessAccount,
    this.userId,
  });

  final String fullName;
  final String email;
  final String subscriptionPlan;
  final BusinessAccount? businessAccount;
  final int? userId;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  static const double _desktopBreakpoint = 900;

  StreamSubscription<void>? _sessionSubscription;

  int _selectedIndex = 0;
  Object _cacheEpoch = Object();
  bool _workspaceReady = false;
  bool _leavingSession = false;
  WorkspaceState? _lastWorkspace;

  BusinessAccount? get _activeBusiness => WorkspaceSession.state.value == null
      ? _businessAccount
      : WorkspaceSession.state.value!.isBusiness
      ? _businessAccount
      : null;

  late BusinessAccount? _businessAccount;
  late String _subscriptionPlan;

  late final List<Widget?> _screenCache;

  Widget _buildScreen(int index) {
    final cached = _screenCache[index];
    if (cached != null) {
      return cached;
    }

    final screen = switch (index) {
      0 => HomeScreen(
        fullName: widget.fullName,
        subscriptionPlan:
            _activeBusiness == null && _subscriptionPlan == 'BUSINESS'
            ? 'FREE'
            : _subscriptionPlan,
        businessAccount: _activeBusiness,
        onOpenVehicles: () => _selectTab(1),
        onOpenInspections: () => _selectTab(2),
        onOpenProfile: () => _selectTab(3),
      ),
      1 => VehicleListScreen(businessAccount: _activeBusiness),
      2 => InspectionHistoryScreen(businessAccount: _activeBusiness),
      3 => ProfileScreen(
        fullName: widget.fullName,
        email: widget.email,
        subscriptionPlan: _subscriptionPlan,
        businessAccount: _businessAccount,
        onBusinessAccountChanged: _updateBusinessAccount,
        onSubscriptionPlanChanged: _updateSubscriptionPlan,
      ),
      _ => throw ArgumentError.value(index, 'index', 'Geçersiz sekme indeksi'),
    };

    _screenCache[index] = screen;
    return screen;
  }

  List<Widget> get _screens => List<Widget>.generate(
    4,
    (index) => index == _selectedIndex || _screenCache[index] != null
        ? _buildScreen(index)
        : const SizedBox.shrink(),
  );

  @override
  void initState() {
    super.initState();

    _screenCache = List<Widget?>.filled(4, null);
    _businessAccount = widget.businessAccount;
    _subscriptionPlan = widget.subscriptionPlan;
    _lastWorkspace = WorkspaceSession.state.value;
    WorkspaceSession.state.addListener(_workspaceChanged);
    WidgetsBinding.instance.addObserver(this);
    _workspaceReady =
        widget.userId == null ||
        WorkspaceSession.state.value?.userId == widget.userId;
    if (!_workspaceReady) _restoreWorkspace();
    _initializeDevicePermissions();

    _sessionSubscription = SessionManager.unauthorizedStream.listen((_) {
      _handleSessionExpired();
    });
  }

  Future<void> _restoreWorkspace() async {
    try {
      await WorkspaceSession.initialize(
        userId: widget.userId!,
        businessId: _businessAccount?.id,
        companyName: _businessAccount?.companyName,
        role: _businessAccount?.role,
      );
      if (mounted) setState(() => _workspaceReady = true);
    } catch (_) {
      if (mounted) _handleSessionExpired();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.userId != null) {
      // Server access checks remain authoritative while offline.
      const AuthService().getCurrentUser().ignore();
    }
  }

  void _workspaceChanged() {
    if (!mounted) return;
    final current = WorkspaceSession.state.value;
    if (current == null ||
        (widget.userId != null && current.userId != widget.userId)) {
      if (widget.userId != null) _handleSessionExpired();
      return;
    }
    final previous = _lastWorkspace;
    _lastWorkspace = current;
    final changedArea =
        previous?.type != current.type ||
        (current.isBusiness && previous?.businessId != current.businessId) ||
        (previous?.businessId != null &&
            (previous?.businessId != current.businessId ||
                previous?.role != current.role));
    setState(() {
      _subscriptionPlan = current.subscriptionPlan ?? _subscriptionPlan;
      _businessAccount = current.businessId == null
          ? null
          : BusinessAccount(
              id: current.businessId!,
              companyName: current.companyName ?? 'Şirket Hesabı',
              role: current.role ?? 'MEMBER',
            );
      _cacheEpoch = Object();
      _screenCache.fillRange(0, _screenCache.length, null);
    });
    if (changedArea) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      });
    }
  }

  Future<void> _initializeDevicePermissions() async {
    await PushNotificationService.instance.registerAuthenticatedDevice();
    await _requestLocationPermission();
  }

  Future<void> _requestLocationPermission() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
    } catch (_) {
      // Location is optional. A denied/unavailable permission must not block login.
    }
  }

  void _selectTab(int index) {
    if (_selectedIndex == index) {
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  void _updateBusinessAccount(BusinessAccount businessAccount) {
    final userId = widget.userId ?? WorkspaceSession.state.value?.userId;
    if (userId != null) {
      WorkspaceSession.initialize(
        userId: userId,
        businessId: businessAccount.id,
        companyName: businessAccount.companyName,
        role: businessAccount.role,
      );
    }
    setState(() {
      _businessAccount = businessAccount;
      _cacheEpoch = Object();
      for (var index = 0; index < _screenCache.length; index++) {
        _screenCache[index] = null;
      }
    });
  }

  void _updateSubscriptionPlan(String subscriptionPlan) {
    if (_subscriptionPlan == subscriptionPlan) {
      return;
    }

    setState(() {
      _subscriptionPlan = subscriptionPlan;
      _cacheEpoch = Object();
      for (var index = 0; index < _screenCache.length; index++) {
        _screenCache[index] = null;
      }
    });
  }

  void _handleSessionExpired() {
    if (!mounted || _leavingSession) {
      return;
    }

    _leavingSession = true;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    WorkspaceSession.state.removeListener(_workspaceChanged);
    WidgetsBinding.instance.removeObserver(this);
    _sessionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_workspaceReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return KeyedSubtree(
      key: ValueKey(_cacheEpoch),
      child: Column(
        children: [
          const WorkspaceSwitcher(),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: WorkspaceSession.state.value?.businessId != null,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth >= _desktopBreakpoint;

                  if (isDesktop) {
                    return _DesktopShell(
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: _selectTab,
                      screens: _screens,
                    );
                  }

                  return _MobileShell(
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: _selectTab,
                    screens: _screens,
                  );
                },
              ),
            ),
          ),
        ],
      ),
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
  final ValueChanged<int> onDestinationSelected;
  final List<Widget> screens;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Builder(
        builder: (context) {
          return screens[selectedIndex];
        },
      ),
      bottomNavigationBar: AppNavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
      ),
    );
  }
}

class _DesktopShell extends StatelessWidget {
  const _DesktopShell({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.screens,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<Widget> screens;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Row(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.16),
                  ),
                  boxShadow: AppTheme.elevatedShadowFor(context),
                ),
                child: NavigationRail(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onDestinationSelected,
                  labelType: NavigationRailLabelType.all,
                  groupAlignment: -0.72,
                  leading: Padding(
                    padding: const EdgeInsets.only(top: 18, bottom: 30),
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: AppTheme.brandGradient,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: AppTheme.primaryShadowFor(context),
                      ),
                      child: const Icon(
                        Icons.car_crash_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home_rounded),
                      label: AppText('Ana Sayfa'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.directions_car_outlined),
                      selectedIcon: Icon(Icons.directions_car_rounded),
                      label: AppText('Araçlar'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.description_outlined),
                      selectedIcon: Icon(Icons.description_rounded),
                      label: AppText('Analizler'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.person_outline_rounded),
                      selectedIcon: Icon(Icons.person_rounded),
                      label: AppText('Profil'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                return screens[selectedIndex];
              },
            ),
          ),
        ],
      ),
    );
  }
}
