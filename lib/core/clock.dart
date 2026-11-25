import 'local_date.dart';

/// The only source of time. `DateTime.now()` is banned outside this file.
abstract interface class Clock {
  DateTime nowUtc();
  DateTime nowLocal();
  LocalDate today();
}

final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();

  @override
  DateTime nowLocal() => DateTime.now();

  @override
  LocalDate today() => LocalDate.fromDateTime(nowLocal());
}
