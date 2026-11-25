import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../ui/strings.dart';
import '../../ui/widgets/widgets.dart';

class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context) => const PScreen(
    title: PulseStrings.finance,
    child: EmptyState(
      icon: LucideIcons.wallet,
      title: PulseStrings.noTransactions,
    ),
  );
}
