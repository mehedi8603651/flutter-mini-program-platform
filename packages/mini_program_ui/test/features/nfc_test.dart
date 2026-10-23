import 'dart:convert';

import 'package:mini_program_ui/mini_program_ui.dart';
import 'package:test/test.dart';

void main() {
  test('NFC authoring produces deterministic pure-Dart actions', () {
    const MpNfcActions api = Mp.nfc;
    final read = api.read(
      targetState: 'tag.data',
      statusState: 'tag.status',
      errorState: 'tag.error',
    );
    expect(read.toJson(), {
      'type': 'nfc.read',
      'props': {
        'timeoutMs': 15000,
        'targetState': 'tag.data',
        'statusState': 'tag.status',
        'errorState': 'tag.error',
      },
    });
    expect(
      jsonEncode(read.toJson()),
      jsonEncode(
        api
            .read(
              targetState: 'tag.data',
              statusState: 'tag.status',
              errorState: 'tag.error',
            )
            .toJson(),
      ),
    );
    expect(api.cancel().toJson()['type'], 'nfc.cancel');
    expect(api.getState(targetState: 'availability').toJson()['props'], {
      'targetState': 'availability',
    });
  });
  test(
    'NFC authoring rejects invalid keys, overlapping paths and timeouts',
    () {
      for (final build in <Object Function()>[
        () => Mp.nfc.read(targetState: ''),
        () => Mp.nfc.read(targetState: 'tag', statusState: 'tag.status'),
        () => Mp.nfc.getState(targetState: 'data', errorState: 'data'),
        () => Mp.nfc.read(targetState: 'tag', timeoutMs: 30001),
        () => Mp.nfc.read(targetState: 'tag', timeoutMs: 0),
      ]) {
        expect(build, throwsA(anything));
      }
    },
  );
}
