// Draws the splash screen's tagline in the app's font. Run after a change:
//   flutter test tool/splash_tagline.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/ui/strings.dart';
import 'package:pulse/ui/tokens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('splash tagline', () async {
    final loader = FontLoader('Plus Jakarta Sans')
      ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans-VF.ttf'));
    await loader.load();
    // Android's branding image is 200 x 80 dp; this is its xxxhdpi size.
    const width = 800, height = 320;
    final builder =
        ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: TextAlign.center))
          ..pushStyle(
            ui.TextStyle(
              color: MelaBrand.jasmine,
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 52,
              fontVariations: const [ui.FontVariation('wght', 500)],
            ),
          )
          ..addText(MelaStrings.tagline);
    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: width.toDouble()));
    final recorder = ui.PictureRecorder();
    ui.Canvas(
      recorder,
    ).drawParagraph(paragraph, ui.Offset(0, (height - paragraph.height) / 2));
    final image = await recorder.endRecording().toImage(width, height);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File('android/app/src/main/res/drawable-xxxhdpi/splash_tagline.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}
