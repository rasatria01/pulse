// A thread adds its sub-routes inside its own branch or screen route.
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../core/routes.dart';
import '../features/calendar/calendar_screen.dart';
import '../features/finance/finance_screen.dart';
import '../features/finance/summary_screen.dart';
import '../features/notes/note_editor_screen.dart';
import '../features/notes/notes_screen.dart';
import '../features/search/search_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/tasks/tasks_screen.dart';
import '../features/today/today_screen.dart';
import '../ui/widgets/gallery_screen.dart';
import 'shell.dart';

StatefulShellBranch _branch(String path, GoRouterWidgetBuilder builder) =>
    StatefulShellBranch(
      routes: [GoRoute(path: path, builder: builder)],
    );

/// The editor covers the shell: no capture bar or tabs over the keyboard.
StatefulShellBranch _notes(GlobalKey<NavigatorState> root) =>
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: Routes.notes,
          builder: (context, state) => const NotesScreen(),
          routes: [
            GoRoute(
              path: ':id',
              parentNavigatorKey: root,
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                return NoteEditorScreen(key: ValueKey(id), id: id);
              },
            ),
          ],
        ),
      ],
    );

GoRouter buildRouter() => _router(GlobalKey<NavigatorState>());

GoRouter _router(GlobalKey<NavigatorState> root) => GoRouter(
  navigatorKey: root,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(shell: shell),
      branches: [
        _branch(Routes.today, (context, state) => const TodayScreen()),
        _branch(Routes.tasks, (context, state) => const TasksScreen()),
        _branch(Routes.calendar, (context, state) => const CalendarScreen()),
        _notes(root),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routes.finance,
              builder: (context, state) => const FinanceScreen(),
              routes: [
                GoRoute(
                  path: 'summary',
                  builder: (context, state) => const SummaryScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: Routes.search,
      builder: (context, state) => const SearchScreen(),
    ),
    GoRoute(
      path: Routes.settings,
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: Routes.gallery,
      builder: (context, state) => const GalleryScreen(),
    ),
  ],
);
