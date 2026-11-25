// PRD section 5: 100,000 random inputs, never throws, each call under 2 ms.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/domain/parser/capture_parser.dart';
import 'package:pulse/domain/parser/parse_result.dart';

import 'fixture.dart';

const _runs = 100000;
const _budgetUs = 2000;

const _pieces = [
  ' ', ' ', ' ', ' ', '\n', '\t', r'\', //
  '-', '+', '*', '/', '@', '#', '!', '>', ':', '.', ',', "'",
  'note:', 'rp', 'k', 'rb', 'jt', 'm', 'am', 'pm', 'h', 'l',
  '0', '1', '2', '9', '00', '12', '30', '2026', '999999999999999999999',
  '@bca', '@gopay', '@bca>@gopay', '@ovo', '#food', '#bill', '#income',
  'jam', 'pukul', 'siang', 'malam', 'nanti', 'besok', 'hari', 'ini',
  'minggu', 'depan', 'next', 'week', 'in', 'days', 'lagi', 'dec', 'feb',
  '29/2', '12/12/9999', '31 des 2999', '9999 hari lagi', '14:00-15:30',
  'İ', 'é', '’', ' ', '😀', '\u0000',
];

String _random(Random random) {
  // One in 500 is a long paste, far past the 200 characters of F1.
  final length = random.nextInt(500) == 0
      ? 200 + random.nextInt(200)
      : random.nextInt(40);
  final text = StringBuffer();
  for (var i = 0; i < length; i++) {
    if (random.nextInt(8) == 0) {
      text.writeCharCode(random.nextInt(0x10000));
    } else {
      text.write(_pieces[random.nextInt(_pieces.length)]);
    }
  }
  return text.toString();
}

CaptureOverrides? _overrides(Random random) {
  if (random.nextInt(10) != 0) return null;
  T? maybe<T>(T value) => random.nextBool() ? value : null;
  return CaptureOverrides(
    kind: maybe(CaptureKind.values[random.nextInt(3)]),
    walletId: maybe('w-bca'),
    toWalletId: maybe('nope'),
    categoryId: maybe('c-food'),
    amount: maybe(random.nextInt(10) - 1),
    when: maybe(now),
  );
}

void main() {
  test('fuzz: no throw, each call under 2 ms', () {
    // Warm up the JIT on a different seed; these calls are not timed.
    final warm = Random(1);
    for (var i = 0; i < 20000; i++) {
      parseCapture(_random(warm), ctx, overrides: _overrides(warm));
    }

    final random = Random(2026);
    final watch = Stopwatch();
    final times = List.filled(_runs, 0);
    var retimed = 0;
    for (var i = 0; i < _runs; i++) {
      final input = _random(random);
      final overrides = _overrides(random);
      int time() {
        watch
          ..reset()
          ..start();
        final result = parseCapture(input, ctx, overrides: overrides);
        watch.stop();
        for (final t in result.tokens) {
          if (t.start < 0 || t.end > input.length || t.start >= t.end) {
            fail('bad token offsets for ${input.codeUnits}');
          }
        }
        return watch.elapsedMicroseconds;
      }

      var us = times[i] = time();
      // A single slow reading can be a GC pause or the OS scheduler. A slow
      // input is slow every time, so the best of 5 more still catches it.
      if (us >= _budgetUs) {
        retimed++;
        for (var again = 0; again < 5; again++) {
          us = min(us, time());
        }
        expect(us, lessThan(_budgetUs), reason: '${input.codeUnits}');
      }
    }

    times.sort();
    printOnFailure('max ${times.last} us');
    // ignore: avoid_print
    print(
      'fuzz: p50 ${times[_runs ~/ 2]} us, p99 ${times[_runs * 99 ~/ 100]} us, '
      'p99.9 ${times[_runs * 999 ~/ 1000]} us, raw max ${times.last} us, '
      're-timed $retimed',
    );
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('pathological long inputs stay under 2 ms', () {
    final inputs = [
      '1' * 5000,
      '1.' * 2500,
      '@' * 5000,
      'a ' * 1000,
      'jam ' * 1000,
      '@a > ' * 500,
      '#x ' * 200,
    ];
    for (final input in inputs) {
      var best = 1 << 30;
      for (var i = 0; i < 20; i++) {
        final watch = Stopwatch()..start();
        parseCapture(input, ctx);
        best = min(best, watch.elapsedMicroseconds);
      }
      // These are 25x the 200 characters of F1.
      expect(best, lessThan(_budgetUs), reason: input.substring(0, 20));
    }
  });
}
