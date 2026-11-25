// PRD section 5, one test per rule bullet.
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/local_date.dart';
import 'package:pulse/domain/entities/action_item.dart';
import 'package:pulse/domain/entities/category.dart';
import 'package:pulse/domain/entities/transaction.dart';
import 'package:pulse/domain/parser/amount_rules.dart';
import 'package:pulse/domain/parser/parse_result.dart';

import 'fixture.dart';

void main() {
  group('kind detection', () {
    test('note prefixes', () {
      expect(note('NOTE:hello').title, 'hello');
      expect(note('/ meeting notes').title, 'meeting notes');
      expect(note('  Note: x').title, 'x');
    });

    test('sign stuck to an amount makes a transaction', () {
      expect(txn('+Rp35.000').type, TxnType.income);
      expect(txn('-rp35k').amount, 35000);
      expect(item('- 35k lunch').title, 'lunch');
      expect(item('-1st draft').title, '-1st draft');
      expect(item('* buy milk').title, 'buy milk');
      expect(item('35k lunch').linkedAmount, 35000);
    });

    test('transfer needs a pair and an amount; spaces around > are fine', () {
      for (final pair in [
        '@bca>@gopay',
        '@bca > @gopay',
        '@bca> @gopay',
        '@bca >@gopay',
      ]) {
        final d = txn('$pair 50k');
        expect(d.type, TxnType.transfer, reason: pair);
        expect((d.walletId, d.toWalletId), ('w-bca', 'w-gopay'));
        expect(d.description, isEmpty, reason: pair);
      }
      final d = item('move @bca>@gopay');
      expect(d.title, 'move @bca>@gopay');
      expect(d.issues, isEmpty);
    });

    test('a sign wins over a transfer pair, and the pair blocks Save', () {
      final d = txn('-50k @bca>@gopay');
      expect(d.type, TxnType.outcome);
      expect(codes(d), contains(IssueCode.unknownWallet));
      expect(d.canSave, isFalse);
      const picked = CaptureOverrides(walletId: 'w-cash');
      expect(txn('-50k @bca>@gopay', o: picked).canSave, isTrue);
    });

    test('a third wallet beside a transfer stays visible', () {
      final d = txn('5k @cash @bca>@gopay');
      expect(d.walletId, 'w-bca');
      expect(d.description, '@cash');
    });
  });

  group('amounts', () {
    test('grammar', () {
      const valid = {
        '35k': 35000,
        '25rb': 25000,
        '25ribu': 25000,
        '7.5jt': 7500000,
        '7,5jt': 7500000,
        '2m': 2000000,
        '2juta': 2000000,
        '1.500': 1500,
        '1,250,000': 1250000,
        'rp35.000': 35000,
        'rp.500': 500,
        '1.234k': 1234,
        '1.2340000000k': 1234,
        '0.000001m': 1,
        '0035': 35,
        '1000000000000000': maxAmount,
        '1000000000jt': maxAmount,
      };
      valid.forEach((text, value) {
        expect(readAmount(text)?.value, value, reason: text);
      });
      for (final text in [
        '35.5',
        '1.2345k',
        '1.250.000k',
        '0',
        '0k',
        '35.000,00',
        '1000000000000001',
        '1000000001jt',
        '99999999999999999999999999k',
        '1.99999999999999999999k',
      ]) {
        expect(readAmount(text), isNotNull, reason: text);
        expect(readAmount(text)!.value, isNull, reason: text);
      }
      for (final text in ['', 'k', '9:00', '12/12', '35kk', '1..5', '35.']) {
        expect(readAmount(text), isNull, reason: text);
      }
    });

    test('action item needs a money-looking number', () {
      expect(item('Read 2 chapters').linkedAmount, isNull);
      expect(item('Pay 5000').linkedAmount, isNull);
      expect(item('Pay 50000').linkedAmount, 50000);
      expect(item('Pay 1.500').linkedAmount, 1500);
      expect(item('Pay Rp500').linkedAmount, 500);
      expect(item('Upgrade to 1.2.3').title, 'Upgrade to 1.2.3');
      expect(item('Upgrade to 1.2.3').issues, isEmpty);
      expect(codes(item('Pay 1.2345k')), {IssueCode.invalidAmount});
    });

    test('only the signed amount counts', () {
      final d = txn('-10k 2 tickets 50k');
      expect(d.amount, 10000);
      expect(d.description, '2 tickets 50k');
    });

    test('a transfer prefers a money-looking number over a bare one', () {
      expect(txn('2 tickets 500k @bca>@gopay').amount, 500000);
      expect(txn('500 @bca>@gopay').amount, 500);
    });

    test('a token with a colon is a time', () {
      final d = item('Call 10:30');
      expect(d.linkedAmount, isNull);
      expect(d.scheduledStart, at(11, 25, 10, 30));
    });

    test('missing amount blocks a forced transaction', () {
      final d = txn(
        'lunch',
        o: const CaptureOverrides(kind: CaptureKind.transaction),
      );
      expect(codes(d), contains(IssueCode.missingAmount));
      expect(d.canSave, isFalse);
    });
  });

  group('wallets', () {
    final context = ParseContext(now, [
      wallet('cash', isDefault: true),
      wallet('gopay', aliases: ['gp']),
      wallet('gojek'),
      wallet('old', isArchived: true),
      wallet('bca'),
      wallet('bca-old', isArchived: true),
    ], categories);

    test('slug, alias, unique prefix, any case', () {
      for (final name in ['@GoPay', '@gp', '@gop']) {
        expect(txn('-1k $name', c: context).walletId, 'w-gopay', reason: name);
      }
      expect(txn('-1k @bc', c: context).walletId, 'w-bca');
    });

    test('ambiguous prefix, unknown and broken handles block', () {
      for (final name in ['@go', '@ovo', '@bca>']) {
        final d = txn('-1k $name', c: context);
        expect(codes(d), contains(IssueCode.unknownWallet), reason: name);
        expect(d.walletId, isNull);
      }
    });

    test('archived wallet blocks', () {
      final d = txn('-1k @old', c: context);
      expect(codes(d), contains(IssueCode.archivedWallet));
      expect(d.canSave, isFalse);
    });

    test('no default wallet blocks', () {
      final d = txn('-1k', c: ParseContext(now, [wallet('bca')], categories));
      expect(codes(d), contains(IssueCode.unknownWallet));
      expect(d.canSave, isFalse);
    });

    test('same wallet transfer blocks', () {
      final d = txn('5k @bca>@bc', c: context);
      expect(codes(d), contains(IssueCode.sameWalletTransfer));
      expect(d.canSave, isFalse);
    });

    test('action item links a wallet', () {
      final d = item('Pay rent 2jt @bca #bills');
      expect(d.linkedWalletId, 'w-bca');
      expect(d.linkedCategoryId, 'c-bills');
      expect(d.title, 'Pay rent');
      expect(d.tagSlugs, isEmpty);
    });

    test('a lone @ and an email are text', () {
      expect(item('meet @ 5 a@b.com').title, 'meet @ 5 a@b.com');
    });
  });

  group('categories and tags', () {
    test('first matching category of the right kind, rest are tags', () {
      final d = txn('-5k #dev #income #makanan #transport #Dev');
      expect(d.categoryId, 'c-food');
      expect(d.tagSlugs, ['dev', 'income', 'transport']);
    });

    test('a transfer has no category', () {
      final d = txn('5k @bca>@gopay #food');
      expect(d.categoryId, isNull);
      expect(d.tagSlugs, ['food']);
      expect(codes(d), isEmpty);
    });

    test('a task that is not a bill keeps #food as a tag', () {
      final d = item('Cook #food');
      expect(d.tagSlugs, ['food']);
      expect(d.linkedCategoryId, isNull);
    });

    test('#bill stays a tag even if a category has that alias', () {
      final d = item(
        'Pay #bill',
        c: ParseContext(now, wallets, [
          category('bills', CategoryKind.outcome, ['bill']),
        ]),
      );
      expect(d.tagSlugs, ['bill']);
      expect(d.isBill, isTrue);
    });

    test('invalid slug stays text', () {
      expect(item('learn #c++ #').title, 'learn #c++ #');
    });
  });

  test('priority words, last one wins', () {
    const words = {
      '!low': Priority.low,
      '!l': Priority.low,
      '!rendah': Priority.low,
      '!med': Priority.med,
      '!m': Priority.med,
      '!sedang': Priority.med,
      '!high': Priority.high,
      '!h': Priority.high,
      '!TINGGI': Priority.high,
    };
    words.forEach((word, priority) {
      expect(item('x $word').priority, priority, reason: word);
    });
    final d = item('x !high !low');
    expect(d.priority, Priority.low);
    expect(d.title, 'x');
  });

  group('dates', () {
    LocalDate? due(String words) {
      final d = item('x $words');
      expect(d.title, 'x', reason: words);
      return d.dueDate;
    }

    test('words and absolute forms', () {
      const cases = {
        'today': '2026-11-25',
        'tdy': '2026-11-25',
        'hari ini': '2026-11-25',
        'hr ini': '2026-11-25',
        'Tomorrow': '2026-11-26',
        'tmr': '2026-11-26',
        'besok': '2026-11-26',
        'bsk': '2026-11-26',
        'lusa': '2026-11-27',
        'yesterday': '2026-11-24',
        'kemarin': '2026-11-24',
        'kmrn': '2026-11-24',
        'next week': '2026-11-30',
        'minggu depan': '2026-11-30',
        'in 3 days': '2026-11-28',
        '3 hari lagi': '2026-11-28',
        '12/12': '2026-12-12',
        '12/12/2027': '2027-12-12',
        '12 dec': '2026-12-12',
        '12 des': '2026-12-12',
        '1 jan 2027': '2027-01-01',
        '25/11': '2026-11-25',
        '24/11': '2027-11-24',
        '1 januari': '2027-01-01',
      };
      cases.forEach((words, iso) {
        expect(due(words), LocalDate.parse(iso), reason: words);
      });
    });

    test('weekdays are strictly after today', () {
      const days = {
        '2026-11-26': ['thu', 'thursday', 'kamis'],
        '2026-11-27': ['fri', 'friday', 'jumat', "jum'at"],
        '2026-11-28': ['sat', 'saturday', 'sabtu'],
        '2026-11-29': ['sun', 'sunday', 'minggu', 'ahad', 'hari minggu'],
        '2026-11-30': ['mon', 'monday', 'senin'],
        '2026-12-01': ['tue', 'tuesday', 'selasa'],
        '2026-12-02': ['wed', 'wednesday', 'rabu'],
      };
      days.forEach((iso, words) {
        for (final word in words) {
          expect(due(word), LocalDate.parse(iso), reason: word);
        }
      });
    });

    test('impossible dates stay text', () {
      for (final text in ['x 31/2', 'x 12/13', 'x 0/1', 'x 31 april']) {
        expect(item(text).title, text);
        expect(item(text).dueDate, isNull);
      }
    });

    test('29 Feb without a year only if this or next year has it', () {
      expect(item('x 29/2').dueDate, isNull);
      final c = ParseContext(DateTime(2027, 3, 1), wallets, categories);
      expect(item('x 29/2', c: c).dueDate, const LocalDate(2028, 2, 29));
    });

    test('only the first date counts', () {
      final d = item('x besok lusa');
      expect(d.dueDate, const LocalDate(2026, 11, 26));
      expect(d.title, 'x lusa');
    });
  });

  group('times', () {
    DateTime? start(String words) {
      final d = item('x besok $words');
      expect(d.title, 'x', reason: words);
      expect(d.dueDate, isNull);
      return d.scheduledStart;
    }

    test('forms and day parts', () {
      const cases = {
        '09:00': (9, 0),
        '9.30': (9, 30),
        'jam 9': (9, 0),
        'jam 21': (21, 0),
        'pukul 14:00': (14, 0),
        '9am': (9, 0),
        '9pm': (21, 0),
        '12am': (0, 0),
        '12pm': (12, 0),
        '9:30pm': (21, 30),
        'jam 2 siang': (14, 0),
        'jam 11 siang': (11, 0),
        'jam 3 sore': (15, 0),
        'jam 6 sore': (18, 0),
        'jam 6 malam': (18, 0),
        'jam 11 malam': (23, 0),
        'jam 7 pagi': (7, 0),
        'jam 8 nanti malam': (20, 0),
        'pagi': (8, 0),
        'siang': (12, 0),
        'sore': (16, 0),
        'malam': (19, 0),
        'nanti malam': (19, 0),
      };
      cases.forEach((words, time) {
        expect(start(words), at(11, 26, time.$1, time.$2), reason: words);
      });
    });

    test('ranges', () {
      const cases = {
        '14:00-15:30': ((14, 0), (15, 30)),
        'jam 9-10': ((9, 0), (10, 0)),
        'jam 7-9 malam': ((19, 0), (21, 0)),
        '9am-1pm': ((9, 0), (13, 0)),
      };
      cases.forEach((words, range) {
        final d = item('x besok $words');
        expect(d.title, 'x', reason: words);
        expect(d.scheduledStart, at(11, 26, range.$1.$1, range.$1.$2));
        expect(d.scheduledEnd, at(11, 26, range.$2.$1, range.$2.$2));
      });
      expect(item('x 23:00-01:00').scheduledEnd, at(11, 26, 1));
    });

    test('not times', () {
      for (final text in [
        'x 24:00',
        'x 9:60',
        'x 13pm',
        'jam 25',
        'pages 14-15',
        'tidur 8 jam',
      ]) {
        expect(item(text).title, text);
        expect(item(text).scheduledStart, isNull, reason: text);
      }
    });

    test('an explicit time beats a day part', () {
      final d = item('makan siang 13:00');
      expect(d.title, 'makan siang');
      expect(d.scheduledStart, at(11, 25, 13));
    });

    test('only a time-only value rolls over', () {
      expect(item('x 10:00').scheduledStart, at(11, 25, 10));
      expect(item('x today 09:00').scheduledStart, at(11, 25, 9));
    });
  });

  group('dates on transactions and notes', () {
    test('time is never moved forward; a future one warns', () {
      final past = txn('-5k 09:00');
      expect(past.occurredAt, at(11, 25, 9));
      expect(codes(past), isNot(contains(IssueCode.futureTransaction)));
      final future = txn('-5k 11:00');
      expect(future.occurredAt, at(11, 25, 11));
      expect(codes(future), contains(IssueCode.futureTransaction));
      expect(future.canSave, isTrue);
    });

    test('date only is 12:00; today does not warn, tomorrow does', () {
      final today = txn('-5k today');
      expect(today.occurredAt, at(11, 25, 12));
      expect(codes(today), isNot(contains(IssueCode.futureTransaction)));
      expect(codes(txn('-5k besok')), contains(IssueCode.futureTransaction));
    });

    test('notes keep date, time, wallet and priority words', () {
      final d = note('note: besok jam 9 @bca !h 50k #a\nbody #b\n# Heading\n');
      expect(d.title, 'besok jam 9 @bca !h 50k');
      expect(d.body, 'body #b\n# Heading');
      expect(d.tagSlugs, ['a', 'b']);
    });

    test('empty titles block', () {
      for (final d in [note('note:'), note('/ #a'), item(''), item('besok')]) {
        expect(codes(d), contains(IssueCode.emptyTitle), reason: d.raw);
        expect(d.canSave, isFalse);
      }
    });
  });

  group('escapes', () {
    test('an escaped token is never claimed', () {
      const input = r'\-35k \@bca \!h \besok \09:00 \50000 a\ b c\\ \';
      final d = item(input);
      expect(d.title, r'-35k @bca !h besok 09:00 50000 a b c\ \');
      expect(d.tokens, isEmpty);
    });

    test('an escaped word cannot complete a phrase', () {
      expect(item(r'x minggu \depan').title, 'x depan');
    });
  });

  test('token offsets point into the raw input', () {
    const input = '  -35k  lunch @gopay #food #x\njam 2 siang kemarin';
    final d = txn(input);
    expect(
      [for (final t in d.tokens) (t.kind, input.substring(t.start, t.end))],
      [
        (TokenKind.kindPrefix, '-'),
        (TokenKind.amount, '35k'),
        (TokenKind.wallet, '@gopay'),
        (TokenKind.category, '#food'),
        (TokenKind.tag, '#x'),
        (TokenKind.time, 'jam 2 siang'),
        (TokenKind.date, 'kemarin'),
      ],
    );
    for (final t in d.tokens) {
      expect(t.text, input.substring(t.start, t.end));
    }
    expect(d.tokens[1].value, 35000);
    expect(d.tokens[2].value, 'w-gopay');

    final n = note('Note: a #b');
    expect([for (final t in n.tokens) t.text], ['Note:', '#b']);
    final transfer = txn('1k @bca > @gopay 9am-10am');
    expect(
      [for (final t in transfer.tokens) (t.kind, t.text)],
      [
        (TokenKind.amount, '1k'),
        (TokenKind.transfer, '@bca > @gopay'),
        (TokenKind.timeRange, '9am-10am'),
      ],
    );
  });

  group('overrides', () {
    test('kind', () {
      const asTask = CaptureOverrides(kind: CaptureKind.actionItem);
      final task = item('-35k lunch', o: asTask);
      expect(task.title, 'lunch');
      expect(task.linkedAmount, 35000);
      const asNote = CaptureOverrides(kind: CaptureKind.note);
      expect(note('-35k besok', o: asNote).title, '-35k besok');
      expect(item('note: x', o: asTask).title, 'x');
      const asTxn = CaptureOverrides(kind: CaptureKind.transaction);
      expect(txn('lunch 35000', o: asTxn).amount, 35000);
    });

    test('chip values win and clear their issues', () {
      final d = txn(
        '-35.5 @ovo #dev',
        o: CaptureOverrides(
          amount: 42,
          walletId: 'w-bca',
          categoryId: 'c-food',
          when: at(11, 20, 8),
        ),
      );
      expect(d.amount, 42);
      expect(d.walletId, 'w-bca');
      expect(d.categoryId, 'c-food');
      expect(d.occurredAt, at(11, 20, 8));
      expect(d.tagSlugs, ['dev']);
      expect(d.issues, isEmpty);
    });

    test('transfer wallets', () {
      final d = txn(
        '1k @ovo>@x',
        o: const CaptureOverrides(walletId: 'w-bca', toWalletId: 'w-cash'),
      );
      expect((d.walletId, d.toWalletId), ('w-bca', 'w-cash'));
      expect(d.issues, isEmpty);
    });

    test('bad override values still block', () {
      final d = txn(
        '-1k',
        o: const CaptureOverrides(amount: 0, walletId: 'gone'),
      );
      expect(
        codes(d),
        containsAll([IssueCode.invalidAmount, IssueCode.unknownWallet]),
      );
    });

    test('a category of the wrong kind is ignored', () {
      final d = txn(
        '+1k #income',
        o: const CaptureOverrides(categoryId: 'c-food'),
      );
      expect(d.categoryId, 'c-income');
    });

    test('action item values', () {
      final d = item(
        'x 14:00-15:00 !l',
        o: CaptureOverrides(
          priority: Priority.high,
          when: at(12, 1, 8),
          amount: 5,
          walletId: 'w-bca',
          categoryId: 'c-food',
        ),
      );
      expect(d.priority, Priority.high);
      expect(d.scheduledStart, at(12, 1, 8));
      expect(d.scheduledEnd, at(12, 1, 9));
      expect(d.linkedAmount, 5);
      expect(d.linkedWalletId, 'w-bca');
      expect(d.linkedCategoryId, 'c-food');
      final dated = item('x besok', o: CaptureOverrides(when: at(12, 1, 8)));
      expect(dated.dueDate, isNull);
    });
  });

  test('a UTC clock yields UTC times', () {
    final c = ParseContext(DateTime.utc(2026, 11, 25, 10), wallets, categories);
    expect(item('x 11:00', c: c).scheduledStart!.isUtc, isTrue);
  });
}
