import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_contracts/mini_program_contracts.dart';
import 'package:mini_program_sdk/mini_program_sdk.dart';

void main() {
  test('endpoint gallery policy is app-scoped and unknown apps are denied', () {
    final source = EndpointRoutingMiniProgramSource(
      deliveryContext: const MiniProgramDeliveryContext(
        hostApp: 'host',
        sdkVersion: '1.0.0',
        hostVersion: '1.0.0',
        capabilities: {},
        platform: 'android',
        locale: 'en-US',
      ),
      endpoints: {
        'photos': MiniProgramEndpoint.public(
          apiBaseUri: Uri.parse('https://static.example.com/photos/'),
          galleryPolicy: const MiniProgramGalleryPolicy(
            enabled: true,
            maxImages: 2,
          ),
        ),
        'other': MiniProgramEndpoint.public(
          apiBaseUri: Uri.parse('https://static.example.com/other/'),
        ),
      },
    );
    expect(source.galleryPolicyFor('photos').maxImages, 2);
    expect(source.galleryPolicyFor('photos').enabled, isTrue);
    expect(source.galleryPolicyFor('other').enabled, isFalse);
    expect(
      () => source.galleryPolicyFor('unknown'),
      throwsA(isA<MiniProgramSourceException>()),
    );
    source.dispose();
  });
  late _GalleryProvider provider;
  late MiniProgramMediaManager media;
  late MiniProgramGalleryManager manager;
  setUp(() {
    provider = _GalleryProvider();
    media = MiniProgramMediaManager(provider);
    manager = MiniProgramGalleryManager(provider, mediaManager: media);
  });
  tearDown(() async {
    await manager.dispose();
    await media.dispose();
  });

  test(
    'default deny and invalid host limits never reach the provider',
    () async {
      await expectLater(
        manager.pickImages(
          miniProgramId: 'a',
          policy: const MiniProgramGalleryPolicy(),
        ),
        throwsA(_error(MiniProgramErrorCodes.galleryNotAccepted)),
      );
      await expectLater(
        manager.pickImages(
          miniProgramId: 'a',
          policy: const MiniProgramGalleryPolicy(enabled: true, maxImages: 100),
        ),
        throwsA(_error(MiniProgramErrorCodes.galleryInvalidRequest)),
      );
      expect(provider.request, isNull);
    },
  );
  test(
    'clamps count and owns references for preview and scoped release',
    () async {
      final future = manager.pickImages(
        miniProgramId: 'a',
        maxImages: 9,
        policy: const MiniProgramGalleryPolicy(enabled: true, maxImages: 2),
      );
      expect(provider.request!.maxImages, 2);
      provider.complete();
      final result = await future;
      expect(media.owns('a', 'gallery_1'), isTrue);
      expect(
        () => media.loadPreview(miniProgramId: 'b', mediaRef: 'gallery_1'),
        throwsA(isA<MiniProgramMediaException>()),
      );
      expect(
        (await media.loadPreview(
          miniProgramId: 'a',
          mediaRef: 'gallery_1',
        )).bytes.length,
        3,
      );
      await manager.releaseAllFor('b');
      expect(provider.released, isEmpty);
      await manager.releaseSelection('a', result);
      expect(provider.released, ['gallery_1']);
    },
  );
  test('cancels same-app operation and releases a late result', () async {
    final future = manager.pickImages(
      miniProgramId: 'a',
      policy: const MiniProgramGalleryPolicy(enabled: true),
    );
    await expectLater(
      manager.pickImages(
        miniProgramId: 'b',
        policy: const MiniProgramGalleryPolicy(enabled: true),
      ),
      throwsA(_error(MiniProgramErrorCodes.galleryRequestInProgress)),
    );
    expect(await manager.cancelFor('b'), isFalse);
    expect(await manager.cancelFor('a'), isTrue);
    final expectation = expectLater(
      future,
      throwsA(_error(MiniProgramErrorCodes.gallerySelectionCancelled)),
    );
    provider.complete();
    await expectation;
    expect(media.isRegistered('gallery_1'), isFalse);
    expect(provider.released, ['gallery_1']);
  });
  test('disposal cleans a late provider result', () async {
    final future = manager.pickImages(
      miniProgramId: 'a',
      policy: const MiniProgramGalleryPolicy(enabled: true),
    );
    await manager.dispose();
    final expectation = expectLater(
      future,
      throwsA(_error(MiniProgramErrorCodes.gallerySelectionCancelled)),
    );
    provider.complete();
    await expectation;
    expect(provider.released, ['gallery_1']);
  });
  test(
    'rejects over-limit output atomically without releasing existing refs',
    () async {
      media.register(miniProgramId: 'other', mediaRef: 'existing');
      final future = manager.pickImages(
        miniProgramId: 'a',
        policy: const MiniProgramGalleryPolicy(enabled: true, maxImageBytes: 5),
      );
      final expectation = expectLater(
        future,
        throwsA(_error(MiniProgramErrorCodes.galleryLimitExceeded)),
      );
      provider.complete();
      await expectation;
      expect(provider.released, ['gallery_1']);
      expect(media.owns('other', 'existing'), isTrue);
    },
  );
  test(
    'rejects duplicate provider refs without deleting earlier ownership',
    () async {
      media.register(miniProgramId: 'a', mediaRef: 'gallery_1');
      final future = manager.pickImages(
        miniProgramId: 'a',
        policy: const MiniProgramGalleryPolicy(enabled: true),
      );
      final expectation = expectLater(
        future,
        throwsA(_error(MiniProgramErrorCodes.galleryInvalidResult)),
      );
      provider.complete();
      await expectation;
      expect(provider.released, isEmpty);
      expect(media.owns('a', 'gallery_1'), isTrue);
    },
  );
}

Matcher _error(String code) =>
    isA<MiniProgramGalleryException>().having((e) => e.errorCode, 'code', code);

class _GalleryProvider implements MiniProgramGalleryProvider {
  final completer = Completer<MiniProgramGalleryResult>();
  MiniProgramGalleryRequest? request;
  final released = <String>[];
  void complete() => completer.complete(
    MiniProgramGalleryResult(
      selectionId: request!.selectionId,
      images: [
        MiniProgramGalleryImage(
          mediaRef: 'gallery_1',
          fileName: 'photo.jpg',
          mimeType: 'image/jpeg',
          bytes: 10,
          width: 100,
          height: 50,
        ),
      ],
      selectedAtUtc: DateTime.utc(2026),
    ),
  );
  @override
  Future<MiniProgramGalleryResult> pickImages(
    MiniProgramGalleryRequest request,
  ) {
    this.request = request;
    return completer.future;
  }

  @override
  Future<bool> cancel(String selectionId) async =>
      selectionId == request?.selectionId;
  @override
  Future<bool> releaseMedia(MiniProgramMediaReleaseRequest request) async {
    released.add(request.mediaRef);
    return true;
  }

  @override
  Future<MiniProgramMediaPreviewResult> loadPreview(
    MiniProgramMediaPreviewRequest request,
  ) async => MiniProgramMediaPreviewResult(
    mediaRef: request.mediaRef,
    mimeType: 'image/jpeg',
    bytes: Uint8List.fromList([1, 2, 3]),
  );
}
