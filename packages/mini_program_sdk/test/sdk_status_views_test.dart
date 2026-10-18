import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  testWidgets('loading and error text remain accessible in short windows', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(640, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_window(const SdkLoadingView()));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Preparing the latest experience...'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(
      find.text('Preparing the latest experience...').hitTestable(),
      findsOneWidget,
    );

    await tester.pumpWidget(
      _window(
        const SdkErrorView(
          failure: MiniProgramFailure(
            message: 'The mini-program artifact could not be loaded.',
            errorCode: 'artifact_not_found',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Error code: artifact_not_found'));
    await tester.pumpAndSettle();
    expect(
      find.text('Error code: artifact_not_found').hitTestable(),
      findsOneWidget,
    );
  });
}

Widget _window(Widget child) => MaterialApp(
  home: Scaffold(
    appBar: AppBar(title: const Text('Mini-program')),
    body: child,
  ),
);
