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

  test('wall clock and money doubles fail', () {
    expect(count('data/a.dart', 'final t = DateTime.now();'), 1);
    expect(count('data/a.dart', 'final t = DateTime.timestamp;'), 1);
    expect(count('domain/a.dart', 'double ratio = 0;'), 1);
    expect(count('domain/a.dart', '// never DateTime.now() or double'), 0);
  });
}
