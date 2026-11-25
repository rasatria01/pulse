import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../ui/widgets/widgets.dart';

/// A captioned control in a finance form.
class LabelledField extends StatelessWidget {
  const LabelledField({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: PulseSpace.s1,
    children: [
      Text(
        label,
        style: PulseText.captionStrong.copyWith(
          color: ShadTheme.of(context).colorScheme.mutedForeground,
        ),
      ),
      Semantics(label: label, child: child),
    ],
  );
}

class FormError extends StatelessWidget {
  const FormError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Text(
      message,
      style: PulseText.caption.copyWith(
        color: ShadTheme.of(context).colorScheme.destructive,
      ),
    ),
  );
}
