import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  test('nested brightness scopes restore the previous request', () async {
    final provider = _RecordingBrightnessProvider();
    final manager = MiniProgramDisplayBrightnessManager(provider);
    final outer = Object();
    final inner = Object();

    await manager.acquire(miniProgramId: 'friends', owner: outer, level: 0.7);
    await manager.acquire(miniProgramId: 'friends', owner: inner, level: 1);
    await manager.release(inner);
    await manager.release(outer);

    expect(provider.operations, <String>[
      'set:0.7',
      'set:1.0',
      'set:0.7',
      'restore',
    ]);
    await manager.dispose();
  });

  test('foreground suspension restores then reapplies brightness', () async {
    final provider = _RecordingBrightnessProvider();
    final manager = MiniProgramDisplayBrightnessManager(provider);

    await manager.acquire(
      miniProgramId: 'friends',
      owner: Object(),
      level: 0.9,
    );
    await manager.suspend();
    await manager.resume();

    expect(provider.operations, <String>['set:0.9', 'restore', 'set:0.9']);
    await manager.dispose();
    expect(provider.operations.last, 'restore');
  });

  test('invalid brightness level has a stable failure', () async {
    final manager = MiniProgramDisplayBrightnessManager(
      _RecordingBrightnessProvider(),
    );

    await expectLater(
      manager.acquire(miniProgramId: 'friends', owner: Object(), level: 0),
      throwsA(
        isA<MiniProgramDisplayBrightnessException>().having(
          (error) => error.errorCode,
          'errorCode',
          MiniProgramErrorCodes.displayBrightnessInvalidLevel,
        ),
      ),
    );
    await manager.dispose();
  });
}

class _RecordingBrightnessProvider
    implements MiniProgramDisplayBrightnessProvider {
  final List<String> operations = <String>[];

  @override
  Future<void> restoreBrightness() async => operations.add('restore');

  @override
  Future<void> setBrightness(double level) async =>
      operations.add('set:${level.toStringAsFixed(1)}');
}
