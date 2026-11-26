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

## Updating without losing data

Install a new version over the old one:

```
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Never use `flutter install`: it uninstalls first, which deletes the data. `flutter run`
also uninstalls if the update is refused.

For an update to keep the data, keep the same:

- **Signing key:** `%USERPROFILE%\.android\debug.keystore` on the build machine. Keep a
  copy somewhere safe. An APK from CI or another machine is signed with another key.
- **Package id** `app.melatime` and database file `pulse.sqlite`.
- **Version code** order: raise the number after `+` in `pubspec.yaml`, never lower it.

A schema change needs a higher `schemaVersion`, a migration step that keeps every row,
a new dump in `drift_schemas/`, a migration test with data in it, and
`backup_check.dart` still accepting backups from older versions. Take a backup in
Settings before installing such an update.
