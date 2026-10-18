import 'dart:io';
import 'package:mini_program_tooling/src/host_endpoint/policy_document.dart';
import 'package:mini_program_tooling/src/host_endpoint/policy_resolver.dart';
import 'package:mini_program_tooling/src/partner_handoff/requested_policy/permissions.dart';
import 'package:test/test.dart';

void main() {
  test(
    'gallery requires explicit host acceptance and preserves accepted limits',
    () async {
      final requested = normalizePartnerHandoffRequestedPermissions({
        'gallery': {
          'enabled': true,
          'reason': 'Choose profile photos.',
          'recommendedMaxImages': 3,
        },
      });
      final directory = await Directory.systemTemp.createTemp(
        'gallery_policy_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/policy.json');
      Future<Map<String, Object?>> update(bool accept, {bool force = false}) =>
          upsertHostPolicyFile(
            policyFile: file,
            appId: 'photos',
            sourcePath: 'photos.partner.json',
            requestedCache: {},
            requestedPublisherApi: {},
            requestedPermissions: requested,
            acceptRequestedPolicy: accept,
            forceAcceptedPolicy: force,
          );
      Map gallery(Map document) =>
          (((document['apps'] as Map)['photos'] as Map)['accepted']
                  as Map)['permissions']['gallery']
              as Map;
      final denied = await update(false);
      expect(gallery(denied)['enabled'], isFalse);
      final accepted = await update(true);
      expect(gallery(accepted), containsPair('maxImages', 3));
      expect(gallery(accepted)['enabled'], isTrue);
      final resolver = buildHostPolicyResolverFile(accepted);
      expect(
        resolver,
        contains('MiniProgramGalleryPolicy galleryPolicyForMiniProgram'),
      );
      expect(resolver, contains('maxImages: 3'));
      expect(gallery(await update(false))['enabled'], isTrue);
      expect(gallery(await update(false, force: true))['enabled'], isFalse);
    },
  );
  test('rejects malformed requested and accepted limits', () {
    for (final patch in <Map<String, Object?>>[
      {'recommendedMaxImages': 31},
      {'recommendedMaxImages': 1.5},
      {'recommendedMaxImageBytes': -1},
      {'recommendedMaxTotalBytes': 314572801},
      {'url': 'content://photos'},
      {'enabled': 'yes'},
    ]) {
      expect(
        () => normalizePartnerHandoffRequestedPermissions({
          'gallery': {'enabled': true, 'reason': 'Select photos.', ...patch},
        }),
        throwsA(anything),
      );
    }
    expect(
      () => validateAcceptedHostPermissions({
        'gallery': {'enabled': true, 'maxImages': 0},
      }),
      throwsA(anything),
    );
    final accepted = validateAcceptedHostPermissions({
      'gallery': {'enabled': true, 'customHostField': 'keep'},
    });
    expect(accepted['gallery'], containsPair('customHostField', 'keep'));
  });
}
