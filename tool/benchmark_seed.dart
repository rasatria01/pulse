// The benchmark database of PRD section 10.
// Run: dart run tool/benchmark_seed.dart <new-file.sqlite>
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:pulse/core/local_date.dart';
import 'package:pulse/data/db/app_database.dart';

const benchmarkToday = LocalDate(2026, 11, 25);
const benchmarkTransactions = 50000;
const benchmarkItems = 10000;
const benchmarkNotes = 2000;

/// Everyday words first; [benchmarkWord] picks the early ones far more often.
const benchmarkWords = [
  'makan', 'siang', 'kopi', 'bayar', 'beli', 'lunch', 'coffee', 'grab', //
  'gojek', 'parkir', 'bensin', 'listrik', 'air', 'internet', 'pulsa', 'sewa',
  'kos', 'belanja', 'pasar', 'warung', 'nasi', 'ayam', 'goreng', 'bakso',
  'mie', 'teh', 'susu', 'roti', 'buah', 'sayur', 'obat', 'dokter', 'klinik',
  'gym', 'buku', 'kursus', 'sekolah', 'kantor', 'meeting', 'laporan',
  'project', 'client', 'invoice', 'design', 'review', 'deploy', 'server',
  'backup', 'email', 'call', 'ibu', 'ayah', 'adik', 'teman', 'kado',
  'liburan', 'tiket', 'kereta', 'pesawat', 'hotel', 'bali', 'jakarta',
  'bandung', 'surabaya', 'transfer', 'tabungan', 'cicilan', 'asuransi',
  'pajak', 'donasi', 'zakat', 'servis', 'motor', 'mobil', 'laundry',
  'cukur', 'netflix', 'spotify', 'game', 'sepatu', 'baju', 'celana',
  'kacamata', 'printer', 'kertas', 'tinta', 'lampu', 'kabel', 'charger',
  'baterai', 'galon', 'gas', 'sabun', 'sampo', 'deterjen', 'minyak',
  'beras', 'telur', 'gula', 'garam',
];

String benchmarkWord(Random r) {
  final x = r.nextDouble();
  return benchmarkWords[(x * x * benchmarkWords.length).floor()];
}

String _phrase(Random r, int least, int most) => [
  for (var i = least + r.nextInt(most - least + 1); i > 0; i--)
    benchmarkWord(r),
].join(' ');

/// Fills a freshly created [db], FTS index included (through its triggers).
Future<void> seedBenchmark(AppDatabase db) async {
  final r = Random(42);
  var next = 0;
  String id(String kind) => '$kind-${(next++).toString().padLeft(7, '0')}';
  const day = Duration.millisecondsPerDay;
  final now = DateTime.utc(2026, 11, 25, 3).millisecondsSinceEpoch;
  String date(int fromToday) => benchmarkToday.addDays(fromToday).toIso();

  final cash = (await db.select(db.wallets).getSingle()).id;
  final categories = await db.select(db.categories).get();
  final outcome = [
    for (final c in categories)
      if (c.kind == 'outcome') c.id,
  ];
  final income = [
    for (final c in categories)
      if (c.kind == 'income') c.id,
  ];
  final wallets = [cash];
  final tags = <String>[];

  await db.batch((b) {
    for (final (i, slug) in ['bca', 'gopay', 'ovo', 'jago'].indexed) {
      final wallet = id('wallet');
      wallets.add(wallet);
      b.insert(
        db.wallets,
        WalletsCompanion.insert(
          id: wallet,
          name: slug,
          slug: slug,
          kind: 'bank',
          initialBalance: const Value(1000000),
          color: 0xFF3B74E0,
          icon: 'wallet',
          sortOrder: Value(i + 1),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    for (var i = 0; i < 30; i++) {
      final tag = id('tag');
      tags.add(tag);
      final slug = '${benchmarkWords[i]}-tag';
      b.insert(
        db.tags,
        TagsCompanion.insert(
          id: tag,
          name: slug,
          slug: slug,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    for (final category in outcome.take(3)) {
      b.insert(
        db.budgets,
        BudgetsCompanion.insert(
          id: id('budget'),
          categoryId: category,
          amount: 3000000,
          effectiveFrom: '2024-01',
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
  });

  void tag(Batch b, String type, String entity, {required int oneIn}) {
    if (r.nextInt(oneIn) != 0) return;
    b.insert(
      db.taggings,
      TaggingsCompanion.insert(
        tagId: tags[r.nextInt(tags.length)],
        entityType: type,
        entityId: entity,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  // Three years of history, oldest first, as a real file grows.
  await db.batch((b) {
    for (var i = 0; i < benchmarkTransactions; i++) {
      final ago =
          1095 * (benchmarkTransactions - 1 - i) ~/ benchmarkTransactions;
      final at = now - ago * day - r.nextInt(3600000);
      final roll = r.nextInt(100);
      final from = r.nextInt(wallets.length);
      final transaction = id('tx');
      final type = roll < 8
          ? 'INCOME'
          : roll < 12
          ? 'TRANSFER'
          : 'OUTCOME';
      b.insert(
        db.transactions,
        TransactionsCompanion.insert(
          id: transaction,
          type: type,
          amount: 1000 * (1 + r.nextInt(type == 'INCOME' ? 2000 : 150)),
          walletId: wallets[from],
          toWalletId: Value(
            type == 'TRANSFER' ? wallets[(from + 1) % wallets.length] : null,
          ),
          categoryId: Value(switch (type) {
            'INCOME' => income[r.nextInt(income.length)],
            'OUTCOME' => outcome[r.nextInt(outcome.length)],
            _ => null,
          }),
          description: Value(_phrase(r, 1, 4)),
          occurredAt: at,
          occurredOn: date(-ago),
          createdAt: at,
          updatedAt: at,
          isDeleted: Value(r.nextInt(100) == 0 ? 1 : 0),
        ),
      );
      tag(b, 'transaction', transaction, oneIn: 8);
    }
  });

  // Mostly finished history; a few hundred still open around today.
  await db.batch((b) {
    for (var i = 0; i < benchmarkItems; i++) {
      final done = r.nextInt(100) < 90;
      final offset = done ? -r.nextInt(1000) : r.nextInt(120) - 30;
      final scheduled = r.nextInt(100) < 35;
      final start = scheduled
          ? now + offset * day + r.nextInt(36000) * 1000
          : null;
      final bill = r.nextInt(20) == 0;
      final item = id('ai');
      final at = now - r.nextInt(1000) * day;
      b.insert(
        db.actionItems,
        ActionItemsCompanion.insert(
          id: item,
          title: _phrase(r, 2, 6),
          body: Value(r.nextInt(5) == 0 ? _phrase(r, 5, 30) : ''),
          status: Value(done ? 'done' : 'open'),
          priority: Value(r.nextInt(10) == 0 ? 3 : r.nextInt(3)),
          dueDate: Value(
            !scheduled && r.nextInt(100) < 70 ? date(offset) : null,
          ),
          scheduledStart: Value(start),
          scheduledEnd: Value(start == null ? null : start + 1800000),
          linkedAmount: Value(bill ? 1000 * (10 + r.nextInt(500)) : null),
          billStatus: Value(
            bill && done ? (r.nextInt(50) == 0 ? 'pending' : 'recorded') : null,
          ),
          completedAt: Value(done ? now + offset * day : null),
          createdAt: at,
          updatedAt: at,
        ),
      );
      tag(b, 'action_item', item, oneIn: 5);
    }
  });

  await db.batch((b) {
    for (var i = 0; i < benchmarkNotes; i++) {
      final note = id('note');
      final at = now - r.nextInt(1000) * day - i;
      final title = _phrase(r, 2, 5);
      b.insert(
        db.notes,
        NotesCompanion.insert(
          id: note,
          title: Value(title),
          body: Value(
            [
              '# $title',
              for (var line = 3 + r.nextInt(25); line > 0; line--)
                _phrase(r, 4, 14),
            ].join('\n'),
          ),
          createdAt: at,
          updatedAt: at,
        ),
      );
      tag(b, 'note', note, oneIn: 3);
    }
    for (var i = 0; i < 20; i++) {
      final rule = id('rule');
      b.insert(
        db.recurringRules,
        RecurringRulesCompanion.insert(
          id: rule,
          name: _phrase(r, 1, 3),
          type: 'OUTCOME',
          amount: 50000,
          walletId: cash,
          categoryId: Value(outcome.first),
          freq: 'monthly',
          startDate: date(-700),
          nextDueDate: date(1 + r.nextInt(28)),
          createdAt: now,
          updatedAt: now,
        ),
      );
      for (var month = 1; month <= 24; month++) {
        b.insert(
          db.recurringOccurrences,
          RecurringOccurrencesCompanion.insert(
            id: id('occ'),
            ruleId: rule,
            occurrenceDate: date(-30 * month),
            // The latest of a few rules still waits for confirmation.
            status: Value(month == 1 && i < 3 ? 'pending' : 'skipped'),
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    }
  });
}

Future<void> main(List<String> args) async {
  if (args.length != 1 || File(args.single).existsSync()) {
    stderr.writeln(
      'usage: dart run tool/benchmark_seed.dart <new-file.sqlite>',
    );
    exitCode = 64;
    return;
  }
  final db = AppDatabase(NativeDatabase(File(args.single)));
  await seedBenchmark(db);
  await db.close();
  stdout.writeln('seeded ${args.single}');
}
