import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shad/shad.dart';

import '../../../app/di.dart';
import '../../../core/routes.dart';
import '../../../ui/strings.dart';
import '../../../ui/widgets/widgets.dart';

const _loadError = 'Couldn’t load your balances. Reopen MelaTime.';

/// Financial pulse. Returns a sliver.
class PulseSection extends ConsumerWidget {
  const PulseSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pulse = ref.watch(todayPulseProvider);
    final value = pulse.value;
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PSectionHeader(MelaStrings.financialPulse),
          if (value != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MelaSpace.s4),
              child: PulseCard(
                liquid: value.liquid,
                todaySpend: value.todaySpend,
                safeToSpend: value.safeToSpend?.perDay,
                showBudgetHint: true,
                wallets: [
                  for (final w in value.wallets)
                    PWalletPill(
                      name: w.wallet.name,
                      color: w.wallet.color,
                      icon: w.wallet.icon,
                      balance: w.balance,
                      onPressed: () => context.go(Routes.finance),
                    ),
                ],
              ),
            )
          else if (pulse.hasError)
            const EmptyState(icon: LucideIcons.circleAlert, title: _loadError),
        ],
      ),
    );
  }
}
