import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elfouad_admin/main.dart';

void main() {
  testWidgets('shows splash while app bootstrap is in progress', (
    WidgetTester tester,
  ) async {
    final pendingInit = Completer<void>();

    await tester.pumpWidget(MyApp(initFuture: pendingInit.future));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
