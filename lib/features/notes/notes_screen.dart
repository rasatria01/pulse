import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../ui/strings.dart';
import '../../ui/widgets/widgets.dart';

class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context) => const PScreen(
    title: PulseStrings.notes,
    child: EmptyState(
      icon: LucideIcons.stickyNote,
      title: PulseStrings.noNotes,
    ),
  );
}
