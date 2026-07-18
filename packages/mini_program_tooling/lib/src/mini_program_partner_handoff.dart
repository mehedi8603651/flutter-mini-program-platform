import 'partner_handoff/coordinator.dart';
import 'partner_handoff/files.dart';
import 'partner_handoff/handoff.dart';
import 'partner_handoff/models.dart';

export 'partner_handoff/errors.dart' show MiniProgramPartnerHandoffException;
export 'partner_handoff/handoff.dart' show MiniProgramPartnerHandoff;
export 'partner_handoff/models.dart'
    show MiniProgramPartnerPackageRequest, MiniProgramPartnerPackageResult;

/// Public compatibility facade for partner handoff package files.
class MiniProgramPartnerHandoffController {
  const MiniProgramPartnerHandoffController();

  Future<MiniProgramPartnerPackageResult> createPackage(
    MiniProgramPartnerPackageRequest request,
  ) => createMiniProgramPartnerPackage(request);

  Future<MiniProgramPartnerHandoff> readPackage(String filePath) =>
      readPartnerHandoffFile(filePath);
}
