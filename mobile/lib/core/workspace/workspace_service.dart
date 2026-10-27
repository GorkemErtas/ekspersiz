import '../network/api_client.dart';
import 'workspace_session.dart';

/// A local preference is published only after the server authorizes the target.
class WorkspaceService {
  const WorkspaceService();

  Future<void> select(WorkspaceType type) async {
    final scope = WorkspaceSession.capture();
    final current = WorkspaceSession.state.value;
    if (current == null ||
        (type == WorkspaceType.business &&
            (current.businessId == null || !current.businessAvailable))) {
      throw StateError('Şirket çalışma alanı kullanılamıyor.');
    }
    final result = await ApiClient(workspace: type).get('/workspace');
    WorkspaceSession.check(scope);
    if (result is! Map ||
        result['type'] != type.header ||
        result['userId'] != current.userId ||
        result['businessId'] !=
            (type == WorkspaceType.business ? current.businessId : null)) {
      throw StateError(
        'Çalışma alanı bilgileri değişti. Hesabınızı yenileyin.',
      );
    }
    await WorkspaceSession.select(type);
  }
}
