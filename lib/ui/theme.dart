import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import 'tokens.dart';

extension PulseColorsShad on PulseColors {
  ShadColorScheme toShad() => ShadColorScheme(
    background: bg,
    foreground: ink,
    card: surface,
    cardForeground: ink,
    popover: surfaceRaised,
    popoverForeground: ink,
    primary: primary,
    primaryForeground: onPrimary,
    secondary: fill,
    secondaryForeground: ink,
    muted: fill,
    mutedForeground: inkMuted,
    accent: fillPressed,
    accentForeground: ink,
    destructive: danger,
    destructiveForeground: onDanger,
    border: line,
    input: lineControl,
    ring: focusRing,
    selection: selection,
    custom: {
      'surfaceRaised': surfaceRaised,
      'inkSubtle': inkSubtle,
      'positive': positive,
      'positiveSoft': positiveSoft,
      'warning': warning,
      'warningSoft': warningSoft,
      'dangerSoft': dangerSoft,
      'scrim': scrim,
    },
  );
}

/// Typed access to the roles shad doesn't have: ShadTheme.of(context).colorScheme.positive
extension PulseScheme on ShadColorScheme {
  Color get surfaceRaised => custom['surfaceRaised']!;
  Color get inkSubtle => custom['inkSubtle']!;
  Color get positive => custom['positive']!;
  Color get positiveSoft => custom['positiveSoft']!;
  Color get warning => custom['warning']!;
  Color get warningSoft => custom['warningSoft']!;
  Color get dangerSoft => custom['dangerSoft']!;
  Color get scrim => custom['scrim']!;
}

final pulseTextTheme = ShadTextTheme(
  family: 'Plus Jakarta Sans',
  h2: PulseText.titleLg,
  h4: PulseText.title,
  p: PulseText.body,
  large: PulseText.bodyStrong,
  small: PulseText.label,
  muted: PulseText.caption,
  custom: {
    'amount-hero': PulseText.amountHero,
    'amount-lg': PulseText.amountLg,
    'amount': PulseText.amount,
    'amount-sm': PulseText.amountSm,
    'caption-strong': PulseText.captionStrong,
    'micro': PulseText.micro,
  },
);

ShadThemeData pulseTheme(Brightness brightness) => ShadThemeData(
  brightness: brightness,
  colorScheme:
      (brightness == Brightness.light ? PulseColors.light : PulseColors.dark)
          .toShad(),
  radius: BorderRadius.circular(PulseRadius.md),
  textTheme: pulseTextTheme,
);
