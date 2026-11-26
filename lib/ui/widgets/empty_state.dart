import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../tokens.dart';
import 'p_button.dart';

/// What a section shows when it has nothing yet.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? body;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = ShadTheme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: MelaSpace.s4,
        vertical: MelaSpace.s6,
      ),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: MelaSpace.s2,
          children: [
            Container(
              width: MelaSize.touch,
              height: MelaSize.touch,
              decoration: BoxDecoration(
                color: colors.muted,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: MelaSize.icon,
                color: colors.mutedForeground,
              ),
            ),
            Text(
              title,
              textAlign: TextAlign.center,
              style: MelaText.bodyStrong.copyWith(color: colors.foreground),
            ),
            if (body != null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Text(
                  body!,
                  textAlign: TextAlign.center,
                  style: MelaText.body.copyWith(color: colors.mutedForeground),
                ),
              ),
            if (actionLabel != null)
              PButton.secondary(
                label: actionLabel,
                icon: actionIcon,
                size: PButtonSize.sm,
                onPressed: onAction,
              ),
          ],
        ),
      ),
    );
  }
}
