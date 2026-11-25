import 'package:uuid/uuid.dart';

import '../../core/ids.dart';

final class UuidIdGenerator implements IdGenerator {
  const UuidIdGenerator();

  @override
  String newId() => const Uuid().v7();
}
