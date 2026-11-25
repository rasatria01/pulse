import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../strings.dart';
import '../theme.dart';
import '../tokens.dart';
import 'common.dart';
import 'p_button.dart';

/// The floating confirmation card with Undo. Show it with [showPSnackbar].
class PSnackbar extends StatelessWidget {
  const PSnackbar({
    super.key,
    required this.message,
    required this.onAction,
    this.actionLabel = PulseStrings.undo,
    this.seconds,
  });

  final String message;
  final VoidCallback onAction;
  final String actionLabel;

  /// Optional countdown.
  final int? seconds;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final colors = theme.colorScheme;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: PulseSize.touch),
      padding: const EdgeInsets.only(left: PulseSpace.s4, right: PulseSpace.s2),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(PulseRadius.xl2),
        boxShadow: PulseShadow.float(theme.brightness),
      ),
      child: Row(
        spacing: PulseSpace.s3,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: PulseSpace.s2),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  message,
                  style: PulseText.body.copyWith(color: colors.foreground),
                ),
              ),
            ),
          ),
          if (seconds != null)
            Text(
              PulseStrings.seconds(seconds!),
              style: PulseText.caption.copyWith(
                color: colors.inkSubtle,
                fontFeatures: PulseText.amount.fontFeatures,
              ),
            ),
          PButton.ghost(
            label: actionLabel,
            icon: LucideIcons.undo2,
            size: PButtonSize.sm,
            onPressed: onAction,
          ),
        ],
      ),
    );
  }
}

/// Shows a [PSnackbar] above the capture bar for 5 seconds. A new one replaces
/// the old one.
void showPSnackbar(
  BuildContext context, {
  required String message,
  required VoidCallback onUndo,
  String actionLabel = PulseStrings.undo,
}) {
  final toaster = ShadToaster.of(context);
  final colors = ShadTheme.of(context).colorScheme;
  final fade = reduceMotion(context)
      ? const Duration(milliseconds: 1)
      : const Duration(milliseconds: 200);
  var used = false;
  toaster.show(
    ShadToast(
      displayDuration: const Duration(seconds: 5),
      alignment: Alignment.bottomCenter,
      offset: Offset(
        PulseSpace.s4,
        MediaQuery.paddingOf(context).bottom +
            PulseSize.capture +
            PulseSpace.s2,
      ),
      animateIn: [FadeEffect(duration: fade)],
      animateOut: [FadeEffect(begin: 1, end: 0, duration: fade)],
      padding: EdgeInsets.zero,
      backgroundColor: colors.background.withValues(alpha: 0),
      border: ShadBorder.none,
      shadows: const [],
      closeIcon: const SizedBox.shrink(),
      description: PSnackbar(
        message: message,
        actionLabel: actionLabel,
        onAction: () {
          // The card stays tappable while it fades out; undo only once.
          if (used) return;
          used = true;
          toaster.hide();
          onUndo();
        },
      ),
    ),
  );
}
