import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/models/business_account.dart';
import '../../auth/services/auth_service.dart';
import '../models/business_member.dart';
import '../services/business_service.dart';

class BusinessManagementScreen extends StatefulWidget {
  const BusinessManagementScreen({
    super.key,
    required this.subscriptionPlan,
    this.businessAccount,
    this.businessService = const BusinessService(),
    this.authService = const AuthService(),
  });

  final String subscriptionPlan;
  final BusinessAccount? businessAccount;
  final BusinessService businessService;
  final AuthService authService;

  @override
  State<BusinessManagementScreen> createState() =>
      _BusinessManagementScreenState();
}

class _BusinessManagementScreenState extends State<BusinessManagementScreen> {
  final _companyFormKey = GlobalKey<FormState>();
  final _invitationFormKey = GlobalKey<FormState>();
  final _acceptFormKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  bool _isCreating = false;
  bool _isInviting = false;
  bool _isAccepting = false;
  int? _removingMembershipId;
  Future<List<BusinessMember>>? _employeesFuture;

  bool get _canCreateAccount =>
      widget.businessAccount == null && widget.subscriptionPlan == 'BUSINESS';

  bool get _isInvitationOnly =>
      widget.businessAccount == null && widget.subscriptionPlan != 'BUSINESS';

  @override
  void initState() {
    super.initState();
    if (widget.businessAccount?.isOwner ?? false) {
      _employeesFuture = widget.businessService.getEmployees();
    }
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    if (_isCreating || !(_companyFormKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isCreating = true);

    try {
      final account = await widget.businessService.createAccount(
        companyName: _companyNameController.text,
      );

      if (mounted) {
        Navigator.of(context).pop<BusinessAccount>(account);
      }
    } catch (exception) {
      _showError(exception, 'Şirket oluşturulamadı.');
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  Future<void> _inviteMember() async {
    if (_isInviting ||
        !(_invitationFormKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isInviting = true);

    try {
      await widget.businessService.inviteMember(email: _emailController.text);

      if (!mounted) return;

      _emailController.clear();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Davet kodu kullanıcının e-posta adresine gönderildi.',
            ),
          ),
        );
    } catch (exception) {
      _showError(exception, 'Davet gönderilemedi.');
    } finally {
      if (mounted) {
        setState(() => _isInviting = false);
      }
    }
  }

  Future<void> _acceptInvitation() async {
    if (_isAccepting || !(_acceptFormKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isAccepting = true);

    try {
      await widget.businessService.acceptInvitation(code: _codeController.text);
      final profile = await widget.authService.getCurrentUser();
      final account = profile.businessAccount;

      if (account == null) {
        throw const FormatException('Şirket üyeliği yenilenemedi.');
      }

      if (mounted) {
        Navigator.of(context).pop<BusinessAccount>(account);
      }
    } catch (exception) {
      _showError(exception, 'Davet kabul edilemedi.');
    } finally {
      if (mounted) {
        setState(() => _isAccepting = false);
      }
    }
  }

  void _reloadEmployees() {
    setState(() {
      _employeesFuture = widget.businessService.getEmployees();
    });
  }

  Future<void> _confirmRemoveEmployee(BusinessMember employee) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Çalışan üyelikten çıkarılsın mı?'),
        content: Text(
          '${employee.fullName} (${employee.email}) şirket araçlarına ve analizlerine erişimini kaybedecek.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Üyelikten Çıkar'),
          ),
        ],
      ),
    );

    if (shouldRemove != true || !mounted) return;

    setState(() => _removingMembershipId = employee.id);

    try {
      await widget.businessService.removeEmployee(employee.id);

      if (!mounted) return;

      _reloadEmployees();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('${employee.fullName} şirket üyeliğinden çıkarıldı.'),
          ),
        );
    } catch (exception) {
      _showError(exception, 'Çalışan üyelikten çıkarılamadı.');
    } finally {
      if (mounted) {
        setState(() => _removingMembershipId = null);
      }
    }
  }

  void _showError(Object exception, String fallback) {
    if (!mounted) return;

    final message = switch (exception) {
      ApiException() => exception.message,
      FormatException() => exception.message,
      _ => fallback,
    };

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String? _validateCompanyName(String? value) {
    final companyName = value?.trim() ?? '';
    if (companyName.isEmpty) return 'Şirket adı zorunludur.';
    if (companyName.length > 150) {
      return 'Şirket adı en fazla 150 karakter olabilir.';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'E-posta adresi zorunludur.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Geçerli bir e-posta adresi girin.';
    }
    return null;
  }

  String? _validateCode(String? value) {
    if (!RegExp(r'^\d{6}$').hasMatch(value?.trim() ?? '')) {
      return 'Davet kodu 6 haneli olmalıdır.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.businessAccount;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isInvitationOnly ? 'Şirket Daveti' : 'Şirket İşlemleri'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
              children: [
                AppPageHeader(
                  icon: _isInvitationOnly
                      ? Icons.mark_email_read_outlined
                      : Icons.business_rounded,
                  title: _isInvitationOnly
                      ? 'Şirket davetini kabul et'
                      : account?.companyName ?? 'Şirket üyeliği',
                  subtitle: _isInvitationOnly
                      ? 'E-postanıza gelen 6 haneli kodla bir şirkete çalışan olarak katılın.'
                      : account == null
                      ? 'Şirket oluşturun veya e-postanıza gelen davet koduyla mevcut bir şirkete katılın.'
                      : 'Şirket araçları ve analizleri bütün üyeler tarafından ortak kullanılır.',
                  badge: _isInvitationOnly
                      ? 'DAVET'
                      : account?.roleLabel ?? 'BUSINESS',
                ),
                const SizedBox(height: 24),
                if (account?.isOwner ?? false) ...[
                  _buildInvitationForm(),
                  const SizedBox(height: 16),
                ],
                if (account != null && !account.isOwner)
                  _buildAccountSummary(account),
                if (_canCreateAccount) ...[
                  _buildCreateAccountForm(),
                  const SizedBox(height: 16),
                ],
                if (account == null) _buildAcceptInvitationForm(),
                if (account?.isOwner ?? false) _buildEmployeeList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountSummary(BusinessAccount account) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSectionHeader(
              icon: Icons.groups_2_outlined,
              title: account.companyName,
              subtitle: account.roleLabel,
            ),
            const SizedBox(height: 18),
            Text(
              'Şirket genelinde 50 aktif araç ve ayda 100 AI analizi ortak kullanılır.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateAccountForm() {
    return AppCard(
      child: Form(
        key: _companyFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppSectionHeader(
              icon: Icons.add_business_rounded,
              title: 'Şirket oluştur',
              subtitle: 'BUSINESS planınızla yeni bir şirket hesabı açın.',
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _companyNameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Şirket Adı',
                prefixIcon: Icon(Icons.business_outlined),
              ),
              validator: _validateCompanyName,
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              label: 'Şirketi Oluştur',
              icon: Icons.add_business_rounded,
              isLoading: _isCreating,
              onPressed: _createAccount,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvitationForm() {
    return AppCard(
      child: Form(
        key: _invitationFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppSectionHeader(
              icon: Icons.person_add_alt_1_rounded,
              title: 'Üye davet et',
              subtitle: 'Kayıtlı bir kullanıcıya şirket daveti gönderin.',
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Kullanıcının E-postası',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
              validator: _validateEmail,
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              label: 'Davet Gönder',
              icon: Icons.send_rounded,
              isLoading: _isInviting,
              onPressed: _inviteMember,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeList() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final employeesFuture = _employeesFuture;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            icon: Icons.groups_2_outlined,
            title: 'Çalışanlar',
            subtitle: 'Şirket araçlarına ve analizlerine erişebilen üyeler.',
            trailing: IconButton(
              tooltip: 'Çalışan listesini yenile',
              onPressed: _removingMembershipId == null
                  ? _reloadEmployees
                  : null,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
          const SizedBox(height: 18),
          if (employeesFuture == null)
            const SizedBox.shrink()
          else
            FutureBuilder<List<BusinessMember>>(
              future: employeesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  final error = snapshot.error;
                  final message = error is ApiException
                      ? error.message
                      : 'Çalışan listesi yüklenemedi.';

                  return Column(
                    children: [
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _reloadEmployees,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Tekrar Dene'),
                      ),
                    ],
                  );
                }

                final employees = snapshot.data ?? const <BusinessMember>[];

                if (employees.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.45,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Henüz şirkete katılmış bir çalışan bulunmuyor.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return Column(
                  children: [
                    for (var index = 0; index < employees.length; index++) ...[
                      if (index > 0) const Divider(height: 1),
                      _EmployeeListItem(
                        employee: employees[index],
                        isRemoving:
                            _removingMembershipId == employees[index].id,
                        canRemove: _removingMembershipId == null,
                        onRemove: () =>
                            _confirmRemoveEmployee(employees[index]),
                      ),
                    ],
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildAcceptInvitationForm() {
    return AppCard(
      child: Form(
        key: _acceptFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppSectionHeader(
              icon: Icons.mark_email_read_outlined,
              title: 'Daveti kabul et',
              subtitle: 'E-postanıza gelen 6 haneli davet kodunu girin.',
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: const InputDecoration(
                labelText: 'Davet Kodu',
                hintText: '123456',
                prefixIcon: Icon(Icons.password_rounded),
              ),
              validator: _validateCode,
              onFieldSubmitted: (_) => _acceptInvitation(),
            ),
            if (!_canCreateAccount &&
                widget.subscriptionPlan != 'BUSINESS') ...[
              const SizedBox(height: 12),
              Text(
                'Davet edilen üyelerin BUSINESS planına ihtiyacı yoktur.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 18),
            PrimaryButton(
              label: 'Daveti Kabul Et',
              icon: Icons.check_circle_outline_rounded,
              isLoading: _isAccepting,
              onPressed: _acceptInvitation,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeListItem extends StatelessWidget {
  const _EmployeeListItem({
    required this.employee,
    required this.isRemoving,
    required this.canRemove,
    required this.onRemove,
  });

  final BusinessMember employee;
  final bool isRemoving;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: colorScheme.primaryContainer,
            foregroundColor: colorScheme.primary,
            child: const Icon(Icons.person_outline_rounded),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.fullName,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  employee.email,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isRemoving)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            )
          else
            IconButton(
              tooltip: 'Üyelikten çıkar',
              onPressed: canRemove ? onRemove : null,
              icon: Icon(
                Icons.person_remove_outlined,
                color: colorScheme.error,
              ),
            ),
        ],
      ),
    );
  }
}
