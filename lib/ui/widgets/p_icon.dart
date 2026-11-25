import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../domain/entities/wallet.dart';
import '../tokens.dart';

/// Lucide names that are stored (wallets.icon, categories.icon) or used by the
/// design system, mapped to the glyphs shad ships.
const Map<String, IconData> pulseIcons = {
  'arrow-right-left': LucideIcons.arrowRightLeft,
  'banknote': LucideIcons.banknote,
  'bus': LucideIcons.bus,
  'calendar': LucideIcons.calendar,
  'calendar-check': LucideIcons.calendarCheck,
  'check': LucideIcons.check,
  'chevron-right': LucideIcons.chevronRight,
  'circle-help': LucideIcons.circleQuestionMark,
  'receipt': LucideIcons.receipt,
  'circle-alert': LucideIcons.circleAlert,
  'circle-dashed': LucideIcons.circleDashed,
  'clock': LucideIcons.clock,
  'flag': LucideIcons.flag,
  'inbox': LucideIcons.inbox,
  'landmark': LucideIcons.landmark,
  'notebook-pen': LucideIcons.notebookPen,
  'plus': LucideIcons.plus,
  'receipt-text': LucideIcons.receiptText,
  'repeat': LucideIcons.repeat,
  'search': LucideIcons.search,
  'shopping-bag': LucideIcons.shoppingBag,
  'smartphone': LucideIcons.smartphone,
  'sticky-note': LucideIcons.stickyNote,
  'sun-medium': LucideIcons.sunMedium,
  'tag': LucideIcons.tag,
  'undo-2': LucideIcons.undo2,
  'utensils': LucideIcons.utensils,
  'wallet': LucideIcons.wallet,
  'x': LucideIcons.x,
  'zap': LucideIcons.zap,
};

/// The icon for a stored name; an unknown name shows [fallback].
IconData pulseIcon(String name, {IconData fallback = LucideIcons.tag}) =>
    pulseIcons[name] ?? fallback;

/// The default icon for a wallet kind.
IconData walletKindIcon(WalletKind kind) => switch (kind) {
  WalletKind.cash => LucideIcons.banknote,
  WalletKind.bank => LucideIcons.landmark,
  WalletKind.ewallet => LucideIcons.smartphone,
  WalletKind.other => LucideIcons.wallet,
};

/// A Lucide icon at a Pulse size, in the colour of the surrounding text.
class PIcon extends StatelessWidget {
  const PIcon(
    this.icon, {
    super.key,
    this.size = PulseSize.icon,
    this.color,
    this.semanticLabel,
  });

  /// From a stored name such as `receipt-text`.
  PIcon.named(
    String name, {
    super.key,
    this.size = PulseSize.icon,
    this.color,
    this.semanticLabel,
  }) : icon = pulseIcon(name);

  final IconData icon;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Icon(
    icon,
    size: size,
    color: color ?? DefaultTextStyle.of(context).style.color,
    semanticLabel: semanticLabel,
  );
}
