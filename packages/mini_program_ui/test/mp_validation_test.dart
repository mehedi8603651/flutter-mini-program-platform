import 'package:mini_program_ui/mini_program_ui.dart';
import 'package:test/test.dart';

void main() {
  group('MpProgram validation', () {
    test('rejects an empty screen registry', () {
      expect(
        () => MpProgram(screens: const <String, MpScreenBuilder>{}),
        throwsArgumentError,
      );
    });

    test('rejects invalid screen IDs', () {
      expect(
        () => MpProgram(
          screens: <String, MpScreenBuilder>{'CouponHome': () => Mp.text('Hi')},
        ),
        throwsArgumentError,
      );
      expect(
        () => MpProgram(
          screens: <String, MpScreenBuilder>{
            'coupon-home': () => Mp.text('Hi'),
          },
        ),
        throwsArgumentError,
      );
    });

    test('rejects empty action and node types', () {
      expect(() => MpAction(''), throwsArgumentError);
      expect(() => MpNode(''), throwsArgumentError);
    });

    test('requires sizedBox to define at least one dimension', () {
      expect(() => Mp.sizedBox(), throwsArgumentError);
    });

    test('core design widget helpers reject invalid configuration', () {
      expect(
        () => Mp.padding(all: -1, child: Mp.text('Hi')),
        throwsArgumentError,
      );
      expect(
        () => Mp.container(width: -1, child: Mp.text('Hi')),
        throwsArgumentError,
      );
      expect(
        () => Mp.container(backgroundColor: 'red', child: Mp.text('Hi')),
        throwsArgumentError,
      );
      expect(() => Mp.divider(thickness: -1), throwsArgumentError);
      expect(() => Mp.divider(color: '#FFF'), throwsArgumentError);
      expect(() => Mp.icon(''), throwsArgumentError);
      expect(() => Mp.icon('video'), throwsArgumentError);
      expect(() => Mp.listTile(title: ''), throwsArgumentError);
      expect(
        () => Mp.listTile(title: 'Profile', leadingIcon: 'video'),
        throwsArgumentError,
      );
      expect(() => Mp.chip(label: ''), throwsArgumentError);
      expect(() => Mp.chip(label: 'New', tone: 'brand'), throwsArgumentError);
      expect(() => Mp.badge(label: ''), throwsArgumentError);
      expect(() => Mp.badge(label: 'New', tone: 'brand'), throwsArgumentError);
    });

    test('future display and layout helpers reject invalid configuration', () {
      expect(() => Mp.alert(title: '', tone: 'info'), throwsArgumentError);
      expect(() => Mp.alert(title: 'Hi', tone: 'brand'), throwsArgumentError);
      expect(() => Mp.alert(title: 'Hi', icon: 'video'), throwsArgumentError);
      expect(() => Mp.avatar(), throwsArgumentError);
      expect(
        () => Mp.avatar(initials: 'MH', icon: 'person'),
        throwsArgumentError,
      );
      expect(() => Mp.avatar(icon: 'person', size: 0), throwsArgumentError);
      expect(
        () => Mp.grid(children: const <MpNode>[], columns: 2),
        throwsArgumentError,
      );
      expect(
        () => Mp.grid(children: <MpNode>[Mp.text('Hi')], columns: 7),
        throwsArgumentError,
      );
      expect(
        () => Mp.wrap(children: const <MpNode>[], spacing: 8),
        throwsArgumentError,
      );
      expect(() => Mp.progress(value: -1), throwsArgumentError);
      expect(() => Mp.progress(value: 2, max: 1), throwsArgumentError);
      expect(
        () => Mp.emptyState(
          title: 'Empty',
          action: Mp.state.set('empty.retry', true),
        ),
        throwsArgumentError,
      );
      expect(
        () => Mp.emptyState(title: 'Empty', actionLabel: 'Retry'),
        throwsArgumentError,
      );
      expect(
        () => Mp.section(title: '', child: Mp.text('Body')),
        throwsArgumentError,
      );
      expect(
        () => Mp.section(
          title: 'Featured',
          child: Mp.text('Body'),
          actionLabel: 'View all',
        ),
        throwsArgumentError,
      );
    });

    test('safe layout primitives reject invalid configuration', () {
      expect(
        () => Mp.align(alignment: 'middle', child: Mp.text('Hi')),
        throwsArgumentError,
      );
      expect(() => Mp.spacer(flex: 0), throwsArgumentError);
      expect(
        () => Mp.listView(children: const <MpNode>[]),
        throwsArgumentError,
      );
      expect(
        () => Mp.listView(children: <MpNode>[Mp.text('Hi')], spacing: -1),
        throwsArgumentError,
      );
      expect(
        () => Mp.listView(children: <MpNode>[Mp.text('Hi')], paddingLeft: -1),
        throwsArgumentError,
      );
    });

    test('runtime parity helpers reject invalid required fields', () {
      expect(
        () => Mp.backendBuilder(requestId: '', endpoint: 'home/bootstrap'),
        throwsArgumentError,
      );
      expect(() => Mp.backend.call(endpoint: ''), throwsArgumentError);
      expect(
        () => Mp.pagedBackendBuilder(
          requestId: 'coupons',
          endpoint: 'coupons/page',
          itemTemplate: Mp.text('{{item.title}}'),
          limit: 0,
        ),
        throwsArgumentError,
      );
      expect(() => Mp.navigation.openScreen(''), throwsArgumentError);
    });

    test('state and router helpers reject invalid configuration', () {
      expect(
        () => Mp.stateBuilder(keys: const <String>[], child: Mp.text('Count')),
        throwsArgumentError,
      );
      expect(() => Mp.state.set('auth.token', 'secret'), throwsArgumentError);
      expect(() => Mp.state.increment('Count'), throwsArgumentError);
      expect(() => Mp.action.sequence(const <MpAction>[]), throwsArgumentError);
      expect(() => Mp.router.push(''), throwsArgumentError);
    });

    test('form helpers reject invalid configuration', () {
      const options = <MpOption>[
        MpOption(value: 'stem', label: 'STEM'),
        MpOption(value: 'arts', label: 'Arts'),
      ];

      expect(() => Mp.form(children: const <MpNode>[]), throwsArgumentError);
      expect(
        () => Mp.textInput(name: 'email', label: 'Email', minLength: -1),
        throwsArgumentError,
      );
      expect(
        () => Mp.textArea(
          name: 'essay',
          label: 'Essay',
          minLines: 6,
          maxLines: 4,
        ),
        throwsArgumentError,
      );
      expect(
        () => Mp.dropdown(
          name: 'program',
          label: 'Program',
          options: const <MpOption>[],
        ),
        throwsArgumentError,
      );
      expect(
        () => Mp.radioGroup(
          name: 'level',
          label: 'Level',
          options: options,
          initialValue: 'missing',
        ),
        throwsArgumentError,
      );
      expect(
        () => Mp.dropdown(
          name: 'program',
          label: 'Program',
          options: const <MpOption>[
            MpOption(value: 'stem', label: 'STEM'),
            MpOption(value: 'stem', label: 'Duplicate'),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => Mp.formSubmit(label: 'Submit', endpoint: ''),
        throwsArgumentError,
      );
      expect(
        () => Mp.toast(message: 'Saved', durationMs: 0),
        throwsArgumentError,
      );
      expect(() => Mp.dialog(message: ''), throwsArgumentError);
    });
  });
}
