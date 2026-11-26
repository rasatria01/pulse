// Providers owned by the notes thread (I). Exported by di.dart.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/local_date.dart';
import '../domain/entities/action_item.dart';
import '../domain/entities/note.dart';
import '../domain/services/note_task_sync_impl.dart';
import 'di.dart';

export '../domain/services/note_task_sync.dart';

/// Keep-alive: it holds the open editors.
final noteTaskSyncProvider = Provider<NoteTaskSync>(
  (ref) => DefaultNoteTaskSync(
    notes: ref.watch(noteRepositoryProvider),
    items: ref.watch(actionItemRepositoryProvider),
    tags: ref.watch(tagRepositoryProvider),
    wallets: ref.watch(walletRepositoryProvider),
    categories: ref.watch(categoryRepositoryProvider),
    transactions: ref.watch(transactionRepositoryProvider),
    settings: ref.watch(settingsRepositoryProvider),
    reminders: ref.watch(reminderSchedulerProvider),
    unitOfWork: ref.watch(unitOfWorkProvider),
    clock: ref.watch(clockProvider),
  ),
);

final noteSummariesProvider = StreamProvider.autoDispose<List<NoteSummary>>(
  (ref) => ref.watch(noteRepositoryProvider).watchAll(),
);

final noteProvider = StreamProvider.autoDispose.family<Note?, String>(
  (ref, id) => ref.watch(noteRepositoryProvider).watch(id),
);

/// The scratchpad of [day]; null until its first keystroke.
final dailyNoteProvider = StreamProvider.autoDispose.family<Note?, LocalDate>(
  (ref, day) => ref.watch(noteRepositoryProvider).watchDaily(day),
);

/// The items synced from a note's lines, for the preview's date chips.
final noteItemsProvider = FutureProvider.autoDispose
    .family<List<ActionItem>, String>(
      (ref, noteId) =>
          ref.watch(actionItemRepositoryProvider).findBySourceNote(noteId),
    );
