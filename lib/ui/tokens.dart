import 'package:flutter/widgets.dart';

abstract final class MelaSpace {
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
abstract final class MelaRadius {
  static const double sm = 6;
  static const double md = 8;
  static const double xl = 14;
  static const double xl2 = 16;
  static const double full = 9999;
}

abstract final class MelaSize {
  static const double touch = 48;
  static const double control = 40;
  static const double controlSm = 32;
  static const double capture = 52;
  static const double tile = 36;
  static const double icon = 20;
  static const double iconSm = 16;
}

/// The app icon's colours. Same in both themes: icon, splash, wordmark.
abstract final class MelaBrand {
  static const leaf = Color(0xFF143B32);
  static const jasmine = Color(0xFFFBF7EE);
  static const turmeric = Color(0xFFE9A83A);
}

/// The only colours a person can pick for a wallet or category.
/// Stored as-is in wallets.color / categories.color (ARGB int); one value for both themes.
abstract final class MelaIdentity {
  static const slate = Color(0xFF6E7E95);
  static const blue = Color(0xFF3B74E0);
  static const sky = Color(0xFF1F8FC7);
  static const teal = Color(0xFF14958A);
  static const green = Color(0xFF36923B);
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

final class MelaColors {
  const MelaColors({
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
    required this.accent,
    required this.onAccent,
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
  final Color accent;
  final Color onAccent;
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

  static const light = MelaColors(
    bg: Color(0xFFF6F3EC),
    surface: Color(0xFFFFFDF9),
    surfaceRaised: Color(0xFFFFFFFF),
    fill: Color(0xFFEEEAE0),
    fillPressed: Color(0xFFE3DED2),
    line: Color(0xFFE5E0D5),
    lineControl: Color(0xFF85837A),
    ink: Color(0xFF17221D),
    inkMuted: Color(0xFF4A5650),
    inkSubtle: Color(0xFF5F6A64),
    primary: Color(0xFF143B32),
    onPrimary: Color(0xFFFBF7EE),
    accent: Color(0xFFE9A83A),
    onAccent: Color(0xFF1F1A10),
    focusRing: Color(0xFF143B32),
    selection: Color(0xFFD3E4DA),
    positive: Color(0xFF0B6F80),
    positiveSoft: Color(0xFFE3F1F1),
    warning: Color(0xFF9A5A00),
    warningSoft: Color(0xFFFBF0DC),
    danger: Color(0xFFB42318),
    dangerSoft: Color(0xFFFCEBE9),
    onDanger: Color(0xFFFFFFFF),
    scrim: Color(0x660D1714),
  );

  static const dark = MelaColors(
    bg: Color(0xFF0D1714),
    surface: Color(0xFF13201C),
    surfaceRaised: Color(0xFF1A2924),
    fill: Color(0xFF21332D),
    fillPressed: Color(0xFF2B3F38),
    line: Color(0xFF24362F),
    lineControl: Color(0xFF6F847B),
    ink: Color(0xFFF2EEE4),
    inkMuted: Color(0xFFAEB8B2),
    inkSubtle: Color(0xFF929D97),
    primary: Color(0xFFA8D5C0),
    onPrimary: Color(0xFF0D1714),
    accent: Color(0xFFE9A83A),
    onAccent: Color(0xFF1F1A10),
    focusRing: Color(0xFFA8D5C0),
    selection: Color(0xFF2E4A40),
    positive: Color(0xFF5CC8D8),
    positiveSoft: Color(0xFF0F2A2E),
    warning: Color(0xFFFFD58A),
    warningSoft: Color(0xFF33280F),
    danger: Color(0xFFF8796F),
    dangerSoft: Color(0xFF3A1816),
    onDanger: Color(0xFF1F0A08),
    scrim: Color(0x99000000),
  );
}

abstract final class MelaShadow {
  static List<BoxShadow> sheet(Brightness b) => [
    BoxShadow(
      offset: const Offset(0, -8),
      blurRadius: 24,
      color: b == Brightness.light
          ? const Color(0x140D1714)
          : const Color(0x80000000),
    ),
  ];
  static List<BoxShadow> float(Brightness b) => [
    BoxShadow(
      offset: const Offset(0, 4),
      blurRadius: 16,
      color: b == Brightness.light
          ? const Color(0x1F0D1714)
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
abstract final class MelaText {
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
