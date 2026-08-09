import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  test(
    'share manager validates content and prevents concurrent requests',
    () async {
      final provider = _ShareProvider();
      final manager = MiniProgramShareManager(provider);
      final first = manager.open(
        miniProgramId: 'notes',
        title: 'Share note',
        text: 'Hello',
        url: Uri.parse('https://example.com/note'),
        mediaRefs: const <String>['media-1'],
      );
      await provider.started.future;

      await expectLater(
        manager.open(miniProgramId: 'notes', text: 'Again'),
        throwsA(
          isA<MiniProgramShareException>().having(
            (error) => error.errorCode,
            'errorCode',
            MiniProgramErrorCodes.shareRequestInProgress,
          ),
        ),
      );
      provider.complete();
      expect((await first).chooserOpened, isTrue);
      expect(provider.request?.miniProgramId, 'notes');
      expect(provider.request?.mediaRefs, const <String>['media-1']);
      manager.dispose();
    },
  );

  test('share manager rejects unsafe and empty content', () async {
    final manager = MiniProgramShareManager(_ImmediateShareProvider());
    await expectLater(
      manager.open(miniProgramId: 'notes'),
      throwsA(
        isA<MiniProgramShareException>().having(
          (error) => error.errorCode,
          'errorCode',
          MiniProgramErrorCodes.shareInvalidContent,
        ),
      ),
    );
    await expectLater(
      manager.open(
        miniProgramId: 'notes',
        url: Uri.parse('http://example.com'),
      ),
      throwsA(isA<MiniProgramShareException>()),
    );
    manager.dispose();
  });

  test('endpoint routing exposes host-accepted share policy', () {
    final source = EndpointRoutingMiniProgramSource(
      endpoints: <String, MiniProgramEndpoint>{
        'notes': MiniProgramEndpoint.public(
          apiBaseUri: Uri.parse('https://example.com/artifacts/notes/'),
          sharePolicy: const MiniProgramSharePolicy(
            enabled: true,
            allowMedia: false,
            maxMediaItems: 2,
          ),
        ),
      },
      deliveryContext: const MiniProgramDeliveryContext(
        hostApp: 'host',
        sdkVersion: '1.0.0',
        hostVersion: '1.0.0',
        capabilities: <String>{},
        platform: 'android',
        locale: 'en-US',
      ),
    );

    expect(source.sharePolicyFor('notes').enabled, isTrue);
    expect(source.sharePolicyFor('notes').allowMedia, isFalse);
    expect(source.sharePolicyFor('notes').maxMediaItems, 2);
    source.dispose();
  });
}

class _ShareProvider implements MiniProgramShareProvider {
  final started = Completer<void>();
  final completed = Completer<MiniProgramShareResult>();
  MiniProgramShareRequest? request;

  void complete() {
    if (!completed.isCompleted) {
      completed.complete(const MiniProgramShareResult(chooserOpened: true));
    }
  }

  @override
  Future<MiniProgramShareResult> open(MiniProgramShareRequest request) {
    this.request = request;
    if (!started.isCompleted) started.complete();
    return completed.future;
  }
}

class _ImmediateShareProvider implements MiniProgramShareProvider {
  @override
  Future<MiniProgramShareResult> open(MiniProgramShareRequest request) async {
    return const MiniProgramShareResult(chooserOpened: true);
  }
}
