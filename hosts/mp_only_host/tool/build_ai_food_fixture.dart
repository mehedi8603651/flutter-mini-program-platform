import 'dart:convert';
import 'dart:io';

import 'package:mini_program_ui/mini_program_ui.dart';

/// A normal pure-Dart mini-program fixture with no AI action descriptions.
Future<void> main() async {
  final program = MpProgram(
    screens: {
      'home': () => Mp.column(
        children: [
          Mp.heading('Green Kitchen'),
          Mp.text('Fresh food prepared to order'),
          Mp.primaryButton(
            label: 'Browse menu',
            action: Mp.navigation.openScreen('menu'),
          ),
        ],
      ),
      'menu': () => Mp.column(
        children: [
          Mp.heading('Menu'),
          Mp.text('Vegetarian noodles — 180 BDT per portion'),
          Mp.primaryButton(
            label: 'Add noodles',
            action: Mp.state.increment('cart.quantity'),
          ),
          Mp.stateBuilder(
            keys: ['cart.quantity'],
            child: Mp.text('Cart quantity: {{state.cart.quantity}}'),
          ),
          Mp.primaryButton(
            label: 'View cart',
            action: Mp.navigation.openScreen('cart'),
          ),
        ],
      ),
      'cart': () => Mp.column(
        children: [
          Mp.heading('Your cart'),
          Mp.stateBuilder(
            keys: ['cart.quantity'],
            child: Mp.text(
              'Vegetarian noodles: {{state.cart.quantity}} portions',
            ),
          ),
          Mp.stateTextField(
            stateKey: 'delivery.note',
            label: 'Delivery note',
            maxLength: 200,
          ),
          Mp.primaryButton(
            label: 'Review order',
            action: Mp.dialog.custom(
              child: Mp.column(
                children: [
                  Mp.heading('Order review'),
                  Mp.stateBuilder(
                    keys: ['cart.quantity', 'delivery.note'],
                    child: Mp.text(
                      'Vegetarian noodles: {{state.cart.quantity}} portions. Note: {{state.delivery.note}}',
                    ),
                  ),
                  Mp.text('Demo only. No order or payment has been submitted.'),
                  Mp.primaryButton(
                    label: 'Close review',
                    action: Mp.dialog.close(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    },
  );
  final root = Directory('assets/mini_programs/mp_ai_food_demo');
  await Directory('${root.path}/screens').create(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');
  for (final entry in program.buildScreensJson().entries) {
    await File(
      '${root.path}/screens/${entry.key}.json',
    ).writeAsString('${encoder.convert(entry.value)}\n');
  }
  await File('${root.path}/manifest.json').writeAsString(
    '${encoder.convert({'id': 'mp_ai_food_demo', 'version': '1.0.0', 'entry': 'home', 'contractVersion': '1.0.0', 'sdkVersionRange': '>=1.0.0 <2.0.0', 'requiredCapabilities': <String>[], 'screenFormat': 'mp', 'screenSchemaVersion': 1})}\n',
  );
}
