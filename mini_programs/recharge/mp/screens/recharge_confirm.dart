import 'package:mini_program_ui/mini_program_ui.dart';

MpNode buildRechargeConfirm() {
  return Mp.column(
    children: <MpNode>[
      Mp.heading('Confirm recharge'),
      Mp.card(
        child: Mp.column(
          children: <MpNode>[
            Mp.heading('Selected bundle'),
            Mp.text('Combo saver'),
            Mp.text('Talktime, SMS, and data bundle'),
            Mp.text('Payable amount: BDT 199'),
          ],
        ),
      ),
      Mp.sizedBox(height: 16),
      Mp.text(
        'Actual payment execution should stay native or on the publisher API; '
        'this mini-program only owns the portable UI.',
      ),
      Mp.sizedBox(height: 16),
      Mp.secondaryButton(
        label: 'Back to bundles',
        action: Mp.navigation.popScreen(),
      ),
    ],
  );
}
