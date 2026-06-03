import 'package:mini_program_ui/mini_program_ui.dart';

MpNode buildMpProfileCenterHome() {
  return Mp.column(
    children: <MpNode>[
      Mp.heading('Mp Profile Center'),
      Mp.text('A lightweight Mp JSON fixture rendered by mini_program_sdk.'),
      Mp.sizedBox(height: 16),
      Mp.image(
        src: 'https://picsum.photos/seed/mp_profile_center/640/320',
        alt: 'Profile workspace image',
      ),
      Mp.sizedBox(height: 16),
      Mp.card(
        child: Mp.column(
          children: <MpNode>[
            Mp.heading('Portable Mp profile'),
            Mp.text(
              'This screen is authored with Mp.* and bundled as versioned Mp JSON.',
            ),
            Mp.text('Fixture id: mp_profile_center'),
          ],
        ),
      ),
      Mp.sizedBox(height: 16),
      Mp.primaryButton(
        label: 'Open Mp profile details',
        action: Mp.navigation.openScreen('mp_profile_center_details'),
      ),
    ],
  );
}
