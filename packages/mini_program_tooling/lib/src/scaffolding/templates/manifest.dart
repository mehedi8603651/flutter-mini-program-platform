import 'dart:convert';

import 'package:mini_program_contracts/mini_program_contracts.dart';

String buildScaffoldManifest({
  required String miniProgramId,
  required List<String> capabilities,
  required String entryScreenId,
}) {
  final usesSecureApi = capabilities.contains(CapabilityIds.secureApi);
  final manifest = <String, dynamic>{
    'id': miniProgramId,
    'version': '1.0.0',
    'entry': entryScreenId,
    'contractVersion': '1.0.0',
    'sdkVersionRange': '>=1.0.0 <2.0.0',
    'requiredCapabilities': capabilities,
    'screenFormat': MiniProgramScreenFormats.mp,
    'screenSchemaVersion': 1,
    'cachePolicy': usesSecureApi
        ? <String, dynamic>{
            'manifest': <String, dynamic>{'mode': 'noCache'},
            'entryScreen': <String, dynamic>{'mode': 'noCache'},
          }
        : <String, dynamic>{
            'manifest': <String, dynamic>{
              'mode': 'staleWhileError',
              'maxStaleSeconds': 86400,
            },
            'entryScreen': <String, dynamic>{
              'mode': 'staleWhileError',
              'maxStaleSeconds': 21600,
            },
          },
    'fallback': <String, dynamic>{
      'strategy': 'errorView',
      'message': '$miniProgramId is temporarily unavailable in this host app.',
    },
  };

  return const JsonEncoder.withIndent('  ').convert(manifest);
}
