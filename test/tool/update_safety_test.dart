// What an installed copy needs from an update to keep its data (see README).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/settings/settings_strings.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('package id and database file are the ones already installed', () {
    expect(
      _read('android/app/build.gradle.kts'),
      contains('applicationId = "app.melatime"'),
    );
    expect(_read('lib/data/db/connection.dart'), contains("/pulse.sqlite'"));
  });

  test('About shows the version being built', () {
    final version = RegExp(
      r'^version: (\d+\.\d+)\.\d+\+\d+\s*$',
      multiLine: true,
    ).firstMatch(_read('pubspec.yaml'))![1];
    expect(SettingsStrings.version, 'Version $version');
  });
}
