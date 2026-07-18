String buildScaffoldBuildScript() => '''
import 'package:mini_program_ui/mini_program_ui.dart';

import '../mp/program.dart';

Future<void> main(List<String> arguments) async {
  await writeMpBuildOutput(miniProgram, arguments: arguments);
}
''';

String buildScaffoldProgram({
  required String entryScreenId,
  required String detailsScreenId,
  required String homeFunctionName,
  required String detailsFunctionName,
}) =>
    '''
import 'package:mini_program_ui/mini_program_ui.dart';

import 'screens/$detailsScreenId.dart';
import 'screens/$entryScreenId.dart';

final miniProgram = MpProgram(
  screens: <String, MpScreenBuilder>{
    '$entryScreenId': $homeFunctionName,
    '$detailsScreenId': $detailsFunctionName,
  },
);
''';

String buildScaffoldHomeScreen({
  required String title,
  required List<String> capabilities,
  required String detailsScreenId,
  required String homeFunctionName,
  required bool withMockBackend,
}) {
  final capabilitiesLabel = capabilities.join(', ');
  return '''
import 'package:mini_program_ui/mini_program_ui.dart';

MpNode $homeFunctionName() {
  return Mp.column(
    children: <MpNode>[
      Mp.heading('$title profile starter'),
      Mp.text(
        'Start from a lightweight Mp JSON flow. Replace this copy and data '
        'shape with your business case, then publish the same JSON to any '
        'public static artifact host.',
      ),
      Mp.sizedBox(height: 12),
      Mp.card(
        child: Mp.column(
          children: <MpNode>[
            Mp.text('Starter capabilities: $capabilitiesLabel'),
          ],
        ),
      ),
${withMockBackend ? buildScaffoldBackendUiSection() : ''}
      Mp.heading('Publisher account'),
      Mp.authBuilder(
        loading: Mp.text('Checking saved sign-in...'),
        signedOut: Mp.card(
          child: Mp.column(
            children: <MpNode>[
              Mp.text('Sign in to load publisher data from the runtime API.'),
              Mp.primaryButton(
                label: 'Sign in with email',
                action: Mp.auth.showEmailAuth(),
              ),
            ],
          ),
        ),
        signedIn: Mp.card(
          child: Mp.column(
            children: <MpNode>[
              Mp.text('Signed in as {{auth.user.email}}'),
              Mp.secondaryButton(
                label: 'Sign out',
                action: Mp.auth.signOut(),
              ),
            ],
          ),
        ),
        error: Mp.text('{{auth.message}}'),
      ),
      Mp.card(
        child: Mp.column(
          children: <MpNode>[
            Mp.heading('Preview User'),
            Mp.text('Email: preview.user@example.com'),
            Mp.text('Tier: $title starter'),
            Mp.text('Status: Ready for your real profile fields'),
          ],
        ),
      ),
      Mp.primaryButton(
        label: 'Open profile details',
        action: Mp.navigation.openScreen('$detailsScreenId'),
      ),
      Mp.text(
        'Keep the default starter simple: one internal route from home to '
        'details, then grow the flow around your real use case.',
      ),
    ],
  );
}
''';
}

String buildScaffoldBackendUiSection() => '''
      Mp.heading('Publisher API data'),
      Mp.backendBuilder(
        requestId: 'home',
        endpoint: 'home/bootstrap',
        cacheTtlSeconds: 60,
        loading: Mp.text('Loading backend home data...'),
        error: Mp.text('{{backend.home.message}}'),
        child: Mp.card(
          child: Mp.column(
            children: <MpNode>[
              Mp.image(src: '{{backend.home.data.imageUrl}}'),
              Mp.heading('{{backend.home.data.title}}'),
              Mp.text('{{backend.home.data.subtitle}}'),
              Mp.text('{{backend.home.data.user.summary}}'),
            ],
          ),
        ),
      ),
      Mp.heading('Paged coupons'),
      Mp.pagedBackendBuilder(
        requestId: 'coupons',
        endpoint: 'coupons/page',
        limit: 2,
        loading: Mp.text('Loading coupons...'),
        loadingMore: Mp.text('Loading more coupons...'),
        empty: Mp.text('No coupons yet.'),
        error: Mp.text('{{backend.coupons.message}}'),
        end: Mp.text('No more coupons.'),
        itemTemplate: Mp.card(
          child: Mp.column(
            children: <MpNode>[
              Mp.image(src: '{{item.imageUrl}}'),
              Mp.heading('{{item.title}}'),
              Mp.text('{{item.description}}'),
            ],
          ),
        ),
        loadMore: Mp.secondaryButton(
          label: 'Load more coupons',
          action: Mp.backend.loadMore(requestId: 'coupons'),
        ),
      ),
''';

String buildScaffoldDetailsScreen({
  required String title,
  required String detailsFunctionName,
}) =>
    '''
import 'package:mini_program_ui/mini_program_ui.dart';

MpNode $detailsFunctionName() {
  return Mp.column(
    children: <MpNode>[
      Mp.heading('$title details'),
      Mp.text(
        'This screen proves Mp navigation without host app route code. Add '
        'real settings, claim history, support, or account details here.',
      ),
      Mp.card(
        child: Mp.column(
          children: <MpNode>[
            Mp.heading('Next customization'),
            Mp.text('Replace the preview copy with your production model.'),
          ],
        ),
      ),
      Mp.secondaryButton(
        label: 'Back',
        action: Mp.navigation.popScreen(),
      ),
    ],
  );
}
''';
