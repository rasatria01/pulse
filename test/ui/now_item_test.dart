import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/domain/entities/action_item.dart';
import 'package:pulse/ui/planner/agenda_row.dart';

void main() {
  final nine = DateTime.utc(2026, 11, 26, 9);
  ActionItem item(String id, int hour, [ActionStatus? status]) => ActionItem(
    id: id,
    title: id,
    status: status ?? ActionStatus.open,
    scheduledStart: DateTime.utc(2026, 11, 26, hour),
    createdAt: nine,
    updatedAt: nine,
  );

  test('only the first open item that is not over is "now"', () {
    final day = [
      item('past', 7),
      item('done', 9, ActionStatus.done),
      item('next', 10),
      item('later', 11),
    ];
    expect(nowItemId(day, nine), 'next');
    expect(nowItemId(day, DateTime.utc(2026, 11, 26, 12)), isNull);
  });
}
