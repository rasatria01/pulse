import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../../domain/services/backup_gateway.dart';
import '../../../ui/widgets/widgets.dart';
import '../settings_strings.dart';

String refusalMessage(String refusal) => switch (refusal) {
  RestoreRefusal.notPulse => SettingsStrings.refusedNotPulse,
  RestoreRefusal.newer => SettingsStrings.refusedNewer,
  RestoreRefusal.schema => SettingsStrings.refusedSchema,
  _ => SettingsStrings.refusedDamaged,
};

/// The summary of a checked backup. Pops true to restore it.
class RestoreSheet extends StatelessWidget {
  const RestoreSheet({super.key, required this.check});

  final RestoreCheck check;

  @override
  Widget build(BuildContext context) {
    final exported = check.exportedAt;
    return PSheet(
      title: SettingsStrings.restoreTitle,
      footer: [
        PButton.ghost(
          label: SettingsStrings.cancel,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        PButton.primary(
          label: SettingsStrings.restoreConfirm,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.5,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: MelaSpace.s1,
            children: [
              Text(
                exported == null
                    ? SettingsStrings.unknownDate
                    : SettingsStrings.exportedOn(
                        DateFormat('d MMM yyyy, HH:mm')
                            .format(exported.toLocal()),
                      ),
                style: MelaText.bodyStrong,
              ),
              for (final MapEntry(key: table, value: name)
                  in SettingsStrings.tableNames.entries)
                if (check.rowCounts[table] case final count?)
                  MergeSemantics(
                    child: Row(
                      spacing: MelaSpace.s3,
                      children: [
                        Expanded(child: Text(name)),
                        Text(SettingsStrings.rows(count)),
                      ],
                    ),
                  ),
              const Text(SettingsStrings.restoreWarning),
            ],
          ),
        ),
      ),
    );
  }
}
