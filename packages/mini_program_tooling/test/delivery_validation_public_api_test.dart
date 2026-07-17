import 'package:mini_program_tooling/mini_program_tooling.dart';
import 'package:test/test.dart';

void main() {
  test('delivery validation public API remains available from the barrel', () {
    const validator = DeliveryRepositoryValidator();
    const message = DeliveryValidationMessage(
      severity: ValidationSeverity.warning,
      code: 'example',
      path: 'example.json',
      message: 'Example warning.',
    );
    const report = DeliveryValidationReport(
      repoRootPath: 'repo',
      messages: <DeliveryValidationMessage>[message],
    );

    expect(validator, isA<DeliveryRepositoryValidator>());
    expect(report.errorCount, 0);
    expect(report.warningCount, 1);
    expect(formatDeliveryValidationReport(report), contains('[warning]'));
  });
}
