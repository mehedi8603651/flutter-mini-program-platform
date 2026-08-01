import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:test/test.dart';

void main() {
  test('QR scan result round-trips inert structured data', () {
    final result = MiniProgramQrScanResult(
      rawValue: 'https://example.com/path',
      valueType: 'url',
      scannedAtUtc: DateTime.utc(2026, 8, 1, 10, 30),
    );

    expect(
      MiniProgramQrScanResult.fromJson(result.toJson()).toJson(),
      result.toJson(),
    );
    expect(result.toJson(), <String, dynamic>{
      'rawValue': 'https://example.com/path',
      'format': 'qr',
      'valueType': 'url',
      'scannedAtUtc': '2026-08-01T10:30:00.000Z',
    });
  });

  test('QR contracts reject invalid formats, values, and timestamps', () {
    expect(
      () => MiniProgramQrScanResult.fromJson(const <String, dynamic>{
        'rawValue': 'value',
        'format': 'aztec',
        'valueType': 'text',
        'scannedAtUtc': '2026-08-01T10:30:00.000Z',
      }),
      throwsFormatException,
    );
    expect(
      () => MiniProgramQrScanResult(
        rawValue: '',
        valueType: 'text',
        scannedAtUtc: DateTime.utc(2026),
      ),
      throwsFormatException,
    );
    expect(
      () => MiniProgramQrScanResult(
        rawValue: 'value',
        valueType: 'binary',
        scannedAtUtc: DateTime.utc(2026),
      ),
      throwsFormatException,
    );
    expect(
      () => MiniProgramQrScanResult(
        rawValue: 'value',
        valueType: 'text',
        scannedAtUtc: DateTime(2026),
      ),
      throwsFormatException,
    );
  });

  test('QR action, capability, and errors are stable', () {
    expect(ActionNames.qrScan, 'qr.scan');
    expect(CapabilityIds.qrScanner, 'qr.scanner');
    expect(CapabilityIds.standardValues, contains(CapabilityIds.qrScanner));
    expect(MiniProgramErrorCodes.qrNotAccepted, 'qr_not_accepted');
    expect(MiniProgramErrorCodes.qrScanCancelled, 'qr_scan_cancelled');
    expect(
      MiniProgramErrorCodes.qrUserGestureRequired,
      'qr_user_gesture_required',
    );
  });
}
