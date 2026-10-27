import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';
import 'package:mini_program_ui/mini_program_ui.dart';

void main() {
  testWidgets(
    'observes resolved live controls and taps their existing actions',
    (tester) async {
      final controller = MiniProgramInteractionController();
      await _mount(
        tester,
        controller,
        Mp.column(
          children: [
            Mp.stateBuilder(
              keys: ['count'],
              child: Mp.text('Cart: {{state.count}}'),
            ),
            Mp.primaryButton(
              label: 'Add noodles',
              action: Mp.state.set('count', 2),
            ),
          ],
        ),
      );
      final before = await _drive(tester, controller.observe());
      expect(before.status, 'ready');
      expect(before.screenId, 'home');
      expect(before.canGoBack, isFalse);
      expect(_text(before), contains('Cart:'));
      final result = await _tap(tester, controller, before, 'Add noodles');
      expect(result.status, 'completed');
      expect(_text(result.snapshot), contains('Cart: 2'));
      expect(result.snapshot.revision, greaterThan(before.revision));
      expect(jsonEncode(result.toJson()), isNot(contains('state.set')));
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets(
    'rejects stale and replayed commands after a manual interaction',
    (tester) async {
      final controller = MiniProgramInteractionController();
      await _mount(
        tester,
        controller,
        Mp.primaryButton(label: 'Add', action: Mp.state.increment('count')),
      );
      final before = await _drive(tester, controller.observe());
      final target = _button(before, 'Add');
      await tester.tap(find.text('Add'));
      await tester.pump();
      final stale = await _drive(
        tester,
        controller.interact(_request(before, target)),
      );
      expect(stale.code, 'stale_view');
      final accepted = _request(stale.snapshot, _button(stale.snapshot, 'Add'));
      final first = await _drive(tester, controller.interact(accepted));
      final replay = await _drive(tester, controller.interact(accepted));
      expect(first.status, 'completed');
      expect(replay.code, 'duplicate_request');
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets(
    'uses form validation, edits the live field, and submits exactly once',
    (tester) async {
      final controller = MiniProgramInteractionController();
      final backend = _Backend();
      await _mount(
        tester,
        controller,
        Mp.form(
          children: [
            Mp.textInput(name: 'note', label: 'Delivery note', required: true),
            Mp.formSubmit(label: 'Submit order', endpoint: '/orders'),
          ],
        ),
        backend: backend,
      );
      var snapshot = await _drive(tester, controller.observe());
      var result = await _tap(tester, controller, snapshot, 'Submit order');
      expect(backend.calls, isEmpty);
      expect(_text(result.snapshot), contains('Check the highlighted fields'));
      final field = result.snapshot.nodes.firstWhere(
        (n) => n.role == 'textField',
      );
      result = await _drive(
        tester,
        controller.interact(
          _request(
            result.snapshot,
            field,
            action: MiniProgramInteractionAction.enterText,
            text: 'No onions',
          ),
        ),
      );
      expect(result.status, 'completed');
      expect(_text(result.snapshot), contains('No onions'));
      snapshot = result.snapshot;
      result = await _tap(tester, controller, snapshot, 'Submit order');
      expect(backend.calls, hasLength(1));
      expect(backend.calls.single.body, {'note': 'No onions'});
      expect(result.status, 'completed');
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets('owned dropdown routes expose only the current choices', (
    tester,
  ) async {
    final controller = MiniProgramInteractionController();
    await _mount(
      tester,
      controller,
      Mp.form(
        children: [
          Mp.dropdown(
            name: 'delivery',
            label: 'Delivery',
            options: [
              MpOption(value: 'collect', label: 'Collect at shop'),
              MpOption(value: 'deliver', label: 'Home delivery'),
            ],
          ),
          Mp.primaryButton(
            label: 'Underlying button',
            action: Mp.state.set('x', 1),
          ),
        ],
      ),
    );
    var snapshot = await _drive(tester, controller.observe());
    var result = await _tap(tester, controller, snapshot, 'Choose');
    snapshot = result.snapshot;
    expect(snapshot.status, 'ready');
    expect(_text(snapshot), contains('Home delivery'));
    expect(_text(snapshot), isNot(contains('Underlying button')));
    result = await _tap(tester, controller, snapshot, 'Home delivery');
    expect(_text(result.snapshot), contains('Home delivery'));
    expect(_text(result.snapshot), contains('Underlying button'));
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets(
    'an open SDK dialog accepts another interaction and Back closes it',
    (tester) async {
      final controller = MiniProgramInteractionController();
      await _mount(
        tester,
        controller,
        Mp.primaryButton(
          label: 'Open details',
          action: Mp.dialog.custom(
            child: Mp.column(
              children: [
                Mp.text('Booking details'),
                Mp.primaryButton(
                  label: 'Close details',
                  action: Mp.dialog.close(),
                ),
              ],
            ),
          ),
        ),
      );
      var snapshot = await _drive(tester, controller.observe());
      var result = await _tap(tester, controller, snapshot, 'Open details');
      expect(result.snapshot.status, 'ready');
      expect(_text(result.snapshot), contains('Booking details'));
      result = await _tap(tester, controller, result.snapshot, 'Close details');
      expect(_text(result.snapshot), contains('Open details'));
      result = await _tap(tester, controller, result.snapshot, 'Open details');
      snapshot = result.snapshot;
      result = await _drive(
        tester,
        controller.interact(
          _request(snapshot, null, action: MiniProgramInteractionAction.back),
        ),
      );
      expect(_text(result.snapshot), contains('Open details'));
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets(
    'backgrounding rejects actions and preserves a live draft on return',
    (tester) async {
      final controller = MiniProgramInteractionController();
      await _mount(
        tester,
        controller,
        Mp.stateTextField(stateKey: 'note', label: 'Note'),
      );
      var snapshot = await _drive(tester, controller.observe());
      final field = snapshot.nodes.firstWhere((n) => n.role == 'textField');
      final edited = await _drive(
        tester,
        controller.interact(
          _request(
            snapshot,
            field,
            action: MiniProgramInteractionAction.enterText,
            text: 'Keep this draft',
          ),
        ),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      snapshot = await _drive(
        tester,
        controller.observe(sessionId: snapshot.sessionId),
      );
      expect(snapshot.status, 'hidden');
      expect(snapshot.nodes, isEmpty);
      final blocked = await _drive(
        tester,
        controller.interact(
          _request(
            edited.snapshot,
            edited.snapshot.nodes.firstWhere((n) => n.role == 'textField'),
            action: MiniProgramInteractionAction.enterText,
            text: 'Wrong',
          ),
        ),
      );
      expect(blocked.code, 'foreground_required');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      snapshot = await _drive(tester, controller.observe());
      expect(_text(snapshot), contains('Keep this draft'));
      expect(snapshot.revision, greaterThan(edited.snapshot.revision));
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets(
    'host screens, hidden state and protected values are not exported',
    (tester) async {
      final controller = MiniProgramInteractionController();
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          home: Scaffold(
            body: Column(
              children: [
                const Text('Private host wallet balance'),
                Expanded(
                  child: MiniProgramInteractionSurface(
                    controller: controller,
                    appId: 'shop',
                    screenId: 'home',
                    child: const Column(
                      children: [
                        Text('Public shop'),
                        TextField(
                          obscureText: true,
                          decoration: InputDecoration(labelText: 'Password'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'never-export-password');
      var snapshot = await _drive(tester, controller.observe());
      expect(
        jsonEncode(snapshot.toJson()),
        isNot(contains('never-export-password')),
      );
      expect(_text(snapshot), isNot(contains('Private host wallet balance')));
      unawaited(
        nav.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Private chat')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      snapshot = await _drive(
        tester,
        controller.observe(sessionId: snapshot.sessionId),
      );
      expect(snapshot.status, 'blocked');
      expect(snapshot.nodes, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets(
    'pending backend work blocks overlapping commands and keeps submitted values',
    (tester) async {
      final controller = MiniProgramInteractionController();
      final backend = _Backend()..gate = Completer<MiniProgramBackendResult>();
      await _mount(
        tester,
        controller,
        Mp.form(
          children: [
            Mp.textInput(name: 'note', label: 'Note', initialValue: 'Draft'),
            Mp.formSubmit(label: 'Save', endpoint: '/orders'),
          ],
        ),
        backend: backend,
      );
      final before = await _drive(tester, controller.observe());
      final first = await _tap(tester, controller, before, 'Save');
      expect(first.status, 'pending');
      expect(first.snapshot.status, 'pending');
      expect(_text(first.snapshot), contains('Submitting'));
      backend.gate!.complete(
        MiniProgramBackendResult.failed(
          errorCode: 'unavailable',
          message: 'Please try again',
        ),
      );
      await tester.pumpAndSettle();
      final after = await _drive(tester, controller.observe());
      expect(_text(after), contains('Draft'));
      expect(_text(after), contains('Please try again'));
      expect(backend.calls, hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets(
    'scroll reveals later live rows with distinct element identities',
    (tester) async {
      final controller = MiniProgramInteractionController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MiniProgramInteractionSurface(
              controller: controller,
              appId: 'shop',
              screenId: 'menu',
              child: ListView.builder(
                itemCount: 100,
                itemExtent: 100,
                itemBuilder: (_, i) =>
                    TextButton(onPressed: () {}, child: Text('Product $i')),
              ),
            ),
          ),
        ),
      );
      var snapshot = await _drive(tester, controller.observe());
      expect(_text(snapshot), isNot(contains('Product 99')));
      final scroller = snapshot.nodes.firstWhere(
        (n) => n.actions.contains(MiniProgramInteractionAction.scrollUp),
      );
      final result = await _drive(
        tester,
        controller.interact(
          _request(
            snapshot,
            scroller,
            action: MiniProgramInteractionAction.scrollUp,
          ),
        ),
      );
      await tester.pumpAndSettle();
      snapshot = await _drive(tester, controller.observe());
      expect(result.status, 'completed');
      expect(_text(snapshot), contains('Product 6'));
      expect(
        snapshot.nodes.map((n) => n.id).toSet().length,
        snapshot.nodes.length,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets('AI taps cannot manufacture permission-gated native gestures', (
    tester,
  ) async {
    final controller = MiniProgramInteractionController();
    final vibration = _Vibration();
    await _mount(
      tester,
      controller,
      Mp.primaryButton(label: 'Haptic', action: Mp.vibration.trigger()),
      vibration: vibration,
    );
    final before = await _drive(tester, controller.observe());
    final result = await _tap(tester, controller, before, 'Haptic');
    expect(result.status, 'failed');
    expect(result.code, 'vibration_user_gesture_required');
    expect(vibration.calls, 0);
    await tester.tap(find.text('Haptic'));
    await tester.pumpAndSettle();
    expect(vibration.calls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  for (final replaceController in [false, true]) {
    testWidgets(
      '${replaceController ? 'controller replacement' : 'app identity change'} interrupts delayed AI sequences',
      (tester) async {
        final first = MiniProgramInteractionController();
        final replacement = MiniProgramInteractionController();
        final backend = _Backend()
          ..gate = Completer<MiniProgramBackendResult>();
        final source = _Source(
          Mp.column(
            children: [
              Mp.primaryButton(
                label: 'Continue',
                action: Mp.action.sequence([
                  Mp.backend.call(endpoint: '/wait'),
                  Mp.state.set('note', 'Old owner continued'),
                ]),
              ),
              Mp.stateBuilder(
                keys: ['note'],
                child: Mp.text('Note: {{state.note}}'),
              ),
            ],
          ),
        );
        final bridge = _Bridge();
        final capabilities = CapabilityRegistry(const []);
        var changed = false;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (_, setState) {
                  update = setState;
                  return MiniProgramInteractionSurface(
                    controller: changed && replaceController
                        ? replacement
                        : first,
                    appId: changed && !replaceController ? 'other' : 'shop',
                    screenId: 'home',
                    child: MiniProgramHost(
                      miniProgramId: 'shop',
                      sdkVersion: '1.0.0',
                      source: source,
                      hostBridge: bridge,
                      capabilityRegistry: capabilities,
                      backendConnector: backend,
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final before = await _drive(tester, first.observe());
        expect(
          (await _tap(tester, first, before, 'Continue')).status,
          'pending',
        );
        update(() => changed = true);
        await tester.pump();
        backend.gate!.complete(MiniProgramBackendResult.success());
        await tester.pumpAndSettle();
        final current = replaceController ? replacement : first;
        final after = await _drive(tester, current.observe());
        expect(after.status, 'ready');
        expect(after.appId, replaceController ? 'shop' : 'other');
        expect(_text(after), isNot(contains('Old owner continued')));
        expect(backend.calls, hasLength(1));
        await tester.pumpWidget(const SizedBox.shrink());
        first.dispose();
        replacement.dispose();
      },
    );
  }

  testWidgets('manual typing interrupts subsequent steps of pending AI work', (
    tester,
  ) async {
    final controller = MiniProgramInteractionController();
    final backend = _Backend()..gate = Completer<MiniProgramBackendResult>();
    await _mount(
      tester,
      controller,
      Mp.column(
        children: [
          Mp.stateTextField(stateKey: 'note', label: 'Note'),
          Mp.primaryButton(
            label: 'Continue',
            action: Mp.action.sequence([
              Mp.backend.call(endpoint: '/wait'),
              Mp.state.set('note', 'Overwritten'),
            ]),
          ),
        ],
      ),
      backend: backend,
    );
    final before = await _drive(tester, controller.observe());
    expect(
      (await _tap(tester, controller, before, 'Continue')).status,
      'pending',
    );
    await tester.enterText(find.byType(EditableText), 'Human draft');
    backend.gate!.complete(MiniProgramBackendResult.success());
    await tester.pumpAndSettle();
    final after = await _drive(tester, controller.observe());
    expect(_text(after), contains('Human draft'));
    expect(_text(after), isNot(contains('Overwritten')));
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('debounced UI work stays pending and is cancelled on hiding', (
    tester,
  ) async {
    final controller = MiniProgramInteractionController();
    await _mount(
      tester,
      controller,
      Mp.column(
        children: [
          Mp.stateTextField(
            stateKey: 'query',
            label: 'Search',
            debounce: const Duration(milliseconds: 600),
            onChanged: Mp.state.set('result', 'Loaded'),
          ),
          Mp.stateBuilder(
            keys: ['result'],
            child: Mp.text('Result: {{state.result}}'),
          ),
        ],
      ),
    );
    final before = await _drive(tester, controller.observe());
    final field = before.nodes.firstWhere((n) => n.role == 'textField');
    final edit = await _drive(
      tester,
      controller.interact(
        _request(
          before,
          field,
          action: MiniProgramInteractionAction.enterText,
          text: 'noodles',
        ),
      ),
    );
    expect(edit.status, 'pending');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(seconds: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final returned = await _drive(tester, controller.observe());
    expect(_text(returned), contains('noodles'));
    expect(_text(returned), isNot(contains('Loaded')));
    final nextField = returned.nodes.firstWhere((n) => n.role == 'textField');
    final next = await _drive(
      tester,
      controller.interact(
        _request(
          returned,
          nextField,
          action: MiniProgramInteractionAction.enterText,
          text: 'soup',
        ),
      ),
    );
    expect(next.status, 'pending');
    await tester.pump(const Duration(seconds: 1));
    final after = await _drive(tester, controller.observe());
    expect(after.status, 'ready');
    expect(_text(after), contains('Loaded'));
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('date picker and checkbox use the current owned UI', (
    tester,
  ) async {
    final controller = MiniProgramInteractionController();
    await _mount(
      tester,
      controller,
      Mp.form(
        children: [
          Mp.dateTime.dateField(
            stateKey: 'date',
            label: 'Visit date',
            initialValue: '2026-10-25',
            minDate: '2026-10-01',
            maxDate: '2026-10-31',
          ),
          Mp.checkbox(name: 'agree', label: 'Agree'),
        ],
      ),
    );
    var snapshot = await _drive(tester, controller.observe());
    final checked = await _tap(tester, controller, snapshot, 'Agree');
    expect(checked.snapshot.nodes.any((n) => n.checked == true), isTrue);
    final open = await _tap(tester, controller, checked.snapshot, 'Visit date');
    expect(open.snapshot.status, 'ready');
    expect(_text(open.snapshot), contains('October 2026'));
    expect(_text(open.snapshot), isNot(contains('Agree')));
    final closed = await _tap(tester, controller, open.snapshot, 'OK');
    expect(_text(closed.snapshot), contains('Agree'));
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets(
    'retained sessions pause separately and ambiguous selection fails closed',
    (tester) async {
      final controller = MiniProgramInteractionController();
      var both = false;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (_, setState) {
                update = setState;
                return Column(
                  children: [
                    MiniProgramInteractionSurface(
                      controller: controller,
                      appId: 'one',
                      screenId: 'a',
                      child: const Text('First app'),
                    ),
                    MiniProgramInteractionSurface(
                      controller: controller,
                      appId: 'two',
                      screenId: 'b',
                      visibility: both
                          ? MiniProgramVisibility.foreground
                          : MiniProgramVisibility.hidden,
                      child: const Text('Second app'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
      final first = await _drive(tester, controller.observe());
      expect(first.appId, 'one');
      expect(_text(first), isNot(contains('Second app')));
      update(() => both = true);
      final ambiguous = await _drive(tester, controller.observe());
      expect(ambiguous.status, 'blocked');
      expect(ambiguous.nodes, isEmpty);
      final chosen = await _drive(
        tester,
        controller.observe(sessionId: first.sessionId),
      );
      expect(chosen.appId, 'one');
      expect(_text(chosen), isNot(contains('Second app')));
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets('metadata is bounded and disabled controls offer no actions', (
    tester,
  ) async {
    final controller = MiniProgramInteractionController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MiniProgramInteractionSurface(
            controller: controller,
            appId: 'shop',
            screenId: 'home',
            child: Column(
              children: [
                const TextButton(onPressed: null, child: Text('Unavailable')),
                SizedBox(
                  height: 24,
                  child: Text(
                    'Long ${'x' * 2000}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  child: Wrap(
                    children: List.generate(
                      250,
                      (i) => Semantics(
                        container: true,
                        child: SizedBox(
                          width: 32,
                          height: 16,
                          child: Text(
                            'Item $i',
                            style: const TextStyle(fontSize: 8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final snapshot = await _drive(tester, controller.observe());
    expect(snapshot.nodes.length, lessThanOrEqualTo(160));
    expect(snapshot.truncated, isTrue);
    expect(snapshot.nodes.every((n) => n.label.length <= 512), isTrue);
    expect(
      snapshot.nodes.firstWhere((n) => n.label.contains('Unavailable')).actions,
      isEmpty,
    );
    expect(utf8.encode(jsonEncode(snapshot.toJson())).length, lessThan(30000));
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets(
    'JSON transport rejects authority injection and malformed commands',
    (tester) async {
      final controller = MiniProgramInteractionController();
      await _mount(
        tester,
        controller,
        Mp.primaryButton(label: 'Shop', action: Mp.state.set('n', 1)),
      );
      for (final request in [
        {'method': 'run', 'action': 'state.clear'},
        {'method': 'observe', 'userGesture': true},
        {
          'method': 'interact',
          'request': {'action': 'tap', 'userGesture': true},
        },
      ]) {
        expect(
          (await _drive(tester, controller.handleRequest(request)))['code'],
          'invalid_request',
        );
      }
      final snapshot = await _drive(tester, controller.observe());
      const codec = StandardMessageCodec();
      final decoded =
          codec.decodeMessage(
                codec.encodeMessage({
                  'method': 'interact',
                  'request': _request(
                    snapshot,
                    _button(snapshot, 'Shop'),
                  ).toJson(),
                }),
              )
              as Map;
      final transported = await _drive(
        tester,
        controller.handleRequest(Map<String, dynamic>.from(decoded)),
      );
      expect(transported['status'], 'completed');
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );
}

int _requestCounter = 0;
MiniProgramInteractionRequest _request(
  MiniProgramInteractionSnapshot snapshot,
  MiniProgramInteractionNode? target, {
  MiniProgramInteractionAction action = MiniProgramInteractionAction.tap,
  String? text,
}) => MiniProgramInteractionRequest(
  requestId: 'r${++_requestCounter}',
  sessionId: snapshot.sessionId,
  revision: snapshot.revision,
  action: action,
  targetId: target?.id,
  text: text,
);

MiniProgramInteractionNode _button(
  MiniProgramInteractionSnapshot snapshot,
  String label,
) => snapshot.nodes.firstWhere(
  (n) =>
      n.label.contains(label) &&
      n.actions.contains(MiniProgramInteractionAction.tap),
  orElse: () => throw StateError(
    'Missing button $label: ${jsonEncode(snapshot.toJson())}',
  ),
);

String _text(MiniProgramInteractionSnapshot snapshot) =>
    snapshot.nodes.map((n) => '${n.label} ${n.value ?? ''}').join('\n');

Future<MiniProgramInteractionResult> _tap(
  WidgetTester tester,
  MiniProgramInteractionController controller,
  MiniProgramInteractionSnapshot snapshot,
  String label,
) => _drive(
  tester,
  controller.interact(_request(snapshot, _button(snapshot, label))),
);

Future<T> _drive<T>(WidgetTester tester, Future<T> future) async {
  var done = false;
  unawaited(
    future.then(
      (_) => done = true,
      onError: (Object _, StackTrace __) {
        done = true;
      },
    ),
  );
  for (var i = 0; i < 40 && !done; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(done, isTrue, reason: 'Interaction did not finish within 40 frames.');
  return future;
}

Future<void> _mount(
  WidgetTester tester,
  MiniProgramInteractionController controller,
  MpNode root, {
  _Backend? backend,
  _Vibration? vibration,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MiniProgramHost(
          miniProgramId: 'shop',
          sdkVersion: '1.0.0',
          source: _Source(root),
          hostBridge: _Bridge(),
          vibrationProvider: vibration,
          capabilityRegistry: CapabilityRegistry(const []),
          interactionController: controller,
          backendConnector: backend,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _Source implements MiniProgramSource, MiniProgramVibrationPolicyProvider {
  _Source(this.root);
  final MpNode root;
  @override
  MiniProgramVibrationPolicy vibrationPolicyFor(String miniProgramId) =>
      const MiniProgramVibrationPolicy(enabled: true);
  @override
  Future<MiniProgramManifest> loadManifest(String miniProgramId) async =>
      const MiniProgramManifest(
        id: 'shop',
        version: '1.0.0',
        entry: 'home',
        contractVersion: '1.0.0',
        sdkVersionRange: SdkVersionRange(value: '>=1.0.0 <2.0.0'),
        requiredCapabilities: [],
        screenFormat: MiniProgramScreenFormats.mp,
        screenSchemaVersion: 1,
      );
  @override
  Future<Map<String, dynamic>> loadScreen({
    required String miniProgramId,
    required String version,
    required String screenId,
  }) async =>
      jsonDecode(
            jsonEncode(
              MpScreenDocument(screenId: screenId, root: root).toJson(),
            ),
          )
          as Map<String, dynamic>;
}

class _Backend implements MiniProgramBackendConnector {
  final calls = <MiniProgramBackendRequest>[];
  Completer<MiniProgramBackendResult>? gate;
  @override
  Future<MiniProgramBackendResult> call(
    MiniProgramBackendRequest request,
  ) async {
    calls.add(request);
    return gate?.future ??
        Future.value(
          MiniProgramBackendResult.success(data: {'orderId': 'demo-1'}),
        );
  }
}

class _Bridge implements HostBridge {
  @override
  Future<HostActionResult> callSecureApi(
    CallSecureApiActionPayload payload,
  ) async => HostActionResult.success();
  @override
  Future<HostActionResult> openNativeScreen(
    OpenNativeScreenActionPayload payload,
  ) async => HostActionResult.success();
  @override
  Future<HostActionResult> trackEvent(TrackEventActionPayload payload) async =>
      HostActionResult.success();
}

class _Vibration implements MiniProgramVibrationProvider {
  int calls = 0;
  @override
  Future<bool> trigger({
    required String miniProgramId,
    required MiniProgramVibrationEffect effect,
  }) async {
    calls++;
    return true;
  }
}
