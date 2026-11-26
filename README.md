# MelaTime

*Menata laku, setiap waktu.*

Offline money, tasks and notes. Android only (`app.melatime`, Android 8+). No INTERNET permission in release.

```
flutter pub get
dart run build_runner build
dart run tool/check_imports.dart
flutter analyze
flutter test
```

Layers and import rules: PRD section 7, enforced by `tool/check_imports.dart`.
Generated files (`*.freezed.dart`, `*.g.dart`) are not committed.

Colours and type: `lib/ui/tokens.dart`, from the MelaTime design system. The splash
tagline is an image; redraw it with `flutter test tool/splash_tagline.dart`.
