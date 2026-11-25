import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shad/shad.dart';

import '../../app/di.dart';
import '../../core/failures.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../ui/strings.dart';
import '../../ui/widgets/widgets.dart';
import 'controllers/settings_providers.dart';
import 'settings_strings.dart';

const _themes = [
  (ShadThemeMode.system, SettingsStrings.themeSystem),
  (ShadThemeMode.light, SettingsStrings.themeLight),
  (ShadThemeMode.dark, SettingsStrings.themeDark),
];

// Every half hour of the day.
final _times = [
  for (var half = 0; half < 48; half++)
    '${(half ~/ 2).toString().padLeft(2, '0')}:${half.isEven ? '00' : '30'}',
];

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _exporting = false;
  String? _message;

  Future<void> _put(String key, String value) async {
    try {
      await ref.read(settingsRepositoryProvider).put(key, value);
    } on AppFailure {
      if (mounted) setState(() => _message = SettingsStrings.saveFailed);
    }
  }

  Future<void> _setDueTime(String time) async {
    final scheduler = ref.read(reminderSchedulerProvider);
    await _put(SettingKeys.dueReminderTime, time);
    await scheduler.resyncAll();
  }

  Future<void> _export({required bool save}) async {
    final gateway = ref.read(backupGatewayProvider);
    setState(() {
      _exporting = true;
      _message = null;
    });
    String? message;
    try {
      final path = await gateway.exportSqlite();
      if (save) {
        if (await gateway.saveAs(path)) message = SettingsStrings.backupSaved;
      } else {
        await gateway.share(path);
      }
    } catch (_) {
      // Plugins throw PlatformException and IO errors besides AppFailure.
      message = SettingsStrings.backupFailed;
    }
    if (!mounted) return;
    setState(() {
      _exporting = false;
      _message = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = ShadTheme.of(context).colorScheme;
    final mode = ref.watch(themeModeProvider).value ?? ShadThemeMode.system;
    final dueTime = ref.watch(dueReminderTimeProvider).value;

    Widget padded(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: PulseSpace.s4,
        vertical: PulseSpace.s1,
      ),
      child: child,
    );
    Widget hint(String text) => padded(
      Text(
        text,
        style: PulseText.caption.copyWith(color: colors.mutedForeground),
      ),
    );

    return PScreen(
      title: PulseStrings.settings,
      onBack: context.pop,
      child: ListView(
        children: [
          const PSectionHeader(SettingsStrings.appearance),
          padded(
            Wrap(
              spacing: PulseSpace.s2,
              children: [
                for (final (value, label) in _themes)
                  PChip(
                    key: ValueKey('theme-${value.name}'),
                    field: SettingsStrings.theme,
                    label: label,
                    selected: mode == value,
                    onPressed: () => _put(SettingKeys.theme, value.name),
                  ),
              ],
            ),
          ),
          const PSectionHeader(SettingsStrings.reminders),
          padded(const Text(SettingsStrings.dueTime)),
          if (dueTime != null)
            padded(
              Align(
                alignment: Alignment.centerLeft,
                child: Semantics(
                  label: SettingsStrings.dueTime,
                  child: ShadSelect<String>(
                    key: const ValueKey('due-time'),
                    initialValue: dueTime,
                    minWidth: 160,
                    maxHeight: 280,
                    options: [
                      for (final time in _times)
                        ShadOption(value: time, child: Text(time)),
                    ],
                    selectedOptionBuilder: (context, time) => Text(time),
                    onChanged: (time) {
                      if (time != null) _setDueTime(time);
                    },
                  ),
                ),
              ),
            ),
          hint(SettingsStrings.dueTimeHint),
          const PSectionHeader(SettingsStrings.backup),
          hint(SettingsStrings.backupHint),
          padded(
            Wrap(
              spacing: PulseSpace.s2,
              runSpacing: PulseSpace.s2,
              children: [
                PButton.primary(
                  label: SettingsStrings.shareBackup,
                  icon: LucideIcons.share2,
                  onPressed: _exporting ? null : () => _export(save: false),
                ),
                PButton.outline(
                  label: SettingsStrings.saveBackup,
                  icon: LucideIcons.download,
                  onPressed: _exporting ? null : () => _export(save: true),
                ),
              ],
            ),
          ),
          if (_message case final message?)
            padded(Semantics(liveRegion: true, child: Text(message))),
        ],
      ),
    );
  }
}
