// PRD section 5 golden fixture: now = Wednesday 2026-11-25 10:00.
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/domain/entities/category.dart';
import 'package:pulse/domain/entities/wallet.dart';
import 'package:pulse/domain/parser/capture_parser.dart';
import 'package:pulse/domain/parser/parse_result.dart';

final now = DateTime(2026, 11, 25, 10);

DateTime at(int month, int day, [int hour = 0, int minute = 0]) =>
    DateTime(2026, month, day, hour, minute);

WalletRef wallet(
  String slug, {
  List<String> aliases = const [],
  bool isDefault = false,
  bool isArchived = false,
}) => WalletRef(
  id: 'w-$slug',
  slug: slug,
  aliases: aliases,
  isDefault: isDefault,
  isArchived: isArchived,
);

CategoryRef category(
  String slug,
  CategoryKind kind, [
  List<String> aliases = const [],
]) => CategoryRef(id: 'c-$slug', slug: slug, aliases: aliases, kind: kind);

final wallets = [
  wallet('cash', isDefault: true),
  wallet('bca'),
  wallet('gopay'),
];

final categories = [
  category('food', CategoryKind.outcome, ['makanan']),
  category('transport', CategoryKind.outcome),
  category('bills', CategoryKind.outcome),
  category('income', CategoryKind.income),
];

final ctx = ParseContext(now, wallets, categories);

const CaptureParser parser = parseCapture;

T _parse<T extends ParseResult>(
  String input,
  CaptureOverrides? overrides,
  ParseContext? context,
) {
  final result = parser(input, context ?? ctx, overrides: overrides);
  expect(result, isA<T>(), reason: input);
  expect(result.raw, input);
  return result as T;
}

TransactionDraft txn(String s, {CaptureOverrides? o, ParseContext? c}) =>
    _parse(s, o, c);

ActionItemDraft item(String s, {CaptureOverrides? o, ParseContext? c}) =>
    _parse(s, o, c);

NoteDraft note(String s, {CaptureOverrides? o, ParseContext? c}) =>
    _parse(s, o, c);

Set<IssueCode> codes(ParseResult r) => {for (final i in r.issues) i.code};
