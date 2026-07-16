import 'package:mini_program_ui/src/mp_action.dart' as legacy_action;
import 'package:mini_program_ui/src/mp_image.dart' as legacy_image;
import 'package:mini_program_ui/src/mp_lazy.dart' as legacy_lazy;
import 'package:mini_program_ui/src/mp_node.dart' as legacy_node;
import 'package:mini_program_ui/src/mp.dart' as legacy_mp;
import 'package:mini_program_ui/src/mp_program.dart' as legacy_program;
import 'package:mini_program_ui/src/mp_schema.dart' as legacy_schema;
import 'package:mini_program_ui/src/mp_skeleton.dart' as legacy_skeleton;
import 'package:mini_program_ui/src/widgets/layout_widgets.dart'
    as legacy_layout;
import 'package:test/test.dart';

void main() {
  test('legacy internal imports remain source compatible through 0.1.x', () {
    final action = legacy_action.MpAction('state.clear');
    final child = legacy_node.MpNode('text');
    final list = legacy_layout.buildListViewNode(children: [child]);
    final program = legacy_program.MpProgram(
      screens: <String, legacy_program.MpScreenBuilder>{'home': () => list},
    );

    expect(action.type, 'state.clear');
    expect(const legacy_mp.MpStateActions(), isA<legacy_mp.MpStateActions>());
    expect(program.buildScreensJson(), contains('home'));
    expect(legacy_image.MpImageSource.asset.wireName, 'asset');
    expect(const legacy_lazy.MpLazy(), isA<legacy_lazy.MpLazy>());
    expect(
      const legacy_skeleton.MpSkeleton(),
      isA<legacy_skeleton.MpSkeleton>(),
    );
    expect(legacy_schema.MpSchema.schemaVersion, 1);
  });
}
