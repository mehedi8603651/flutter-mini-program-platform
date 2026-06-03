import 'package:mini_program_ui/mini_program_ui.dart';

import 'screens/mp_profile_center_details.dart';
import 'screens/mp_profile_center_home.dart';

final miniProgram = MpProgram(
  screens: <String, MpScreenBuilder>{
    'mp_profile_center_home': buildMpProfileCenterHome,
    'mp_profile_center_details': buildMpProfileCenterDetails,
  },
);
