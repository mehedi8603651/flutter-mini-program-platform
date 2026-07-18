import 'package:mini_program_contracts/mini_program_contracts.dart';

class MiniProgramScaffoldRequest {
  const MiniProgramScaffoldRequest({
    required this.miniProgramId,
    this.repoRootPath,
    this.outputRootPath,
    this.title,
    this.description,
    this.capabilities = const <String>{'analytics'},
    this.backendTemplate,
    this.screenFormat = MiniProgramScreenFormats.mp,
    this.force = false,
  });

  final String miniProgramId;
  final String? repoRootPath;
  final String? outputRootPath;
  final String? title;
  final String? description;
  final Set<String> capabilities;
  final String? backendTemplate;
  final String screenFormat;
  final bool force;
}

class MiniProgramScaffoldResult {
  const MiniProgramScaffoldResult({
    required this.repoRootPath,
    required this.miniProgramRootPath,
    required this.miniProgramId,
    required this.title,
    required this.description,
    required this.capabilities,
    required this.screenFormat,
    required this.createdPaths,
  });

  final String? repoRootPath;
  final String miniProgramRootPath;
  final String miniProgramId;
  final String title;
  final String description;
  final List<String> capabilities;
  final String screenFormat;
  final List<String> createdPaths;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'repoRootPath': repoRootPath,
    'miniProgramRootPath': miniProgramRootPath,
    'miniProgramId': miniProgramId,
    'title': title,
    'description': description,
    'capabilities': capabilities,
    'screenFormat': screenFormat,
    'createdPaths': createdPaths,
  };
}

class MiniProgramScaffoldException implements Exception {
  const MiniProgramScaffoldException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MiniProgramScaffoldSpecification {
  const MiniProgramScaffoldSpecification({
    required this.repoRootPath,
    required this.miniProgramRootPath,
    required this.miniProgramId,
    required this.title,
    required this.description,
    required this.capabilities,
    required this.backendTemplate,
    required this.screenFormat,
    required this.force,
  });

  final String? repoRootPath;
  final String miniProgramRootPath;
  final String miniProgramId;
  final String title;
  final String description;
  final List<String> capabilities;
  final String? backendTemplate;
  final String screenFormat;
  final bool force;

  bool get withMockBackend => backendTemplate == 'mock';
  String get entryScreenId => '${miniProgramId}_home';
  String get detailsScreenId => '${miniProgramId}_details';
  String get packageName => '${miniProgramId}_mini_program';
}
