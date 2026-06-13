import 'package:mini_program_ui/mini_program_ui.dart';

MpNode buildFoodOrderHome() {
  return Mp.column(
    children: <MpNode>[
      Mp.heading('Food Order'),
      Mp.text('Browse a compact Mp-only menu and continue to cart review.'),
      Mp.sizedBox(height: 16),
      Mp.image(
        src: 'https://picsum.photos/seed/food_order_menu/640/320',
        alt: 'Prepared meal table',
      ),
      Mp.sizedBox(height: 16),
      Mp.card(
        child: Mp.column(
          children: <MpNode>[
            Mp.heading('Popular meals'),
            Mp.listTile(
              title: 'Chicken biryani',
              subtitle: 'Aromatic rice, tender chicken, salad',
              leadingIcon: 'star',
              badge: 'BDT 260',
            ),
            Mp.listTile(
              title: 'Beef tehari',
              subtitle: 'Slow cooked beef with fragrant rice',
              leadingIcon: 'gift',
              badge: 'BDT 290',
            ),
            Mp.listTile(
              title: 'Vegetable khichuri',
              subtitle: 'Lentils, rice, mixed vegetables',
              leadingIcon: 'check',
              badge: 'BDT 180',
            ),
          ],
        ),
      ),
      Mp.sizedBox(height: 16),
      Mp.primaryButton(
        label: 'Review cart',
        action: Mp.navigation.openScreen('food_order_cart'),
      ),
    ],
  );
}
