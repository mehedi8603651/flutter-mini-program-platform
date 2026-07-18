Map<String, Object?> inspectWorkflowRemote(bool requested) {
  if (!requested) {
    return <String, Object?>{'checked': false};
  }
  return <String, Object?>{
    'checked': true,
    'supported': false,
    'message':
        'Provider remote artifact checks were removed. Host static artifacts from artifactBaseUrl and use optional middle-server runtime APIs.',
    'errors': <String>[],
  };
}

List<String> buildWorkflowNextActions({
  required Map<String, Object?> workspace,
  required Map<String, Object?> miniProgram,
  required Map<String, Object?> hostApp,
  required Map<String, Object?> environment,
  required Map<String, Object?> remote,
}) {
  final actions = <String>[];
  switch (workspace['type']) {
    case 'mini_program':
      if (((miniProgram['build'] as Map?)?['exists']) != true) {
        actions.add('Run `miniprogram build`.');
      }
      final validation = miniProgram['validation'] as Map<String, Object?>;
      if (validation['status'] != 'ok' && validation['status'] != 'warning') {
        actions.add('Run `miniprogram validate`.');
      }
      actions.add(
        'Build and verify portable artifacts with `miniprogram artifact build` and `miniprogram artifact verify`.',
      );
    case 'host_app':
      if (hostApp['runtimeSetupExists'] != true) {
        actions.add('Run `miniprogram embed init`.');
      }
      if ((hostApp['endpointCount'] as int? ?? 0) == 0) {
        actions.add('Run `miniprogram host endpoint import <partner.json>`.');
      }
    default:
      actions.add('Open a mini-program or Flutter host app workspace.');
  }
  return actions;
}

String computeWorkflowSeverity({
  required Map<String, Object?> workspace,
  required Map<String, Object?> miniProgram,
  required Map<String, Object?> hostApp,
  required Map<String, Object?> environment,
  required Map<String, Object?> remote,
}) {
  switch (workspace['type']) {
    case 'mini_program':
      if (((miniProgram['build'] as Map?)?['exists']) != true) {
        return 'warning';
      }
      final validation = miniProgram['validation'] as Map<String, Object?>;
      if (validation['status'] == 'error') {
        return 'error';
      }
      if ((remote['errors'] as List?)?.isNotEmpty == true) {
        return 'warning';
      }
      return 'ok';
    case 'host_app':
      if (hostApp['runtimeSetupExists'] != true ||
          (hostApp['endpointCount'] as int? ?? 0) == 0) {
        return 'warning';
      }
      return 'ok';
    default:
      return 'warning';
  }
}
