import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shad/shad.dart';

import '../../app/di.dart';
import '../../core/failures.dart';
import '../../core/local_date.dart';
import '../../core/rupiah.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/wallet.dart';
import '../../domain/parser/amount_rules.dart' show readAmount;
import '../../ui/day_label.dart';
import '../../ui/strings.dart';
import '../../ui/widgets/p_picker.dart';
import '../../ui/widgets/widgets.dart';
import 'finance_strings.dart';
import 'form_fields.dart';

/// Edits [transaction], or records a new transfer when it is null. Pops with
/// true after a delete.
class TransactionSheet extends ConsumerStatefulWidget {
  const TransactionSheet({super.key, this.transaction});

  final Transaction? transaction;

  @override
  ConsumerState<TransactionSheet> createState() => _TransactionSheetState();
}

class _TransactionSheetState extends ConsumerState<TransactionSheet> {
  late final Transaction? _old = widget.transaction;
  late TxnType _type = _old?.type ?? TxnType.transfer;
  late final _amount = TextEditingController(
    text: _old == null ? '' : '${_old.amount.value}',
  );
  late final _description = TextEditingController(text: _old?.description);
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

  /// Null until a date is picked: the stored instant and day stay as they are.
  DateTime? _picked;
  bool _confirmDelete = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = message;
    });
  }

  Future<void> _run(Future<void> Function() write, {bool? result}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await write();
      if (mounted) Navigator.of(context).pop(result);
    } on AppFailure {
      _fail(FinanceStrings.saveFailed);
    }
  }

  Future<void> _save() async {
    final amount = readAmount(
      _amount.text.replaceAll(RegExp(r'\s'), '').toLowerCase(),
    )?.value;
    final walletId = _walletId;
    final transfer = _type == TxnType.transfer;
    if (amount == null) return _fail(FinanceStrings.amountError);
    if (walletId == null) return _fail(FinanceStrings.walletError);
    if (transfer && (_toWalletId == null || _toWalletId == walletId)) {
      return _fail(FinanceStrings.transferError);
    }

    final old = _old;
    final picked = _picked;
    final clock = ref.read(clockProvider);
    final input = TransactionInput(
      type: _type,
      amount: Rupiah(amount),
      walletId: walletId,
      toWalletId: transfer ? _toWalletId : null,
      categoryId: transfer ? null : _categoryId,
      description: _description.text.trim(),
      occurredAt: picked?.toUtc() ?? old?.occurredAt ?? clock.nowUtc(),
      occurredOn: picked != null
          ? LocalDate.fromDateTime(picked)
          : old?.occurredOn ?? clock.today(),
      // An update replaces every column: keep the links.
      parentTransactionId: old?.parentTransactionId,
      sourceActionItemId: old?.sourceActionItemId,
    );
    final repository = ref.read(transactionRepositoryProvider);
    await _run(() async {
      old == null
          ? await repository.create(input)
          : await repository.update(old.id, input);
    });
  }

  Widget _chip(
    String field,
    String label,
    VoidCallback onPressed, [
    int? dot,
  ]) => LabelledField(
    label: field,
    child: Align(
      alignment: Alignment.centerLeft,
      child: PChip(
        key: ValueKey(field),
        field: field,
        label: label,
        dotColor: dot,
        onPressed: onPressed,
      ),
    ),
  );

  Widget _walletChip(
    String field,
    List<Wallet> wallets,
    String? selected,
    ValueChanged<String> onPicked,
  ) {
    final wallet = wallets.where((w) => w.id == selected).firstOrNull;
    // An archived wallet stays only where this transaction already uses it.
    final kept = {_old?.walletId, _old?.toWalletId};
    return _chip(field, wallet?.name ?? FinanceStrings.wallet, () async {
      final picked = await showPOptions<String>(
        context,
        title: field,
        selected: selected,
        options: [
          for (final w in wallets)
            if (!w.isArchived || kept.contains(w.id))
              (value: w.id, label: w.name, dotColor: w.color),
        ],
      );
      if (picked != null && mounted) setState(() => onPicked(picked));
    }, wallet?.color);
  }

  Future<void> _pickCategory(List<Category> categories) async {
    final kind = _type == TxnType.income
        ? CategoryKind.income
        : CategoryKind.outcome;
    final picked = await showCategoryPicker(
      context,
      title: FinanceStrings.category,
      selected: _categoryId,
      options: [
        for (final c in categories)
          if (!c.isArchived && c.kind == kind) c,
      ],
      onCreate: (name) async =>
          (await ref
                  .read(categoryRepositoryProvider)
                  .create(newCategoryInput(name, kind, categories)))
              .id,
    );
    if (picked != null && mounted) setState(() => _categoryId = picked);
  }

  @override
  Widget build(BuildContext context) {
    final old = _old;
    final wallets = [
      for (final b
          in ref.watch(walletBalancesProvider).value ?? <WalletBalance>[])
        b.wallet,
    ];
    final categories =
        ref.watch(categoriesProvider).value ?? const <Category>[];
    final category = categories.where((c) => c.id == _categoryId).firstOrNull;
    final transfer = _type == TxnType.transfer;
    final clock = ref.read(clockProvider);
    final when = _picked ?? old?.occurredAt.toLocal() ?? clock.nowLocal();
    final day = _picked == null && old != null
        ? old.occurredOn
        : LocalDate.fromDateTime(when);
    final error = _error;

    return PSheet(
      title: old == null
          ? FinanceStrings.newTransfer
          : FinanceStrings.editTransaction,
      footer: [
        if (old != null)
          _confirmDelete
              ? PButton.destructive(
                  label: FinanceStrings.confirmDelete,
                  onPressed: () => _run(
                    () => ref
                        .read(transactionRepositoryProvider)
                        .softDelete(old.id),
                    result: true,
                  ),
                )
              : PButton.ghost(
                  label: FinanceStrings.delete,
                  onPressed: () => setState(() => _confirmDelete = true),
                ),
        PButton.primary(
          label: MelaStrings.save,
          onPressed: _busy ? null : _save,
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: MelaSpace.s3,
        children: [
          if (!transfer)
            Wrap(
              spacing: MelaSpace.s2,
              children: [
                for (final (type, label) in const [
                  (TxnType.outcome, MelaStrings.expense),
                  (TxnType.income, MelaStrings.income),
                ])
                  PChip(
                    label: label,
                    selected: _type == type,
                    onPressed: () => setState(() {
                      // A category belongs to one kind.
                      if (_type != type) _categoryId = null;
                      _type = type;
                    }),
                  ),
              ],
            ),
          LabelledField(
            label: FinanceStrings.amount,
            child: ShadInput(
              key: const ValueKey(FinanceStrings.amount),
              controller: _amount,
            ),
          ),
          _walletChip(
            transfer ? FinanceStrings.fromWallet : FinanceStrings.wallet,
            wallets,
            _walletId,
            (id) => _walletId = id,
          ),
          if (transfer)
            _walletChip(
              FinanceStrings.toWallet,
              wallets,
              _toWalletId,
              (id) => _toWalletId = id,
            )
          else
            _chip(
              FinanceStrings.category,
              category?.name ?? FinanceStrings.uncategorized,
              () => _pickCategory(categories),
              category?.color,
            ),
          LabelledField(
            label: FinanceStrings.description,
            child: ShadInput(
              key: const ValueKey(FinanceStrings.description),
              controller: _description,
            ),
          ),
          _chip(
            FinanceStrings.date,
            '${dayLabel(day, clock.today())} ${timeLabel(when)}',
            () async {
              final picked = await showPDateTime(
                context,
                title: FinanceStrings.date,
                timeFieldLabel: FinanceStrings.time,
                timeError: FinanceStrings.timeError,
                initial: when,
              );
              if (picked != null && mounted) setState(() => _picked = picked);
            },
          ),
          if (error != null) FormError(error),
        ],
      ),
    );
  }
}
