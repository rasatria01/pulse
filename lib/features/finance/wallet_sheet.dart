import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shad/shad.dart';

import '../../app/di.dart';
import '../../core/failures.dart';
import '../../core/rupiah.dart';
import '../../domain/entities/wallet.dart';
import '../../domain/parser/amount_rules.dart' show readAmount;
import '../../ui/strings.dart';
import '../../ui/widgets/widgets.dart';
import 'finance_strings.dart';
import 'form_fields.dart';

final _slugShape = RegExp(r'^[a-z0-9_-]+$');

String _kindLabel(WalletKind kind) => switch (kind) {
  WalletKind.cash => FinanceStrings.cash,
  WalletKind.bank => FinanceStrings.bank,
  WalletKind.ewallet => FinanceStrings.ewallet,
  WalletKind.other => FinanceStrings.other,
};

String _kindIcon(WalletKind kind) => switch (kind) {
  WalletKind.cash => 'banknote',
  WalletKind.bank => 'landmark',
  WalletKind.ewallet => 'smartphone',
  WalletKind.other => 'wallet',
};

/// A balance may be zero or negative, unlike a captured amount. Null when
/// [input] is not a balance.
int? parseBalance(String input) {
  var text = input.replaceAll(RegExp(r'\s'), '').toLowerCase();
  if (text.isEmpty) return 0;
  final negative = text.startsWith('-') || text.startsWith('−');
  if (negative) text = text.substring(1);
  if (text == '0') return 0;
  final value = readAmount(text)?.value;
  return value == null ? null : (negative ? -value : value);
}

/// Adds a wallet, or edits [wallet].
class WalletSheet extends ConsumerStatefulWidget {
  const WalletSheet({super.key, this.wallet});

  final Wallet? wallet;

  @override
  ConsumerState<WalletSheet> createState() => _WalletSheetState();
}

class _WalletSheetState extends ConsumerState<WalletSheet> {
  late final Wallet? _old = widget.wallet;
  late final _name = TextEditingController(text: _old?.name);
  late final _slug = TextEditingController(text: _old?.slug);
  late final _aliases = TextEditingController(text: _old?.aliases.join(' '));
  late final _balance = TextEditingController(
    text: _old == null ? '' : '${_old.initialBalance.value}',
  );
  late WalletKind _kind = _old?.kind ?? WalletKind.cash;
  late int _color = _old?.color ?? MelaIdentity.slate.toARGB32();
  late bool _include = _old?.includeInTotal ?? true;
  bool _confirmArchive = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _slug, _aliases, _balance]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<void> Function() write, {String slug = ''}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await write();
      if (mounted) Navigator.of(context).pop();
    } on ConflictFailure {
      _fail(FinanceStrings.handleTaken(slug));
    } on AppFailure {
      _fail(FinanceStrings.saveFailed);
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = message;
    });
  }

  /// Saves the form. [then] runs in the same transaction, so Set default and
  /// Archive keep unsaved edits.
  Future<void> _save([Future<void> Function(String id)? then]) async {
    final name = _name.text.trim();
    // A new wallet may leave the handle to its name.
    var slug = _slug.text.trim().toLowerCase();
    if (slug.isEmpty) {
      slug = name.toLowerCase().replaceAll(RegExp('[^a-z0-9_-]'), '');
    }
    final aliases = _aliases.text
        .toLowerCase()
        .split(RegExp(r'[\s,]+'))
        .where((a) => a.isNotEmpty)
        .toList();
    final balance = parseBalance(_balance.text);
    if (name.isEmpty) return _fail(FinanceStrings.nameError);
    if (![slug, ...aliases].every(_slugShape.hasMatch)) {
      return _fail(FinanceStrings.handleError);
    }
    if (balance == null) return _fail(FinanceStrings.balanceError);

    final repository = ref.read(walletRepositoryProvider);
    final unitOfWork = ref.read(unitOfWorkProvider);
    final old = _old;
    await _run(slug: slug, () async {
      if (old == null) {
        await repository.create(
          WalletInput(
            name: name,
            slug: slug,
            aliases: aliases,
            kind: _kind,
            initialBalance: Rupiah(balance),
            color: _color,
            icon: _kindIcon(_kind),
            includeInTotal: _include,
          ),
        );
        return;
      }
      await unitOfWork.run(() async {
        await repository.update(
          old.id,
          WalletPatch(
            name: name,
            slug: slug,
            aliases: aliases,
            kind: _kind,
            initialBalance: Rupiah(balance),
            color: _color,
            icon: _kind == old.kind ? null : _kindIcon(_kind),
            includeInTotal: _include,
          ),
        );
        await then?.call(old.id);
      });
    });
  }

  Widget _input(String label, TextEditingController controller) =>
      LabelledField(
        label: label,
        child: ShadInput(key: ValueKey(label), controller: controller),
      );

  @override
  Widget build(BuildContext context) {
    final old = _old;
    final canRetire = old != null && !old.isDefault && !old.isArchived;
    final repository = ref.read(walletRepositoryProvider);
    final error = _error;
    return PSheet(
      title: old == null ? FinanceStrings.addWallet : FinanceStrings.editWallet,
      footer: [
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
          _input(FinanceStrings.handle, _slug),
          _input(FinanceStrings.aliases, _aliases),
          _input(FinanceStrings.startingBalance, _balance),
          LabelledField(
            label: FinanceStrings.type,
            child: Wrap(
              spacing: MelaSpace.s2,
              children: [
                for (final kind in WalletKind.values)
                  PChip(
                    label: _kindLabel(kind),
                    selected: kind == _kind,
                    onPressed: () => setState(() => _kind = kind),
                  ),
              ],
            ),
          ),
          LabelledField(
            label: FinanceStrings.colour,
            child: Wrap(
              spacing: MelaSpace.s2,
              children: [
                for (final (i, color) in MelaIdentity.all.indexed)
                  PChip(
                    label: FinanceStrings.colourNames[i],
                    dotColor: color.toARGB32(),
                    selected: color.toARGB32() == _color,
                    onPressed: () => setState(() => _color = color.toARGB32()),
                  ),
              ],
            ),
          ),
          Wrap(
            children: [
              PChip(
                label: FinanceStrings.includeInTotal,
                icon: _include ? LucideIcons.check : LucideIcons.x,
                selected: _include,
                onPressed: () => setState(() => _include = !_include),
              ),
            ],
          ),
          if (canRetire) ...[
            Wrap(
              spacing: MelaSpace.s2,
              children: [
                PButton.secondary(
                  label: FinanceStrings.setDefault,
                  onPressed: () => _save(repository.setDefault),
                ),
                if (_confirmArchive)
                  PButton.destructive(
                    label: FinanceStrings.confirmArchive,
                    onPressed: () => _save(repository.archive),
                  )
                else
                  PButton.outline(
                    label: FinanceStrings.archive,
                    onPressed: () => setState(() => _confirmArchive = true),
                  ),
              ],
            ),
            if (_confirmArchive) const Text(FinanceStrings.archiveWarning),
          ],
          if (error != null) FormError(error),
        ],
      ),
    );
  }
}
