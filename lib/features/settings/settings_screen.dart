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
import 'widgets/restore_sheet.dart';

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
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    final restored = ref.read(restoreResultProvider);
    if (restored != null) {
      _message = restored
          ? SettingsStrings.restored
          : SettingsStrings.restoreFailed;
    }
  }

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

  Future<void> _export({required bool save, bool json = false}) => _run(
    json ? SettingsStrings.jsonFailed : SettingsStrings.backupFailed,
    () async {
      final gateway = ref.read(backupGatewayProvider);
      final path = json
          ? await gateway.exportJson()
          : await gateway.exportSqlite();
      if (save) {
        if (!await gateway.saveAs(path)) return null;
        return json ? SettingsStrings.jsonSaved : SettingsStrings.backupSaved;
      }
      await gateway.share(path);
      return null;
    },
  );

  /// Pick, check, show what is in the file, and only then replace the data.
  Future<void> _restore() => _run(SettingsStrings.readFailed, () async {
    final gateway = ref.read(backupGatewayProvider);
    final restore = ref.read(restoreRunnerProvider);
    final path = await gateway.pickBackup();
    if (path == null) return null;
    var handedOver = false;
    try {
      final check = await gateway.inspect(path);
      if (check.refusal case final refusal?) return refusalMessage(refusal);
      if (!mounted) return null;
      final confirmed = await showPSheet<bool>(
        context: Navigator.of(context, rootNavigator: true).context,
        builder: (_) => RestoreSheet(check: check),
      );
      if (confirmed == true) {
        // Restarts the app, so this screen is gone when it returns.
        handedOver = true;
        await restore(path);
      }
      return null;
    } finally {
      if (!handedOver) await gateway.discard(path);
    }
  });

  /// Runs one backup action at a time and shows what it returns.
  Future<void> _run(String failed, Future<String?> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    String? message;
    try {
      message = await action();
    } catch (_) {
      // Plugins throw PlatformException and IO errors besides AppFailure.
      message = failed;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
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
        horizontal: MelaSpace.s4,
        vertical: MelaSpace.s1,
      ),
      child: child,
    );
    Widget hint(String text) => padded(
      Text(
        text,
        style: MelaText.caption.copyWith(color: colors.mutedForeground),
      ),
    );

    final list = ListView(
      children: [
        const PSectionHeader(SettingsStrings.appearance),
        padded(
          Wrap(
            spacing: MelaSpace.s2,
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
            spacing: MelaSpace.s2,
            runSpacing: MelaSpace.s2,
            children: [
              PButton.primary(
                label: SettingsStrings.shareBackup,
                icon: LucideIcons.share2,
                onPressed: _busy ? null : () => _export(save: false),
              ),
              PButton.outline(
                label: SettingsStrings.saveBackup,
                icon: LucideIcons.download,
                onPressed: _busy ? null : () => _export(save: true),
              ),
            ],
          ),
        ),
        hint(SettingsStrings.jsonHint),
        padded(
          Wrap(
            spacing: MelaSpace.s2,
            runSpacing: MelaSpace.s2,
            children: [
              PButton.outline(
                label: SettingsStrings.shareJson,
                icon: LucideIcons.share2,
                onPressed: _busy
                    ? null
                    : () => _export(save: false, json: true),
              ),
              PButton.outline(
                label: SettingsStrings.saveJson,
                icon: LucideIcons.download,
                onPressed: _busy ? null : () => _export(save: true, json: true),
              ),
            ],
          ),
        ),
        const PSectionHeader(SettingsStrings.restore),
        hint(SettingsStrings.restoreHint),
        padded(
          Align(
            alignment: Alignment.centerLeft,
            child: PButton.outline(
              label: SettingsStrings.chooseBackup,
              icon: LucideIcons.upload,
              onPressed: _busy ? null : _restore,
            ),
          ),
        ),
        const PSectionHeader(SettingsStrings.about),
        padded(
          Image.asset(
            ShadTheme.of(context).brightness == Brightness.dark
                ? 'assets/brand/lockup_on_dark.png'
                : 'assets/brand/lockup.png',
            height: MelaSize.control,
            alignment: Alignment.centerLeft,
            semanticLabel: MelaStrings.appName,
          ),
        ),
        hint(MelaStrings.tagline),
      ],
    );

    return PScreen(
      title: MelaStrings.settings,
      onBack: context.pop,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: list),
          // Below the list, so that it shows wherever the list is scrolled.
          if (_message case final message?)
            padded(Semantics(liveRegion: true, child: Text(message))),
        ],
      ),
    );
  }
}
