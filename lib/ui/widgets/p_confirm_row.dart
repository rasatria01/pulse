import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../core/rupiah.dart';
import '../strings.dart';
import '../theme.dart';
import '../tokens.dart';
import 'amount_text.dart';
import 'common.dart';
import 'p_button.dart';

enum ConfirmSource { bill, recurring }

/// A pending bill or recurring occurrence with Confirm, Edit and Skip. A null
/// [amount] reads "No amount"; the caller's Confirm then opens the sheet.
class PConfirmRow extends StatelessWidget {
  const PConfirmRow({
    super.key,
    required this.title,
    required this.source,
    required this.onConfirm,
    required this.onEdit,
    required this.onSkip,
    this.meta,
    this.amount,
    this.type = AmountType.outcome,
  });

  final String title;
  final ConfirmSource source;
  final VoidCallback onConfirm;
  final VoidCallback onEdit;
  final VoidCallback onSkip;

  /// Wallet, or wallet · date.
  final String? meta;
  final Rupiah? amount;
  final AmountType type;

  @override
  Widget build(BuildContext context) {
    final colors = ShadTheme.of(context).colorScheme;
    final bill = source == ConfirmSource.bill;
    final kind = bill ? MelaStrings.bill : MelaStrings.recurring;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MelaSpace.s4,
        MelaSpace.s3,
        MelaSpace.s4,
        MelaSpace.s1,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: MelaSpace.s3,
        children: [
          PIconTile(icon: bill ? LucideIcons.receiptText : LucideIcons.repeat),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: MelaSpace.s1,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: MelaSpace.s3,
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: MelaText.bodyStrong.copyWith(
                              color: colors.foreground,
                            ),
                          ),
                          Text(
                            meta == null ? kind : '$kind · $meta',
                            style: MelaText.caption.copyWith(
                              color: colors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (amount != null)
                      TrailingAmount(child: AmountText(amount!, type: type))
                    else
                      Text(
                        MelaStrings.noAmount,
                        style: MelaText.caption.copyWith(
                          color: colors.inkSubtle,
                        ),
                      ),
                  ],
                ),
                Wrap(
                  spacing: MelaSpace.s2,
                  children: [
                    PButton.primary(
                      label: MelaStrings.confirm,
                      size: PButtonSize.sm,
                      onPressed: onConfirm,
                    ),
                    PButton.secondary(
                      label: MelaStrings.edit,
                      size: PButtonSize.sm,
                      onPressed: onEdit,
                    ),
                    PButton.ghost(
                      label: MelaStrings.skip,
                      size: PButtonSize.sm,
                      onPressed: onSkip,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
