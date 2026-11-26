import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/db/app_database.dart';
import 'package:pulse/ui/widgets/p_icon.dart';

void main() {
  test(
    'every seeded wallet and category icon is known to the UI kit',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final rows = await db
          .customSelect(
            'SELECT icon FROM wallets UNION SELECT icon FROM categories',
          )
          .get();
      expect(rows, isNotEmpty);
      for (final row in rows) {
        expect(melaIcons, contains(row.read<String>('icon')));
      }
    },
  );
}
