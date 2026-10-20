import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Markdown stays inside the chat's existing scroll view and theme.
class AssistantMessageBody extends StatelessWidget {
  const AssistantMessageBody({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyMedium!.copyWith(
      color: theme.colorScheme.onSurface,
      height: 1.5,
    );
    final heading = theme.textTheme.titleMedium!.copyWith(
      color: theme.colorScheme.onSurface,
      fontWeight: FontWeight.w700,
      height: 1.4,
    );
    return MarkdownBody(
      data: text,
      selectable: true,
      fitContent: true,
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: body,
        h1: heading,
        h2: heading,
        h3: heading,
        h4: heading,
        h5: heading,
        h6: heading,
        listBullet: body,
        listIndent: 20,
        blockSpacing: 8,
        a: body.copyWith(
          color: theme.brightness == Brightness.dark
              ? theme.colorScheme.secondary
              : theme.colorScheme.primary,
          decoration: TextDecoration.underline,
        ),
        textScaler: MediaQuery.textScalerOf(context),
      ),
      // Assistant replies are text; rendering arbitrary remote images would
      // introduce background network requests into the conversation.
      imageBuilder: (uri, title, alt) => Text(alt ?? title ?? '', style: body),
      onTapLink: (label, href, title) async {
        final uri = Uri.tryParse(href ?? '');
        if (uri == null ||
            !const {'https', 'http'}.contains(uri.scheme) ||
            uri.host.isEmpty) {
          return;
        }
        try {
          final opened = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          if (opened || !context.mounted) return;
        } catch (_) {
          if (!context.mounted) return;
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kaynak bağlantısı açılamadı.')),
          );
        }
      },
    );
  }
}
