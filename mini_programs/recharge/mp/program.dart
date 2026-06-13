import 'package:mini_program_ui/mini_program_ui.dart';

import 'screens/recharge_confirm.dart';
import 'screens/recharge_home.dart';

final miniProgram = MpProgram(
  screens: <String, MpScreenBuilder>{
    'recharge_home': buildRechargeHome,
    'recharge_confirm': buildRechargeConfirm,
  },
);
