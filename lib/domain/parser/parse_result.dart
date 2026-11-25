// PRD section 5. Types only; the parser itself is thread C.
import '../../core/local_date.dart';
import '../entities/action_item.dart';
import '../entities/category.dart';
import '../entities/transaction.dart';
import '../entities/wallet.dart';

final class ParseContext {
  final DateTime nowLocal; // from Clock, device timezone
  final List<WalletRef> wallets;
  final List<CategoryRef> categories;
  const ParseContext(this.nowLocal, this.wallets, this.categories);
}

enum CaptureKind { transaction, actionItem, note }

/// A value picked through a chip wins over what the parser reads later.
final class CaptureOverrides {
  final CaptureKind? kind;
  final String? walletId, toWalletId, categoryId;
  final int? amount;
  final DateTime? when;
  final Priority? priority;
  const CaptureOverrides({
    this.kind,
    this.walletId,
    this.toWalletId,
    this.categoryId,
    this.amount,
    this.when,
    this.priority,
  });
}

enum TokenKind {
  kindPrefix,
  amount,
  wallet,
  transfer,
  category,
  tag,
  priority,
  date,
  time,
  timeRange,
}

final class ParsedToken {
  final TokenKind kind;
  final int start, end; // [start, end) offsets into the raw input, for chips
  final String text;
  final Object? value; // resolved id, int amount, DateTime, Priority...
  const ParsedToken(this.kind, this.start, this.end, this.text, this.value);
}

// Order matters: everything up to emptyTitle blocks Save.
enum IssueCode {
  invalidAmount,
  missingAmount,
  unknownWallet,
  archivedWallet,
  sameWalletTransfer,
  emptyTitle,
  unknownCategory,
  futureTransaction,
  defaultWalletUsed,
}

final class ParseIssue {
  final IssueCode code;
  final int? start, end;
  const ParseIssue(this.code, {this.start, this.end});
  bool get blocking => code.index <= IssueCode.emptyTitle.index;
}

sealed class ParseResult {
  final String raw;
  final List<ParsedToken> tokens;
  final List<ParseIssue> issues;
  const ParseResult(this.raw, this.tokens, this.issues);
  bool get canSave => !issues.any((i) => i.blocking);
}

final class TransactionDraft extends ParseResult {
  final TxnType type;
  final int? amount;
  final String? walletId, toWalletId, categoryId;
  final List<String> tagSlugs;
  final String description;
  final DateTime occurredAt;
  const TransactionDraft(
    super.raw,
    super.tokens,
    super.issues, {
    required this.type,
    this.amount,
    this.walletId,
    this.toWalletId,
    this.categoryId,
    this.tagSlugs = const [],
    this.description = '',
    required this.occurredAt,
  });
}

final class ActionItemDraft extends ParseResult {
  final String title;
  final Priority priority;
  final LocalDate? dueDate;
  final DateTime? scheduledStart, scheduledEnd;
  final int? linkedAmount;
  final String? linkedWalletId, linkedCategoryId;
  final List<String> tagSlugs;
  bool get isBill => linkedAmount != null || tagSlugs.contains('bill');
  const ActionItemDraft(
    super.raw,
    super.tokens,
    super.issues, {
    required this.title,
    this.priority = Priority.none,
    this.dueDate,
    this.scheduledStart,
    this.scheduledEnd,
    this.linkedAmount,
    this.linkedWalletId,
    this.linkedCategoryId,
    this.tagSlugs = const [],
  });
}

final class NoteDraft extends ParseResult {
  final String title, body;
  final List<String> tagSlugs;
  const NoteDraft(
    super.raw,
    super.tokens,
    super.issues, {
    required this.title,
    this.body = '',
    this.tagSlugs = const [],
  });
}
