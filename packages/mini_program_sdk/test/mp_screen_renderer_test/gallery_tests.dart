part of '../mp_screen_renderer_test.dart';

void _mpGalleryTests() {
  testWidgets('gallery actions require a gesture and host acceptance', (
    tester,
  ) async {
    final state = MpStateManager()..set('photos', {'previous': true});
    final action = _jsonAction(
      Mp.gallery.pickImages(targetState: 'photos', statusState: 'status'),
    );
    final gestureDenied =
        await _runMpAction(tester, action, stateManager: state)
            as HostActionResult;
    expect(
      gestureDenied.errorCode,
      MiniProgramErrorCodes.galleryUserGestureRequired,
    );
    final policyDenied =
        await _runMpAction(
              tester,
              action,
              stateManager: state,
              userGesture: true,
            )
            as HostActionResult;
    expect(policyDenied.errorCode, MiniProgramErrorCodes.galleryNotAccepted);
    expect(state.get<Map>('photos'), {'previous': true});
    state.dispose();
  });
  testWidgets(
    'gallery writes safe metadata and cancellation keeps the selection',
    (tester) async {
      final state = MpStateManager();
      final provider = _ResultGalleryProvider();
      final media = MiniProgramMediaManager(provider);
      final manager = MiniProgramGalleryManager(provider, mediaManager: media);
      final action = _jsonAction(
        Mp.gallery.pickImages(
          targetState: 'photos',
          statusState: 'status',
          errorState: 'error',
          requestId: 'pick-1',
        ),
      );
      Future<HostActionResult> run() async =>
          await _runMpAction(
                tester,
                action,
                stateManager: state,
                galleryManager: manager,
                mediaManager: media,
                galleryPolicy: const MiniProgramGalleryPolicy(enabled: true),
                userGesture: true,
              )
              as HostActionResult;
      final success = await run();
      expect(success.isSuccess, isTrue);
      expect(success.requestId, 'pick-1');
      final selection = state.get<Map>('photos')!;
      expect(selection['images'], hasLength(1));
      expect(
        (selection['images'] as List).first,
        containsPair('mediaRef', 'gallery_test'),
      );
      expect(state.get<String>('status'), 'success');
      expect(media.owns('coupon', 'gallery_test'), isTrue);
      provider.cancelled = true;
      final cancelled = await run();
      expect(cancelled.status, HostActionStatus.cancelled);
      expect(state.get<Map>('photos'), selection);
      expect(state.get<String>('status'), 'cancelled');
      expect(state.contains('error'), isFalse);
      await manager.dispose();
      await media.dispose();
      state.dispose();
    },
  );
  testWidgets(
    'gallery state quota failure releases imported media and rolls back',
    (tester) async {
      final state = MpStateManager(
        policy: const MiniProgramLiveStatePolicy(
          maxBytes: 1024,
          maxValueBytes: 100,
        ),
      )..set('photos', {'previous': true});
      final provider = _ResultGalleryProvider();
      final media = MiniProgramMediaManager(provider);
      final manager = MiniProgramGalleryManager(provider, mediaManager: media);
      final result =
          await _runMpAction(
                tester,
                _jsonAction(
                  Mp.gallery.pickImages(
                    targetState: 'photos',
                    statusState: 'status',
                  ),
                ),
                stateManager: state,
                galleryManager: manager,
                mediaManager: media,
                galleryPolicy: const MiniProgramGalleryPolicy(enabled: true),
                userGesture: true,
              )
              as HostActionResult;
      expect(result.errorCode, MiniProgramErrorCodes.stateLimitExceeded);
      expect(state.get<Map>('photos'), {'previous': true});
      expect(provider.released, ['gallery_test']);
      await manager.dispose();
      await media.dispose();
      state.dispose();
    },
  );
  test(
    'gallery validator rejects unsupported native data and invalid counts',
    () {
      for (final props in <Map<String, dynamic>>[
        {'maxImages': 0},
        {'maxImages': 31},
        {'quality': 0},
        {'maxWidth': 9000},
        {'nativePath': '/sdcard/photo.jpg'},
        {
          'mimeTypes': ['*/*'],
        },
      ]) {
        expect(
          () => const MpScreenValidator().validate(
            _cacheActionScreen('gallery.pickImages', {
              'targetState': 'photos',
              ...props,
            }),
            expectedScreenId: 'coupon_home',
          ),
          throwsA(isA<MiniProgramRenderException>()),
        );
      }
    },
  );
}

class _ResultGalleryProvider implements MiniProgramGalleryProvider {
  bool cancelled = false;
  final released = <String>[];
  @override
  Future<MiniProgramGalleryResult> pickImages(
    MiniProgramGalleryRequest request,
  ) async {
    if (cancelled) {
      throw const MiniProgramGalleryException(
        errorCode: MiniProgramErrorCodes.gallerySelectionCancelled,
        message: 'Cancelled.',
      );
    }
    return MiniProgramGalleryResult(
      selectionId: request.selectionId,
      images: [
        MiniProgramGalleryImage(
          mediaRef: 'gallery_test',
          fileName: 'photo.jpg',
          mimeType: 'image/jpeg',
          bytes: 10,
          width: 100,
          height: 50,
        ),
      ],
      selectedAtUtc: DateTime.utc(2026),
    );
  }

  @override
  Future<bool> cancel(String selectionId) async => true;
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
    bytes: Uint8List.fromList([1]),
  );
}
