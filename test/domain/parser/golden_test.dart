// PRD section 5 golden table: all 19 rows.
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/local_date.dart';
import 'package:pulse/domain/entities/action_item.dart';
import 'package:pulse/domain/entities/transaction.dart';
import 'package:pulse/domain/parser/parse_result.dart';

import 'fixture.dart';

void main() {
  test('1 outcome with wallet and category', () {
    final d = txn('-35k lunch @gopay #food');
    expect(d.type, TxnType.outcome);
    expect(d.amount, 35000);
    expect(d.walletId, 'w-gopay');
    expect(d.categoryId, 'c-food');
    expect(d.description, 'lunch');
    expect(d.occurredAt, now);
    expect(d.tagSlugs, isEmpty);
    expect(d.issues, isEmpty);
  });

  test('2 income', () {
    final d = txn('+7.5jt monthly salary @bca #income');
    expect(d.type, TxnType.income);
    expect(d.amount, 7500000);
    expect(d.walletId, 'w-bca');
    expect(d.categoryId, 'c-income');
    expect(d.description, 'monthly salary');
    expect(d.issues, isEmpty);
  });

  test('3 scheduled bill', () {
    final d = item('Pay internet bill 350k tomorrow 09:00 !high #bill');
    expect(d.title, 'Pay internet bill');
    expect(d.scheduledStart, at(11, 26, 9));
    expect(d.dueDate, isNull);
    expect(d.priority, Priority.high);
    expect(d.tagSlugs, ['bill']);
    expect(d.linkedAmount, 350000);
    expect(d.isBill, isTrue);
    expect(d.issues, isEmpty);
  });

  test('4 unscheduled task', () {
    final d = item('Refactor auth middleware !med #dev');
    expect(d.title, 'Refactor auth middleware');
    expect(d.scheduledStart, isNull);
    expect(d.dueDate, isNull);
    expect(d.priority, Priority.med);
    expect(d.tagSlugs, ['dev']);
  });

  test('5 note', () {
    final d = note('note: Idea for weekend meal prep #personal');
    expect(d.title, 'Idea for weekend meal prep');
    expect(d.tagSlugs, ['personal']);
    expect(d.canSave, isTrue);
  });

  test('6 default wallet, uncategorized, backdated', () {
    final d = txn('-25rb parkir kemarin');
    expect(d.type, TxnType.outcome);
    expect(d.amount, 25000);
    expect(d.walletId, 'w-cash');
    expect(d.categoryId, isNull);
    expect(d.description, 'parkir');
    expect(d.occurredAt, at(11, 24, 12));
    expect(codes(d), {IssueCode.defaultWalletUsed, IssueCode.unknownCategory});
    expect(d.canSave, isTrue);
  });

  test('7 transfer', () {
    final d = txn('500k @bca>@gopay topup');
    expect(d.type, TxnType.transfer);
    expect(d.amount, 500000);
    expect(d.walletId, 'w-bca');
    expect(d.toWalletId, 'w-gopay');
    expect(d.categoryId, isNull);
    expect(d.description, 'topup');
    expect(d.issues, isEmpty);
  });

  test('8 weekday and jam', () {
    final d = item('Bayar listrik 1.250.000 senin jam 9 #bill');
    expect(d.title, 'Bayar listrik');
    expect(d.scheduledStart, at(11, 30, 9));
    expect(d.linkedAmount, 1250000);
    expect(d.tagSlugs, ['bill']);
  });

  test('9 time range', () {
    final d = item('Sync klien besok 14:00-15:30 #work');
    expect(d.title, 'Sync klien');
    expect(d.scheduledStart, at(11, 26, 14));
    expect(d.scheduledEnd, at(11, 26, 15, 30));
    expect(d.tagSlugs, ['work']);
  });

  test('10 passed time moves to tomorrow', () {
    final d = item('Standup 09:00');
    expect(d.title, 'Standup');
    expect(d.scheduledStart, at(11, 26, 9));
  });

  test('11 day part adjusts jam', () {
    final d = item('Gym jam 7 malam');
    expect(d.title, 'Gym');
    expect(d.scheduledStart, at(11, 25, 19));
  });

  test('12 lusa is a due date', () {
    final d = item('Laundry lusa');
    expect(d.title, 'Laundry');
    expect(d.dueDate, const LocalDate(2026, 11, 27));
    expect(d.scheduledStart, isNull);
  });

  test('13 absolute date bill', () {
    final d = item('Bayar kos 1,5jt 12/12 #bill');
    expect(d.title, 'Bayar kos');
    expect(d.dueDate, const LocalDate(2026, 12, 12));
    expect(d.linkedAmount, 1500000);
    expect(d.tagSlugs, ['bill']);
  });

  test('14 a year is not an amount', () {
    final d = item('Plan 2026 trip');
    expect(d.title, 'Plan 2026 trip');
    expect(d.linkedAmount, isNull);
  });

  test('15 thousands separator', () {
    final d = txn('-1.500 parkir @cash #transport');
    expect(d.type, TxnType.outcome);
    expect(d.amount, 1500);
    expect(d.walletId, 'w-cash');
    expect(d.categoryId, 'c-transport');
    expect(d.issues, isEmpty);
  });

  test('16 invalid amount blocks Save', () {
    final d = txn('-35.5 coffee');
    expect(d.amount, isNull);
    expect(codes(d), contains(IssueCode.invalidAmount));
    expect(codes(d), isNot(contains(IssueCode.missingAmount)));
    expect(d.canSave, isFalse);
  });

  test('17 unknown wallet blocks Save', () {
    final d = txn('-50k makan @ovo');
    expect(d.walletId, isNull);
    final issue = d.issues.singleWhere(
      (i) => i.code == IssueCode.unknownWallet,
    );
    expect(d.raw.substring(issue.start!, issue.end), '@ovo');
    expect(d.canSave, isFalse);
  });

  test('18 escaped hash', () {
    final d = item(r'Fix \#123 crash !h');
    expect(d.title, 'Fix #123 crash');
    expect(d.priority, Priority.high);
    expect(d.tagSlugs, isEmpty);
  });

  test('19 leading dash is stripped', () {
    final d = item('- buy milk');
    expect(d.title, 'buy milk');
  });
}
