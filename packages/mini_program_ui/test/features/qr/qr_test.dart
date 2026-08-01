import 'package:mini_program_ui/mini_program_ui.dart';
import 'package:test/test.dart';

void main() {
  test('QR generator serializes deterministic presentation options', () {
    expect(
      Mp.qr
          .generate(
            value: 'https://example.com',
            size: 240,
            padding: 16,
            foregroundColor: '#101820',
            backgroundColor: '#FFFFFF',
            errorCorrection: 'high',
            semanticLabel: 'Example QR code',
          )
          .toJson(),
      <String, Object?>{
        'type': 'qrCode',
        'props': <String, Object?>{
          'backgroundColor': '#FFFFFF',
          'errorCorrection': 'high',
          'foregroundColor': '#101820',
          'padding': 16.0,
          'semanticLabel': 'Example QR code',
          'size': 240.0,
          'value': 'https://example.com',
        },
        'children': <Object?>[],
      },
    );
  });

  test('QR scan serializes accepted runtime options', () {
    expect(
      Mp.qr
          .scan(
            allowTorch: false,
            timeout: const Duration(seconds: 20),
            targetState: 'qr.result',
            statusState: 'qr.status',
            errorState: 'qr.error',
            requestId: 'scan-one',
          )
          .toJson(),
      <String, Object?>{
        'type': 'qr.scan',
        'props': <String, Object?>{
          'allowTorch': false,
          'errorState': 'qr.error',
          'requestId': 'scan-one',
          'statusState': 'qr.status',
          'targetState': 'qr.result',
          'timeoutMs': 20000,
        },
      },
    );
  });

  test('QR APIs reject unsafe bounds and state keys', () {
    expect(() => Mp.qr.generate(value: 'value', size: 95), throwsArgumentError);
    expect(
      () => Mp.qr.generate(value: 'value', size: 100, padding: 50),
      throwsArgumentError,
    );
    expect(
      () => Mp.qr.generate(value: 'value', errorCorrection: 'maximum'),
      throwsArgumentError,
    );
    expect(
      () => Mp.qr.scan(
        timeout: const Duration(milliseconds: 999),
        targetState: 'qr.result',
      ),
      throwsArgumentError,
    );
    expect(() => Mp.qr.scan(targetState: 'qr..result'), throwsArgumentError);
  });
}
