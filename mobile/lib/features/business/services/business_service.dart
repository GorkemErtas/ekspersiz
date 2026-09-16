import '../../../core/network/api_client.dart';
import '../../auth/models/business_account.dart';
import '../models/business_member.dart';

class BusinessService {
  const BusinessService({this.apiClient = const ApiClient()});

  final ApiClient apiClient;

  Future<BusinessAccount> createAccount({required String companyName}) async {
    final response = await apiClient.post(
      '/business-accounts',
      body: {'companyName': companyName.trim()},
    );

    if (response is! Map) {
      throw const FormatException('Şirket bilgileri alınamadı.');
    }

    return BusinessAccount.fromJson(Map<String, dynamic>.from(response));
  }

  Future<void> inviteMember({required String email}) async {
    await apiClient.post(
      '/business-invitations',
      body: {'email': email.trim().toLowerCase()},
    );
  }

  Future<void> acceptInvitation({required String code}) async {
    await apiClient.post(
      '/business-invitations/accept',
      body: {'code': code.trim()},
    );
  }

  Future<List<BusinessMember>> getEmployees() async {
    final response = await apiClient.get('/business-members');

    if (response is! List) {
      throw const FormatException('Şirket çalışanları alınamadı.');
    }

    return response
        .map(
          (item) =>
              BusinessMember.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<void> removeEmployee(int membershipId) async {
    await apiClient.delete('/business-members/$membershipId');
  }
}
