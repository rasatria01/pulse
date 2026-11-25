import 'package:flutter/widgets.dart';

import '../../ui/strings.dart';
import '../../ui/widgets/widgets.dart';

/// Opened by the shell's capture bar.
Future<void> showCaptureSheet(BuildContext context) => showPSheet<void>(
  context: context,
  builder: (context) => const CaptureSheet(),
);

/// Placeholder until quick capture lands.
class CaptureSheet extends StatelessWidget {
  const CaptureSheet({super.key});

  @override
  Widget build(BuildContext context) => const PSheet(
    title: PulseStrings.quickCapture,
    child: Text(PulseStrings.captureEmpty),
  );
}
