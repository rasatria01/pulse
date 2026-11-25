// Later threads append their own routes here.
import 'package:go_router/go_router.dart';

import '../features/today/today_screen.dart';

GoRouter buildRouter() => GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const TodayScreen()),
  ],
);
