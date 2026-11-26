import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../core/rupiah.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/wallet.dart';
import '../strings.dart';
import '../widgets/amount_text.dart';
import '../widgets/p_button.dart';
import '../widgets/p_chip.dart';
import '../widgets/p_sheet.dart';
import 'form_fields.dart';
import 'planner_strings.dart';

/// What the person chose in the confirmation sheet.
sealed class BillSheetResult {
  const BillSheetResult();
}

final class BillConfirmed extends BillSheetResult {
  const BillConfirmed({
    required this.amount,
    required this.walletId,
    required this.categoryId,
    required this.description,
  });

  final Rupiah amount;
  final String walletId;
  final String categoryId;
  final String description;
}

final class BillSkipped extends BillSheetResult {
  const BillSkipped();
}

/// The confirmation sheet of PRD 9.1. Pops a [BillSheetResult]; null means
/// dismissed, which the caller treats as "later".
class BillSheet extends StatefulWidget {
  const BillSheet({
    super.key,
    required this.wallets,
    required this.categories,
    required this.walletId,
    required this.categoryId,
    required this.description,
    this.amount,
  });

  final List<Wallet> wallets;
  final List<Category> categories;
  final String walletId;
  final String categoryId;
  final String description;

  /// Null leaves the field empty.
  final Rupiah? amount;

  @override
  State<BillSheet> createState() => _BillSheetState();
}

class _BillSheetState extends State<BillSheet> {
  late final _amount = TextEditingController(
    text: widget.amount?.value.toString(),
  );
  late final _description = TextEditingController(text: widget.description);
  late var _walletId = widget.walletId;
  late var _categoryId = widget.categoryId;

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  Rupiah? get _value {
    final value = int.tryParse(_amount.text);
    return value == null || value <= 0 ? null : Rupiah(value);
  }

  void _confirm() {
    final amount = _value;
    if (amount == null) return;
    Navigator.of(context).pop<BillSheetResult>(
      BillConfirmed(
        amount: amount,
        walletId: _walletId,
        categoryId: _categoryId,
        description: _description.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final value = _value;
    return PSheet(
      title: PlannerStrings.recordPayment,
      footer: [
        PButton.ghost(
          label: MelaStrings.skip,
          onPressed: () =>
              Navigator.of(context).pop<BillSheetResult>(const BillSkipped()),
        ),
        PButton.primary(
          label: PlannerStrings.recordPayment,
          onPressed: value == null ? null : _confirm,
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          PField(
            label: PlannerStrings.amount,
            error: value == null ? PlannerStrings.needsAmount : null,
            child: ShadInput(
              key: const ValueKey('bill-amount'),
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(12),
              ],
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (value != null) AmountText(value, size: AmountSize.lg),
          PChoiceChips(
            label: PlannerStrings.wallet,
            options: [for (final w in widget.wallets) (w.id, w.name, w.color)],
            value: _walletId,
            onChanged: (id) => setState(() => _walletId = id),
          ),
          PChoiceChips(
            label: PlannerStrings.category,
            options: [
              for (final c in widget.categories) (c.id, c.name, c.color),
            ],
            value: _categoryId,
            onChanged: (id) => setState(() => _categoryId = id),
          ),
          PField(
            label: PlannerStrings.description,
            child: ShadInput(controller: _description),
          ),
        ],
      ),
    );
  }
}

/// Wallet or category chips, with their identity dots.
class PChoiceChips extends StatelessWidget {
  const PChoiceChips({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final String label;

  /// (id, name, ARGB colour).
  final List<(String, String, int)> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => PField(
    label: label,
    child: PChipRow(
      children: [
        for (final (id, name, color) in options)
          PChip(
            field: label,
            label: name,
            dotColor: color,
            selected: id == value,
            onPressed: () => onChanged(id),
          ),
      ],
    ),
  );
}

/// Reopening a recorded bill (PRD 9.1). Pops true to delete the payment, false
/// to keep it, null to leave the bill done.
class ReopenBillSheet extends StatelessWidget {
  const ReopenBillSheet({super.key, required this.amount});

  final Rupiah amount;

  @override
  Widget build(BuildContext context) => PSheet(
    title: PlannerStrings.reopenBill,
    footer: [
      PButton.ghost(
        label: PlannerStrings.keepPayment,
        onPressed: () => Navigator.of(context).pop(false),
      ),
      PButton.destructive(
        label: PlannerStrings.deletePayment,
        onPressed: () => Navigator.of(context).pop(true),
      ),
    ],
    child: Text(PlannerStrings.paymentRecorded(formatRupiah(amount))),
  );
}
