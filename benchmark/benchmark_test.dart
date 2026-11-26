// PRD section 10 on the seeded database, in a file. The numbers are this host's,
// not the reference phone's. Not in test/, as timings taken beside the other
// tests mean nothing. Run: flutter test benchmark
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/local_date.dart';
import 'package:pulse/domain/entities/action_item.dart';
import 'package:pulse/domain/entities/search.dart';
import 'package:pulse/domain/entities/tag.dart';

import '../test/data/support.dart';
import '../tool/benchmark_seed.dart';

/// 200 searches: common and rare words, prefixes as typed, two words, tags.
List<SearchQuery> _queries() {
  final r = Random(7);
  String word() => benchmarkWords[r.nextInt(benchmarkWords.length)];
  String common() => benchmarkWords[r.nextInt(8)];
  return [
    for (var i = 0; i < 25; i++) ...[
      SearchQuery(text: common()),
      SearchQuery(text: word()),
      SearchQuery(text: word().substring(0, 2)),
      SearchQuery(text: '${common()} ${word()}'),
      SearchQuery(text: '#${benchmarkWords[r.nextInt(30)]}-tag'),
      SearchQuery(text: '${word()} #${benchmarkWords[r.nextInt(30)]}-tag'),
      SearchQuery(
        text: common(),
        type: EntityType.values[i % EntityType.values.length],
      ),
      // One letter: the widest query there is.
      SearchQuery(text: common().substring(0, 1)),
    ],
  ];
}

double _percentile(List<double> ms, double p) =>
    (ms.toList()..sort())[(ms.length * p).ceil() - 1];

Future<double> _time(Future<Object?> Function() run) async {
  final watch = Stopwatch()..start();
  await run();
  return watch.elapsedMicroseconds / 1000;
}

void main() {
  late Directory dir;
  late Harness h;

  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('pulse-bench');
    // No stream cache: every `.first` below must reach SQLite.
    h = Harness(
      DatabaseConnection(
        NativeDatabase(File('${dir.path}/bench.sqlite')),
        closeStreamsSynchronously: true,
      ),
    );
    await seedBenchmark(h.db);
  });
  tearDownAll(() async {
    await h.db.close();
    dir.deleteSync(recursive: true);
  });

  test('the database has the PRD volumes', () async {
    for (final (table, rows) in [
      ('transactions', benchmarkTransactions),
      ('action_items', benchmarkItems),
      ('notes', benchmarkNotes),
    ]) {
      final n = (await h.sql('SELECT COUNT(*) AS n FROM $table')).single;
      expect(n.read<int>('n'), greaterThanOrEqualTo(rows));
    }
  });

  test('search p95 over 200 mixed queries is under 50 ms', () async {
    final queries = _queries();
    expect(queries, hasLength(200));
    await h.search.search(queries.first); // warm the page cache
    final ms = [for (final q in queries) await _time(() => h.search.search(q))];
    // The eight shapes of _queries, in order.
    for (final (i, shape) in const [
      'common word',
      'any word',
      'two-letter prefix',
      'two words',
      'tag only',
      'word and tag',
      'one type',
      'one letter',
    ].indexed) {
      final of = [for (var j = i; j < ms.length; j += 8) ms[j]];
      // ignore: avoid_print
      print('  $shape: p50 ${_percentile(of, .5)}, max ${of.reduce(max)} ms');
    }
    // ignore: avoid_print
    print(
      'search: p50 ${_percentile(ms, .5)} ms, p95 ${_percentile(ms, .95)} ms, '
      'max ${ms.reduce(max)} ms',
    );
    expect(_percentile(ms, .95), lessThan(50));
  });

  test('Today and Finance queries', () async {
    const day = benchmarkToday;
    const end = LocalDate(2026, 11, 30);
    const first = LocalDate(2026, 11, 1);
    final queries = <String, Stream<Object?> Function()>{
      'wallet balances': () => h.wallets.watchAll(includeArchived: true),
      'liquid total': () => h.wallets.watchLiquidTotal(),
      'spent today': () => h.transactions.watchOutcomeTotal(day, day),
      'spent this month': () => h.transactions.watchOutcomeTotal(first, day),
      'budget statuses': () => h.budgets.watchMonth(day.monthOf),
      'committed bills': () =>
          h.items.watchCommitted(day, end, doneSince: day.startUtc()),
      'occurrences': () => h.recurring.watchOccurrences(day, end),
      'pending occurrences': () => h.recurring.watchPending(),
      'rules': () => h.recurring.watchRules(),
      'pending bills': () => h.items.watchPendingBills(),
      'inbox': () => h.items.watchInbox(day),
      'timeline': () =>
          h.items.watchScheduled(day.startUtc(), day.addDays(1).startUtc()),
      'due lane': () => h.items.watchDueOn(day),
      'scratchpad': () => h.notes.watchDaily(day),
      'tags': () => h.tags.watchAll(),
      'finance history, 90 days': () => h.transactions.watchRange(
        day.addDays(-90),
        const LocalDate(9999, 12, 31),
      ),
      'tasks, open': () =>
          h.items.watchTasks(const TaskFilter(statuses: {ActionStatus.open})),
      'tasks, done': () =>
          h.items.watchTasks(const TaskFilter(statuses: {ActionStatus.done})),
      'notes list': () => h.notes.watchAll(),
    };
    for (final MapEntry(key: name, value: query) in queries.entries) {
      var rows = 0;
      final ms = <double>[];
      for (var i = 0; i < 6; i++) {
        final t = await _time(() async {
          final value = await query().first;
          rows = value is List ? value.length : 1;
          return value;
        });
        if (i > 0) ms.add(t); // the first run warms the cache
      }
      // ignore: avoid_print
      print('$name: median ${_percentile(ms, .5)} ms, $rows rows');
    }
  });
}
