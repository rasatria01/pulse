import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../tokens.dart';

/// The heading above a section of a screen.
class PSectionHeader extends StatelessWidget {
  const PSectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      PulseSpace.s4,
      PulseSpace.s4,
      PulseSpace.s4,
      PulseSpace.s1,
    ),
    child: Semantics(
      header: true,
      child: Text(
        title,
        style: PulseText.title.copyWith(
          color: ShadTheme.of(context).colorScheme.foreground,
        ),
      ),
    ),
  );
}
