// Hidden developer screen (route /gallery): every widget with sample data, so
// its copy is not user-facing and stays out of MelaStrings.
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../core/rupiah.dart';
import 'widgets.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final _input = TextEditingController(text: '-35k lunch @gopay #food');
  bool _done = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ShadTheme.of(context).colorScheme;
    final teal = MelaIdentity.teal.toARGB32();
    final amber = MelaIdentity.amber.toARGB32();
    void nothing() {}

    Widget section(String name, List<Widget> children) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: MelaSpace.s2,
      children: [
        Text(name, style: MelaText.title.copyWith(color: colors.foreground)),
        ...children,
      ],
    );

    final sections = [
      section('PButton', [
        Wrap(
          spacing: MelaSpace.s2,
          children: [
            PButton.primary(label: 'Save', onPressed: nothing),
            PButton.secondary(label: 'Edit', onPressed: nothing),
            PButton.outline(label: 'Add task', onPressed: nothing),
            PButton.ghost(label: 'Skip', onPressed: nothing),
            PButton.destructive(label: 'Delete', onPressed: nothing),
            const PButton.primary(label: 'Disabled', onPressed: null),
            PButton.secondary(
              icon: LucideIcons.search,
              semanticLabel: 'Search',
              size: PButtonSize.sm,
              onPressed: nothing,
            ),
          ],
        ),
      ]),
      section('PChip', [
        PChipRow(
          children: [
            for (final tone in PChipTone.values)
              PChip(label: tone.name, tone: tone, onPressed: nothing),
            PChip(label: 'Selected', selected: true, onPressed: nothing),
            PChip(
              label: 'GoPay',
              field: 'Wallet',
              dotColor: teal,
              onPressed: nothing,
            ),
          ],
        ),
      ]),
      section('PIcon', [
        Wrap(
          spacing: MelaSpace.s3,
          runSpacing: MelaSpace.s3,
          children: [
            for (final name in melaIcons.keys)
              PIcon.named(name, color: colors.foreground, semanticLabel: name),
          ],
        ),
      ]),
      section('AmountText', [
        const AmountText(
          Rupiah(182500),
          type: AmountType.balance,
          size: AmountSize.hero,
        ),
        const Wrap(
          spacing: MelaSpace.s4,
          children: [
            AmountText(Rupiah(35000)),
            AmountText(Rupiah(7500000), type: AmountType.income),
            AmountText(Rupiah(200000), type: AmountType.transfer),
            AmountText(Rupiah(-120000), type: AmountType.balance),
          ],
        ),
      ]),
      section('EmptyState', [
        EmptyState(
          icon: LucideIcons.inbox,
          title: 'No bills waiting',
          body: 'Add #bill to a task and it shows up here.',
          actionLabel: 'Add task',
          actionIcon: LucideIcons.plus,
          onAction: nothing,
        ),
      ]),
      section('PSheet', [
        PButton.secondary(
          label: 'Open sheet',
          onPressed: () => showPSheet<void>(
            context: context,
            builder: (context) => PSheet(
              title: 'Pay electricity bill',
              footer: [
                PButton.ghost(
                  label: 'Not now',
                  onPressed: () => Navigator.of(context).pop(),
                ),
                PButton.primary(
                  label: 'Record payment',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
              child: const Text('The bill is recorded from BCA.'),
            ),
          ),
        ),
      ]),
      section('PSnackbar', [
        PSnackbar(
          message: 'Saved “lunch” to GoPay',
          seconds: 5,
          onAction: nothing,
        ),
        PButton.secondary(
          label: 'Show snackbar',
          onPressed: () => showPSnackbar(
            context,
            message: 'Saved “lunch” to GoPay',
            onUndo: nothing,
          ),
        ),
      ]),
      section('PCaptureBar', [
        PCaptureBar(onOpen: nothing),
        PCaptureBar.open(
          controller: _input,
          onSave: nothing,
          hint: '@gopy isn\u2019t a wallet. Tap the chip to pick one.',
          chips: [
            PChip(label: 'Expense', field: 'Kind', onPressed: nothing),
            PChip(label: 'Rp\u00a035.000', numeric: true, onPressed: nothing),
            PChip(label: '@gopy', tone: PChipTone.error, onPressed: nothing),
            PChip(
              label: 'Uncategorized',
              tone: PChipTone.placeholder,
              onPressed: nothing,
            ),
          ],
        ),
      ]),
      section('PulseCard and PWalletPill', [
        PulseCard(
          safeToSpend: const Rupiah(182500),
          todaySpend: const Rupiah(152000),
          liquid: const Rupiah(4250000),
          wallets: [
            PWalletPill(
              name: 'Cash',
              color: amber,
              icon: 'banknote',
              balance: const Rupiah(250000),
              selected: true,
              onPressed: nothing,
            ),
            PWalletPill(
              name: 'GoPay',
              color: teal,
              icon: 'smartphone',
              balance: const Rupiah(4000000),
              onPressed: nothing,
            ),
          ],
        ),
        const PulseCard(liquid: Rupiah(4250000), showBudgetHint: true),
      ]),
      section('PBudgetBar', [
        for (final spent in [400000, 860000, 1112000])
          PBudgetBar(
            category: 'Food',
            icon: 'utensils',
            color: amber,
            spent: Rupiah(spent),
            cap: const Rupiah(1000000),
          ),
      ]),
      section('PTimelineItem', [
        const PTimelineItem(title: 'File the report', meta: '#admin'),
        const PTimelineItem(
          title: 'Team sync',
          start: '13:30',
          end: '14:00',
          duration: '30 min',
          now: true,
        ),
      ]),
      section('PInboxItem', [
        PInboxItem(
          title: 'Pay internet',
          reason: InboxReason.overdue,
          dueLabel: 'Overdue · 2 days',
          meta: '#admin',
          amount: const Rupiah(350000),
          done: _done,
          onComplete: (v) => setState(() => _done = v),
          onSchedule: nothing,
        ),
        PInboxItem(
          title: 'Call the bank',
          reason: InboxReason.high,
          onComplete: (_) {},
        ),
      ]),
      section('PConfirmRow', [
        PConfirmRow(
          title: 'Electricity',
          source: ConfirmSource.bill,
          meta: 'BCA',
          amount: const Rupiah(450000),
          onConfirm: nothing,
          onEdit: nothing,
          onSkip: nothing,
        ),
        PConfirmRow(
          title: 'Rent',
          source: ConfirmSource.recurring,
          meta: 'BCA · 1 Dec',
          onConfirm: nothing,
          onEdit: nothing,
          onSkip: nothing,
        ),
      ]),
    ];

    return ColoredBox(
      color: colors.background,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(MelaSpace.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: MelaSpace.s6,
            children: sections,
          ),
        ),
      ),
    );
  }
}
