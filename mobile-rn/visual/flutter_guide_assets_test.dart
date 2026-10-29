// Export the ORIGINAL decorative Flutter artwork, with no UI redesign or network calls.
// Run from mobile/: flutter test --no-pub ../mobile-rn/visual/flutter_guide_assets_test.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/onboarding/models/onboarding_step.dart';
import 'package:mobile/features/onboarding/widgets/guide_artwork.dart';
import 'flutter_reference_test.dart' show installInter;

void main() {
 TestWidgetsFlutterBinding.ensureInitialized();
 setUpAll(installInter);
 for(final brightness in Brightness.values) {
  for(final feature in GuideFeature.values) {
   testWidgets('original guide ${brightness.name} ${feature.name}',(tester) async {
    tester.view.physicalSize=const Size(360,300);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    final key=GlobalKey();
    await tester.pumpWidget(MaterialApp(theme:brightness==Brightness.dark?AppTheme.darkTheme:AppTheme.lightTheme,home:Scaffold(body:RepaintBoundary(key:key,child:GuideArtwork(feature:feature)))));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
     final image=await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage(pixelRatio:3);
     final bytes=await image.toByteData(format:ui.ImageByteFormat.png);image.dispose();
     final directory=Directory('../mobile-rn/assets/guide')..createSync(recursive:true);
     File('${directory.path}/${feature.name}-${brightness.name}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    expect(tester.takeException(),isNull);
   });
  }
 }
}
