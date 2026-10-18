import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_only_host/main.dart';

const _windowChannel = MethodChannel(
  'dev.miniprogram.mp_only_host/mini_program_window',
);

void main() {
  setUp(() {
    // Asset futures must not carry a previous widget test's fake async zone.
    rootBundle.clear();
  });

  testWidgets(
    'default launches and reopens mini-programs through native windows',
    (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _windowChannel,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      await tester.pumpWidget(const MpOnlyHostApp());

      for (final title in <String>[
        'Mp Profile Center',
        'Mp Orders',
        'Mp Wallet',
        'Mp Profile Center',
      ]) {
        await tester.tap(find.text('Open $title'));
        await tester.pump();
      }

      expect(calls.map((call) => call.method), everyElement('openMiniProgram'));
      expect(calls.map((call) => call.arguments), <Map<String, String>>[
        {'appId': 'mp_profile_center', 'title': 'Mp Profile Center'},
        {'appId': 'mp_orders', 'title': 'Mp Orders'},
        {'appId': 'mp_wallet', 'title': 'Mp Wallet'},
        {'appId': 'mp_profile_center', 'title': 'Mp Profile Center'},
      ]);
      expect(find.text('Mp-only Host'), findsOneWidget);
      expect(find.text('Open Mp profile details'), findsNothing);
    },
  );

  testWidgets('the native window catalog remains usable in landscape', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(640, 280));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MpOnlyHostApp());
    await tester.ensureVisible(find.text('Open Mp Wallet'));
    expect(tester.takeException(), isNull);
    expect(find.text('Open Mp Wallet').hitTestable(), findsOneWidget);
  });

  testWidgets('the host catalog offers multiple mini-programs', (tester) async {
    await tester.pumpWidget(const MpOnlyHostApp());

    expect(find.text('Open Mp Profile Center'), findsOneWidget);
    expect(find.text('Open Mp Orders'), findsOneWidget);
    expect(find.text('Open Mp Wallet'), findsOneWidget);
  });

  testWidgets('reports a full native window pool without navigating away', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _windowChannel,
      (_) async => throw PlatformException(
        code: 'mini_program_window_limit',
        message: 'All mini-program windows are in use.',
      ),
    );

    await tester.pumpWidget(const MpOnlyHostApp());
    await tester.tap(find.text('Open Mp Orders'));
    await tester.pumpAndSettle();

    expect(find.text('Mp-only Host'), findsOneWidget);
    expect(find.text('Open Mp Orders'), findsOneWidget);
    expect(
      find.text(
        'Could not open mini-program: All mini-program windows are in use.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'reports missing native integration while keeping the host open',
    (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _windowChannel,
        (_) async => throw MissingPluginException(),
      );
      await tester.pumpWidget(const MpOnlyHostApp());
      await tester.tap(find.text('Open Mp Profile Center'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'This host build does not include Android mini-program windows.',
        ),
        findsOneWidget,
      );
      expect(find.text('Open Mp Profile Center'), findsOneWidget);
      expect(find.text('Open Mp profile details'), findsNothing);
    },
  );
}
