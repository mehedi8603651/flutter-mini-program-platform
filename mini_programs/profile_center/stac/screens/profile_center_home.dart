import 'package:stac_core/stac_core.dart';

import '../components/profile_summary_card.dart';

@StacScreen(screenName: 'profile_center_home')
StacWidget profileCenterHome() {
  return StacScaffold(
    appBar: StacAppBar(title: StacText(data: 'Profile Center')),
    body: StacSafeArea(
      child: StacSingleChildScrollView(
        padding: StacEdgeInsets.all(24),
        child: StacColumn(
          crossAxisAlignment: StacCrossAxisAlignment.start,
          children: [
            StacText(
              data: 'Portable account module',
              style: StacCustomTextStyle(
                fontSize: 28,
                fontWeight: StacFontWeight.w700,
                color: '#1A202C',
              ),
            ),
            StacSizedBox(height: 12),
            StacText(
              data:
                  'This mini-program is delivered through the shared SDK, '
                  'keeps native work behind the host bridge, and now proves '
                  'backend-selected version rollout.',
            ),
            StacSizedBox(height: 24),
            StacContainer(
              padding: StacEdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: StacBoxDecoration(
                color: '#DFF4EA',
                borderRadius: StacBorderRadius.all(18),
              ),
              child: StacText(
                data: 'Active release: Profile Center v1.1.0',
                style: StacCustomTextStyle(
                  fontSize: 15,
                  fontWeight: StacFontWeight.w600,
                  color: '#14532D',
                ),
              ),
            ),
            StacSizedBox(height: 16),
            profileSummaryCard(),
            StacSizedBox(height: 24),
            StacFilledButton(
              onPressed: const StacAction(
                jsonData: {
                  'actionType': 'hostAction',
                  'requestId': 'profile-track-open',
                  'action': 'trackEvent',
                  'payload': {
                    'name': 'profile_center_opened',
                    'properties': {
                      'source': 'profile_center',
                      'surface': 'profile_center',
                    },
                  },
                },
              ),
              child: StacText(data: 'Track Profile Event'),
            ),
            StacSizedBox(height: 12),
            StacFilledButton(
              onPressed: const StacAction(
                jsonData: {
                  'actionType': 'hostAction',
                  'requestId': 'profile-open-native-editor',
                  'action': 'openNativeScreen',
                  'payload': {
                    'route': 'profile_editor',
                    'args': {'userId': 'guest_001', 'source': 'profile_center'},
                    'expectResult': true,
                  },
                },
              ),
              child: StacText(data: 'Open Native Edit Screen'),
            ),
          ],
        ),
      ),
    ),
  );
}
