import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../domain/entities/wallet.dart';
import '../tokens.dart';

/// Lucide names that are stored (wallets.icon, categories.icon) or used by the
/// design system, mapped to the glyphs shad ships.
const Map<String, IconData> melaIcons = {
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
  // Category choices (categoryIcons).
  'coffee': LucideIcons.coffee,
  'shopping-cart': LucideIcons.shoppingCart,
  'car': LucideIcons.car,
  'fuel': LucideIcons.fuel,
  'house': LucideIcons.house,
  'wifi': LucideIcons.wifi,
  'droplet': LucideIcons.droplet,
  'heart-pulse': LucideIcons.heartPulse,
  'pill': LucideIcons.pill,
  'shirt': LucideIcons.shirt,
  'graduation-cap': LucideIcons.graduationCap,
  'book-open': LucideIcons.bookOpen,
  'gamepad-2': LucideIcons.gamepad2,
  'film': LucideIcons.film,
  'music': LucideIcons.music,
  'plane': LucideIcons.plane,
  'gift': LucideIcons.gift,
  'dumbbell': LucideIcons.dumbbell,
  'baby': LucideIcons.baby,
  'paw-print': LucideIcons.pawPrint,
  'wrench': LucideIcons.wrench,
  'briefcase': LucideIcons.briefcase,
  'piggy-bank': LucideIcons.piggyBank,
  'hand-coins': LucideIcons.handCoins,
  'trending-up': LucideIcons.trendingUp,
  'sparkles': LucideIcons.sparkles,
};

/// The icons offered when a person picks a category's icon, in order.
const categoryIcons = [
  'tag',
  'utensils',
  'coffee',
  'shopping-cart',
  'shopping-bag',
  'bus',
  'car',
  'fuel',
  'house',
  'receipt',
  'zap',
  'wifi',
  'droplet',
  'smartphone',
  'heart-pulse',
  'pill',
  'shirt',
  'graduation-cap',
  'book-open',
  'gamepad-2',
  'film',
  'music',
  'plane',
  'gift',
  'dumbbell',
  'baby',
  'paw-print',
  'wrench',
  'briefcase',
  'banknote',
  'piggy-bank',
  'hand-coins',
  'trending-up',
  'landmark',
  'sparkles',
];

/// The icon for a stored name; an unknown name shows [fallback].
IconData melaIcon(String name, {IconData fallback = LucideIcons.tag}) =>
    melaIcons[name] ?? fallback;

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
    this.size = MelaSize.icon,
    this.color,
    this.semanticLabel,
  });

  /// From a stored name such as `receipt-text`.
  PIcon.named(
    String name, {
    super.key,
    this.size = MelaSize.icon,
    this.color,
    this.semanticLabel,
  }) : icon = melaIcon(name);

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
