import 'package:flutter/material.dart';

import 'app_icon_box.dart';

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context)
            .colorScheme;

    final textTheme =
        Theme.of(context)
            .textTheme;

    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,

      children: [
        AppIconBox(
          icon:
          icon,

          size:
          42,

          iconSize:
          21,

          borderRadius:
          14,
        ),

        const SizedBox(
          width:
          12,
        ),

        Expanded(
          child:
          Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,

            children: [
              Text(
                title,

                style:
                textTheme
                    .titleMedium
                    ?.copyWith(
                  fontWeight:
                  FontWeight.w900,
                ),
              ),

              if (subtitle !=
                  null) ...[
                const SizedBox(
                  height:
                  3,
                ),

                Text(
                  subtitle!,

                  style:
                  textTheme
                      .bodySmall
                      ?.copyWith(
                    color:
                    colorScheme
                        .onSurfaceVariant,

                    height:
                    1.4,
                  ),
                ),
              ],
            ],
          ),
        ),

        if (trailing !=
            null) ...[
          const SizedBox(
            width:
            12,
          ),

          trailing!,
        ],
      ],
    );
  }
}
