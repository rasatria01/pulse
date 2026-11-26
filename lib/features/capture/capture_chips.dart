// Maps a parse result to chips, always in the order Kind, Amount, Wallet,
// Category, Date/Time, Priority, Tags.
import 'package:flutter/foundation.dart' show ValueKey;

import '../../core/local_date.dart';
import '../../core/rupiah.dart';
import '../../domain/entities/action_item.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/wallet.dart';
import '../../domain/parser/parse_result.dart';
import '../../ui/day_label.dart';
import '../../ui/strings.dart';
import '../../ui/widgets/widgets.dart';
import 'capture_strings.dart';

enum CaptureField {
  kind,
  amount,
  wallet,
  toWallet,
  category,
  when,
  priority,
  tags,
}

String priorityLabel(Priority priority) => switch (priority) {
  Priority.none => CaptureStrings.noPriority,
  Priority.low => CaptureStrings.lowPriority,
  Priority.med => CaptureStrings.medPriority,
  Priority.high => CaptureStrings.highPriority,
};

ParseIssue? _issue(ParseResult draft, Set<IssueCode> codes) {
  for (final issue in draft.issues) {
    if (codes.contains(issue.code)) return issue;
  }
  return null;
}

const _walletIssues = {
  IssueCode.unknownWallet,
  IssueCode.archivedWallet,
  IssueCode.sameWalletTransfer,
};

/// One line for the first blocking issue, or null if the draft can be saved.
String? captureHint(ParseResult draft, List<Wallet> wallets) {
  for (final issue in draft.issues) {
    if (!issue.blocking) continue;
    final start = issue.start, end = issue.end;
    final typed = start == null || end == null
        ? null
        : draft.raw.substring(start, end);
    switch (issue.code) {
      case IssueCode.invalidAmount:
        return CaptureStrings.hintInvalidAmount;
      case IssueCode.missingAmount:
        return CaptureStrings.hintMissingAmount;
      case IssueCode.unknownWallet:
        return typed == null
            ? CaptureStrings.hintNoWallet
            : CaptureStrings.unknownWallet(typed);
      case IssueCode.archivedWallet:
        return CaptureStrings.archivedWallet(typed ?? CaptureStrings.wallet);
      case IssueCode.sameWalletTransfer:
        return CaptureStrings.hintSameWallet;
      case IssueCode.emptyTitle:
        return CaptureStrings.hintEmptyTitle;
      case IssueCode.unknownCategory:
      case IssueCode.futureTransaction:
      case IssueCode.defaultWalletUsed:
        break; // not blocking
    }
  }
  return null;
}

List<PChip> captureChips(
  ParseResult draft, {
  required List<Wallet> wallets,
  required List<Category> categories,
  required LocalDate today,
  required bool whenPicked,
  required void Function(CaptureField) onTap,
}) {
  PChip chip(
    CaptureField field,
    String name,
    String label, {
    PChipTone tone = PChipTone.neutral,
    int? dotColor,
    bool numeric = false,
  }) => PChip(
    key: ValueKey(field),
    field: name,
    label: label,
    tone: tone,
    dotColor: dotColor,
    numeric: numeric,
    onPressed: () => onTap(field),
  );

  PChip walletChip(
    CaptureField field,
    String name,
    String? id, {
    String Function(String)? wrap,
  }) {
    final wallet = wallets.where((w) => w.id == id).firstOrNull;
    final issue = _issue(draft, _walletIssues);
    final bad =
        wallet == null ||
        wallet.isArchived ||
        issue?.code == IssueCode.sameWalletTransfer;
    final start = issue?.start, end = issue?.end;
    // The typed text names one wallet only outside a transfer.
    final label =
        wallet?.name ??
        (wrap == null && start != null && end != null
            ? draft.raw.substring(start, end)
            : CaptureStrings.pickWallet);
    return chip(
      field,
      name,
      wrap == null ? label : wrap(label),
      dotColor: wallet?.color,
      tone: bad
          ? PChipTone.error
          : _issue(draft, const {IssueCode.defaultWalletUsed}) != null
          ? PChipTone.warning
          : PChipTone.neutral,
    );
  }

  PChip categoryChip(String? id, String placeholder) {
    final category = categories.where((c) => c.id == id).firstOrNull;
    return chip(
      CaptureField.category,
      CaptureStrings.category,
      category?.name ?? placeholder,
      dotColor: category?.color,
      tone: category == null ? PChipTone.placeholder : PChipTone.neutral,
    );
  }

  PChip tagsChip(List<String> slugs) => chip(
    CaptureField.tags,
    CaptureStrings.tags,
    slugs.isEmpty ? CaptureStrings.noTag : slugs.map((s) => '#$s').join(' '),
    tone: slugs.isEmpty ? PChipTone.placeholder : PChipTone.neutral,
  );

  PChip kindChip(String label, [PChipTone tone = PChipTone.neutral]) =>
      chip(CaptureField.kind, CaptureStrings.kind, label, tone: tone);

  PChip amountChip(int? amount, AmountType type) {
    final invalid = _issue(draft, const {IssueCode.invalidAmount}) != null;
    if (invalid || amount == null) {
      return chip(
        CaptureField.amount,
        CaptureStrings.amount,
        invalid ? CaptureStrings.invalidAmount : CaptureStrings.addAmount,
        tone: PChipTone.error,
      );
    }
    return chip(
      CaptureField.amount,
      CaptureStrings.amount,
      formatAmount(Rupiah(amount), type),
      numeric: true,
    );
  }

  bool typed(Set<TokenKind> kinds) =>
      draft.tokens.any((t) => kinds.contains(t.kind));

  switch (draft) {
    case TransactionDraft d:
      final timed =
          whenPicked || typed(const {TokenKind.time, TokenKind.timeRange});
      final dated = timed || typed(const {TokenKind.date});
      final day = dayLabel(LocalDate.fromDateTime(d.occurredAt), today);
      return [
        kindChip(switch (d.type) {
          TxnType.outcome => MelaStrings.expense,
          TxnType.income => MelaStrings.income,
          TxnType.transfer => MelaStrings.transfer,
        }, d.type == TxnType.income ? PChipTone.positive : PChipTone.neutral),
        amountChip(d.amount, AmountType.of(d.type)),
        if (d.type == TxnType.transfer) ...[
          walletChip(
            CaptureField.wallet,
            CaptureStrings.fromWallet,
            d.walletId,
            wrap: CaptureStrings.from,
          ),
          walletChip(
            CaptureField.toWallet,
            CaptureStrings.toWallet,
            d.toWalletId,
            wrap: CaptureStrings.to,
          ),
        ] else ...[
          walletChip(CaptureField.wallet, CaptureStrings.wallet, d.walletId),
          categoryChip(d.categoryId, CaptureStrings.uncategorized),
        ],
        chip(
          CaptureField.when,
          CaptureStrings.date,
          timed
              ? '$day ${timeLabel(d.occurredAt)}'
              : dated
              ? day
              : CaptureStrings.now,
          tone: _issue(draft, const {IssueCode.futureTransaction}) != null
              ? PChipTone.warning
              : dated
              ? PChipTone.neutral
              : PChipTone.placeholder,
        ),
        tagsChip(d.tagSlugs),
      ];
    case ActionItemDraft d:
      final start = d.scheduledStart, end = d.scheduledEnd, due = d.dueDate;
      final when = start != null
          ? '${dayLabel(LocalDate.fromDateTime(start), today)} '
                '${timeLabel(start)}'
                '${end == null ? '' : '–${timeLabel(end)}'}'
          : due != null
          ? CaptureStrings.due(dayLabel(due, today))
          : null;
      return [
        kindChip(d.isBill ? CaptureStrings.bill : CaptureStrings.task),
        if (d.linkedAmount != null ||
            _issue(draft, const {IssueCode.invalidAmount}) != null)
          amountChip(d.linkedAmount, AmountType.balance),
        if (d.linkedWalletId != null || _issue(draft, _walletIssues) != null)
          walletChip(
            CaptureField.wallet,
            CaptureStrings.wallet,
            d.linkedWalletId,
          ),
        if (d.isBill || d.linkedCategoryId != null)
          categoryChip(d.linkedCategoryId, CaptureStrings.category),
        chip(
          CaptureField.when,
          CaptureStrings.date,
          when ?? CaptureStrings.noDate,
          tone: when == null ? PChipTone.placeholder : PChipTone.neutral,
        ),
        chip(
          CaptureField.priority,
          CaptureStrings.priority,
          d.priority == Priority.none
              ? CaptureStrings.priority
              : priorityLabel(d.priority),
          tone: d.priority == Priority.none
              ? PChipTone.placeholder
              : PChipTone.neutral,
        ),
        tagsChip(d.tagSlugs),
      ];
    case NoteDraft d:
      return [kindChip(CaptureStrings.note), tagsChip(d.tagSlugs)];
  }
}
