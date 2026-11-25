import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// The system's alarms, as the scheduler uses them.
abstract interface class AlarmPlatform {
  /// Replaces any alarm with the same [id].
  Future<void> schedule({
    required int id,
    required DateTime atUtc,
    required String title,
    required String body,
  });

  /// Also dismisses a notification already shown with this id.
  Future<void> cancel(int id);

  /// Ids still waiting to fire.
  Future<List<int>> pendingIds();
}

/// flutter_local_notifications on Android.
final class AndroidAlarmPlatform implements AlarmPlatform {
  AndroidAlarmPlatform({
    required this.channelName,
    required this.channelDescription,
  });

  final String channelName;
  final String channelDescription;

  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _ready;
  bool _asked = false;

  AndroidFlutterLocalNotificationsPlugin get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()!;

  Future<void> _init() => _ready ??= _plugin
      .initialize(
        settings: const InitializationSettings(
          // res/drawable; res/raw/keep.xml keeps it from resource shrinking.
          android: AndroidInitializationSettings('ic_notification'),
        ),
      )
      .then<void>((_) {})
      .onError((Object e, StackTrace s) {
        _ready = null; // try again next time
        Error.throwWithStackTrace(e, s);
      });

  @override
  Future<void> schedule({
    required int id,
    required DateTime atUtc,
    required String title,
    required String body,
  }) async {
    await _init();
    // Android 13+ POST_NOTIFICATIONS, asked when there is first something to
    // show. Not awaited: a caller may hold a database transaction.
    if (!_asked) {
      _asked = true;
      unawaited(
        _android.requestNotificationsPermission().then<void>(
          (_) {},
          onError: (_) => _asked = false,
        ),
      );
    }
    // Only Android 12 can refuse exact alarms (the user may revoke it there).
    final exact = await _android.canScheduleExactNotifications() ?? false;
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      // An instant, so UTC: no timezone database needed.
      scheduledDate: tz.TZDateTime.from(atUtc, tz.UTC),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'reminders',
          channelName,
          channelDescription: channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
        ),
      ),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancel(int id) async {
    await _init();
    await _plugin.cancel(id: id);
  }

  @override
  Future<List<int>> pendingIds() async {
    await _init();
    final pending = await _plugin.pendingNotificationRequests();
    return [for (final request in pending) request.id];
  }
}
