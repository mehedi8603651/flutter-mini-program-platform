import 'package:flutter_test/flutter_test.dart';
import 'package:mp_only_host/main.dart';

void main() {
  testWidgets('opens and navigates the bundled Mp fixture', (tester) async {
    await tester.pumpWidget(const MpOnlyHostApp());

    await tester.tap(find.text('Open Mp Profile Center'));
    await tester.pumpAndSettle();

    expect(find.text('Mp Profile Center'), findsWidgets);
    expect(find.text('Open Mp profile details'), findsOneWidget);

    await tester.tap(find.text('Open Mp profile details'));
    await tester.pumpAndSettle();

    expect(find.text('Mp profile details'), findsOneWidget);
  });
}
