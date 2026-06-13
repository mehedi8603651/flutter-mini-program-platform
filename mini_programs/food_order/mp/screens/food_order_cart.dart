import 'package:mini_program_ui/mini_program_ui.dart';

MpNode buildFoodOrderCart() {
  return Mp.column(
    children: <MpNode>[
      Mp.heading('Cart review'),
      Mp.card(
        child: Mp.column(
          children: <MpNode>[
            Mp.heading('Today\'s order'),
            Mp.text('Chicken biryani x 1'),
            Mp.text('Vegetable khichuri x 1'),
            Mp.text('Estimated total: BDT 440'),
          ],
        ),
      ),
      Mp.sizedBox(height: 16),
      Mp.text(
        'Payment and final order submission should stay behind the host bridge '
        'or a publisher-owned API.',
      ),
      Mp.sizedBox(height: 16),
      Mp.secondaryButton(
        label: 'Back to menu',
        action: Mp.navigation.popScreen(),
      ),
    ],
  );
}
