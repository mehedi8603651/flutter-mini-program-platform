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

    test('text style helpers reject invalid configuration', () {
      expect(() => Mp.text(''), throwsArgumentError);
      expect(() => Mp.heading(''), throwsArgumentError);
      expect(() => Mp.text('Hi', size: 0), throwsArgumentError);
      expect(() => Mp.text('Hi', color: '#FFF'), throwsArgumentError);
      expect(() => Mp.text('Hi', weight: 'heavy'), throwsArgumentError);
      expect(() => Mp.text('Hi', align: 'middle'), throwsArgumentError);
      expect(() => Mp.text('Hi', overflow: 'truncate'), throwsArgumentError);
      expect(() => Mp.text('Hi', maxLines: 0), throwsArgumentError);
      expect(() => Mp.text('Hi', lineHeight: 0), throwsArgumentError);
      expect(() => Mp.text('Hi', textDirection: 'both'), throwsArgumentError);
      expect(() => Mp.text('Hi', locale: 'en_us'), throwsArgumentError);
      expect(() => Mp.text('Hi', variant: ''), throwsArgumentError);
      expect(() => Mp.heading('Hi', level: 0), throwsArgumentError);
      expect(() => Mp.heading('Hi', level: 7), throwsArgumentError);
    });

    test('lightweight theme helpers reject invalid configuration', () {
      expect(
        () => Mp.theme(
          colors: const <String, String>{'primary': '#FFF'},
          child: Mp.text('Hi'),
        ),
        throwsArgumentError,
      );
      expect(
        () => Mp.theme(
          colors: const <String, String>{'bad-token': '#FFFFFF'},
          child: Mp.text('Hi'),
        ),
        throwsArgumentError,
      );
      expect(
        () => Mp.theme(
          typography: const <String, Map<String, Object?>>{
            '': <String, Object?>{'size': 16},
          },
          child: Mp.text('Hi'),
        ),
        throwsArgumentError,
      );
      expect(
        () => Mp.theme(
          typography: const <String, Map<String, Object?>>{
            'title': <String, Object?>{'size': 0},
          },
          child: Mp.text('Hi'),
        ),
        throwsArgumentError,
      );
      expect(
        () => Mp.theme(
          typography: const <String, Map<String, Object?>>{
            'title': <String, Object?>{'weight': 'heavy'},
          },
          child: Mp.text('Hi'),
        ),
        throwsArgumentError,
      );
      expect(
        () => Mp.theme(
          typography: const <String, Map<String, Object?>>{
            'title': <String, Object?>{'lineHeight': 0},
          },
          child: Mp.text('Hi'),
        ),
        throwsArgumentError,
      );
      expect(
        () => Mp.theme(
          typography: const <String, Map<String, Object?>>{
            'title': <String, Object?>{'color': 'bad-token'},
          },
          child: Mp.text('Hi'),
        ),
        throwsArgumentError,
      );
      expect(
        () => Mp.theme(
          typography: const <String, Map<String, Object?>>{
            'title': <String, Object?>{'fontFamily': 'Inter'},
          },
          child: Mp.text('Hi'),
        ),
        throwsArgumentError,
      );
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

    test('visual layout primitives reject invalid configuration', () {
      expect(
        () => Mp.opacity(opacity: -0.1, child: Mp.text('Hi')),
        throwsArgumentError,
      );
      expect(
        () => Mp.opacity(opacity: 1.1, child: Mp.text('Hi')),
        throwsArgumentError,
      );
      expect(
        () => Mp.aspectRatio(aspectRatio: 0, child: Mp.text('Hi')),
        throwsArgumentError,
      );
      expect(() => Mp.stack(children: const <MpNode>[]), throwsArgumentError);
      expect(
        () => Mp.stack(alignment: 'middle', children: <MpNode>[Mp.text('Hi')]),
        throwsArgumentError,
      );
      expect(() => Mp.positioned(child: Mp.text('Hi')), throwsArgumentError);
      expect(
        () => Mp.positioned(top: -1, child: Mp.text('Hi')),
        throwsArgumentError,
      );
      expect(
        () => Mp.positioned(left: 1, right: 1, width: 10, child: Mp.text('Hi')),
        throwsArgumentError,
      );
      expect(
        () =>
            Mp.positioned(top: 1, bottom: 1, height: 10, child: Mp.text('Hi')),
        throwsArgumentError,
      );
    });

    test('flex sizing primitives reject invalid configuration', () {
      expect(
        () => Mp.expanded(flex: 0, child: Mp.text('Hi')),
        throwsArgumentError,
      );
      expect(
        () => Mp.flexible(flex: -1, child: Mp.text('Hi')),
        throwsArgumentError,
      );
      expect(
        () => Mp.flexible(fit: 'fill', child: Mp.text('Hi')),
        throwsArgumentError,
      );

      final expanded = Mp.expanded(child: Mp.text('Hi'));
      final flexible = Mp.flexible(child: Mp.text('Hi'));
      expect(expanded.props, <String, Object?>{'flex': 1});
      expect(flexible.props, <String, Object?>{'fit': 'loose', 'flex': 1});
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
