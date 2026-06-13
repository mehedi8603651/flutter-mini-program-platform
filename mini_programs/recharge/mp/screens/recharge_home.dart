import 'package:mini_program_ui/mini_program_ui.dart';

MpNode buildRechargeHome() {
  return Mp.column(
    children: <MpNode>[
      Mp.heading('Recharge'),
      Mp.text('Choose a simple prepaid bundle from an Mp-only screen.'),
      Mp.sizedBox(height: 16),
      Mp.card(
        child: Mp.column(
          children: <MpNode>[
            Mp.heading('Saved number'),
            Mp.text('+880 17XX XXXXXX'),
            Mp.text('Operator: Demo Mobile'),
          ],
        ),
      ),
      Mp.sizedBox(height: 16),
      Mp.card(
        child: Mp.column(
          children: <MpNode>[
            Mp.heading('Recommended bundles'),
            Mp.listTile(
              title: 'Talktime BDT 100',
              subtitle: 'Instant balance recharge',
              leadingIcon: 'star',
              badge: 'Popular',
            ),
            Mp.listTile(
              title: 'Data 5 GB',
              subtitle: '7 days internet pack',
              leadingIcon: 'gift',
              badge: 'BDT 129',
            ),
            Mp.listTile(
              title: 'Combo saver',
              subtitle: 'Talktime, SMS, and data bundle',
              leadingIcon: 'check',
              badge: 'BDT 199',
            ),
          ],
        ),
      ),
      Mp.sizedBox(height: 16),
      Mp.primaryButton(
        label: 'Continue',
        action: Mp.navigation.openScreen('recharge_confirm'),
      ),
    ],
  );
}
