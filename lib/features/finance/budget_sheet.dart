import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shad/shad.dart';

import '../../app/di.dart';
import '../../core/failures.dart';
import '../../core/rupiah.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/category.dart';
import '../../domain/parser/amount_rules.dart' show readAmount;
import '../../ui/planner/bill_sheet.dart' show PChoiceChips;
import '../../ui/strings.dart';
import '../../ui/widgets/widgets.dart';
import 'finance_strings.dart';
import 'form_fields.dart';

/// Sets or removes a category's cap from the current budget month on.
class BudgetSheet extends ConsumerStatefulWidget {
  const BudgetSheet({super.key, this.categoryId});

  /// Null picks one in the sheet.
  final String? categoryId;

  @override
  ConsumerState<BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends ConsumerState<BudgetSheet> {
  late String? _categoryId = widget.categoryId;
  late final _cap = TextEditingController(text: _capText(widget.categoryId));
  bool _busy = false;
  String? _error;

  /// The cap in force, or empty.
  String _capText(String? categoryId) => [
    for (final s
        in ref.read(budgetStatusesProvider).value ?? const <BudgetStatus>[])
      if (s.categoryId == categoryId) '${s.cap.value}',
  ].join();

  @override
  void dispose() {
    _cap.dispose();
    super.dispose();
  }

  Future<void> _write(Rupiah cap) async {
    final categoryId = _categoryId;
    if (categoryId == null) {
      setState(() => _error = FinanceStrings.categoryError);
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final period = await ref.read(budgetPeriodProvider.future);
      await ref
          .read(budgetRepositoryProvider)
          .setCap(categoryId, cap, period.month);
      if (mounted) Navigator.of(context).pop();
    } on AppFailure {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = FinanceStrings.saveFailed;
      });
    }
  }

  void _save() {
    final cap = readAmount(
      _cap.text.replaceAll(RegExp(r'\s'), '').toLowerCase(),
    )?.value;
    if (cap == null) {
      setState(() => _error = FinanceStrings.capError);
      return;
    }
    _write(Rupiah(cap));
  }

  @override
  Widget build(BuildContext context) {
    final categories = [
      for (final c in ref.watch(categoriesProvider).value ?? const <Category>[])
        if (c.kind == CategoryKind.outcome && !c.isArchived) c,
    ];
    final capped =
        (ref.watch(budgetStatusesProvider).value ?? const <BudgetStatus>[]).any(
          (s) => s.categoryId == _categoryId,
        );
    final error = _error;
    return PSheet(
      title: FinanceStrings.editBudget,
      footer: [
        if (capped)
          PButton.ghost(
            label: FinanceStrings.removeCap,
            onPressed: _busy ? null : () => _write(Rupiah.zero),
          ),
        PButton.primary(
          label: PulseStrings.save,
          onPressed: _busy ? null : _save,
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: PulseSpace.s3,
        children: [
          PChoiceChips(
            label: FinanceStrings.category,
            options: [for (final c in categories) (c.id, c.name, c.color)],
            value: _categoryId ?? '',
            onChanged: (id) => setState(() {
              _categoryId = id;
              _cap.text = _capText(id);
              _error = null;
            }),
          ),
          LabelledField(
            label: FinanceStrings.monthlyCap,
            child: ShadInput(
              key: const ValueKey(FinanceStrings.monthlyCap),
              controller: _cap,
            ),
          ),
          const Text(FinanceStrings.capNote),
          if (error != null) FormError(error),
        ],
      ),
    );
  }
}
