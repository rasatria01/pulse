import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/local_date.dart';
import 'package:pulse/data/platform/uuid_id_generator.dart';

void main() {
  test('LocalDate parses, formats and crosses month ends', () {
    expect(LocalDate.parse('2027-02-28').addDays(1).toIso(), '2027-03-01');
    expect(LocalDate.parse('2028-02-28').addDays(1).toIso(), '2028-02-29');
    expect(
      const LocalDate(2026, 12, 31).addDays(1),
      const LocalDate(2027, 1, 1),
    );
    expect(LocalMonth.parse('2026-12').lastDay.toIso(), '2026-12-31');
    expect(
      const LocalDate(2026, 1, 2).compareTo(const LocalDate(2026, 1, 10)),
      isNegative,
    );
  });

  test('LocalDate rejects impossible and malformed dates', () {
    for (final bad in ['2026-02-30', '2026-13-01', '26-01-01', 'today']) {
      expect(() => LocalDate.parse(bad), throwsFormatException, reason: bad);
    }
  });

  test('ids are UUIDv7', () {
    expect(
      const UuidIdGenerator().newId(),
      matches(r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-'),
    );
  });
}
