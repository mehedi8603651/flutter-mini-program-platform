import 'package:mini_program_ui/mini_program_ui.dart';
import 'package:test/test.dart';

void main() {
  test('the supported barrel exposes the stable authoring surface', () {
    const namespaces = <Object>[
      MpActionActions(),
      MpAuthActions(),
      MpBackendActions(),
      MpCacheActions(),
      MpDataActions(),
      MpLocationActions(),
      MpMathActions(),
      MpNavigationActions(),
      MpRouterActions(),
      MpSearch(),
      MpStateActions(),
      MpTimer(),
      MpLazy(),
      MpSkeleton(),
    ];

    const option = MpOption(value: 'one', label: 'One');
    final action = MpAction('state.clear');
    final node = MpNode('text', props: <String, Object?>{'data': 'Hello'});
    final program = MpProgram(
      screens: <String, MpScreenBuilder>{'home': () => node},
    );
    final document = MpScreenDocument(screenId: 'home', root: node);
    final buildWriter = writeMpBuildOutput;

    expect(namespaces, hasLength(14));
    expect(option.toJson(), <String, Object?>{'label': 'One', 'value': 'one'});
    expect(action.type, 'state.clear');
    expect(Mp.cache.data, isA<MpCacheBucketActions>());
    expect(program.buildScreensJson(), contains('home'));
    expect(document.toJson()['schemaVersion'], 1);
    expect(buildWriter, isNotNull);
    expect(MpImageSource.asset.wireName, 'asset');
    expect(MpImageFit.cover.wireName, 'cover');
    expect(MpSkeletonVariant.box.name, 'box');
    expect(MpSchema.schemaVersion, 1);
  });
}
