import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:titra/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TitraApp builds without throwing', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(TitraApp(
      navigatorKey: GlobalKey<NavigatorState>(),
      prefs: prefs,
    ));

    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
