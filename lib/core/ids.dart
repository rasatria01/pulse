/// Primary keys are UUIDv7 text (D6). Implemented in data/platform.
abstract interface class IdGenerator {
  String newId();
}
