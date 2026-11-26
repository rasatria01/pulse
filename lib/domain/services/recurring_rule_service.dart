import '../../core/clock.dart';
import '../../core/failures.dart';
import '../entities/recurring_rule.dart';
import '../repositories/recurring_repository.dart';
import '../repositories/settings_repository.dart';
import 'item_service.dart' show quietly;
import 'recurrence.dart';
import 'recurring_engine.dart';
import 'reminder_scheduler.dart';
import 'unit_of_work.dart';

/// Create, edit, pause and delete of recurring rules, with their reminders.
/// Every save catches up at once, so a rule due today shows up today.
class RecurringRuleService {
  const RecurringRuleService({
    required this._rules,
    required this._engine,
    required this._settings,
    required this._reminders,
    required this._unitOfWork,
    required this._clock,
  });

  final RecurringRepository _rules;
  final RecurringEngine _engine;
  final SettingsRepository _settings;
  final ReminderScheduler _reminders;
  final UnitOfWork _unitOfWork;
  final Clock _clock;

  /// The series starts at the start date, so a past one is caught up.
  /// [input]'s nextDueDate and notifId are ignored.
  Future<void> create(RecurringRuleInput input) async {
    _checkEnd(input);
    final rule = await _unitOfWork.run(
      () async => _rules.create(
        input.copyWith(
          nextDueDate: input.startDate,
          notifId: await _settings.nextNotificationId(),
        ),
      ),
    );
    await _refresh(rule.id);
  }

  /// A changed schedule, or a rule that had ended, continues from today: an
  /// edit never posts into the past.
  Future<void> edit(String id, RecurringRuleInput input) async {
    _checkEnd(input);
    await _unitOfWork.run(() async {
      final old = await _require(id);
      final reshaped =
          input.freq != old.freq || input.startDate != old.startDate;
      final rescheduled = reshaped || input.interval != old.interval;
      final end = old.endDate;
      final ended = end != null && old.nextDueDate.isAfter(end);
      final updated = await _rules.update(
        id,
        RecurringRulePatch(
          name: input.name,
          type: input.type,
          amount: input.amount,
          walletId: input.walletId,
          toWalletId: (value: input.toWalletId),
          categoryId: (value: input.categoryId),
          description: input.description,
          freq: input.freq,
          interval: input.interval,
          byWeekday: reshaped ? (value: null) : null,
          byMonthDay: reshaped ? (value: null) : null,
          startDate: input.startDate,
          endDate: (value: input.endDate),
          autoPost: input.autoPost,
        ),
      );
      if (!rescheduled && !ended) return;
      final today = _clock.today();
      await _rules.setNextDue(
        id,
        firstOccurrenceOnOrAfter(
          updated,
          today.isAfter(input.startDate) ? today : input.startDate,
          from: rescheduled ? input.startDate : old.nextDueDate,
        ),
      );
    });
    await _refresh(id);
  }

  /// Resuming drops the dates missed while paused.
  Future<void> setPaused(String id, bool paused) async {
    await _unitOfWork.run(() async {
      final rule = await _require(id);
      await _rules.update(
        id,
        RecurringRulePatch(
          isPaused: paused,
          nextDueDate: paused || !rule.isPaused
              ? null
              : firstOccurrenceOnOrAfter(
                  rule,
                  _clock.today(),
                  from: rule.nextDueDate,
                ),
        ),
      );
    });
    await _refresh(id);
  }

  Future<void> delete(String id) async {
    final rule = await _require(id);
    await _rules.softDelete(id);
    final notifId = rule.notifId;
    if (notifId != null) await quietly(() => _reminders.cancel(notifId));
  }

  Future<void> _refresh(String id) async {
    try {
      await _engine.catchUp(_clock.today());
    } on AppFailure {
      // The rule is saved: a failed catch-up must not read as a failed save,
      // or a retry adds a second rule. The next run tries again.
    }
    final rule = await _require(id);
    await quietly(() => _reminders.scheduleRule(rule));
  }

  void _checkEnd(RecurringRuleInput input) {
    final end = input.endDate;
    if (end != null && end.isBefore(input.startDate)) {
      throw const ValidationFailure(
        'end date is before the start date',
        field: 'endDate',
      );
    }
  }

  Future<RecurringRule> _require(String id) async =>
      await _rules.find(id) ?? (throw NotFoundFailure('recurring rule $id'));
}
