// A thread adds its sub-routes inside its own branch or screen route.
import 'package:go_router/go_router.dart';

import '../core/routes.dart';
import '../features/calendar/calendar_screen.dart';
import '../features/finance/finance_screen.dart';
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

GoRouter buildRouter() => GoRouter(
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(shell: shell),
      branches: [
        _branch(Routes.today, (context, state) => const TodayScreen()),
        _branch(Routes.tasks, (context, state) => const TasksScreen()),
        _branch(Routes.calendar, (context, state) => const CalendarScreen()),
        _branch(Routes.notes, (context, state) => const NotesScreen()),
        _branch(Routes.finance, (context, state) => const FinanceScreen()),
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
