// PRD section 5: the quick-capture parser. Pure; "now" comes from the context.
import '../../core/local_date.dart';
import '../entities/action_item.dart';
import '../entities/category.dart';
import '../entities/transaction.dart';
import '../entities/wallet.dart';
import 'amount_rules.dart';
import 'date_words.dart';
import 'parse_result.dart';

/// Pure and synchronous: same input and context, same output.
typedef CaptureParser = ParseResult Function(
  String input,
  ParseContext ctx, {
  CaptureOverrides? overrides,
});

ParseResult parseCapture(
  String input,
  ParseContext ctx, {
  CaptureOverrides? overrides,
}) => _Capture(input, ctx, overrides ?? const CaptureOverrides()).parse();

final class _Word {
  _Word(this.start, this.end, this.text, {required this.escaped});

  int start;
  final int end;

  /// With escapes removed; what ends up in a title or description.
  String text;

  final bool escaped;

  /// Claimed words are left out of the title or description.
  bool claimed = false;
}

List<_Word> _tokenize(String input) {
  final words = <_Word>[];
  final text = StringBuffer();
  var start = -1;
  var escaped = false;
  void flush(int end) {
    if (start < 0) return;
    words.add(_Word(start, end, text.toString(), escaped: escaped));
    text.clear();
    start = -1;
    escaped = false;
  }

  for (var i = 0; i < input.length; i++) {
    var char = input[i];
    if (char.trim().isEmpty) {
      flush(i);
      continue;
    }
    if (start < 0) start = i;
    if (char == r'\' && i + 1 < input.length) {
      escaped = true;
      char = input[++i];
    }
    text.write(char);
  }
  flush(input.length);
  return words;
}

final _notePrefix = RegExp(r'^\s*(note:|/)', caseSensitive: false);
final _tag = RegExp(r'^#([a-z0-9_-]+)$');
final _pairJoined = RegExp(r'^@([^@>]+)>@([^@>]+)$');
final _pairLeft = RegExp(r'^@([^@>]+)>$');
final _pairRight = RegExp(r'^>@([^@>]+)$');
final _handle = RegExp(r'^@([^@>]+)$');
// Wider than a pair half, so that a broken "@bca>" blocks instead of hiding.
final _walletWord = RegExp(r'^@(.+)$');

const _priorities = {
  '!low': Priority.low,
  '!l': Priority.low,
  '!rendah': Priority.low,
  '!med': Priority.med,
  '!m': Priority.med,
  '!sedang': Priority.med,
  '!high': Priority.high,
  '!h': Priority.high,
  '!tinggi': Priority.high,
};

typedef _Pair = ({int first, int last, String from, String to});
typedef _Tag = ({int index, String slug});

final class _Capture {
  _Capture(this.input, this.ctx, this.overrides)
    : today = LocalDate.fromDateTime(ctx.nowLocal);

  final String input;
  final ParseContext ctx;
  final CaptureOverrides overrides;
  final LocalDate today;

  late final List<_Word> words;

  /// What the matchers see, one per word: lowercase, '' once escaped or claimed.
  late final List<String> matches;
  final tokens = <ParsedToken>[];
  final issues = <ParseIssue>[];

  ParseResult parse() {
    final note = _notePrefix.firstMatch(input);
    // The prefix is blanked, not cut, so that offsets stay true.
    var source = input;
    if (note != null) {
      final start = note.end - note[1]!.length;
      _token(TokenKind.kindPrefix, start, note.end, null);
      source = input.replaceRange(start, note.end, ' ' * note[1]!.length);
    }
    words = _tokenize(source);
    matches = [for (final w in words) w.escaped ? '' : w.text.toLowerCase()];

    final kind = overrides.kind ?? (note != null ? CaptureKind.note : null);
    if (kind == CaptureKind.note) return _note(source);

    // A leading "- " or "* " is list punctuation.
    if (matches.isNotEmpty && (matches.first == '-' || matches.first == '*')) {
      _claim(0, 1);
      _token(TokenKind.kindPrefix, words.first.start, words.first.end, null);
    }

    // A sign stuck to an amount: -35k, +7.5jt.
    String? sign;
    AmountText? signed;
    if (matches.isNotEmpty &&
        (matches.first.startsWith('-') || matches.first.startsWith('+'))) {
      signed = readAmount(matches.first.substring(1));
      if (signed != null) {
        final first = words.first;
        sign = matches.first[0];
        _token(TokenKind.kindPrefix, first.start, first.start + 1, null);
        first.start++;
        first.text = first.text.substring(1);
        matches[0] = matches[0].substring(1);
      }
    }
    final signedIsAmount = signed != null && kind != CaptureKind.actionItem;
    if (signedIsAmount) _claim(0, 1);

    // Claim order: transfer pair, wallet, priority, tags, time, date, amount.
    final pair = _findPair();
    if (pair != null) {
      for (var i = pair.first; i <= pair.last; i++) {
        matches[i] = '';
      }
    }
    final wallet = _claimWallet();
    final tags = _claimTags();
    final time = _claimTime();
    final date = _claimDate();

    // Money-looking amounts win over bare numbers ("2 tickets 500k").
    int? amountAt;
    AmountText? amount;
    if (signedIsAmount) {
      amountAt = 0;
      amount = signed;
    } else {
      for (var i = 0; i < matches.length; i++) {
        final found = readAmount(matches[i]);
        if (found == null) continue;
        if (found.looksLikeMoney) {
          amountAt = i;
          amount = found;
          break;
        }
      }
    }

    final isTransaction =
        kind == CaptureKind.transaction ||
        (kind == null &&
            (sign != null ||
                (pair != null && matches.any((m) => readAmount(m) != null))));

    if (isTransaction && amount == null) {
      for (var i = 0; i < matches.length && amount == null; i++) {
        amount = readAmount(matches[i]);
        if (amount != null) amountAt = i;
      }
    }

    if (amount != null) {
      final word = words[amountAt!];
      _claim(amountAt, 1);
      _token(TokenKind.amount, word.start, word.end, amount.value);
      if (amount.value == null && overrides.amount == null) {
        _issue(IssueCode.invalidAmount, word.start, word.end);
      }
    }
    var value = amount?.value;
    final picked = overrides.amount;
    if (picked != null) {
      value = picked > 0 && picked <= maxAmount ? picked : null;
      if (value == null) _issue(IssueCode.invalidAmount);
    }

    return isTransaction
        ? _transaction(
            type: sign == '+'
                ? TxnType.income
                : sign == null && pair != null
                ? TxnType.transfer
                : TxnType.outcome,
            amount: value,
            missingAmount: amount == null && picked == null,
            pair: pair,
            wallet: wallet,
            tags: tags,
            date: date,
            time: time,
          )
        : _actionItem(
            amount: value,
            wallet: wallet,
            tags: tags,
            date: date,
            time: time,
          );
  }

  // Claiming.

  void _claim(int from, int count) {
    for (var i = from; i < from + count; i++) {
      words[i].claimed = true;
      matches[i] = '';
    }
  }

  void _token(TokenKind kind, int start, int end, Object? value) => tokens.add(
    ParsedToken(kind, start, end, input.substring(start, end), value),
  );

  void _issue(IssueCode code, [int? start, int? end]) =>
      issues.add(ParseIssue(code, start: start, end: end));

  _Pair? _findPair() {
    String at(int i) => i < matches.length ? matches[i] : '';
    for (var i = 0; i < matches.length; i++) {
      final joined = _pairJoined.firstMatch(at(i));
      if (joined != null) {
        return (first: i, last: i, from: joined[1]!, to: joined[2]!);
      }
      final left = _pairLeft.firstMatch(at(i));
      if (left != null) {
        final to = _handle.firstMatch(at(i + 1));
        if (to != null) {
          return (first: i, last: i + 1, from: left[1]!, to: to[1]!);
        }
      }
      final from = _handle.firstMatch(at(i));
      if (from == null) continue;
      final right = _pairRight.firstMatch(at(i + 1));
      if (right != null) {
        return (first: i, last: i + 1, from: from[1]!, to: right[1]!);
      }
      if (at(i + 1) == '>') {
        final to = _handle.firstMatch(at(i + 2));
        if (to != null) {
          return (first: i, last: i + 2, from: from[1]!, to: to[1]!);
        }
      }
    }
    return null;
  }

  ({int index, String name})? _claimWallet() {
    for (var i = 0; i < matches.length; i++) {
      final m = _walletWord.firstMatch(matches[i]);
      if (m == null) continue;
      _claim(i, 1);
      return (index: i, name: m[1]!);
    }
    return null;
  }

  List<_Tag> _claimTags() {
    final found = <_Tag>[];
    for (var i = 0; i < matches.length; i++) {
      final m = _tag.firstMatch(matches[i]);
      if (m == null) continue;
      _claim(i, 1);
      found.add((index: i, slug: m[1]!));
    }
    return found;
  }

  /// A range, else an explicit time, else a day part. The first one wins.
  ({int first, int last, int start, int? end})? _claimTime() {
    for (final matcher in [matchTimeRange, matchTime, matchDayPart]) {
      for (var i = 0; i < matches.length; i++) {
        if (matches[i].isEmpty) continue;
        final m = matcher(matches, i);
        if (m == null) continue;
        _claim(i, m.words);
        return (first: i, last: i + m.words - 1, start: m.start, end: m.end);
      }
    }
    return null;
  }

  ({int first, int last, LocalDate date})? _claimDate() {
    for (var i = 0; i < matches.length; i++) {
      if (matches[i].isEmpty) continue;
      final m = matchDate(matches, i, today);
      if (m == null) continue;
      _claim(i, m.words);
      return (first: i, last: i + m.words - 1, date: m.date);
    }
    return null;
  }

  // Shared pieces.

  /// 23:00-01:00 ends the next day.
  int _endMinutes(int start, int end) => end < start ? end + 24 * 60 : end;

  DateTime _at(LocalDate date, [int minutes = 0]) {
    final make = ctx.nowLocal.isUtc ? DateTime.utc : DateTime.new;
    return make(date.year, date.month, date.day, 0, minutes);
  }

  String get _text => [
    for (final w in words)
      if (!w.claimed) w.text,
  ].join(' ');

  /// Exact slug, then exact alias, then a unique prefix of either.
  WalletRef? _findWallet(String name) {
    for (final w in ctx.wallets) {
      if (w.slug.toLowerCase() == name) return w;
    }
    for (final w in ctx.wallets) {
      if (w.aliases.any((a) => a.toLowerCase() == name)) return w;
    }
    final prefixed = [
      for (final w in ctx.wallets)
        if ([w.slug, ...w.aliases].any((a) => a.toLowerCase().startsWith(name)))
          w,
    ];
    // An archived wallet never makes a live one ambiguous.
    final live = prefixed.where((w) => !w.isArchived).toList();
    final pool = live.isEmpty ? prefixed : live;
    return pool.length == 1 ? pool.single : null;
  }

  /// A picked wallet wins over the typed [name]. Issues cover [start]..[end].
  String? _wallet(String? picked, String? name, int? start, int? end) {
    WalletRef? found;
    if (picked != null) {
      for (final w in ctx.wallets) {
        if (w.id == picked) found = w;
      }
      start = end = null;
    } else if (name != null) {
      found = _findWallet(name);
    }
    if (found == null) {
      _issue(IssueCode.unknownWallet, start, end);
    } else if (found.isArchived) {
      _issue(IssueCode.archivedWallet, start, end);
    }
    return found?.id;
  }

  String? _findCategory(String slug, CategoryKind kind) {
    for (final c in ctx.categories) {
      if (c.kind == kind && c.slug.toLowerCase() == slug) return c.id;
    }
    for (final c in ctx.categories) {
      if (c.kind == kind && c.aliases.any((a) => a.toLowerCase() == slug)) {
        return c.id;
      }
    }
    return null;
  }

  /// Emits the chip tokens. The first category of [kind] is not a tag.
  ({String? categoryId, List<String> tagSlugs}) _splitTags(
    List<_Tag> tags,
    CategoryKind? kind, {
    String? keepAsTag,
  }) {
    String? categoryId, categorySlug;
    final slugs = <String>{};
    for (final tag in tags) {
      final word = words[tag.index];
      if (kind != null && categoryId == null && tag.slug != keepAsTag) {
        categoryId = _findCategory(tag.slug, kind);
        if (categoryId != null) {
          categorySlug = tag.slug;
          _token(TokenKind.category, word.start, word.end, categoryId);
          continue;
        }
      }
      _token(TokenKind.tag, word.start, word.end, tag.slug);
      if (tag.slug != categorySlug) slugs.add(tag.slug);
    }
    return (categoryId: categoryId, tagSlugs: slugs.toList());
  }

  void _whenTokens(
    ({int first, int last, LocalDate date})? date,
    ({int first, int last, int start, int? end})? time,
    LocalDate day,
  ) {
    if (date != null) {
      _token(
        TokenKind.date,
        words[date.first].start,
        words[date.last].end,
        _at(date.date),
      );
    }
    if (time != null) {
      final end = time.end;
      _token(
        end == null ? TokenKind.time : TokenKind.timeRange,
        words[time.first].start,
        words[time.last].end,
        end == null
            ? _at(day, time.start)
            : (_at(day, time.start), _at(day, _endMinutes(time.start, end))),
      );
    }
  }

  List<ParsedToken> get _sortedTokens =>
      tokens..sort((a, b) => a.start.compareTo(b.start));

  // Drafts.

  TransactionDraft _transaction({
    required TxnType type,
    required int? amount,
    required bool missingAmount,
    required _Pair? pair,
    required ({int index, String name})? wallet,
    required List<_Tag> tags,
    required ({int first, int last, LocalDate date})? date,
    required ({int first, int last, int start, int? end})? time,
  }) {
    if (missingAmount) _issue(IssueCode.missingAmount);

    String? walletId, toWalletId;
    if (type == TxnType.transfer) {
      final start = words[pair!.first].start, end = words[pair.last].end;
      _claim(pair.first, pair.last - pair.first + 1);
      walletId = _wallet(overrides.walletId, pair.from, start, end);
      toWalletId = _wallet(overrides.toWalletId, pair.to, start, end);
      _token(TokenKind.transfer, start, end, (walletId, toWalletId));
      // A third @wallet means nothing here: leave it visible.
      if (wallet != null) words[wallet.index].claimed = false;
      if (walletId != null && walletId == toWalletId) {
        _issue(IssueCode.sameWalletTransfer, start, end);
      }
    } else {
      // A pair next to a sign is neither one wallet nor a transfer: block
      // until a wallet is picked.
      if (pair != null && overrides.walletId == null) {
        _issue(
          IssueCode.unknownWallet,
          words[pair.first].start,
          words[pair.last].end,
        );
      }
      if (wallet != null) {
        final word = words[wallet.index];
        walletId = _wallet(
          overrides.walletId,
          wallet.name,
          word.start,
          word.end,
        );
        _token(TokenKind.wallet, word.start, word.end, walletId);
      } else if (overrides.walletId != null) {
        walletId = _wallet(overrides.walletId, null, null, null);
      } else if (pair == null) {
        for (final w in ctx.wallets) {
          if (w.isDefault && !w.isArchived) walletId ??= w.id;
        }
        _issue(
          walletId == null
              ? IssueCode.unknownWallet
              : IssueCode.defaultWalletUsed,
        );
      }
    }

    final kind = switch (type) {
      TxnType.income => CategoryKind.income,
      TxnType.outcome => CategoryKind.outcome,
      TxnType.transfer => null,
    };
    final split = _splitTags(tags, kind);
    var categoryId = split.categoryId;
    if (kind != null) {
      final picked = overrides.categoryId;
      // A pick of the wrong kind is stale (the sign changed since).
      if (picked != null &&
          !ctx.categories.any((c) => c.id == picked && c.kind != kind)) {
        categoryId = picked;
      }
      if (categoryId == null) _issue(IssueCode.unknownCategory);
    }

    final day = date?.date ?? today;
    _whenTokens(date, time, day);
    final occurredAt =
        overrides.when ??
        (time != null
            ? _at(day, time.start)
            : date != null
            ? _at(day, 12 * 60)
            : ctx.nowLocal);
    // A date-only "today" sits at 12:00 and is not "in the future".
    final exact = overrides.when != null || time != null;
    if (exact
        ? occurredAt.isAfter(ctx.nowLocal)
        : LocalDate.fromDateTime(occurredAt).isAfter(today)) {
      _issue(IssueCode.futureTransaction);
    }

    return TransactionDraft(
      input,
      _sortedTokens,
      issues,
      type: type,
      amount: amount,
      walletId: walletId,
      toWalletId: toWalletId,
      categoryId: categoryId,
      tagSlugs: split.tagSlugs,
      description: _text,
      occurredAt: occurredAt,
    );
  }

  ActionItemDraft _actionItem({
    required int? amount,
    required ({int index, String name})? wallet,
    required List<_Tag> tags,
    required ({int first, int last, LocalDate date})? date,
    required ({int first, int last, int start, int? end})? time,
  }) {
    var priority = Priority.none;
    for (var i = 0; i < matches.length; i++) {
      final found = _priorities[matches[i]];
      if (found == null) continue;
      priority = found;
      _claim(i, 1);
      _token(TokenKind.priority, words[i].start, words[i].end, found);
    }

    String? walletId;
    if (wallet != null) {
      final word = words[wallet.index];
      walletId = _wallet(overrides.walletId, wallet.name, word.start, word.end);
      _token(TokenKind.wallet, word.start, word.end, walletId);
    } else if (overrides.walletId != null) {
      walletId = _wallet(overrides.walletId, null, null, null);
    }

    // Only a bill has a linked category; otherwise #food is just a tag.
    final isBill = amount != null || tags.any((t) => t.slug == 'bill');
    final split = _splitTags(
      tags,
      isBill ? CategoryKind.outcome : null,
      keepAsTag: 'bill',
    );

    var day = date?.date ?? today;
    LocalDate? dueDate;
    DateTime? start, end;
    if (time != null) {
      if (date == null && _at(day, time.start).isBefore(ctx.nowLocal)) {
        day = day.addDays(1);
      }
      start = _at(day, time.start);
      final until = time.end;
      if (until != null && until != time.start) {
        end = _at(day, _endMinutes(time.start, until));
      }
    } else {
      dueDate = date?.date;
    }
    _whenTokens(date, time, day);

    final when = overrides.when;
    if (when != null) {
      final length = start == null ? null : end?.difference(start);
      start = when;
      end = length == null ? null : when.add(length);
      dueDate = null;
    }

    final title = _text;
    if (title.isEmpty) _issue(IssueCode.emptyTitle);

    return ActionItemDraft(
      input,
      _sortedTokens,
      issues,
      title: title,
      priority: overrides.priority ?? priority,
      dueDate: dueDate,
      scheduledStart: start,
      scheduledEnd: end,
      linkedAmount: amount,
      linkedWalletId: walletId,
      linkedCategoryId: overrides.categoryId ?? split.categoryId,
      tagSlugs: split.tagSlugs,
    );
  }

  /// The first line is the title, the rest is the body, kept verbatim.
  /// Only #tags are read; date and time words stay in the text.
  NoteDraft _note(String source) {
    final split = _splitTags(_claimTags(), null);

    var title = '';
    var body = '';
    if (words.isNotEmpty) {
      var lineEnd = source.indexOf('\n', words.first.start);
      if (lineEnd < 0) lineEnd = source.length;
      title = [
        for (final w in words)
          if (!w.claimed && w.start < lineEnd) w.text,
      ].join(' ');
      body = source.substring(lineEnd).trim();
    }
    if (title.isEmpty) _issue(IssueCode.emptyTitle);

    return NoteDraft(
      input,
      _sortedTokens,
      issues,
      title: title,
      body: body,
      tagSlugs: split.tagSlugs,
    );
  }
}
