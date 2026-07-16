import 'package:flutter_test/flutter_test.dart';
import 'package:mini_program_sdk/data/mini_program_data_resource.dart' as data;

void main() {
  test('historical data resource import path retains public declarations', () {
    expect(data.miniProgramJsonAssetMaxBytes, 2 * 1024 * 1024);
    expect(data.miniProgramJsonAssetMaxDepth, 32);
    expect(data.miniProgramJsonAssetMaxMembers, 50000);
    expect(data.miniProgramJsonAssetPathMaxLength, 256);
    expect(data.MiniProgramDataResourceManager(), isNotNull);
    expect(
      const data.MiniProgramDataException(code: 'code', message: 'message'),
      isNotNull,
    );
  });
}
