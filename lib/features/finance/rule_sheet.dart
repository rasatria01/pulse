import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shad/shad.dart';

import '../../app/di.dart';
import '../../core/failures.dart';
import '../../core/local_date.dart';
import '../../core/rupiah.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/recurring_rule.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/wallet.dart';
import '../../domain/parser/amount_rules.dart' show readAmount;
import '../../ui/day_label.dart';
import '../../ui/planner/bill_sheet.dart' show PChoiceChips;
import '../../ui/planner/form_fields.dart' show PChoiceField, PDateField;
import '../../ui/strings.dart';
import '../../ui/widgets/widgets.dart';
import 'finance_strings.dart';
import 'form_fields.dart';

String _freqLabel(RecurFreq freq) => switch (freq) {
  RecurFreq.daily => FinanceStrings.daily,
  RecurFreq.weekly => FinanceStrings.weekly,
  RecurFreq.monthly => FinanceStrings.monthly,
  RecurFreq.yearly => FinanceStrings.yearly,
};

String _unit(RecurFreq freq) => switch (freq) {
  RecurFreq.daily => FinanceStrings.days,
  RecurFreq.weekly => FinanceStrings.weeks,
  RecurFreq.monthly => FinanceStrings.months,
  RecurFreq.yearly => FinanceStrings.years,
};

/// "Monthly · Next 28 Feb · Ask me", for the rule list.
String ruleSummary(RecurringRule rule, LocalDate today) {
  final end = rule.endDate;
  return [
    rule.interval == 1
        ? _freqLabel(rule.freq)
        : FinanceStrings.everyN(rule.interval, _unit(rule.freq)),
    if (rule.isPaused)
      FinanceStrings.paused
    else if (end != null && rule.nextDueDate.isAfter(end))
      FinanceStrings.ended
    else
      FinanceStrings.next(dayLabel(rule.nextDueDate, today)),
    rule.autoPost ? FinanceStrings.autoPost : FinanceStrings.remind,
  ].join(' · ');
}

/// Adds a recurring rule, or edits, pauses or deletes [rule].
class RuleSheet extends ConsumerStatefulWidget {
  const RuleSheet({super.key, this.rule});

  final RecurringRule? rule;

  @override
  ConsumerState<RuleSheet> createState() => _RuleSheetState();
}

class _RuleSheetState extends ConsumerState<RuleSheet> {
  late final RecurringRule? _old = widget.rule;
  late final _name = TextEditingController(text: _old?.name);
  late final _amount = TextEditingController(
    text: _old == null ? '' : '${_old.amount.value}',
  );
  late final _interval = TextEditingController(text: '${_old?.interval ?? 1}');
  late TxnType _type = _old?.type ?? TxnType.outcome;
  late String? _walletId =
      _old?.walletId ??
      ref
          .read(walletBalancesProvider)
          .value
          ?.where((w) => w.wallet.isDefault)
          .firstOrNull
          ?.wallet
          .id;
  late String? _toWalletId = _old?.toWalletId;
  late String? _categoryId = _old?.categoryId;
  late RecurFreq _freq = _old?.freq ?? RecurFreq.monthly;
  late LocalDate _start = _old?.startDate ?? ref.read(todayProvider);
  late LocalDate? _end = _old?.endDate;
  late bool _autoPost = _old?.autoPost ?? false;
  bool _confirmDelete = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _interval.dispose();
    super.dispose();
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = message;
    });
  }

  Future<void> _run(Future<void> Function() write) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await write();
      if (mounted) Navigator.of(context).pop();
    } on AppFailure {
      _fail(FinanceStrings.saveFailed);
    }
  }

  /// Saves the form, then pauses or resumes if [paused] is given.
  Future<void> _save({bool? paused}) async {
    final name = _name.text.trim();
    final amount = readAmount(
      _amount.text.replaceAll(RegExp(r'\s'), '').toLowerCase(),
    )?.value;
    final interval = int.tryParse(_interval.text.trim());
    final walletId = _walletId;
    final transfer = _type == TxnType.transfer;
    final end = _end;
    if (name.isEmpty) return _fail(FinanceStrings.nameError);
    if (amount == null) return _fail(FinanceStrings.amountError);
    if (walletId == null) return _fail(FinanceStrings.walletError);
    if (transfer && (_toWalletId == null || _toWalletId == walletId)) {
      return _fail(FinanceStrings.transferError);
    }
    if (interval == null || interval < 1 || interval > 999) {
      return _fail(FinanceStrings.intervalError);
    }
    if (end != null && end.isBefore(_start)) {
      return _fail(FinanceStrings.endError);
    }

    final input = RecurringRuleInput(
      name: name,
      type: _type,
      amount: Rupiah(amount),
      walletId: walletId,
      toWalletId: transfer ? _toWalletId : null,
      categoryId: transfer ? null : _categoryId,
      description: _old?.description ?? '',
      freq: _freq,
      interval: interval,
      startDate: _start,
      endDate: end,
      nextDueDate: _start,
      autoPost: _autoPost,
    );
    final service = ref.read(recurringRuleServiceProvider);
    final old = _old;
    await _run(() async {
      if (old == null) return service.create(input);
      // Pause first: the edit's catch-up must not post a rule being paused.
      if (paused == true) await service.setPaused(old.id, true);
      await service.edit(old.id, input);
      if (paused == false) await service.setPaused(old.id, false);
    });
  }

  Widget _input(String label, TextEditingController controller) =>
      LabelledField(
        label: label,
        child: ShadInput(key: ValueKey(label), controller: controller),
      );

  Widget _wallets(
    String label,
    List<Wallet> wallets,
    String? selected,
    ValueChanged<String> onPicked,
  ) {
    // An archived wallet stays only where this rule already uses it.
    final kept = {_old?.walletId, _old?.toWalletId};
    return PChoiceChips(
      label: label,
      options: [
        for (final w in wallets)
          if (!w.isArchived || kept.contains(w.id)) (w.id, w.name, w.color),
      ],
      value: selected ?? '',
      onChanged: (id) => setState(() => onPicked(id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final old = _old;
    final today = ref.watch(todayProvider);
    final wallets = [
      for (final b
          in ref.watch(walletBalancesProvider).value ?? <WalletBalance>[])
        b.wallet,
    ];
    final kind = _type == TxnType.income
        ? CategoryKind.income
        : CategoryKind.outcome;
    final categories = [
      for (final c in ref.watch(categoriesProvider).value ?? const <Category>[])
        if (c.kind == kind && (!c.isArchived || c.id == old?.categoryId)) c,
    ];
    final transfer = _type == TxnType.transfer;
    final error = _error;

    return PSheet(
      title: old == null
          ? FinanceStrings.addRecurring
          : FinanceStrings.editRecurring,
      footer: [
        if (old != null) ...[
          _confirmDelete
              ? PButton.destructive(
                  label: FinanceStrings.confirmDelete,
                  onPressed: () => _run(
                    () => ref.read(recurringRuleServiceProvider).delete(old.id),
                  ),
                )
              : PButton.ghost(
                  label: FinanceStrings.delete,
                  onPressed: () => setState(() => _confirmDelete = true),
                ),
          PButton.secondary(
            label: old.isPaused ? FinanceStrings.resume : FinanceStrings.pause,
            onPressed: _busy ? null : () => _save(paused: !old.isPaused),
          ),
        ],
        PButton.primary(
          label: MelaStrings.save,
          onPressed: _busy ? null : () => _save(),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: MelaSpace.s3,
        children: [
          _input(FinanceStrings.name, _name),
          PChoiceField<TxnType>(
            label: FinanceStrings.type,
            options: const [
              (TxnType.outcome, MelaStrings.expense),
              (TxnType.income, MelaStrings.income),
              (TxnType.transfer, MelaStrings.transfer),
            ],
            value: _type,
            onChanged: (type) => setState(() {
              // A category belongs to one kind.
              if (_type != type) _categoryId = null;
              _type = type;
            }),
          ),
          _input(FinanceStrings.amount, _amount),
          _wallets(
            transfer ? FinanceStrings.fromWallet : FinanceStrings.wallet,
            wallets,
            _walletId,
            (id) => _walletId = id,
          ),
          if (transfer)
            _wallets(
              FinanceStrings.toWallet,
              wallets,
              _toWalletId,
              (id) => _toWalletId = id,
            )
          else
            PChoiceChips(
              label: FinanceStrings.category,
              options: [for (final c in categories) (c.id, c.name, c.color)],
              // Nothing picked saves as Uncategorized.
              value: _categoryId ?? '',
              onChanged: (id) => setState(() => _categoryId = id),
            ),
          PChoiceField<RecurFreq>(
            label: FinanceStrings.repeats,
            options: [for (final f in RecurFreq.values) (f, _freqLabel(f))],
            value: _freq,
            onChanged: (freq) => setState(() => _freq = freq),
          ),
          _input(FinanceStrings.every, _interval),
          PDateField(
            label: FinanceStrings.startDate,
            value: _start,
            today: today,
            allowNone: false,
            onChanged: (day) => setState(() => _start = day ?? _start),
          ),
          PDateField(
            label: FinanceStrings.endDate,
            value: _end,
            today: today,
            onChanged: (day) => setState(() => _end = day),
          ),
          PChoiceField<bool>(
            label: FinanceStrings.whenDue,
            options: const [
              (false, FinanceStrings.remind),
              (true, FinanceStrings.autoPost),
            ],
            value: _autoPost,
            onChanged: (value) => setState(() => _autoPost = value),
          ),
          if (error != null) FormError(error),
        ],
      ),
    );
  }
}
