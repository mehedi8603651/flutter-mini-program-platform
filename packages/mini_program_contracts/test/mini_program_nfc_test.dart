import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:test/test.dart';

void main() {
  test(
    'NFC HTTPS records preserve valid percent-encoded international paths',
    () {
      const uri = 'https://shop.example/%E5%BA%97%E9%93%BA';
      expect(
        MiniProgramNfc.result('nfc.read', {
          'records': [
            {'type': 'uri', 'uri': uri},
          ],
        }),
        {
          'records': [
            {'type': 'uri', 'uri': uri},
          ],
        },
      );
    },
  );
  test('NFC has canonical actions and an optional read capability', () {
    expect(MiniProgramNfc.actions, {
      ActionNames.nfcGetState,
      ActionNames.nfcRead,
      ActionNames.nfcCancel,
    });
    expect(CapabilityIds.isValid(CapabilityIds.nfcRead), isTrue);
    expect(MiniProgramErrorCodes.nfcRequestCancelled, 'nfc_request_cancelled');
    expect(MiniProgramNfc.arguments('nfc.read', {}), {'timeoutMs': 15000});
    expect(MiniProgramNfc.arguments('nfc.cancel', {}), isEmpty);
  });
  test(
    'NFC arguments reject unknown properties and unbounded or bound timeouts',
    () {
      for (final args in [
        {'timeoutMs': 0},
        {'timeoutMs': 30001},
        {'timeoutMs': 1500.0},
        {'timeoutMs': '{{state.timeout}}'},
        {'tagId': 'secret'},
        {'maxRecords': 64},
      ]) {
        expect(
          () => MiniProgramNfc.arguments('nfc.read', args),
          throwsFormatException,
        );
      }
      expect(
        () => MiniProgramNfc.arguments('nfc.write', {}),
        throwsFormatException,
      );
      expect(
        () => MiniProgramNfc.arguments('nfc.getState', {'timeoutMs': 15000}),
        throwsFormatException,
      );
    },
  );
  test('NDEF results contain bounded text and inert HTTPS values only', () {
    final result = MiniProgramNfc.result('nfc.read', {
      'nativeTagId': 'never exported',
      'records': [
        {
          'type': 'text',
          'text': '店铺\nProduct 12',
          'language': 'zh-CN',
          'bytes': [1, 2],
        },
        {
          'type': 'uri',
          'uri': 'https://shop.example/products/12',
          'intent': 'never exported',
        },
      ],
    });
    expect(result, {
      'records': [
        {'type': 'text', 'text': '店铺\nProduct 12', 'language': 'zh-CN'},
        {'type': 'uri', 'uri': 'https://shop.example/products/12'},
      ],
    });
  });
  test(
    'NFC rejects unsafe URI records, malformed text, and unsupported records',
    () {
      for (final record in [
        for (final uri in [
          'http://example.com',
          'tel:123',
          'intent://x',
          'https://u:p@example.com',
          'https://example.com/a b',
          'https://example.com/%00',
          'https://example.com/\\x',
          'https:///',
        ])
          {'type': 'uri', 'uri': uri},
        {'type': 'text', 'text': 'bad\u0000text', 'language': 'en'},
        {'type': 'text', 'text': '\ud800', 'language': 'en'},
        {'type': 'text', 'text': 'ok', 'language': 'a b'},
        {'type': 'text', 'text': 123, 'language': 'en'},
        {
          'type': 'mime',
          'bytes': [1],
        },
      ]) {
        expect(
          () => MiniProgramNfc.result('nfc.read', {
            'records': [record],
          }),
          throwsFormatException,
        );
      }
    },
  );
  test('NFC enforces accepted types, UTF-8 byte totals, and record counts', () {
    final record = {'type': 'text', 'text': '汉字', 'language': 'zh'};
    expect(
      () => MiniProgramNfc.result('nfc.read', {
        'records': [record],
      }, byteLimit: 7),
      throwsFormatException,
    );
    expect(
      MiniProgramNfc.result('nfc.read', {
        'records': [record],
      }, byteLimit: 8),
      isNotEmpty,
    );
    expect(
      () => MiniProgramNfc.result(
        'nfc.read',
        {
          'records': [record],
        },
        allowedRecordTypes: ['uri'],
      ),
      throwsFormatException,
    );
    expect(
      () => MiniProgramNfc.result('nfc.read', {
        'records': [record, record],
      }, recordLimit: 1),
      throwsFormatException,
    );
    expect(
      () => MiniProgramNfc.result('nfc.read', {'records': []}),
      throwsFormatException,
    );
    expect(
      () => MiniProgramNfc.result('nfc.read', {
        'records': [
          {'type': 'text', 'text': 'x' * 4097, 'language': ''},
        ],
      }),
      throwsFormatException,
    );
    for (final types in [
      [],
      ['unknown'],
      ['text', 'text', 'uri'],
    ]) {
      expect(() => MiniProgramNfc.recordTypes(types), throwsFormatException);
    }
  });
  test(
    'NFC availability rejects contradictory or missing values and strips extras',
    () {
      expect(
        MiniProgramNfc.result('nfc.getState', {
          'supported': false,
          'enabled': false,
          'native': 'ignored',
        }),
        {'supported': false, 'enabled': false},
      );
      expect(
        () => MiniProgramNfc.result('nfc.getState', {
          'supported': false,
          'enabled': true,
        }),
        throwsFormatException,
      );
      expect(
        () => MiniProgramNfc.result('nfc.getState', {}),
        throwsFormatException,
      );
    },
  );
}
