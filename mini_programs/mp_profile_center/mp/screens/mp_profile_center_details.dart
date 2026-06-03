import 'package:mini_program_ui/mini_program_ui.dart';

MpNode buildMpProfileCenterDetails() {
  return Mp.column(
    children: <MpNode>[
      Mp.heading('Mp profile details'),
      Mp.card(
        child: Mp.column(
          children: <MpNode>[
            Mp.text(
              'Internal Mp navigation kept this flow inside the mini-program stack.',
            ),
            Mp.text(
              'This fixture verifies that Mp screens can navigate without Stac.',
            ),
          ],
        ),
      ),
      Mp.sizedBox(height: 16),
      Mp.secondaryButton(
        label: 'Back to Mp profile home',
        action: Mp.navigation.popScreen(),
      ),
    ],
  );
}
