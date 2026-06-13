import 'package:mini_program_ui/mini_program_ui.dart';

import 'screens/food_order_cart.dart';
import 'screens/food_order_home.dart';

final miniProgram = MpProgram(
  screens: <String, MpScreenBuilder>{
    'food_order_home': buildFoodOrderHome,
    'food_order_cart': buildFoodOrderCart,
  },
);
