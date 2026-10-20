part of '../mp_screen_renderer_test.dart';

Map<String, dynamic> _dateTimeScreen(MpNode field) => _jsonMap(
  MpProgram(
    screens: {'coupon_home': () => field},
  ).buildScreensJson()['coupon_home']!,
);

Future<BuildContext> _openDateTime(WidgetTester tester, String key) async {
  final field = find.byKey(ValueKey('mp-date-time-$key'));
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  return tester.element(
    find
        .byWidgetPredicate(
          (widget) =>
              widget is DatePickerDialog ||
              widget is TimePickerDialog ||
              widget is DateRangePickerDialog,
        )
        .first,
  );
}

Future<void> _selectDateTime(
  WidgetTester tester,
  String key,
  Object result,
) async {
  final context = await _openDateTime(tester, key);
  Navigator.of(context).pop(result);
  await tester.pumpAndSettle();
}

void _mpDateTimeTests() {
  group('date/time fields', () {
    test('date/time validator accepts all three pure-Dart builders', () {
      for (final field in [
        Mp.dateTime.dateField(
          stateKey: 'booking.date',
          label: 'Date',
          initialValue: '2026-10-25',
        ),
        Mp.dateTime.timeField(
          stateKey: 'booking.time',
          label: 'Time',
          initialValue: '14:30',
        ),
        Mp.dateTime.dateRangeField(
          stateKey: 'booking.stay',
          label: 'Stay',
          initialValue: {'start': '2026-10-25', 'end': '2026-10-28'},
        ),
      ]) {
        const MpScreenValidator().validate(
          _dateTimeScreen(field),
          expectedScreenId: 'coupon_home',
        );
      }
    });

    test(
      'date/time validator rejects unknown properties, invalid values and types',
      () {
        final invalidProps = <Map<String, dynamic>>[
          {'stateKey': 'booking.token'},
          {'stateKey': 'Booking.date'},
          {'name': 'bad.name'},
          {'label': ''},
          {'label': 'x' * 513},
          {'enabled': 'true'},
          {'required': 1},
          {'initialValue': null},
          {'initialValue': '2026-02-30'},
          {'initialValue': '{{state.date}}'},
          {'minDate': null},
          {'minDate': '2026-13-01'},
          {'minDate': '2027-01-01', 'maxDate': '2026-01-01'},
          {'maxDate': '2026-10-24', 'initialValue': '2026-10-25'},
          {'url': 'https://example.com'},
          {
            'onChanged': {'type': 'unknown', 'props': {}},
          },
        ];
        for (final changes in invalidProps) {
          final screen = _dateTimeScreen(
            Mp.dateTime.dateField(stateKey: 'booking.date', label: 'Date'),
          );
          (screen['root']['props'] as Map).addAll(changes);
          expect(
            () => const MpScreenValidator().validate(
              screen,
              expectedScreenId: 'coupon_home',
            ),
            throwsA(isA<MiniProgramRenderException>()),
            reason: '$changes',
          );
        }
        for (final field in [
          Mp.dateTime.timeField(stateKey: 'booking.time', label: 'Time'),
          Mp.dateTime.dateRangeField(stateKey: 'booking.stay', label: 'Stay'),
        ]) {
          final screen = _dateTimeScreen(field);
          screen['root']['props']['initialValue'] = field.type == 'timeField'
              ? '24:00'
              : {'start': '2026-10-28', 'end': '2026-10-25'};
          expect(
            () => const MpScreenValidator().validate(
              screen,
              expectedScreenId: 'coupon_home',
            ),
            throwsA(isA<MiniProgramRenderException>()),
          );
        }
        final children = _dateTimeScreen(
          Mp.dateTime.timeField(stateKey: 'booking.time', label: 'Time'),
        );
        children['root']['children'] = [Mp.text('Invalid child').toJson()];
        expect(
          () => const MpScreenValidator().validate(
            children,
            expectedScreenId: 'coupon_home',
          ),
          throwsA(isA<MiniProgramRenderException>()),
        );
      },
    );

    testWidgets(
      'date selection uses the real calendar and commits before onChanged',
      (tester) async {
        final state = MpStateManager();
        final backend = MiniProgramBackendStore();
        await tester.pumpWidget(
          _scopedApp(
            backendStore: backend,
            stateManager: state,
            screenJson: _dateTimeScreen(
              Mp.dateTime.dateField(
                stateKey: 'booking.date',
                label: 'Delivery date',
                initialValue: '2026-10-25',
                minDate: '2026-10-01',
                maxDate: '2026-10-31',
                onChanged: Mp.state.set(
                  'booking.confirmed',
                  '{{state.booking.date}}',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(state.get('booking.date'), '2026-10-25');
        final context = await _openDateTime(tester, 'booking.date');
        await tester.tap(find.text('26').last);
        await tester.tap(
          find.text(MaterialLocalizations.of(context).okButtonLabel),
        );
        await tester.pumpAndSettle();
        expect(state.get('booking.date'), '2026-10-26');
        expect(state.get('booking.confirmed'), '2026-10-26');
        expect(find.byType(DatePickerDialog), findsNothing);
        await tester.pumpWidget(const SizedBox());
        state.dispose();
        backend.dispose();
      },
    );

    testWidgets('time input uses 24-hour display and stores canonical HH:mm', (
      tester,
    ) async {
      final state = MpStateManager();
      final backend = MiniProgramBackendStore();
      await tester.pumpWidget(
        _scopedApp(
          backendStore: backend,
          stateManager: state,
          alwaysUse24HourFormat: true,
          screenJson: _dateTimeScreen(
            Mp.dateTime.timeField(
              stateKey: 'booking.time',
              label: 'Time',
              initialValue: '09:15',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final context = await _openDateTime(tester, 'booking.time');
      await tester.tap(
        find.byTooltip(
          MaterialLocalizations.of(context).inputTimeModeButtonLabel,
        ),
      );
      await tester.pumpAndSettle();
      final inputs = find.descendant(
        of: find.byType(TimePickerDialog),
        matching: find.byType(EditableText),
      );
      await tester.enterText(inputs.at(0), '14');
      await tester.enterText(inputs.at(1), '30');
      await tester.tap(
        find.text(MaterialLocalizations.of(context).okButtonLabel),
      );
      await tester.pumpAndSettle();
      expect(state.get('booking.time'), '14:30');
      expect(find.text('14:30'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
      backend.dispose();
    });

    testWidgets(
      'range calendar selects ordered endpoints and keeps same-day ranges valid',
      (tester) async {
        final state = MpStateManager();
        final backend = MiniProgramBackendStore();
        final screen = _dateTimeScreen(
          Mp.dateTime.dateRangeField(
            stateKey: 'booking.stay',
            label: 'Stay',
            minDate: '2026-10-01',
            maxDate: '2026-10-31',
            initialValue: {'start': '2026-10-25', 'end': '2026-10-28'},
          ),
        );
        await tester.pumpWidget(
          _scopedApp(
            backendStore: backend,
            stateManager: state,
            screenJson: screen,
          ),
        );
        await tester.pumpAndSettle();
        final context = await _openDateTime(tester, 'booking.stay');
        await tester.tap(find.text('26').last);
        await tester.tap(find.text('29').last);
        await tester.tap(
          find.text(MaterialLocalizations.of(context).saveButtonLabel),
        );
        await tester.pumpAndSettle();
        expect(state.get('booking.stay'), {
          'start': '2026-10-26',
          'end': '2026-10-29',
        });
        await _selectDateTime(
          tester,
          'booking.stay',
          DateTimeRange(
            start: DateTime(2026, 10, 27),
            end: DateTime(2026, 10, 27),
          ),
        );
        expect(state.get('booking.stay'), {
          'start': '2026-10-27',
          'end': '2026-10-27',
        });
        await tester.pumpWidget(const SizedBox());
        state.dispose();
        backend.dispose();
      },
    );

    for (final kind in ['date', 'time', 'range']) {
      testWidgets(
        '$kind cancellation and Back keep the selection and never call onChanged',
        (tester) async {
          final state = MpStateManager();
          final backend = MiniProgramBackendStore();
          final field = switch (kind) {
            'date' => Mp.dateTime.dateField(
              stateKey: 'booking.value',
              label: 'Date',
              initialValue: '2026-10-25',
              onChanged: Mp.state.set('changed', true),
            ),
            'time' => Mp.dateTime.timeField(
              stateKey: 'booking.value',
              label: 'Time',
              initialValue: '14:30',
              onChanged: Mp.state.set('changed', true),
            ),
            _ => Mp.dateTime.dateRangeField(
              stateKey: 'booking.value',
              label: 'Range',
              initialValue: {'start': '2026-10-25', 'end': '2026-10-28'},
              onChanged: Mp.state.set('changed', true),
            ),
          };
          await tester.pumpWidget(
            _scopedApp(
              backendStore: backend,
              stateManager: state,
              screenJson: _dateTimeScreen(field),
            ),
          );
          await tester.pumpAndSettle();
          final previous = state.get<Object?>('booking.value');
          final context = await _openDateTime(tester, 'booking.value');
          Navigator.of(context).pop();
          await tester.pumpAndSettle();
          expect(state.get('booking.value'), previous);
          await _openDateTime(tester, 'booking.value');
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(state.get('booking.value'), previous);
          expect(state.contains('changed'), isFalse);
          await tester.pumpWidget(const SizedBox());
          state.dispose();
          backend.dispose();
        },
      );
    }

    testWidgets('empty cancellation leaves the state key absent', (
      tester,
    ) async {
      final state = MpStateManager();
      final backend = MiniProgramBackendStore();
      await tester.pumpWidget(
        _scopedApp(
          backendStore: backend,
          stateManager: state,
          screenJson: _dateTimeScreen(
            Mp.dateTime.dateField(stateKey: 'booking.date', label: 'Date'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final context = await _openDateTime(tester, 'booking.date');
      Navigator.of(context).pop();
      await tester.pumpAndSettle();
      expect(state.contains('booking.date'), isFalse);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
      backend.dispose();
    });

    testWidgets(
      'existing state wins over initial values and external changes update the field',
      (tester) async {
        final state = MpStateManager()..set('booking.date', '2026-10-28');
        final backend = MiniProgramBackendStore();
        await tester.pumpWidget(
          _scopedApp(
            backendStore: backend,
            stateManager: state,
            screenJson: _dateTimeScreen(
              Mp.dateTime.dateField(
                stateKey: 'booking.date',
                label: 'Date',
                initialValue: '2026-10-25',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        var context = await _openDateTime(tester, 'booking.date');
        expect(
          tester
              .widget<DatePickerDialog>(find.byType(DatePickerDialog))
              .initialDate,
          DateTime(2026, 10, 28),
        );
        state.set('booking.date', '2026-10-29');
        await tester.pumpAndSettle();
        expect(find.byType(DatePickerDialog), findsNothing);
        context = await _openDateTime(tester, 'booking.date');
        expect(
          tester
              .widget<DatePickerDialog>(find.byType(DatePickerDialog))
              .initialDate,
          DateTime(2026, 10, 29),
        );
        Navigator.of(context).pop();
        await tester.pumpAndSettle();
        state.set('booking.date', '2026-02-30');
        await tester.pumpAndSettle();
        expect(find.text('Choose a valid date or time.'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        state.dispose();
        backend.dispose();
      },
    );

    testWidgets(
      'required fields block submission and selections enter the existing form body',
      (tester) async {
        final state = MpStateManager();
        final backend = MiniProgramBackendStore();
        final connector = _RecordingBackendConnector(
          responses: [
            MiniProgramBackendResult.success(
              endpoint: '/book',
              method: 'POST',
              data: const {'saved': true},
            ),
          ],
        );
        final screen = _dateTimeScreen(
          Mp.form(
            children: [
              Mp.dateTime.dateField(
                stateKey: 'booking.date',
                label: 'Date',
                required: true,
              ),
              Mp.dateTime.timeField(
                stateKey: 'booking.time',
                label: 'Time',
                initialValue: '14:30',
              ),
              Mp.dateTime.dateRangeField(
                stateKey: 'booking.stay',
                label: 'Stay',
                initialValue: {'start': '2026-10-25', 'end': '2026-10-28'},
              ),
              Mp.formSubmit(label: 'Book', endpoint: '/book'),
            ],
          ),
        );
        await tester.pumpWidget(
          _scopedApp(
            backendStore: backend,
            stateManager: state,
            backendConnector: connector,
            screenJson: screen,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Book'));
        await tester.pumpAndSettle();
        expect(find.text('This field is required.'), findsOneWidget);
        expect(connector.calls, isEmpty);
        await _selectDateTime(tester, 'booking.date', DateTime(2026, 10, 25));
        await tester.tap(find.text('Book'));
        await tester.pumpAndSettle();
        expect(connector.calls.single.body, {
          'date': '2026-10-25',
          'time': '14:30',
          'stay': {'start': '2026-10-25', 'end': '2026-10-28'},
        });
        await tester.pumpWidget(const SizedBox());
        state.dispose();
        backend.dispose();
      },
    );

    testWidgets('disabled and hidden fields cannot open pickers', (
      tester,
    ) async {
      final state = MpStateManager();
      final backend = MiniProgramBackendStore();
      for (final hidden in [false, true]) {
        await tester.pumpWidget(
          _scopedApp(
            backendStore: backend,
            stateManager: state,
            isForeground: !hidden,
            screenJson: _dateTimeScreen(
              Mp.dateTime.dateField(
                stateKey: 'booking.date',
                label: 'Date',
                enabled: hidden,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('mp-date-time-booking.date')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(DatePickerDialog), findsNothing);
      }
      await tester.pumpWidget(const SizedBox());
      state.dispose();
      backend.dispose();
    });

    for (final change in [
      'app',
      'state',
      'key',
      'bounds',
      'disabled',
      'hidden',
    ]) {
      testWidgets(
        'changing $change dismisses only the owned picker and ignores its result',
        (tester) async {
          final state = MpStateManager()..set('booking.date', '2026-10-25');
          final nextState = MpStateManager();
          final backend = MiniProgramBackendStore();
          Widget app({bool changed = false}) => _scopedApp(
            backendStore: backend,
            stateManager: changed && change == 'state' ? nextState : state,
            miniProgramId: changed && change == 'app' ? 'other' : 'coupon',
            isForeground: !(changed && change == 'hidden'),
            screenJson: _dateTimeScreen(
              Mp.dateTime.dateField(
                stateKey: changed && change == 'key'
                    ? 'booking.other'
                    : 'booking.date',
                label: 'Date',
                maxDate: changed && change == 'bounds'
                    ? '2026-10-26'
                    : '2100-12-31',
                enabled: !(changed && change == 'disabled'),
                onChanged: Mp.state.set('changed', true),
              ),
            ),
          );
          await tester.pumpWidget(app());
          await tester.pumpAndSettle();
          await _openDateTime(tester, 'booking.date');
          await tester.pumpWidget(app(changed: true));
          await tester.pumpAndSettle();
          expect(find.byType(DatePickerDialog), findsNothing);
          expect(state.get('booking.date'), '2026-10-25');
          expect(state.contains('changed'), isFalse);
          expect(nextState.contains('changed'), isFalse);
          await tester.pumpWidget(const SizedBox());
          state.dispose();
          nextState.dispose();
          backend.dispose();
        },
      );
    }

    testWidgets(
      'backgrounding cancels an open picker and retains confirmed values on resume',
      (tester) async {
        final state = MpStateManager()..set('booking.date', '2026-10-25');
        final backend = MiniProgramBackendStore();
        await tester.pumpWidget(
          _scopedApp(
            backendStore: backend,
            stateManager: state,
            screenJson: _dateTimeScreen(
              Mp.dateTime.dateField(stateKey: 'booking.date', label: 'Date'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await _openDateTime(tester, 'booking.date');
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pumpAndSettle();
        expect(state.get('booking.date'), '2026-10-25');
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(find.byType(DatePickerDialog), findsNothing);
        final context = await _openDateTime(tester, 'booking.date');
        expect(
          tester
              .widget<DatePickerDialog>(find.byType(DatePickerDialog))
              .initialDate,
          DateTime(2026, 10, 25),
        );
        Navigator.of(context).pop();
        await tester.pumpAndSettle();
        expect(state.get('booking.date'), '2026-10-25');
        await tester.pumpWidget(const SizedBox());
        state.dispose();
        backend.dispose();
      },
    );

    testWidgets(
      'quota rejection preserves form/state and does not run onChanged',
      (tester) async {
        final state = MpStateManager(
          policy: const MiniProgramLiveStatePolicy(
            maxBytes: 128,
            maxValueBytes: 8,
          ),
        );
        final backend = MiniProgramBackendStore();
        await tester.pumpWidget(
          _scopedApp(
            backendStore: backend,
            stateManager: state,
            screenJson: _dateTimeScreen(
              Mp.form(
                children: [
                  Mp.dateTime.dateField(
                    stateKey: 'booking.date',
                    label: 'Date',
                    onChanged: Mp.state.set('changed', true),
                  ),
                  Mp.text('Value: {{form.date}}'),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await _selectDateTime(tester, 'booking.date', DateTime(2026, 10, 25));
        expect(state.contains('booking.date'), isFalse);
        expect(state.contains('changed'), isFalse);
        expect(find.text('Value: '), findsOneWidget);
        expect(find.text('Unable to save this selection.'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        state.dispose();
        backend.dispose();
      },
    );

    testWidgets(
      'a covered picker is removed without popping the newer host route',
      (tester) async {
        final state = MpStateManager();
        final backend = MiniProgramBackendStore();
        await tester.pumpWidget(
          _scopedApp(
            backendStore: backend,
            stateManager: state,
            screenJson: _dateTimeScreen(
              Mp.dateTime.dateField(stateKey: 'booking.date', label: 'Date'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final context = await _openDateTime(tester, 'booking.date');
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Host chat')),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Host chat'), findsOneWidget);
        expect(
          find.byType(DatePickerDialog, skipOffstage: false),
          findsNothing,
        );
        expect(state.contains('booking.date'), isFalse);
        await tester.pumpWidget(const SizedBox());
        state.dispose();
        backend.dispose();
      },
    );

    testWidgets(
      'disposing a field with a picker open leaves no pending write',
      (tester) async {
        final state = MpStateManager();
        final backend = MiniProgramBackendStore();
        await tester.pumpWidget(
          _scopedApp(
            backendStore: backend,
            stateManager: state,
            screenJson: _dateTimeScreen(
              Mp.dateTime.dateField(stateKey: 'booking.date', label: 'Date'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await _openDateTime(tester, 'booking.date');
        await tester.pumpWidget(const MaterialApp(home: Text('Host')));
        await tester.pumpAndSettle();
        expect(state.contains('booking.date'), isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        state.dispose();
        backend.dispose();
      },
    );
  });
}
