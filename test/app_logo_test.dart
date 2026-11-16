import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:msgi_one/core/widgets/app_logo.dart';
import 'package:msgi_one/core/widgets/one_widgets.dart';

void main() {
  testWidgets('Approved full logo loads without tint or distortion', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BrandMark(prominent: true))),
    );
    await tester.pumpAndSettle();
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, AppLogo.originalAsset);
    expect(image.fit, BoxFit.contain);
    expect(image.color, isNull);
    expect(image.semanticLabel, 'MSGI One');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Compact branding uses emblem with readable text on narrow enlarged layouts',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(body: BrandMark()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as AssetImage).assetName, AppLogo.emblemAsset);
      expect(image.color, isNull);
      expect(find.text('MSGI One'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
