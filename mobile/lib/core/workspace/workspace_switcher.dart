import 'package:flutter/material.dart';

import '../localization/app_text.dart';
import 'workspace_service.dart';
import 'workspace_session.dart';

class WorkspaceSwitcher extends StatefulWidget {
  const WorkspaceSwitcher({super.key});
  @override
  State<WorkspaceSwitcher> createState() => _WorkspaceSwitcherState();
}

class _WorkspaceSwitcherState extends State<WorkspaceSwitcher> {
  bool _busy = false;

  Future<void> _choose(WorkspaceState current) async {
    final scope = WorkspaceSession.capture();
    final selected = await showModalBottomSheet<WorkspaceType>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const AppText('Kişisel Hesap'),
                subtitle: const AppText('Kişisel araçlarınız ve kredileriniz'),
                trailing: current.isBusiness
                    ? null
                    : const Icon(Icons.check_rounded),
                onTap: () => Navigator.pop(context, WorkspaceType.personal),
              ),
              ListTile(
                leading: const Icon(Icons.business_outlined),
                title: AppText(current.companyName ?? 'Şirket Hesabı'),
                subtitle: const AppText('Ortak araçlar ve şirket kredileri'),
                trailing: current.isBusiness
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.pop(context, WorkspaceType.business),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
    if (!mounted || selected == null || selected == current.type) return;
    setState(() => _busy = true);
    try {
      WorkspaceSession.check(scope);
      await const WorkspaceService().select(selected);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<WorkspaceState?>(
    valueListenable: WorkspaceSession.state,
    builder: (context, current, _) {
      if (current?.businessId == null) return const SizedBox.shrink();
      final colors = Theme.of(context).colorScheme;
      return SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Material(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              key: const Key('workspace-switcher'),
              borderRadius: BorderRadius.circular(14),
              onTap: _busy ? null : () => _choose(current!),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      current!.isBusiness
                          ? Icons.business_outlined
                          : Icons.person_outline,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppText(
                        current.isBusiness
                            ? current.companyName ?? 'Şirket Hesabı'
                            : 'Kişisel Hesap',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_busy)
                      const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      const Icon(Icons.unfold_more_rounded, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
