import 'package:mini_program_ui/mini_program_ui.dart';

import 'screens/mp_rewards_center_home.dart';

final miniProgram = MpProgram(
  screens: <String, MpScreenBuilder>{
    'mp_rewards_center_home': buildMpRewardsCenterHome,
  },
);
