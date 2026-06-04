import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_legacy_stac/src/actions/sdk_mini_program_load_more_action.dart';
import 'package:mini_program_legacy_stac/src/rendering/sdk_mini_program_paged_backend_builder_parser.dart';

void main() {
  group('paged backend parser models', () {
    test('load-more action accepts requestId only', () {
      final model = SdkMiniProgramLoadMoreAction.fromJson(
        const <String, dynamic>{
          'actionType': 'miniProgramLoadMore',
          'requestId': 'coupons',
        },
      );

      expect(model.requestId, 'coupons');
      expect(model.toQuery(), isNull);
    });

    test('paged builder rejects missing item template', () {
      expect(
        () => SdkMiniProgramPagedBackendBuilderModel.fromJson(
          const <String, dynamic>{
            'requestId': 'coupons',
            'endpoint': 'coupons/list',
          },
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('paged builder rejects non-positive limit', () {
      expect(
        () => SdkMiniProgramPagedBackendBuilderModel.fromJson(
          const <String, dynamic>{
            'requestId': 'coupons',
            'endpoint': 'coupons/list',
            'limit': 0,
            'itemTemplate': <String, dynamic>{'type': 'text', 'data': 'x'},
          },
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
