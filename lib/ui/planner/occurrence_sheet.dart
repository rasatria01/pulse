import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../core/rupiah.dart';
import '../strings.dart';
import '../widgets/amount_text.dart';
import '../widgets/p_button.dart';
import '../widgets/p_sheet.dart';
import 'form_fields.dart';
import 'planner_strings.dart';

/// What the person chose for a pending recurring occurrence.
sealed class OccurrenceSheetResult {
  const OccurrenceSheetResult();
}

final class OccurrenceConfirmed extends OccurrenceSheetResult {
  const OccurrenceConfirmed(this.amount);

  final Rupiah amount;
}

final class OccurrenceSkipped extends OccurrenceSheetResult {
  const OccurrenceSkipped();
}

/// A pending occurrence with its amount editable (PRD 9.3). The wallet and
/// category are the rule's. Pops null when dismissed: it stays pending.
class OccurrenceSheet extends StatefulWidget {
  const OccurrenceSheet({
    super.key,
    required this.title,
    required this.amount,
    required this.walletName,
  });

  final String title;
  final Rupiah amount;
  final String walletName;

  @override
  State<OccurrenceSheet> createState() => _OccurrenceSheetState();
}

class _OccurrenceSheetState extends State<OccurrenceSheet> {
  late final _amount = TextEditingController(text: '${widget.amount.value}');

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Rupiah? get _value {
    final value = int.tryParse(_amount.text);
    return value == null || value <= 0 ? null : Rupiah(value);
  }

  void _pop(OccurrenceSheetResult result) =>
      Navigator.of(context).pop<OccurrenceSheetResult>(result);

  @override
  Widget build(BuildContext context) {
    final value = _value;
    return PSheet(
      title: widget.title,
      footer: [
        PButton.ghost(
          label: MelaStrings.skip,
          onPressed: () => _pop(const OccurrenceSkipped()),
        ),
        PButton.primary(
          label: PlannerStrings.recordRecurring,
          onPressed: value == null
              ? null
              : () => _pop(OccurrenceConfirmed(value)),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          PField(
            label: PlannerStrings.amount,
            error: value == null ? PlannerStrings.needsRecurringAmount : null,
            child: ShadInput(
              key: const ValueKey('occurrence-amount'),
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
          Text(PlannerStrings.fromWallet(widget.walletName)),
        ],
      ),
    );
  }
}
