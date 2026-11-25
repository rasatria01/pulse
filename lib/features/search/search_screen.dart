import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:shad/shad.dart';

import '../../ui/strings.dart';
import '../../ui/widgets/widgets.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) => PScreen(
    title: PulseStrings.search,
    onBack: context.pop,
    child: const EmptyState(
      icon: LucideIcons.search,
      title: PulseStrings.searchEmpty,
    ),
  );
}
