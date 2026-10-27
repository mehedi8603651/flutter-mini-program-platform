import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_only_host/main.dart';

const _windowChannel = MethodChannel(
  'dev.miniprogram.mp_only_host/mini_program_window',
);

void main() {
  testWidgets('toolbar Back pops the catalog before returning to the host', (
    tester,
  ) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue =
        '/mini-program/mp_ai_controls_demo';
    addTearDown(
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
    );
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _windowChannel,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    await tester.pump();
    await miniProgramMain();
    await tester.pump(const Duration(seconds: 1));
    await _waitForText(tester, 'Browse catalog');
    await tester.ensureVisible(find.text('Browse catalog'));
    await tester.tap(find.text('Browse catalog'));
    await _waitForText(tester, 'Tea catalog');
    expect(find.text('Tea catalog'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await _waitForText(tester, 'Tea preferences');
    expect(find.text('Tea preferences'), findsOneWidget);
    expect(calls.where((call) => call.method == 'showHost'), isEmpty);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(calls.where((call) => call.method == 'showHost'), hasLength(1));
    await tester.ensureVisible(find.text('Browse catalog'));
    await tester.tap(find.text('Browse catalog'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Return to host'));
    await tester.pumpAndSettle();
    expect(calls.where((call) => call.method == 'showHost'), hasLength(2));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<void> _waitForText(WidgetTester tester, String text) async {
  for (
    var attempt = 0;
    attempt < 50 && find.text(text).evaluate().isEmpty;
    attempt++
  ) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(find.text(text), findsOneWidget);
  await tester.pumpAndSettle();
}
