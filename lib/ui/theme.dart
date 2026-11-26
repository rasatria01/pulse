import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import 'tokens.dart';

extension MelaColorsShad on MelaColors {
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
      'turmeric': accent,
      'onTurmeric': onAccent,
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
extension MelaScheme on ShadColorScheme {
  Color get surfaceRaised => custom['surfaceRaised']!;
  Color get inkSubtle => custom['inkSubtle']!;
  Color get turmeric => custom['turmeric']!;
  Color get onTurmeric => custom['onTurmeric']!;
  Color get positive => custom['positive']!;
  Color get positiveSoft => custom['positiveSoft']!;
  Color get warning => custom['warning']!;
  Color get warningSoft => custom['warningSoft']!;
  Color get dangerSoft => custom['dangerSoft']!;
  Color get scrim => custom['scrim']!;
}

final melaTextTheme = ShadTextTheme(
  family: 'Plus Jakarta Sans',
  h2: MelaText.titleLg,
  h4: MelaText.title,
  p: MelaText.body,
  large: MelaText.bodyStrong,
  small: MelaText.label,
  muted: MelaText.caption,
  custom: {
    'amount-hero': MelaText.amountHero,
    'amount-lg': MelaText.amountLg,
    'amount': MelaText.amount,
    'amount-sm': MelaText.amountSm,
    'caption-strong': MelaText.captionStrong,
    'micro': MelaText.micro,
  },
);

ShadThemeData melaTheme(Brightness brightness) => ShadThemeData(
  brightness: brightness,
  colorScheme:
      (brightness == Brightness.light ? MelaColors.light : MelaColors.dark)
          .toShad(),
  radius: BorderRadius.circular(MelaRadius.md),
  textTheme: melaTextTheme,
);
