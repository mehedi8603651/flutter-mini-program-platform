import 'dart:convert';
import 'dart:io';

import 'package:mini_program_ui/mini_program_ui.dart';

/// Ordinary authoring APIs exercise editable, modal, calendar and scroll UI.
/// There are no model instructions or AI-specific node descriptions here.
Future<void> main() async {
  final program = MpProgram(
    screens: {
      'home': () => Mp.scrollView(
        child: Mp.form(
          id: 'preferences',
          children: [
            Mp.heading('Tea preferences'),
            Mp.searchField(
              stateKey: 'search.query',
              label: 'Search products',
              maxLength: 80,
            ),
            Mp.dropdown(
              name: 'service',
              label: 'Service',
              initialValue: 'delivery',
              options: const [
                MpOption(value: 'delivery', label: 'Delivery'),
                MpOption(value: 'pickup', label: 'Pickup'),
              ],
            ),
            Mp.checkbox(name: 'reusable', label: 'Use a reusable cup'),
            Mp.dateTime.dateField(
              stateKey: 'pickup.date',
              label: 'Pickup date',
              initialValue: '2026-10-26',
              minDate: '2026-10-01',
              maxDate: '2026-10-31',
            ),
            Mp.primaryButton(
              label: 'Review preferences',
              action: Mp.dialog.custom(
                child: Mp.column(
                  children: [
                    Mp.heading('Preference review'),
                    Mp.stateBuilder(
                      keys: ['search.query', 'pickup.date'],
                      child: Mp.text(
                        'Search: {{state.search.query}}. Date: {{state.pickup.date}}.',
                      ),
                    ),
                    Mp.text(
                      'Service: {{form.service}}. Reusable cup: {{form.reusable}}.',
                    ),
                    Mp.primaryButton(
                      label: 'Close review',
                      action: Mp.dialog.close(),
                    ),
                  ],
                ),
              ),
            ),
            Mp.secondaryButton(
              label: 'Browse catalog',
              action: Mp.navigation.openScreen('catalog'),
            ),
          ],
        ),
      ),
      'catalog': () => Mp.page(
        child: Mp.padding(
          all: 18,
          child: Mp.column(
            children: [
              Mp.heading('Tea catalog'),
              Mp.secondaryButton(
                label: 'Back to preferences',
                action: Mp.navigation.popScreen(),
              ),
              Mp.expanded(
                child: Mp.scrollView(
                  child: Mp.column(
                    children: [
                      for (var i = 1; i <= 24; i++)
                        Mp.card(
                          child: Mp.column(
                            children: [
                              Mp.text('Catalog item $i'),
                              Mp.secondaryButton(
                                label: 'Open item $i',
                                action: Mp.dialog.custom(
                                  child: Mp.column(
                                    children: [
                                      Mp.heading('Catalog item $i details'),
                                      Mp.text(
                                        'This item is available for pickup.',
                                      ),
                                      Mp.primaryButton(
                                        label: 'Close details',
                                        action: Mp.dialog.close(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    },
  );
  final root = Directory('assets/mini_programs/mp_ai_controls_demo');
  await Directory('${root.path}/screens').create(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');
  for (final entry in program.buildScreensJson().entries) {
    await File(
      '${root.path}/screens/${entry.key}.json',
    ).writeAsString('${encoder.convert(entry.value)}\n');
  }
  await File('${root.path}/manifest.json').writeAsString(
    '${encoder.convert({'id': 'mp_ai_controls_demo', 'version': '1.0.0', 'entry': 'home', 'contractVersion': '1.0.0', 'sdkVersionRange': '>=1.0.0 <2.0.0', 'requiredCapabilities': <String>[], 'screenFormat': 'mp', 'screenSchemaVersion': 1})}\n',
  );
}
