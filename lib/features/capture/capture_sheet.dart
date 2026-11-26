import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shad/shad.dart';

import '../../app/di.dart';
import '../../core/failures.dart';
import '../../core/local_date.dart';
import '../../core/rupiah.dart';
import '../../domain/entities/action_item.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/wallet.dart';
import '../../domain/parser/amount_rules.dart' show readAmount;
import '../../domain/parser/capture_parser.dart';
import '../../domain/parser/parse_result.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../ui/strings.dart';
import '../../ui/widgets/p_picker.dart';
import '../../ui/widgets/widgets.dart';
import 'capture_chips.dart';
import 'capture_strings.dart';

/// What the 5 s Undo offers.
typedef CaptureUndo = ({String message, VoidCallback undo});

/// Opened by the shell's capture bar. A save still inside its Undo window when
/// the sheet closes gets the app snackbar instead.
Future<void> showCaptureSheet(BuildContext context) async {
  CaptureUndo? pending;
  await showPSheet<void>(
    context: context,
    builder: (context) => CaptureSheet(onUndoChanged: (u) => pending = u),
  );
  final left = pending;
  if (left != null && context.mounted) {
    showPSnackbar(context, message: left.message, onUndo: left.undo);
  }
}

class CaptureSheet extends ConsumerStatefulWidget {
  const CaptureSheet({super.key, this.onUndoChanged});

  final ValueChanged<CaptureUndo?>? onUndoChanged;

  @override
  ConsumerState<CaptureSheet> createState() => _CaptureSheetState();
}

class _CaptureSheetState extends ConsumerState<CaptureSheet> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  late final SettingsRepository _settings;
  String _stored = '';

  // Values picked through a chip; they win until the entry is saved or cleared.
  CaptureKind? _kind;
  String? _walletId, _toWalletId, _categoryId;
  int? _amount;
  DateTime? _when;
  Priority? _priority;

  bool _saving = false;
  String? _error;
  CaptureUndo? _undo;
  Timer? _undoTimer;

  @override
  void initState() {
    super.initState();
    _settings = ref.read(settingsRepositoryProvider);
    _text.addListener(_onText);
    _restore();
  }

  @override
  void dispose() {
    _undoTimer?.cancel();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    final draft = await _settings.watch(SettingKeys.captureDraft).first;
    if (!mounted || draft == null || _text.text.isNotEmpty) return;
    _stored = draft;
    _text.value = TextEditingValue(
      text: draft,
      selection: TextSelection.collapsed(offset: draft.length),
    );
  }

  /// Written on every change, so unsaved text survives the app being
  /// backgrounded or killed.
  void _onText() {
    final text = _text.text;
    if (text != _stored) {
      _stored = text;
      _settings.put(SettingKeys.captureDraft, text).ignore();
      _error = null;
      if (text.isEmpty) _clearOverrides();
    }
    setState(() {});
  }

  void _clearOverrides() {
    _kind = null;
    _walletId = _toWalletId = _categoryId = null;
    _amount = null;
    _when = null;
    _priority = null;
  }

  /// Null until the wallets and categories have loaded.
  ({List<Wallet> wallets, List<Category> categories})? get _lookups {
    final balances = ref.read(walletBalancesProvider).value;
    final categories = ref.read(categoriesProvider).value;
    if (balances == null || categories == null) return null;
    return (
      wallets: [for (final b in balances) b.wallet],
      categories: categories,
    );
  }

  ParseResult _parse(List<Wallet> wallets, List<Category> categories) =>
      parseCapture(
        _text.text,
        ParseContext(
          ref.read(clockProvider).nowLocal(),
          [
            for (final w in wallets)
              WalletRef(
                id: w.id,
                slug: w.slug,
                aliases: w.aliases,
                isDefault: w.isDefault,
                isArchived: w.isArchived,
              ),
          ],
          [
            for (final c in categories)
              if (!c.isArchived)
                CategoryRef(
                  id: c.id,
                  slug: c.slug,
                  aliases: c.aliases,
                  kind: c.kind,
                ),
          ],
        ),
        overrides: CaptureOverrides(
          kind: _kind,
          walletId: _walletId,
          toWalletId: _toWalletId,
          categoryId: _categoryId,
          amount: _amount,
          when: _when,
          priority: _priority,
        ),
      );

  Future<void> _save() async {
    final lookups = _lookups;
    if (_saving || lookups == null) return;
    final draft = _parse(lookups.wallets, lookups.categories);
    if (!draft.canSave) return;
    final raw = _text.text;
    final service = ref.read(captureServiceProvider);
    setState(() => _saving = true);
    try {
      final outcome = await service.commit(draft);
      // Even if the sheet is gone, the saved text must not come back.
      if (!mounted) {
        await _settings.put(SettingKeys.captureDraft, '');
        return;
      }
      // Text typed while saving is the next entry.
      if (_text.text == raw) _text.clear();
      _clearOverrides();
      var undone = false;
      _offerUndo((
        message: _savedMessage(draft, lookups.wallets),
        undo: () {
          if (undone) return;
          undone = true;
          _offerUndo(null);
          service.undo(outcome).catchError((Object _) {
            if (mounted) setState(() => _error = CaptureStrings.undoFailed);
          });
        },
      ));
    } on AppFailure {
      if (mounted) setState(() => _error = CaptureStrings.saveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _offerUndo(CaptureUndo? undo) {
    widget.onUndoChanged?.call(undo);
    _undoTimer?.cancel();
    if (!mounted) return;
    _undoTimer = undo == null
        ? null
        : Timer(const Duration(seconds: 5), () => _offerUndo(null));
    setState(() => _undo = undo);
  }

  String _savedMessage(ParseResult draft, List<Wallet> wallets) {
    String name(String? id) =>
        wallets.where((w) => w.id == id).firstOrNull?.name ?? '';
    return switch (draft) {
      TransactionDraft d => CaptureStrings.savedTo(
        d.description.isNotEmpty
            ? CaptureStrings.quoted(d.description)
            : d.type == TxnType.transfer
            ? CaptureStrings.aTransfer
            : formatAmount(Rupiah(d.amount!), AmountType.of(d.type)),
        name(d.type == TxnType.transfer ? d.toWalletId : d.walletId),
      ),
      ActionItemDraft d => CaptureStrings.savedTask(d.title),
      NoteDraft d => CaptureStrings.savedNote(d.title),
    };
  }

  // Pickers.

  Future<void> _pick(CaptureField field) async {
    final lookups = _lookups;
    if (lookups == null) return;
    final draft = _parse(lookups.wallets, lookups.categories);
    switch (field) {
      case CaptureField.kind:
        final picked = await showPOptions<CaptureKind>(
          context,
          title: CaptureStrings.kind,
          selected: switch (draft) {
            TransactionDraft() => CaptureKind.transaction,
            ActionItemDraft() => CaptureKind.actionItem,
            NoteDraft() => CaptureKind.note,
          },
          options: [
            for (final (kind, label) in const [
              (CaptureKind.transaction, CaptureStrings.transaction),
              (CaptureKind.actionItem, CaptureStrings.task),
              (CaptureKind.note, CaptureStrings.note),
            ])
              (value: kind, label: label, dotColor: null),
          ],
        );
        if (picked != null) _kind = picked;
      case CaptureField.amount:
        final picked = await showPSheet<int>(
          context: context,
          builder: (context) => const _AmountSheet(),
        );
        if (picked != null) _amount = picked;
      case CaptureField.wallet || CaptureField.toWallet:
        final to = field == CaptureField.toWallet;
        final picked = await showPOptions<String>(
          context,
          title: to ? CaptureStrings.toWallet : CaptureStrings.wallet,
          selected: switch (draft) {
            TransactionDraft d => to ? d.toWalletId : d.walletId,
            ActionItemDraft d => d.linkedWalletId,
            NoteDraft() => null,
          },
          options: [
            for (final w in lookups.wallets)
              if (!w.isArchived)
                (value: w.id, label: w.name, dotColor: w.color),
          ],
        );
        if (picked != null) {
          to ? _toWalletId = picked : _walletId = picked;
        }
      case CaptureField.category:
        final kind = draft is TransactionDraft && draft.type == TxnType.income
            ? CategoryKind.income
            : CategoryKind.outcome;
        final selected = switch (draft) {
          TransactionDraft d => d.categoryId,
          ActionItemDraft d => d.linkedCategoryId,
          NoteDraft() => null,
        };
        // An unmatched #word is the likeliest name for a new category.
        final typed = selected != null
            ? null
            : draft.tokens
                      .where(
                        (t) => t.kind == TokenKind.tag && t.value != 'bill',
                      )
                      .firstOrNull
                      ?.value
                  as String?;
        final picked = await showCategoryPicker(
          context,
          title: CaptureStrings.category,
          selected: selected,
          initialQuery: typed ?? '',
          options: [
            for (final c in lookups.categories)
              if (!c.isArchived && c.kind == kind) c,
          ],
          onCreate: (name) async =>
              (await ref
                      .read(categoryRepositoryProvider)
                      .create(newCategoryInput(name, kind, lookups.categories)))
                  .id,
        );
        if (picked != null) _categoryId = picked;
      case CaptureField.when:
        final picked = await showPDateTime(
          context,
          title: CaptureStrings.date,
          timeFieldLabel: CaptureStrings.time,
          timeError: CaptureStrings.timeError,
          initial: switch (draft) {
            TransactionDraft d => d.occurredAt,
            ActionItemDraft d => d.scheduledStart ?? _nineOn(d.dueDate),
            NoteDraft() => ref.read(clockProvider).nowLocal(),
          },
        );
        if (picked != null) _when = picked;
      case CaptureField.priority:
        final picked = await showPOptions<Priority>(
          context,
          title: CaptureStrings.priority,
          selected: draft is ActionItemDraft ? draft.priority : null,
          options: [
            for (final p in Priority.values)
              (value: p, label: priorityLabel(p), dotColor: null),
          ],
        );
        if (picked != null) _priority = picked;
      case CaptureField.tags:
        await _pickTag(draft);
    }
    if (!mounted) return;
    setState(() {});
    _focus.requestFocus();
  }

  DateTime _nineOn(LocalDate? day) {
    final on = day ?? ref.read(clockProvider).today();
    return DateTime(on.year, on.month, on.day, 9);
  }

  /// Tags live in the text: picking one adds or removes its #word.
  Future<void> _pickTag(ParseResult draft) async {
    final tags = await ref.read(tagRepositoryProvider).watchAll().first;
    if (!mounted) return;
    final picked = await showPOptions<String>(
      context,
      title: CaptureStrings.tags,
      empty: CaptureStrings.noTags,
      options: [
        for (final tag in tags)
          (value: tag.slug, label: '#${tag.slug}', dotColor: null),
      ],
    );
    if (picked == null || !mounted) return;
    var text = _text.text;
    final present = [
      for (final t in draft.tokens)
        if (t.kind == TokenKind.tag && t.value == picked) t,
    ];
    if (present.isEmpty) {
      text = '${text.trimRight()} #$picked';
    } else {
      for (final token in present.reversed) {
        text = text.replaceRange(token.start, token.end, '');
      }
      text = text.replaceAll(RegExp(' {2,}'), ' ').trim();
    }
    _text.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ShadTheme.of(context).colorScheme;
    // Watched so that the chips follow a wallet or category change.
    ref.watch(walletBalancesProvider);
    ref.watch(categoriesProvider);
    final lookups = _lookups;
    final draft = lookups != null && _text.text.trim().isNotEmpty
        ? _parse(lookups.wallets, lookups.categories)
        : null;
    final chips = draft == null
        ? const <PChip>[]
        : captureChips(
            draft,
            wallets: lookups!.wallets,
            categories: lookups.categories,
            today: ref.read(clockProvider).today(),
            whenPicked: _when != null,
            onTap: _pick,
          );
    final hint = draft == null ? null : captureHint(draft, lookups!.wallets);
    // The bar shows its hint only next to a red chip.
    final loose = chips.any((c) => c.tone == PChipTone.error) ? null : hint;
    final undo = _undo;
    final error = _error;
    return PSheet(
      title: MelaStrings.quickCapture,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: MelaSpace.s2,
        children: [
          PCaptureBar.open(
            controller: _text,
            focusNode: _focus,
            chips: chips,
            hint: hint,
            onSave: draft != null && draft.canSave && !_saving ? _save : null,
          ),
          if (loose != null)
            Text(
              loose,
              style: MelaText.caption.copyWith(color: colors.mutedForeground),
            ),
          if (error != null)
            Semantics(
              liveRegion: true,
              child: Text(
                error,
                style: MelaText.caption.copyWith(color: colors.destructive),
              ),
            ),
          // Inside the sheet: the app snackbar would sit behind the keyboard.
          if (undo != null)
            PSnackbar(message: undo.message, onAction: undo.undo),
        ],
      ),
    );
  }
}

class _AmountSheet extends StatefulWidget {
  const _AmountSheet();

  @override
  State<_AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends State<_AmountSheet> {
  final _text = TextEditingController();
  bool _invalid = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _save() {
    final value = readAmount(_text.text.trim().toLowerCase())?.value;
    if (value == null) {
      setState(() => _invalid = true);
    } else {
      Navigator.of(context).pop(value);
    }
  }

  @override
  Widget build(BuildContext context) => PSheet(
    title: CaptureStrings.amount,
    footer: [PButton.primary(label: MelaStrings.save, onPressed: _save)],
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: MelaSpace.s2,
      children: [
        Semantics(
          label: CaptureStrings.amount,
          child: ShadInput(
            key: const ValueKey('amount-field'),
            controller: _text,
            autofocus: true,
            placeholder: const Text(CaptureStrings.amount),
            onSubmitted: (_) => _save(),
          ),
        ),
        if (_invalid)
          Text(
            CaptureStrings.amountError,
            style: MelaText.caption.copyWith(
              color: ShadTheme.of(context).colorScheme.destructive,
            ),
          ),
      ],
    ),
  );
}
