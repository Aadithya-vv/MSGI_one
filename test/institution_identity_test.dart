import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:msgi_one/features/catalog/domain/academic_catalog.dart';
import 'package:msgi_one/features/catalog/presentation/msec_institution_identity.dart';

import 'helpers/demo_test_support.dart';

void main() {
  testWidgets(
    'Pending institutional imagery is explicit, local and not a crest',
    (tester) async {
      final old = HttpOverrides.current, http = RejectDemoHttp();
      HttpOverrides.global = http;
      addTearDown(() => HttpOverrides.global = old);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: MsecInstitutionIdentity(campusPreview: true)),
        ),
      );
      expect(find.text(MsecCatalog.name), findsOneWidget);
      expect(find.textContaining('Campus image placeholder'), findsOneWidget);
      expect(
        find.textContaining('Official crest awaiting permission'),
        findsOneWidget,
      );
      expect(find.byType(Image), findsNothing);
      expect(http.requests, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Institution identity wraps on a small screen with enlarged text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: const Scaffold(
              body: SingleChildScrollView(
                child: MsecInstitutionIdentity(campusPreview: true),
              ),
            ),
          ),
        ),
      );
      expect(find.text(MsecCatalog.name), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
