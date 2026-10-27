import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mp_only_host/phone_ai/phone_ai_goal_sheet.dart';
import 'package:mp_only_host/phone_ai/phone_ai_model.dart';
import 'package:mp_only_host/phone_ai/phone_ai_runner.dart';
import 'package:mp_only_host/phone_ai/phone_ai_test_workspace.dart';

void main() {
  testWidgets(
    'empty goals are disabled and the sheet fits a narrow screen with large text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          ),
          home: const Scaffold(
            body: PhoneAiGoalSheet(
              initialGoal: '',
              status: 'Needs your input',
              message: 'Which tea would you like?',
              history: [],
              canContinue: true,
              decisions: 2,
              tokens: 200,
              costUsd: 0.0001,
              maxDecisions: 16,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final start = find.widgetWithText(FilledButton, 'Start AI');
      expect(tester.widget<FilledButton>(start).onPressed, isNull);
      await tester.enterText(find.byType(TextField), 'Choose tea');
      await tester.pump();
      expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
      await tester.ensureVisible(start);
      expect(start.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'changing the mini-program owner cancels its in-flight model reply',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final navigator = GlobalKey<NavigatorState>();
      final response = Completer<PhoneAiReply>();
      final model = _Model(response.future);
      var interactions = 0;
      Future<Map<String, dynamic>> dispatch(
        Map<String, dynamic> request,
      ) async {
        if (request['method'] == 'interact') interactions++;
        return _view('old');
      }

      Widget app(String id) => MaterialApp(
        navigatorKey: navigator,
        builder: (_, child) => PhoneAiTestWorkspace(
          appId: id,
          dispatch: dispatch,
          navigatorKey: navigator,
          modelFactory: () => model,
          limits: const PhoneAiLimits(
            observationInterval: Duration.zero,
            actionInterval: Duration.zero,
          ),
          child: child!,
        ),
        home: const Scaffold(body: Text('Mini-program body')),
      );
      await tester.pumpWidget(app('old'));
      await _start(tester);
      expect(model.calls, 1);
      await tester.pumpWidget(app('new'));
      await tester.pump();
      expect(model.closed, isTrue);
      response.complete(
        PhoneAiReply(decision: {'action': 'tap', 'targetId': 'n1'}),
      );
      await tester.pumpAndSettle();
      expect(interactions, 0);
      expect(
        tester
            .widget<Semantics>(find.byKey(const ValueKey('host_ai_bubble')))
            .properties
            .value,
        'Ready',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a goal sheet opened for an old owner cannot start the new owner',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final navigator = GlobalKey<NavigatorState>();
      final model = _Model(
        Future.value(
          PhoneAiReply(
            decision: {'action': 'done', 'message': 'Visible result.'},
          ),
        ),
      );
      Future<Map<String, dynamic>> dispatch(
        Map<String, dynamic> request,
      ) async => _view('old');
      Widget app(String id) => MaterialApp(
        navigatorKey: navigator,
        builder: (_, child) => PhoneAiTestWorkspace(
          appId: id,
          dispatch: dispatch,
          navigatorKey: navigator,
          modelFactory: () => model,
          child: child!,
        ),
        home: const Scaffold(body: Text('Mini-program body')),
      );
      await tester.pumpWidget(app('old'));
      await tester.tap(find.byKey(const ValueKey('host_ai_bubble')));
      await tester.pumpAndSettle();
      await tester.pumpWidget(app('new'));
      await tester.pumpAndSettle();
      expect(find.byType(PhoneAiGoalSheet), findsNothing);
      expect(model.calls, 0);
      expect(
        tester
            .widget<Semantics>(find.byKey(const ValueKey('host_ai_bubble')))
            .properties
            .value,
        'Ready',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'manual takeover offers Continue with the original editable goal',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final navigator = GlobalKey<NavigatorState>();
      final delayed = Completer<PhoneAiReply>();
      final model = _Model(delayed.future);
      Future<Map<String, dynamic>> dispatch(
        Map<String, dynamic> request,
      ) async => _view('tea');
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          builder: (_, child) => PhoneAiTestWorkspace(
            appId: 'tea',
            dispatch: dispatch,
            navigatorKey: navigator,
            modelFactory: () => model,
            limits: const PhoneAiLimits(
              observationInterval: Duration.zero,
              actionInterval: Duration.zero,
            ),
            child: child!,
          ),
          home: const Scaffold(body: Center(child: Text('Mini-program body'))),
        ),
      );
      await _start(tester);
      await tester.tap(find.text('Mini-program body'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('host_ai_bubble')).hitTestable(),
        findsOneWidget,
      );
      expect(model.closed, isTrue);
      await tester.tap(find.byKey(const ValueKey('host_ai_bubble')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isNotEmpty,
      );
      expect(
        find.textContaining('Continue will read the current screen'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Minimize'));
      await tester.tap(find.text('Minimize'));
      await tester.pumpAndSettle();
      delayed.complete(
        PhoneAiReply(decision: {'action': 'tap', 'targetId': 'n1'}),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('minimizing and Android Back preserve the edited goal draft', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    final model = _Model(Completer<PhoneAiReply>().future);
    await _mount(tester, navigator, model);
    final content = tester.getRect(find.text('Mini-program body'));
    await tester.tap(find.byKey(const ValueKey('host_ai_bubble')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'Find my vegetarian booking',
    );
    await tester.ensureVisible(find.text('Minimize'));
    await tester.tap(find.text('Minimize'));
    await tester.pumpAndSettle();
    expect(find.byType(PhoneAiGoalSheet), findsNothing);
    expect(model.calls, 0);
    expect(tester.getRect(find.text('Mini-program body')), content);
    await tester.tap(find.byKey(const ValueKey('host_ai_bubble')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Find my vegetarian booking',
    );
    await tester.enterText(find.byType(TextField), 'Choose green tea');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('host_ai_bubble')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Choose green tea',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('dragging keeps a run active and opening its panel pauses it', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    final delayed = Completer<PhoneAiReply>();
    final model = _Model(delayed.future);
    await _mount(tester, navigator, model);
    await _start(tester);
    expect(model.calls, 1);
    await tester.drag(
      find.byKey(const ValueKey('host_ai_bubble')),
      const Offset(-500, -80),
    );
    await tester.pumpAndSettle();
    expect(model.closed, isFalse);
    expect(
      find.byKey(const ValueKey('host_ai_bubble_stop')).hitTestable(),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('host_ai_bubble')));
    await tester.pumpAndSettle();
    expect(model.closed, isTrue);
    expect(find.text('Continue AI'), findsOneWidget);
    expect(find.text('Paused — assistant panel opened'), findsOneWidget);
    await tester.ensureVisible(find.text('Minimize'));
    await tester.tap(find.text('Minimize'));
    await tester.pumpAndSettle();
    delayed.complete(
      PhoneAiReply(decision: {'action': 'tap', 'targetId': 'n1'}),
    );
    await tester.pump();
    expect(model.calls, 1);
    expect(
      find.byKey(const ValueKey('host_ai_bubble_stop')).hitTestable(),
      findsOneWidget,
    );
    expect(find.text('Paused - tap AI'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('host_ai_bubble_stop')));
    await tester.pumpAndSettle();
    expect(find.text('Task cancelled'), findsOneWidget);
    expect(find.byKey(const ValueKey('host_ai_bubble_stop')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('host_ai_bubble')));
    await tester.pumpAndSettle();
    expect(find.text('Start AI'), findsOneWidget);
    expect(find.text('Continue AI'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a second goal can be cancelled after the model pauses it', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final navigator = GlobalKey<NavigatorState>();
    final replies = [
      _Model(
        Future.value(
          PhoneAiReply(
            decision: {
              'action': 'done',
              'message': 'The first result is visible.',
            },
          ),
        ),
      ),
      _Model(
        Future.value(
          PhoneAiReply(
            decision: {
              'action': 'blocked',
              'message': 'This screen has no matching item.',
            },
          ),
        ),
      ),
      _Model(Completer<PhoneAiReply>().future),
    ];
    var factories = 0;
    PhoneAiModel modelFactory() => replies[factories++];
    Future<Map<String, dynamic>> dispatch(Map<String, dynamic> _) async =>
        _view('tea');
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        builder: (_, child) => PhoneAiTestWorkspace(
          appId: 'tea',
          initialGoal: 'First goal',
          dispatch: dispatch,
          navigatorKey: navigator,
          modelFactory: modelFactory,
          limits: const PhoneAiLimits(
            observationInterval: Duration.zero,
            actionInterval: Duration.zero,
          ),
          child: child!,
        ),
        home: const Scaffold(body: Text('Mini-program body')),
      ),
    );
    await _start(tester);
    expect(find.text('Done - tap AI'), findsOneWidget);
    expect(find.byKey(const ValueKey('host_ai_bubble_stop')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('host_ai_bubble')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Second goal');
    await tester.tap(find.text('Start AI'));
    await tester.pumpAndSettle();
    expect(factories, 2);
    expect(find.text('Paused - tap AI'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('host_ai_bubble_stop')).hitTestable(),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('host_ai_bubble')));
    await tester.pumpAndSettle();
    expect(find.text('This screen has no matching item.'), findsOneWidget);
    expect(find.text('Continue AI'), findsOneWidget);
    await tester.ensureVisible(find.text('Cancel task'));
    await tester.tap(find.text('Cancel task'));
    await tester.pumpAndSettle();
    expect(find.byType(PhoneAiGoalSheet), findsNothing);
    expect(find.text('Task cancelled'), findsOneWidget);
    expect(find.byKey(const ValueKey('host_ai_bubble_stop')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('host_ai_bubble')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Second goal',
    );
    expect(find.text('Start AI'), findsOneWidget);
    await tester.tap(find.byTooltip('Back to mini-program'));
    await tester.pumpAndSettle();
    await _start(tester);
    expect(factories, 3);
    expect(find.text('AI working'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('host_ai_bubble_stop')));
    await tester.pumpAndSettle();
    expect(replies.last.closed, isTrue);
    expect(find.text('Task cancelled'), findsOneWidget);
    expect(find.text('Mini-program body'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving the foreground during dismissal cancels queued Start', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    final model = _Model(Completer<PhoneAiReply>().future);
    await _mount(tester, navigator, model);
    await tester.tap(find.byKey(const ValueKey('host_ai_bubble')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start AI'));
    await tester.tap(find.text('Start AI'));
    await tester.pump(const Duration(milliseconds: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(model.calls, 0);
    expect(find.byKey(const ValueKey('host_ai_bubble_stop')), findsNothing);
    expect(
      find.byKey(const ValueKey('host_ai_bubble')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _mount(
  WidgetTester tester,
  GlobalKey<NavigatorState> navigator,
  PhoneAiModel model,
) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigator,
      builder: (_, child) => PhoneAiTestWorkspace(
        appId: 'tea',
        dispatch: (_) async => _view('tea'),
        navigatorKey: navigator,
        modelFactory: () => model,
        limits: const PhoneAiLimits(
          observationInterval: Duration.zero,
          actionInterval: Duration.zero,
        ),
        child: child!,
      ),
      home: const Scaffold(body: Center(child: Text('Mini-program body'))),
    ),
  );
}

Future<void> _start(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('host_ai_bubble')));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Start AI'));
  await tester.tap(find.text('Start AI'));
  await tester.pumpAndSettle();
  await tester.pump();
}

Map<String, dynamic> _view(String appId) => {
  'appId': appId,
  'sessionId': 'session',
  'screenId': 'home',
  'revision': 1,
  'status': 'ready',
  'canGoBack': false,
  'nodes': [
    {
      'id': 'n1',
      'role': 'button',
      'label': 'Open details',
      'actions': ['tap'],
    },
  ],
};

class _Model implements PhoneAiModel {
  _Model(this.response);
  final Future<PhoneAiReply> response;
  int calls = 0;
  bool closed = false;
  @override
  Future<PhoneAiReply> decide({
    required String goal,
    required Map<String, dynamic> snapshot,
    required List<String> progress,
  }) {
    calls++;
    return response;
  }

  @override
  void close() => closed = true;
}
