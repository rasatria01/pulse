// PRD section 5, amount rules. Integer arithmetic only.

const maxAmount = 1000000000000000; // 10^15

final _shape = RegExp(r'^(rp\.?)?(\d+(?:[.,]\d+)*)(ribu|rb|k|juta|jt|m)?$');
final _separator = RegExp('[.,]');
final _leadingZeros = RegExp(r'^0+');

/// A word shaped like an amount. [value] is null when it breaks the rules.
final class AmountText {
  const AmountText(this.value, {required this.explicit, required this.grouped});

  final int? value;

  /// Has a suffix or an Rp prefix, so it was clearly meant as money.
  final bool explicit;

  /// Has thousands separators or at least 5 digits.
  final bool grouped;

  /// Counts as money without a sign (the action item rule).
  bool get looksLikeMoney => explicit || (grouped && value != null);
}

/// Null when [word] (lowercase) is not amount-shaped at all.
AmountText? readAmount(String word) {
  final m = _shape.firstMatch(word);
  if (m == null) return null;
  final number = m[2]!;
  final suffix = m[3];
  final groups = number.split(_separator);
  return AmountText(
    _rupiah(groups, suffix),
    explicit: m[1] != null || suffix != null,
    grouped: groups.length > 1 || number.length >= 5,
  );
}

int? _rupiah(List<String> groups, String? suffix) {
  var whole = groups.first;
  var fraction = '';
  var scale = 1;
  if (suffix != null) {
    // One separator at most, and it is the decimal point.
    if (groups.length > 2) return null;
    if (groups.length == 2) fraction = groups[1];
    scale = switch (suffix) {
      'k' || 'rb' || 'ribu' => 1000,
      _ => 1000000,
    };
  } else {
    if (groups.skip(1).any((g) => g.length != 3)) return null;
    whole = groups.join();
  }

  whole = whole.replaceFirst(_leadingZeros, '');
  // 16 digits hold 10^15 and cannot overflow int.
  if (whole.length > 16) return null;
  final units = whole.isEmpty ? 0 : int.parse(whole);
  if (units > maxAmount ~/ scale) return null;

  var end = fraction.length;
  while (end > 0 && fraction[end - 1] == '0') {
    end--;
  }
  var part = 0;
  if (end > 0) {
    // More than 6 decimals can never be a whole rupiah.
    if (end > 6) return null;
    var divisor = 1;
    for (var i = 0; i < end; i++) {
      divisor *= 10;
    }
    final scaled = int.parse(fraction.substring(0, end)) * scale;
    if (scaled % divisor != 0) return null; // no silent rounding
    part = scaled ~/ divisor;
  }

  final total = units * scale + part;
  return total > 0 && total <= maxAmount ? total : null;
}
