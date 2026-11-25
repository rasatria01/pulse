# Pulse

Offline money, tasks and notes. Android only. No INTERNET permission in release.

```
flutter pub get
dart run build_runner build
dart run tool/check_imports.dart
flutter analyze
flutter test
```

Layers and import rules: PRD section 7, enforced by `tool/check_imports.dart`.
Generated files (`*.freezed.dart`, `*.g.dart`) are not committed.
