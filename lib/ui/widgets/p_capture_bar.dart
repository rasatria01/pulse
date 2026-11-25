import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../strings.dart';
import '../theme.dart';
import '../tokens.dart';
import 'common.dart';
import 'p_button.dart';
import 'p_chip.dart';

/// Quick capture. The default constructor is the bar pinned to the bottom of a
/// main screen; [PCaptureBar.open] is the field, Save and parse chips shown
/// inside a sheet.
class PCaptureBar extends StatelessWidget {
  const PCaptureBar({
    super.key,
    required VoidCallback this.onOpen,
    this.placeholder = PulseStrings.capturePlaceholder,
  }) : controller = null,
       focusNode = null,
       chips = const [],
       hint = null,
       onChanged = null,
       onSave = null;

  /// Chips keep the caller's order: Kind, Amount, Wallet, Category, Date/Time,
  /// Priority, Tags. Save is disabled while any chip is in error.
  const PCaptureBar.open({
    super.key,
    required TextEditingController this.controller,
    this.focusNode,
    this.chips = const [],
    this.hint,
    this.onChanged,
    required this.onSave,
    this.placeholder = PulseStrings.capturePlaceholder,
  }) : onOpen = null;

  final VoidCallback? onOpen;
  final String placeholder;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final List<PChip> chips;

  /// One line saying what is wrong, shown while a chip is in error.
  final String? hint;
  final ValueChanged<String>? onChanged;

  /// Also runs on Enter. The caller clears the controller.
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) =>
      onOpen != null ? _closed(context) : _open(context);

  Widget _closed(BuildContext context) {
    final colors = ShadTheme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: PTapTarget(
          label: PulseStrings.quickCapture,
          onTap: onOpen,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: PulseSize.capture),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(
              horizontal: PulseSpace.s4,
              vertical: PulseSpace.s1,
            ),
            child: Container(
              constraints: const BoxConstraints(minHeight: PulseSize.control),
              padding: const EdgeInsets.symmetric(horizontal: PulseSpace.s3),
              decoration: BoxDecoration(
                color: colors.muted,
                borderRadius: BorderRadius.circular(PulseRadius.md),
              ),
              child: Row(
                spacing: PulseSpace.s2,
                children: [
                  Icon(
                    LucideIcons.plus,
                    size: PulseSize.icon,
                    color: colors.inkSubtle,
                  ),
                  Expanded(
                    child: Text(
                      placeholder,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PulseText.body.copyWith(color: colors.inkSubtle),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _open(BuildContext context) {
    final colors = ShadTheme.of(context).colorScheme;
    final hasError = chips.any((c) => c.tone == PChipTone.error);
    final save = hasError ? null : onSave;
    final border = ShadBorder.all(
      color: hasError ? colors.destructive : colors.input,
      width: 1,
      radius: BorderRadius.circular(PulseRadius.md),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: PulseSpace.s1,
      children: [
        Row(
          spacing: PulseSpace.s2,
          children: [
            Expanded(
              child: Semantics(
                label: PulseStrings.quickCapture,
                child: ShadInput(
                  controller: controller,
                  focusNode: focusNode,
                  autofocus: true,
                  placeholder: Text(
                    placeholder,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: PulseText.body.copyWith(color: colors.foreground),
                  decoration: ShadDecoration(
                    color: colors.surfaceRaised,
                    border: border,
                    focusedBorder: border,
                  ),
                  textInputAction: TextInputAction.done,
                  onChanged: onChanged,
                  // Overrides the default unfocus: the next entry can start.
                  onEditingComplete: () {},
                  onSubmitted: (_) => save?.call(),
                ),
              ),
            ),
            PButton.primary(label: PulseStrings.save, onPressed: save),
          ],
        ),
        Semantics(
          container: true,
          explicitChildNodes: true,
          label: PulseStrings.parsedChips,
          child: PChipRow(children: chips),
        ),
        if (hasError && hint != null)
          Semantics(
            liveRegion: true,
            child: Text(
              hint!,
              style: PulseText.caption.copyWith(color: colors.destructive),
            ),
          ),
      ],
    );
  }
}
