// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:logbook_app_001/main.dart';

void main() {
  testWidgets('Onboarding smoke test', (WidgetTester tester) async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    await binding.setSurfaceSize(const Size(1080, 1920));

    // Build app dan pastikan halaman awal onboarding tampil.
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Selamat Datang!'), findsOneWidget);
    expect(find.text('Lewati'), findsOneWidget);
    expect(find.text('Lanjut'), findsOneWidget);

    await binding.setSurfaceSize(null);
  });
}
