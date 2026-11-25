import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_imports.dart';

void main() {
  int count(String path, String source) => violations(path, source).length;

  test('allowed imports pass', () {
    expect(
      count('domain/services/a.dart', "import '../../core/clock.dart';"),
      0,
    );
    expect(count('features/today/a.dart', "import '../../app/di.dart';"), 0);
    expect(count('features/today/widgets/a.dart', "import '../b.dart';"), 0);
    expect(count('core/clock.dart', 'DateTime.now();'), 0);
  });

  test('forbidden imports fail', () {
    expect(count('core/a.dart', "import 'package:uuid/uuid.dart';"), 1);
    expect(count('domain/a.dart', "import 'package:flutter/widgets.dart';"), 1);
    expect(count('data/a.dart', "import 'package:pulse/ui/theme.dart';"), 1);
    expect(count('ui/a.dart', "import '../data/db/x.dart';"), 1);
    expect(count('features/today/a.dart', "import '../tasks/b.dart';"), 1);
    expect(
      count('features/today/a.dart', "import 'package:drift/drift.dart';"),
      1,
    );
    expect(count('features/today/a.dart', "export '../../data/x.dart';"), 1);
  });

  test('evasions fail', () {
    const feature = 'features/today/a.dart';
    expect(
      count(
        feature,
        "import 'x.dart'\n    if (dart.library.io) '../../data/x.dart';",
      ),
      1,
    );
    expect(
      count(feature, "import 'package:pulse/features/today/../tasks/b.dart';"),
      1,
    );
    expect(count(feature, "part '../tasks/b.dart';"), 1);
    expect(count('features/today/widgets/a.dart', "part of '../b.dart';"), 0);
    expect(count('domain/a.dart', "import 'dart:io';"), 1);
    expect(count('shared/a.dart', ''), 1);
    expect(
      count('data/a.dart', "const u = 'http://x'; var t = DateTime.now();"),
      1,
    );
    expect(count('data/a.dart', "/* DateTime.now() */"), 0);
    expect(count('domain/a.dart', "const s = 'double tap';"), 0);
    expect(count('domain/a.dart', 'final x = n.toDouble();'), 1);
  });

  test('wall clock and money doubles fail', () {
    expect(count('data/a.dart', 'final t = DateTime.now();'), 1);
    expect(count('data/a.dart', 'final t = DateTime.timestamp;'), 1);
    expect(count('domain/a.dart', 'double ratio = 0;'), 1);
    expect(count('domain/a.dart', '// never DateTime.now() or double'), 0);
  });
}
