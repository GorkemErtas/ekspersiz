import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../auth/session_manager.dart';
import '../network/api_exception.dart';
import 'business_workspace_access.dart';

enum WorkspaceType {
  personal('PERSONAL'),
  business('BUSINESS');

  const WorkspaceType(this.header);
  final String header;
}

@immutable
class WorkspaceState {
  const WorkspaceState({
    required this.userId,
    required this.type,
    this.businessId,
    this.companyName,
    this.role,
    this.subscriptionPlan,
    this.businessAvailable = false,
    this.businessAccessStatus = 'UNKNOWN',
    this.businessSandbox = false,
  });
  final int userId;
  final WorkspaceType type;
  final int? businessId;
  final String? companyName;
  final String? role;
  final String? subscriptionPlan;
  final bool businessAvailable;
  final String businessAccessStatus;
  final bool businessSandbox;
  bool get isBusiness => type == WorkspaceType.business;
  String get businessAccessMessage =>
      businessWorkspaceAccessMessage(businessAccessStatus);
}

class WorkspaceRequest {
  const WorkspaceRequest(this.type, this.generation);
  final WorkspaceType? type;
  final Object generation;
}

/// Client preference only. The server reauthorizes every request.
class WorkspaceSession {
  WorkspaceSession._();
  static final state = ValueNotifier<WorkspaceState?>(null);
  static const _storage = FlutterSecureStorage();
  static Object _generation = Object();
  static Object _initialization = Object();

  static WorkspaceRequest capture({WorkspaceType? override}) =>
      WorkspaceRequest(override ?? state.value?.type, _generation);

  static void check(WorkspaceRequest request) {
    if (!identical(request.generation, _generation)) {
      throw const ApiException(
        statusCode: 409,
        message:
            'Çalışma alanı veya oturum değişti. İşlemi seçili alanda yeniden açın.',
      );
    }
  }

  static Future<void> initialize({
    required int userId,
    int? businessId,
    String? companyName,
    String? role,
    String? subscriptionPlan,
    bool businessAvailable = false,
    String businessAccessStatus = 'UNKNOWN',
    bool businessSandbox = false,
  }) async {
    final ticket = _initialization = Object();
    final current = state.value;
    final plan =
        subscriptionPlan ??
        (current?.userId == userId ? current?.subscriptionPlan : null);
    WorkspaceType type;
    if (current?.userId == userId) {
      type = current!.type;
      if (!businessAvailable ||
          businessId == null ||
          (current.isBusiness && businessId != current.businessId)) {
        type = WorkspaceType.personal;
      }
    } else {
      String? preference;
      try {
        preference = await _storage.read(key: 'workspace:user:$userId');
      } catch (_) {
        /* Preference storage is optional. */
      }
      if (!identical(ticket, _initialization)) {
        throw const ApiException(
          statusCode: 409,
          message: 'Oturum değişti. Lütfen tekrar deneyin.',
        );
      }
      type =
          preference == 'PERSONAL' || businessId == null || !businessAvailable
          ? WorkspaceType.personal
          : WorkspaceType.business;
    }
    final sameWorkspace =
        current?.userId == userId &&
        current?.type == type &&
        current?.businessId == businessId &&
        current?.companyName == companyName &&
        current?.role == role &&
        current?.businessAvailable == businessAvailable &&
        current?.businessAccessStatus == businessAccessStatus &&
        current?.businessSandbox == businessSandbox;
    if (sameWorkspace && current?.subscriptionPlan == plan) {
      return;
    }
    final next = WorkspaceState(
      userId: userId,
      type: type,
      businessId: businessId,
      companyName: companyName,
      role: role,
      subscriptionPlan: plan,
      businessAvailable: businessAvailable,
      businessAccessStatus: businessAccessStatus,
      businessSandbox: businessSandbox,
    );
    if (sameWorkspace) {
      // Subscription metadata can refresh as the store sheet closes. It does
      // not change the request's user/workspace or invalidate its purchase.
      state.value = next;
    } else {
      _publish(next);
    }
    final published = capture();
    await _remember(userId, type);
    check(published);
  }

  static Future<void> select(WorkspaceType type) async {
    final current = state.value;
    if (current == null ||
        (type == WorkspaceType.business &&
            (current.businessId == null || !current.businessAvailable))) {
      throw StateError('Şirket çalışma alanı kullanılamıyor.');
    }
    _initialization = Object();
    if (current.type == type) return;
    _publish(
      WorkspaceState(
        userId: current.userId,
        type: type,
        businessId: current.businessId,
        companyName: current.companyName,
        role: current.role,
        subscriptionPlan: current.subscriptionPlan,
        businessAvailable: current.businessAvailable,
        businessAccessStatus: current.businessAccessStatus,
        businessSandbox: current.businessSandbox,
      ),
    );
    final published = capture();
    await _remember(current.userId, type);
    check(published);
  }

  static void revokeBusiness() {
    _initialization = Object();
    final current = state.value;
    if (current == null) {
      _generation = Object();
      return;
    }
    _publish(
      WorkspaceState(
        userId: current.userId,
        type: WorkspaceType.personal,
        businessId: current.businessId,
        companyName: current.companyName,
        role: current.role,
        subscriptionPlan: current.subscriptionPlan,
        businessAvailable: false,
        businessAccessStatus: current.businessAvailable
            ? 'UNKNOWN'
            : current.businessAccessStatus,
        businessSandbox: current.businessSandbox,
      ),
    );
    _remember(current.userId, WorkspaceType.personal);
  }

  static void clear() {
    _initialization = Object();
    _generation = Object();
    state.value = null;
  }

  static void _publish(WorkspaceState next) {
    _generation = Object();
    SessionManager.invalidateImages();
    state.value = next;
  }

  static Future<void> _remember(int userId, WorkspaceType type) async {
    if (state.value?.userId != userId || state.value?.type != type) return;
    try {
      await _storage.write(key: 'workspace:user:$userId', value: type.header);
    } catch (_) {
      /* Keep the authorized in-memory selection. */
    }
  }
}
