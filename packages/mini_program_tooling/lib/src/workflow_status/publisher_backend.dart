import 'dart:io';

import 'package:path/path.dart' as p;

Future<Map<String, Object?>> inspectWorkflowPublisherBackendStarter(
  String workspacePath,
) async {
  final mockBackendRootPath = p.join(workspacePath, 'backend', 'mock');
  final serverPath = p.join(mockBackendRootPath, 'bin', 'server.dart');
  final dataRootPath = p.join(mockBackendRootPath, 'data');
  final dataFiles = <String>[
    'home_bootstrap.json',
    'coupons_list.json',
    'session.json',
  ];
  final existingDataFiles = <String>[];
  for (final dataFile in dataFiles) {
    final file = File(p.join(dataRootPath, dataFile));
    if (await file.exists()) {
      existingDataFiles.add(dataFile);
    }
  }
  final mockDetected =
      await File(serverPath).exists() && await Directory(dataRootPath).exists();
  return <String, Object?>{
    'detected': mockDetected,
    'template': mockDetected ? 'mock' : null,
    'storageMode': mockDetected ? 'bundled' : null,
    'backendRootPath': mockBackendRootPath,
    'serverPath': serverPath,
    'dataRootPath': dataRootPath,
    'dataFiles': existingDataFiles,
    'mock': <String, Object?>{
      'detected': mockDetected,
      'backendRootPath': mockBackendRootPath,
      'serverPath': serverPath,
      'dataRootPath': dataRootPath,
      'dataFiles': existingDataFiles,
    },
    'expectedRoutes': <String>[
      'GET /health',
      'GET /home/bootstrap',
      'GET /coupons/list',
      'GET /coupons/page',
      'GET /auth/session',
      'POST /coupon/redeem',
    ],
  };
}
