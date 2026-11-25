import 'package:flutter/widgets.dart';

abstract final class PulseSpace {
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s8 = 32;
  static const double s12 = 48;
}

/// Matches ShadRadii with md = 8: sm 6, xl 14, xl2 16.
abstract final class PulseRadius {
  static const double sm = 6;
  static const double md = 8;
  static const double xl = 14;
  static const double xl2 = 16;
  static const double full = 9999;
}

abstract final class PulseSize {
  static const double touch = 48;
  static const double control = 40;
  static const double controlSm = 32;
  static const double capture = 52;
  static const double tile = 36;
  static const double icon = 20;
  static const double iconSm = 16;
}

/// The only colours a person can pick for a wallet or category.
/// Stored as-is in wallets.color / categories.color (ARGB int); one value for both themes.
abstract final class PulseIdentity {
  static const slate = Color(0xFF64748B);
  static const blue = Color(0xFF3B74E0);
  static const sky = Color(0xFF1F8FC7);
  static const teal = Color(0xFF14958A);
  static const green = Color(0xFF3A9A3F);
  static const olive = Color(0xFF8A8A1F);
  static const amber = Color(0xFFB7791F);
  static const orange = Color(0xFFD9622B);
  static const rose = Color(0xFFD6456B);
  static const violet = Color(0xFF8B5CF6);

  static const all = [
    slate,
    blue,
    sky,
    teal,
    green,
    olive,
    amber,
    orange,
    rose,
    violet,
  ];
}

final class PulseColors {
  const PulseColors({
    required this.bg,
    required this.surface,
    required this.surfaceRaised,
    required this.fill,
    required this.fillPressed,
    required this.line,
    required this.lineControl,
    required this.ink,
    required this.inkMuted,
    required this.inkSubtle,
    required this.primary,
    required this.onPrimary,
    required this.focusRing,
    required this.selection,
    required this.positive,
    required this.positiveSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.onDanger,
    required this.scrim,
  });

  final Color bg;
  final Color surface;
  final Color surfaceRaised;
  final Color fill;
  final Color fillPressed;
  final Color line;
  final Color lineControl;
  final Color ink;
  final Color inkMuted;
  final Color inkSubtle;
  final Color primary;
  final Color onPrimary;
  final Color focusRing;
  final Color selection;
  final Color positive;
  final Color positiveSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;
  final Color onDanger;
  final Color scrim;

  static const light = PulseColors(
    bg: Color(0xFFFAFAFA),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    fill: Color(0xFFF1F1F3),
    fillPressed: Color(0xFFE6E6E9),
    line: Color(0xFFE6E6E9),
    lineControl: Color(0xFF8A8A93),
    ink: Color(0xFF18181B),
    inkMuted: Color(0xFF52525B),
    inkSubtle: Color(0xFF696972),
    primary: Color(0xFF18181B),
    onPrimary: Color(0xFFFAFAFA),
    focusRing: Color(0xFF3F3F46),
    selection: Color(0xFFD4D4D8),
    positive: Color(0xFF0B6F80),
    positiveSoft: Color(0xFFE5F3F5),
    warning: Color(0xFF9A5A00),
    warningSoft: Color(0xFFFBF1DF),
    danger: Color(0xFFB42318),
    dangerSoft: Color(0xFFFCEBE9),
    onDanger: Color(0xFFFFFFFF),
    scrim: Color(0x6609090B),
  );

  static const dark = PulseColors(
    bg: Color(0xFF09090B),
    surface: Color(0xFF121215),
    surfaceRaised: Color(0xFF1B1B1F),
    fill: Color(0xFF242428),
    fillPressed: Color(0xFF2F2F34),
    line: Color(0xFF27272C),
    lineControl: Color(0xFF6E6E77),
    ink: Color(0xFFF4F4F5),
    inkMuted: Color(0xFFA1A1AA),
    inkSubtle: Color(0xFF8C8C95),
    primary: Color(0xFFF4F4F5),
    onPrimary: Color(0xFF18181B),
    focusRing: Color(0xFFD4D4D8),
    selection: Color(0xFF3F3F46),
    positive: Color(0xFF5CC8D8),
    positiveSoft: Color(0xFF0D2A30),
    warning: Color(0xFFF0B04A),
    warningSoft: Color(0xFF2F2410),
    danger: Color(0xFFF8796F),
    dangerSoft: Color(0xFF371715),
    onDanger: Color(0xFF1F0A08),
    scrim: Color(0x99000000),
  );
}

abstract final class PulseShadow {
  static List<BoxShadow> sheet(Brightness b) => [
    BoxShadow(
      offset: const Offset(0, -8),
      blurRadius: 24,
      color: b == Brightness.light
          ? const Color(0x1409090B)
          : const Color(0x80000000),
    ),
  ];
  static List<BoxShadow> float(Brightness b) => [
    BoxShadow(
      offset: const Offset(0, 4),
      blurRadius: 16,
      color: b == Brightness.light
          ? const Color(0x1F09090B)
          : const Color(0x99000000),
    ),
  ];
}

TextStyle _style(
  double size,
  double lineHeight,
  int weight, {
  double? tracking,
  bool tabular = false,
}) => TextStyle(
  fontFamily: 'Plus Jakarta Sans',
  fontSize: size,
  height: lineHeight / size,
  fontWeight: FontWeight.values[weight ~/ 100 - 1],
  fontVariations: [FontVariation('wght', weight.toDouble())],
  letterSpacing: tracking,
  fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
);

/// Type styles. Every amount style sets tabular figures; use them for times and percentages too.
abstract final class PulseText {
  static final amountHero = _style(36, 40, 700, tracking: -0.72, tabular: true);
  static final titleLg = _style(24, 32, 700, tracking: -0.24);
  static final title = _style(18, 24, 600);
  static final bodyStrong = _style(15, 22, 600);
  static final body = _style(15, 22, 400);
  static final label = _style(14, 20, 500);
  static final caption = _style(13, 18, 400);
  static final captionStrong = _style(13, 18, 600);
  static final micro = _style(11, 16, 500, tracking: 0.22);
  static final amountLg = _style(22, 28, 600, tracking: -0.22, tabular: true);
  static final amount = _style(15, 22, 600, tabular: true);
  static final amountSm = _style(13, 18, 500, tabular: true);
}
