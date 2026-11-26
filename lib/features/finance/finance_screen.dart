import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shad/shad.dart';

import '../../app/di.dart';
import '../../core/local_date.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/recurring_rule.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/wallet.dart';
import '../../ui/day_label.dart';
import '../../ui/strings.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/widgets.dart';
import 'budget_sheet.dart';
import 'finance_strings.dart';
import 'rule_sheet.dart';
import 'transaction_sheet.dart';
import 'wallet_sheet.dart';

const _page = 90; // days of history per "Show older"

final _historyProvider = StreamProvider.autoDispose
    .family<List<Transaction>, LocalDate>(
      (ref, from) => ref
          .watch(transactionRepositoryProvider)
          .watchRange(from, const LocalDate(9999, 12, 31)),
    );

class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  bool _showArchived = false;
  int _days = _page;

  /// Kept while a longer history loads, so the list and scroll position stay.
  List<Transaction>? _transactions;

  /// Above the capture bar and tabs, so the keyboard inset is counted once.
  BuildContext get _root => Navigator.of(context, rootNavigator: true).context;

  Future<void> _openWallet([Wallet? wallet]) => showPSheet<void>(
    context: _root,
    builder: (context) => WalletSheet(wallet: wallet),
  );

  Future<void> _openBudget([String? categoryId]) => showPSheet<void>(
    context: _root,
    builder: (context) => BudgetSheet(categoryId: categoryId),
  );

  Future<void> _openRule([RecurringRule? rule]) => showPSheet<void>(
    context: _root,
    builder: (context) => RuleSheet(rule: rule),
  );

  Future<void> _openTransaction([Transaction? transaction]) async {
    final repository = ref.read(transactionRepositoryProvider);
    final deleted = await showPSheet<bool>(
      context: _root,
      builder: (context) => TransactionSheet(transaction: transaction),
    );
    if (deleted != true || transaction == null || !mounted) return;
    showPSnackbar(
      context,
      message: FinanceStrings.deleted,
      onUndo: () => repository.undelete(transaction.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProvider);
    final balances = ref.watch(walletBalancesProvider);
    final all = balances.value ?? const <WalletBalance>[];
    final live = all.where((w) => !w.wallet.isArchived).length;
    final shown = [
      for (final w in all)
        if (_showArchived || !w.wallet.isArchived) w,
    ];
    final history = ref.watch(_historyProvider(today.addDays(-_days)));
    final transactions = _transactions = history.value ?? _transactions;
    final budgets = ref.watch(budgetStatusesProvider);
    final caps = budgets.value ?? const <BudgetStatus>[];
    final rules = ref.watch(recurringRulesProvider);
    final recurring = rules.value ?? const <RecurringRule>[];
    final categories = {
      for (final c in ref.watch(categoriesProvider).value ?? <Category>[])
        c.id: c,
    };
    final wallets = {for (final w in all) w.wallet.id: w.wallet};

    Widget button(String label, VoidCallback onPressed) => SliverToBoxAdapter(
      child: Center(
        child: PButton.ghost(
          label: label,
          size: PButtonSize.sm,
          onPressed: onPressed,
        ),
      ),
    );

    return PScreen(
      title: PulseStrings.finance,
      actions: [
        PButton.ghost(
          icon: LucideIcons.arrowRightLeft,
          semanticLabel: FinanceStrings.transfer,
          onPressed: live < 2 ? null : _openTransaction,
        ),
        PButton.ghost(
          icon: LucideIcons.plus,
          semanticLabel: FinanceStrings.addWallet,
          onPressed: _openWallet,
        ),
      ],
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: PSectionHeader(FinanceStrings.wallets),
          ),
          if (balances.hasError ||
              history.hasError ||
              budgets.hasError ||
              rules.hasError)
            const SliverToBoxAdapter(
              child: EmptyState(
                icon: LucideIcons.circleAlert,
                title: FinanceStrings.loadError,
              ),
            ),
          SliverList.builder(
            itemCount: shown.length,
            itemBuilder: (context, i) {
              final WalletBalance(:wallet, :balance) = shown[i];
              final meta = [
                '@${wallet.slug}',
                if (wallet.isDefault) FinanceStrings.isDefault,
                if (!wallet.includeInTotal) FinanceStrings.notInTotal,
                if (wallet.isArchived) FinanceStrings.archived,
              ].join(' · ');
              return _Row(
                key: ValueKey('wallet-${wallet.slug}'),
                icon: pulseIcon(wallet.icon, fallback: LucideIcons.wallet),
                color: identityColor(wallet.color),
                title: wallet.name,
                meta: meta,
                amount: AmountText(balance, type: AmountType.balance),
                semanticLabel:
                    '${wallet.name}, $meta, '
                    '${amountLabel(balance, AmountType.balance)}',
                onTap: () => _openWallet(wallet),
              );
            },
          ),
          if (all.any((w) => w.wallet.isArchived))
            button(
              _showArchived
                  ? FinanceStrings.hideArchived
                  : FinanceStrings.showArchived,
              () => setState(() => _showArchived = !_showArchived),
            ),
          const SliverToBoxAdapter(
            child: PSectionHeader(FinanceStrings.budgets),
          ),
          SliverList.builder(
            itemCount: caps.length,
            itemBuilder: (context, i) {
              final status = caps[i];
              final category = categories[status.categoryId];
              return Padding(
                key: ValueKey('budget-${category?.slug}'),
                padding: const EdgeInsets.symmetric(
                  horizontal: PulseSpace.s4,
                  vertical: PulseSpace.s2,
                ),
                child: PBudgetBar(
                  category: category?.name ?? '',
                  color: category?.color ?? PulseIdentity.slate.toARGB32(),
                  icon: category?.icon ?? 'tag',
                  spent: status.spent,
                  cap: status.cap,
                  onPressed: () => _openBudget(status.categoryId),
                ),
              );
            },
          ),
          button(FinanceStrings.addBudget, _openBudget),
          const SliverToBoxAdapter(
            child: PSectionHeader(FinanceStrings.recurring),
          ),
          SliverList.builder(
            itemCount: recurring.length,
            itemBuilder: (context, i) {
              final rule = recurring[i];
              final type = AmountType.of(rule.type);
              final meta = ruleSummary(rule, today);
              return _Row(
                key: ValueKey('rule-${rule.id}'),
                icon: LucideIcons.repeat,
                color: null,
                title: rule.name,
                meta: meta,
                amount: AmountText(rule.amount, type: type),
                semanticLabel:
                    '${rule.name}, $meta, ${amountLabel(rule.amount, type)}',
                onTap: () => _openRule(rule),
              );
            },
          ),
          button(FinanceStrings.addRecurring, _openRule),
          const SliverToBoxAdapter(
            child: PSectionHeader(FinanceStrings.transactions),
          ),
          if (transactions != null && transactions.isEmpty)
            const SliverToBoxAdapter(
              child: EmptyState(
                icon: LucideIcons.receiptText,
                title: PulseStrings.noTransactions,
              ),
            ),
          SliverList.builder(
            itemCount: transactions?.length ?? 0,
            itemBuilder: (context, i) {
              final t = transactions![i];
              final category = categories[t.categoryId];
              final type = AmountType.of(t.type);
              final from = wallets[t.walletId]?.name ?? '';
              final to = wallets[t.toWalletId]?.name;
              final title = t.description.isNotEmpty
                  ? t.description
                  : category?.name ?? FinanceStrings.transfer;
              final meta = [
                dayLabel(t.occurredOn, today),
                to == null ? from : '$from → $to',
                ?category?.name,
              ].join(' · ');
              return _Row(
                key: ValueKey(t.id),
                icon: category == null
                    ? LucideIcons.arrowRightLeft
                    : pulseIcon(category.icon),
                color: category == null ? null : identityColor(category.color),
                title: title,
                meta: meta,
                amount: AmountText(t.amount, type: type),
                semanticLabel: '$title, $meta, ${amountLabel(t.amount, type)}',
                onTap: () => _openTransaction(t),
              );
            },
          ),
          button(
            FinanceStrings.showOlder,
            () => setState(() => _days += _page),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.meta,
    required this.amount,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final Color? color;
  final String title, meta, semanticLabel;
  final Widget amount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ShadTheme.of(context).colorScheme;
    return PTapTarget(
      label: semanticLabel,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: PulseSpace.s4,
          vertical: PulseSpace.s3,
        ),
        child: Row(
          spacing: PulseSpace.s3,
          children: [
            PIconTile(icon: icon, color: color),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PulseText.bodyStrong,
                  ),
                  Text(
                    meta,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: PulseText.caption.copyWith(
                      color: colors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            amount,
          ],
        ),
      ),
    );
  }
}
