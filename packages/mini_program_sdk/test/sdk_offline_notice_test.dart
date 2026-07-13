import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  testWidgets(
    'offline notice uses warning colors and dismisses after two seconds',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SdkOfflineNotice(cachedAssetCount: 2)),
        ),
      );

      final message = find.text(
        'Showing cached content while the backend is unavailable. '
        'Includes 2 cached assets.',
      );
      expect(message, findsOneWidget);

      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(SdkOfflineNotice),
          matching: find.byType(Material),
        ),
      );
      final icon = tester.widget<Icon>(find.byIcon(Icons.wifi_off_rounded));
      final text = tester.widget<Text>(message);
      expect(material.color, const Color(0xFFFFE7A3));
      expect(icon.color, const Color(0xFF9B1C1F));
      expect(text.style?.color, const Color(0xFF332600));

      await tester.pump(const Duration(milliseconds: 1999));
      expect(message, findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1));
      expect(message, findsNothing);
      expect(find.byIcon(Icons.wifi_off_rounded), findsNothing);
    },
  );
}
