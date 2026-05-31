part of '../miniprogram_cli.dart';

extension _MiniprogramCliPublisherBackendFirebaseCommands on MiniprogramCli {
  Future<int> _runPublisherBackendFirebase(List<String> arguments) async {
    if (_isGroupHelpRequest(arguments)) {
      _stdout.writeln(_publisherBackendFirebaseUsage());
      return 0;
    }
    if (arguments.isEmpty) {
      _stderr.writeln(_publisherBackendFirebaseUsage());
      return 64;
    }

    switch (arguments.first) {
      case 'deploy':
        return _runPublisherBackendFirebaseDeploy(arguments.sublist(1));
      case 'status':
        return _runPublisherBackendFirebaseStatus(arguments.sublist(1));
      case 'outputs':
        return _runPublisherBackendFirebaseOutputs(arguments.sublist(1));
      case 'host-command':
        return _runPublisherBackendFirebaseHostCommand(arguments.sublist(1));
      case 'handoff':
        return _runPublisherBackendFirebaseHandoff(arguments.sublist(1));
      case 'access-key':
        return _runPublisherBackendFirebaseAccessKey(arguments.sublist(1));
      case 'auth':
        return _runPublisherBackendFirebaseAuth(arguments.sublist(1));
      case 'smoke':
        return _runPublisherBackendFirebaseSmoke(arguments.sublist(1));
      case 'seed':
        return _runPublisherBackendFirebaseSeed(arguments.sublist(1));
      case 'data':
        return _runPublisherBackendFirebaseData(arguments.sublist(1));
      case 'destroy':
        return _runPublisherBackendFirebaseDestroy(arguments.sublist(1));
      default:
        _stderr.writeln(
          'Unknown publisher-backend firebase command: ${arguments.first}',
        );
        _stderr.writeln(_publisherBackendFirebaseUsage());
        return 64;
    }
  }

  Future<int> _runPublisherBackendFirebaseDeploy(List<String> arguments) async {
    final parser = _publisherBackendFirebaseCommandParser()
      ..addFlag(
        'public-invoker',
        defaultsTo: true,
        help:
            'Grant allUsers Cloud Run Invoker after deploy so host apps can call the HTTPS function.',
      )
      ..addFlag('json', negatable: false, help: 'Print machine-readable JSON.');
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram publisher-backend firebase deploy [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    final resolved = await _resolvePublisherBackendFirebaseInputs(results);
    final result = await _publisherBackendStarter.firebaseDeploy(
      PublisherBackendFirebaseDeployRequest(
        miniProgramRootPath: resolved.miniProgramRootPath,
        environment: resolved.environment,
        configurePublicInvoker: results.flag('public-invoker'),
      ),
    );
    if (results.flag('json')) {
      _stdout.writeln(_prettyJson(_publisherBackendFirebaseDeployJson(result)));
    } else {
      _stdout.writeln(_formatPublisherBackendFirebaseDeployResult(result));
    }
    return result.healthy == false ? 1 : 0;
  }

  Future<int> _runPublisherBackendFirebaseStatus(List<String> arguments) async {
    final parser = _publisherBackendFirebaseCommandParser()
      ..addFlag('json', negatable: false, help: 'Print machine-readable JSON.');
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram publisher-backend firebase status [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    final resolved = await _resolvePublisherBackendFirebaseInputs(results);
    final result = await _publisherBackendStarter.firebaseStatus(
      PublisherBackendFirebaseStatusRequest(
        miniProgramRootPath: resolved.miniProgramRootPath,
        environment: resolved.environment,
      ),
    );
    if (results.flag('json')) {
      _stdout.writeln(_prettyJson(_publisherBackendFirebaseStatusJson(result)));
    } else {
      _stdout.writeln(_formatPublisherBackendFirebaseStatusResult(result));
    }
    return !result.scaffoldExists || result.healthy == false ? 1 : 0;
  }

  Future<int> _runPublisherBackendFirebaseOutputs(
    List<String> arguments,
  ) async {
    final parser = _publisherBackendFirebaseCommandParser()
      ..addFlag('json', negatable: false, help: 'Print machine-readable JSON.');
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram publisher-backend firebase outputs [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    final resolved = await _resolvePublisherBackendFirebaseInputs(results);
    final result = await _publisherBackendStarter.firebaseOutputs(
      PublisherBackendFirebaseOutputsRequest(
        miniProgramRootPath: resolved.miniProgramRootPath,
        environment: resolved.environment,
      ),
    );
    if (results.flag('json')) {
      _stdout.writeln(
        _prettyJson(_publisherBackendFirebaseOutputsJson(result)),
      );
    } else {
      _stdout.writeln(_formatPublisherBackendFirebaseOutputsResult(result));
    }
    return 0;
  }

  Future<int> _runPublisherBackendFirebaseHostCommand(
    List<String> arguments,
  ) async {
    final parser = _publisherBackendFirebaseCommandParser()
      ..addOption(
        'api-base-url',
        help: 'Mini-program delivery API base URL for manifests/screens.',
      )
      ..addOption(
        'title',
        help:
            'Display title for the host registry. Defaults to the manifest title or appId.',
      )
      ..addOption(
        'access-key',
        help: 'MiniProgram delivery access key for protected delivery.',
      )
      ..addFlag(
        'public',
        negatable: false,
        help: 'Generate a public/static host endpoint command.',
      )
      ..addOption(
        'host-project-root',
        help:
            'Optional Flutter host app root to inspect for an existing matching endpoint.',
      )
      ..addFlag('json', negatable: false, help: 'Print machine-readable JSON.');
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram publisher-backend firebase host-command --api-base-url <url> (--access-key <key>|--public) [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }

    final rawDeliveryApiBaseUrl = results.option('api-base-url')?.trim() ?? '';
    if (rawDeliveryApiBaseUrl.isEmpty) {
      throw const FormatException(
        'publisher-backend firebase host-command requires --api-base-url <url>.',
      );
    }
    final deliveryApiBaseUri = Uri.tryParse(rawDeliveryApiBaseUrl);
    if (deliveryApiBaseUri == null ||
        !deliveryApiBaseUri.hasScheme ||
        deliveryApiBaseUri.host.isEmpty) {
      throw FormatException(
        'publisher-backend firebase host-command expected an absolute '
        '--api-base-url, got: $rawDeliveryApiBaseUrl',
      );
    }

    final accessKey = results.option('access-key')?.trim() ?? '';
    final isPublic = results.flag('public');
    if (accessKey.isEmpty && !isPublic) {
      throw const FormatException(
        'publisher-backend firebase host-command requires --access-key <key> '
        'or --public.',
      );
    }
    if (accessKey.isNotEmpty && isPublic) {
      throw const FormatException(
        'publisher-backend firebase host-command cannot use both '
        '--access-key and --public.',
      );
    }

    final resolved = await _resolvePublisherBackendFirebaseInputs(results);
    final manifestInfo = await _readMiniProgramManifestInfo(
      resolved.miniProgramRootPath,
    );
    final outputs = await _publisherBackendStarter.firebaseOutputs(
      PublisherBackendFirebaseOutputsRequest(
        miniProgramRootPath: resolved.miniProgramRootPath,
        environment: resolved.environment,
      ),
    );
    final backendBaseUrl =
        outputs.outputs['PublisherBackendBaseUrl']?.trim() ?? '';
    if (backendBaseUrl.isEmpty) {
      throw PublisherBackendException(
        'Firebase publisher backend output PublisherBackendBaseUrl is missing.',
      );
    }

    final title = results.option('title')?.trim().isNotEmpty == true
        ? results.option('title')!.trim()
        : manifestInfo.title ?? _defaultTitleForAppId(manifestInfo.appId);
    final hostProjectRootPath =
        results.option('host-project-root')?.trim().isNotEmpty == true
        ? p.normalize(p.absolute(results.option('host-project-root')!.trim()))
        : null;
    final accessMode = isPublic ? 'public' : 'protected';
    final commandText = _buildFirebaseHostEndpointCommandText(
      appId: manifestInfo.appId,
      title: title,
      deliveryApiBaseUrl: rawDeliveryApiBaseUrl,
      backendBaseUrl: backendBaseUrl,
      accessMode: accessMode,
      accessKey: accessKey.isEmpty ? null : accessKey,
      hostProjectRootPath: hostProjectRootPath,
    );
    final readiness = hostProjectRootPath == null
        ? null
        : await _inspectFirebaseHostEndpointReadiness(
            hostProjectRootPath: hostProjectRootPath,
            appId: manifestInfo.appId,
            deliveryApiBaseUrl: rawDeliveryApiBaseUrl,
            backendBaseUrl: backendBaseUrl,
            accessMode: accessMode,
          );
    final hostAuthReadiness = hostProjectRootPath == null
        ? null
        : await _inspectHostAuthReadiness(
            hostProjectRootPath: hostProjectRootPath,
          );
    final result = _PublisherBackendFirebaseHostCommandResult(
      provider: outputs.provider,
      environmentName: outputs.environmentName,
      projectId: outputs.projectId,
      region: outputs.region,
      functionName: outputs.functionName,
      miniProgramRootPath: resolved.miniProgramRootPath,
      miniProgramId: manifestInfo.appId,
      title: title,
      deliveryApiBaseUrl: rawDeliveryApiBaseUrl,
      backendBaseUrl: backendBaseUrl,
      accessMode: accessMode,
      hostEndpointCommandText: commandText,
      hostProjectRootPath: hostProjectRootPath,
      readiness: readiness,
      hostAuthReadiness: hostAuthReadiness,
    );
    if (results.flag('json')) {
      _stdout.writeln(
        _prettyJson(_publisherBackendFirebaseHostCommandJson(result)),
      );
    } else {
      _stdout.writeln(_formatPublisherBackendFirebaseHostCommandResult(result));
    }
    return 0;
  }

  Future<int> _runPublisherBackendFirebaseHandoff(
    List<String> arguments,
  ) async {
    final parser = _publisherBackendFirebaseCommandParser()
      ..addOption(
        'delivery-url',
        help: 'Mini-program delivery API base URL for manifest/screen JSON.',
      )
      ..addOption(
        'title',
        help:
            'Human-readable mini-program title. Defaults to manifest title or app id.',
      )
      ..addOption(
        'access-key',
        help: 'MiniProgram delivery access key for protected delivery.',
      )
      ..addFlag(
        'public',
        negatable: false,
        help: 'Create a public/static handoff package without an access key.',
      )
      ..addOption(
        'output',
        abbr: 'o',
        help:
            'Output partner package path. Defaults to <mini-program-root>/<appId>-<env>.partner.json.',
      )
      ..addFlag('json', negatable: false, help: 'Print machine-readable JSON.');
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram publisher-backend firebase handoff --delivery-url <url> (--access-key <key>|--public) [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }

    final rawDeliveryUrl = results.option('delivery-url')?.trim() ?? '';
    if (rawDeliveryUrl.isEmpty) {
      throw const FormatException(
        'publisher-backend firebase handoff requires --delivery-url <url>.',
      );
    }
    final deliveryUri = Uri.tryParse(rawDeliveryUrl);
    if (deliveryUri == null ||
        !deliveryUri.hasScheme ||
        deliveryUri.host.isEmpty) {
      throw FormatException(
        'publisher-backend firebase handoff expected an absolute '
        '--delivery-url, got: $rawDeliveryUrl',
      );
    }

    final accessKey = results.option('access-key')?.trim() ?? '';
    final isPublic = results.flag('public');
    if (accessKey.isEmpty && !isPublic) {
      throw const FormatException(
        'publisher-backend firebase handoff requires --access-key <key> '
        'or --public.',
      );
    }
    if (accessKey.isNotEmpty && isPublic) {
      throw const FormatException(
        'publisher-backend firebase handoff cannot use both --access-key '
        'and --public.',
      );
    }

    final resolved = await _resolvePublisherBackendFirebaseInputs(results);
    final manifestInfo = await _readMiniProgramManifestInfo(
      resolved.miniProgramRootPath,
    );
    final outputs = await _publisherBackendStarter.firebaseOutputs(
      PublisherBackendFirebaseOutputsRequest(
        miniProgramRootPath: resolved.miniProgramRootPath,
        environment: resolved.environment,
      ),
    );
    final backendBaseUrl =
        outputs.outputs['PublisherBackendBaseUrl']?.trim() ?? '';
    if (backendBaseUrl.isEmpty) {
      throw PublisherBackendException(
        'Firebase publisher backend output PublisherBackendBaseUrl is missing.',
      );
    }

    final title = results.option('title')?.trim().isNotEmpty == true
        ? results.option('title')!.trim()
        : manifestInfo.title ?? _defaultTitleForAppId(manifestInfo.appId);
    final outputPath = results.option('output')?.trim().isNotEmpty == true
        ? results.option('output')!.trim()
        : p.join(
            resolved.miniProgramRootPath,
            '${manifestInfo.appId}-${resolved.environment.name}.partner.json',
          );
    final packageResult = await _partnerHandoffController.createPackage(
      MiniProgramPartnerPackageRequest(
        appId: manifestInfo.appId,
        title: title,
        apiBaseUri: deliveryUri,
        backendBaseUri: Uri.parse(backendBaseUrl),
        accessKey: isPublic ? null : accessKey,
        outputPath: outputPath,
      ),
    );
    final hostImportCommandText = _buildHostEndpointImportCommandText(
      packageResult.filePath,
    );
    final result = _PublisherBackendFirebaseHandoffResult(
      provider: outputs.provider,
      environmentName: outputs.environmentName,
      projectId: outputs.projectId,
      region: outputs.region,
      functionName: outputs.functionName,
      miniProgramRootPath: resolved.miniProgramRootPath,
      packageResult: packageResult,
      hostImportCommandText: hostImportCommandText,
    );
    if (results.flag('json')) {
      _stdout.writeln(
        _prettyJson(_publisherBackendFirebaseHandoffJson(result)),
      );
    } else {
      _stdout.writeln(_formatPublisherBackendFirebaseHandoffResult(result));
    }
    return 0;
  }

  Future<int> _runPublisherBackendFirebaseAuth(List<String> arguments) async {
    if (_isGroupHelpRequest(arguments)) {
      _stdout.writeln(_publisherBackendFirebaseAuthUsage());
      return 0;
    }
    if (arguments.isEmpty) {
      _stderr.writeln(_publisherBackendFirebaseAuthUsage());
      return 64;
    }

    switch (arguments.first) {
      case 'status':
        return _runPublisherBackendFirebaseAuthStatus(arguments.sublist(1));
      default:
        _stderr.writeln(
          'Unknown publisher-backend firebase auth command: ${arguments.first}',
        );
        _stderr.writeln(_publisherBackendFirebaseAuthUsage());
        return 64;
    }
  }

  Future<int> _runPublisherBackendFirebaseAccessKey(
    List<String> arguments,
  ) async {
    if (_isGroupHelpRequest(arguments)) {
      _stdout.writeln(_publisherBackendFirebaseAccessKeyUsage());
      return 0;
    }
    if (arguments.isEmpty) {
      _stderr.writeln(_publisherBackendFirebaseAccessKeyUsage());
      return 64;
    }

    switch (arguments.first) {
      case 'create':
        return _runPublisherBackendFirebaseAccessKeyCreate(
          arguments.sublist(1),
        );
      case 'list':
        return _runPublisherBackendFirebaseAccessKeyList(arguments.sublist(1));
      case 'revoke':
        return _runPublisherBackendFirebaseAccessKeyRevoke(
          arguments.sublist(1),
        );
      case 'rotate':
        return _runPublisherBackendFirebaseAccessKeyRotate(
          arguments.sublist(1),
        );
      default:
        _stderr.writeln(
          'Unknown publisher-backend firebase access-key command: ${arguments.first}',
        );
        _stderr.writeln(_publisherBackendFirebaseAccessKeyUsage());
        return 64;
    }
  }

  Future<int> _runPublisherBackendFirebaseAccessKeyCreate(
    List<String> arguments,
  ) async {
    final parser = _publisherBackendFirebaseAccessKeyParser()
      ..addOption('key-id', help: 'Stable partner/host key id.')
      ..addOption(
        'expires-at-utc',
        help: 'Optional ISO-8601 expiry timestamp for the key.',
      )
      ..addOption(
        'key',
        hide: true,
        help: 'Optional explicit access key value. Intended for tests/CI.',
      )
      ..addFlag('json', negatable: false, help: 'Print machine-readable JSON.');
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram publisher-backend firebase access-key create --key-id <id> [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    final keyId = results.option('key-id')?.trim() ?? '';
    if (keyId.isEmpty) {
      throw const FormatException(
        'publisher-backend firebase access-key create requires --key-id <id>.',
      );
    }
    final resolved = await _resolvePublisherBackendFirebaseInputs(results);
    final result = await _publisherBackendStarter.firebaseAccessKeyCreate(
      PublisherBackendFirebaseAccessKeyCreateRequest(
        miniProgramRootPath: resolved.miniProgramRootPath,
        environment: resolved.environment,
        keyId: keyId,
        accessKey: results.option('key'),
        expiresAtUtc: results.option('expires-at-utc'),
      ),
    );
    if (results.flag('json')) {
      _stdout.writeln(
        _prettyJson(_publisherBackendFirebaseAccessKeyCreateJson(result)),
      );
    } else {
      _stdout.writeln(
        _formatPublisherBackendFirebaseAccessKeyCreateResult(result),
      );
    }
    return 0;
  }

  Future<int> _runPublisherBackendFirebaseAccessKeyList(
    List<String> arguments,
  ) async {
    final parser = _publisherBackendFirebaseAccessKeyParser()
      ..addFlag('json', negatable: false, help: 'Print machine-readable JSON.');
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram publisher-backend firebase access-key list [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    final resolved = await _resolvePublisherBackendFirebaseInputs(results);
    final result = await _publisherBackendStarter.firebaseAccessKeyList(
      PublisherBackendFirebaseAccessKeyListRequest(
        miniProgramRootPath: resolved.miniProgramRootPath,
        environment: resolved.environment,
      ),
    );
    if (results.flag('json')) {
      _stdout.writeln(
        _prettyJson(_publisherBackendFirebaseAccessKeyListJson(result)),
      );
    } else {
      _stdout.writeln(
        _formatPublisherBackendFirebaseAccessKeyListResult(result),
      );
    }
    return 0;
  }

  Future<int> _runPublisherBackendFirebaseAccessKeyRevoke(
    List<String> arguments,
  ) async {
    final parser = _publisherBackendFirebaseAccessKeyParser()
      ..addOption('key-id', help: 'Access key id to revoke.')
      ..addFlag('json', negatable: false, help: 'Print machine-readable JSON.');
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram publisher-backend firebase access-key revoke --key-id <id> [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    final keyId = results.option('key-id')?.trim() ?? '';
    if (keyId.isEmpty) {
      throw const FormatException(
        'publisher-backend firebase access-key revoke requires --key-id <id>.',
      );
    }
    final resolved = await _resolvePublisherBackendFirebaseInputs(results);
    final result = await _publisherBackendStarter.firebaseAccessKeyRevoke(
      PublisherBackendFirebaseAccessKeyRevokeRequest(
        miniProgramRootPath: resolved.miniProgramRootPath,
        environment: resolved.environment,
        keyId: keyId,
      ),
    );
    if (results.flag('json')) {
      _stdout.writeln(
        _prettyJson(_publisherBackendFirebaseAccessKeyRevokeJson(result)),
      );
    } else {
      _stdout.writeln(
        _formatPublisherBackendFirebaseAccessKeyRevokeResult(result),
      );
    }
    return 0;
  }

  Future<int> _runPublisherBackendFirebaseAccessKeyRotate(
    List<String> arguments,
  ) async {
    final parser = _publisherBackendFirebaseAccessKeyParser()
      ..addOption('key-id', help: 'Access key id to rotate.')
      ..addOption('new-key-id', help: 'Optional id for the replacement key.')
      ..addOption(
        'expires-at-utc',
        help: 'Optional ISO-8601 expiry timestamp for the replacement key.',
      )
      ..addOption(
        'key',
        hide: true,
        help: 'Optional explicit access key value. Intended for tests/CI.',
      )
      ..addFlag('json', negatable: false, help: 'Print machine-readable JSON.');
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram publisher-backend firebase access-key rotate --key-id <id> [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    final keyId = results.option('key-id')?.trim() ?? '';
    if (keyId.isEmpty) {
      throw const FormatException(
        'publisher-backend firebase access-key rotate requires --key-id <id>.',
      );
    }
    final resolved = await _resolvePublisherBackendFirebaseInputs(results);
    final result = await _publisherBackendStarter.firebaseAccessKeyRotate(
      PublisherBackendFirebaseAccessKeyRotateRequest(
        miniProgramRootPath: resolved.miniProgramRootPath,
        environment: resolved.environment,
        keyId: keyId,
        newKeyId: results.option('new-key-id'),
        accessKey: results.option('key'),
        expiresAtUtc: results.option('expires-at-utc'),
      ),
    );
    if (results.flag('json')) {
      _stdout.writeln(
        _prettyJson(_publisherBackendFirebaseAccessKeyRotateJson(result)),
      );
    } else {
      _stdout.writeln(
        _formatPublisherBackendFirebaseAccessKeyRotateResult(result),
      );
    }
    return 0;
  }

  Future<int> _runPublisherBackendFirebaseAuthStatus(
    List<String> arguments,
  ) async {
    final parser = _publisherBackendFirebaseCommandParser()
      ..addOption(
        'host-project-root',
        help:
            'Optional Flutter host app root to inspect for SDK auth controller setup.',
      )
      ..addFlag('json', negatable: false, help: 'Print machine-readable JSON.');
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram publisher-backend firebase auth status [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    final resolved = await _resolvePublisherBackendFirebaseInputs(results);
    final authStatus = await _publisherBackendStarter.firebaseAuthStatus(
      PublisherBackendFirebaseAuthStatusRequest(
        miniProgramRootPath: resolved.miniProgramRootPath,
        environment: resolved.environment,
      ),
    );
    final hostProjectRootPath =
        results.option('host-project-root')?.trim().isNotEmpty == true
        ? p.normalize(p.absolute(results.option('host-project-root')!.trim()))
        : null;
    final hostAuthReadiness = hostProjectRootPath == null
        ? null
        : await _inspectHostAuthReadiness(
            hostProjectRootPath: hostProjectRootPath,
          );
    final result = _PublisherBackendFirebaseAuthStatusCliResult(
      authStatus: authStatus,
      hostProjectRootPath: hostProjectRootPath,
      hostAuthReadiness: hostAuthReadiness,
    );
    if (results.flag('json')) {
      _stdout.writeln(
        _prettyJson(_publisherBackendFirebaseAuthStatusJson(result)),
      );
    } else {
      _stdout.writeln(_formatPublisherBackendFirebaseAuthStatusResult(result));
    }
    return authStatus.ready && (hostAuthReadiness?.ready ?? true) ? 0 : 1;
  }

  Future<int> _runPublisherBackendFirebaseSmoke(List<String> arguments) async {
    final parser = _publisherBackendFirebaseCommandParser()
      ..addFlag('json', negatable: false, help: 'Print machine-readable JSON.')
      ..addFlag(
        'include-write',
        negatable: false,
        help:
            'Also verify POST /coupon/redeem and the resulting Firestore redemption. This mutates backend data.',
      )
      ..addFlag(
        'include-auth',
        negatable: false,
        help:
            'Also verify publisher-owned Firebase email auth, refresh, protected session, and sign-out.',
      )
      ..addOption(
        'write-coupon-id',
        defaultsTo: 'coupon-10',
        help: 'Coupon ID used with --include-write.',
      )
      ..addOption(
        'write-user-id',
        defaultsTo: 'smoke-user',
        help: 'User ID used with --include-write.',
      )
      ..addOption('auth-email', help: 'Email used with --include-auth.')
      ..addOption('auth-password', help: 'Password used with --include-auth.')
      ..addOption(
        'access-key',
        help: 'MiniProgram access key for protected Firebase backends.',
      )
      ..addFlag(
        'auth-create-user',
        negatable: false,
        help:
            'Attempt auth/email/sign-up before sign-in. Existing users are accepted.',
      );
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram publisher-backend firebase smoke [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    final includeWrite = results.flag('include-write');
    final includeAuth = results.flag('include-auth');
    if (!includeWrite &&
        (results.wasParsed('write-coupon-id') ||
            results.wasParsed('write-user-id'))) {
      _stderr.writeln(
        '--write-coupon-id and --write-user-id require --include-write.',
      );
      return 64;
    }
    if (!includeAuth &&
        (results.wasParsed('auth-email') ||
            results.wasParsed('auth-password') ||
            results.flag('auth-create-user'))) {
      _stderr.writeln(
        '--auth-email, --auth-password, and --auth-create-user require --include-auth.',
      );
      return 64;
    }
    final writeCouponId = results.option('write-coupon-id')?.trim() ?? '';
    final writeUserId = results.option('write-user-id')?.trim() ?? '';
    if (includeWrite && (writeCouponId.isEmpty || writeUserId.isEmpty)) {
      _stderr.writeln(
        '--write-coupon-id and --write-user-id must not be empty.',
      );
      return 64;
    }
    final authEmail = results.option('auth-email')?.trim() ?? '';
    final authPassword = results.option('auth-password')?.trim() ?? '';
    if (includeAuth && (authEmail.isEmpty || authPassword.isEmpty)) {
      _stderr.writeln('--auth-email and --auth-password are required.');
      return 64;
    }
    final accessKey = results.option('access-key')?.trim();
    final resolved = await _resolvePublisherBackendFirebaseInputs(results);
    final result = await _publisherBackendStarter.firebaseSmoke(
      PublisherBackendFirebaseSmokeRequest(
        miniProgramRootPath: resolved.miniProgramRootPath,
        environment: resolved.environment,
        includeWrite: includeWrite,
        writeCouponId: writeCouponId,
        writeUserId: writeUserId,
        includeAuth: includeAuth,
        authEmail: includeAuth ? authEmail : null,
        authPassword: includeAuth ? authPassword : null,
        authCreateUser: results.flag('auth-create-user'),
        accessKey: accessKey == null || accessKey.isEmpty ? null : accessKey,
      ),
    );
    if (results.flag('json')) {
      _stdout.writeln(_prettyJson(_publisherBackendFirebaseSmokeJson(result)));
    } else {
      _stdout.writeln(_formatPublisherBackendFirebaseSmokeResult(result));
    }
    return result.passed ? 0 : 1;
  }

  Future<int> _runPublisherBackendFirebaseSeed(List<String> arguments) async {
    final parser = _publisherBackendFirebaseCommandParser()
      ..addFlag('json', negatable: false, help: 'Print machine-readable JSON.');
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram publisher-backend firebase seed [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    final resolved = await _resolvePublisherBackendFirebaseInputs(results);
    final result = await _publisherBackendStarter.firebaseSeed(
      PublisherBackendFirebaseSeedRequest(
        miniProgramRootPath: resolved.miniProgramRootPath,
        environment: resolved.environment,
      ),
    );
    if (results.flag('json')) {
      _stdout.writeln(_prettyJson(_publisherBackendFirebaseSeedJson(result)));
    } else {
      _stdout.writeln(_formatPublisherBackendFirebaseSeedResult(result));
    }
    return result.seeded ? 0 : 1;
  }

  Future<int> _runPublisherBackendFirebaseData(List<String> arguments) async {
    if (_isGroupHelpRequest(arguments)) {
      _stdout.writeln(_publisherBackendFirebaseDataUsage());
      return 0;
    }
    if (arguments.isEmpty) {
      _stderr.writeln(_publisherBackendFirebaseDataUsage());
      return 64;
    }

    switch (arguments.first) {
      case 'status':
        return _runPublisherBackendFirebaseDataStatus(arguments.sublist(1));
      case 'export':
        return _runPublisherBackendFirebaseDataExport(arguments.sublist(1));
      case 'import':
        return _runPublisherBackendFirebaseDataImport(arguments.sublist(1));
      case 'redemptions':
        return _runPublisherBackendFirebaseDataRedemptions(
          arguments.sublist(1),
        );
      default:
        _stderr.writeln(
          'Unknown publisher-backend firebase data command: ${arguments.first}',
        );
        _stderr.writeln(_publisherBackendFirebaseDataUsage());
        return 64;
    }
  }

  Future<int> _runPublisherBackendFirebaseDataStatus(
    List<String> arguments,
  ) async {
    final parser = _publisherBackendFirebaseCommandParser()
      ..addFlag('json', negatable: false, help: 'Print machine-readable JSON.');
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram publisher-backend firebase data status [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    final resolved = await _resolvePublisherBackendFirebaseInputs(results);
    final result = await _publisherBackendStarter.firebaseDataStatus(
      PublisherBackendFirebaseDataStatusRequest(
        miniProgramRootPath: resolved.miniProgramRootPath,
        environment: resolved.environment,
      ),
    );
    if (results.flag('json')) {
      _stdout.writeln(
        _prettyJson(_publisherBackendFirebaseDataStatusJson(result)),
      );
    } else {
      _stdout.writeln(_formatPublisherBackendFirebaseDataStatusResult(result));
    }
    return result.available ? 0 : 1;
  }

  Future<int> _runPublisherBackendFirebaseDataExport(
    List<String> arguments,
  ) async {
    final parser = _publisherBackendFirebaseCommandParser()
      ..addFlag(
        'include-redemptions',
        negatable: false,
        help: 'Include redemption records in the export file.',
      )
      ..addOption('output', help: 'Optional export JSON file path.')
      ..addFlag('json', negatable: false, help: 'Print machine-readable JSON.');
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram publisher-backend firebase data export [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    final resolved = await _resolvePublisherBackendFirebaseInputs(results);
    final result = await _publisherBackendStarter.firebaseDataExport(
      PublisherBackendFirebaseDataExportRequest(
        miniProgramRootPath: resolved.miniProgramRootPath,
        environment: resolved.environment,
        outputPath: results.option('output'),
        includeRedemptions: results.flag('include-redemptions'),
      ),
    );
    if (results.flag('json')) {
      _stdout.writeln(
        _prettyJson(_publisherBackendFirebaseDataExportJson(result)),
      );
    } else {
      _stdout.writeln(_formatPublisherBackendFirebaseDataExportResult(result));
    }
    return result.exported ? 0 : 1;
  }

  Future<int> _runPublisherBackendFirebaseDataImport(
    List<String> arguments,
  ) async {
    final parser = _publisherBackendFirebaseCommandParser()
      ..addFlag(
        'include-redemptions',
        negatable: false,
        help: 'Import redemption records from the export file.',
      )
      ..addFlag(
        'dry-run',
        negatable: false,
        help: 'Validate and summarize the import without writing data.',
      )
      ..addOption('input', help: 'Required export JSON file path.')
      ..addFlag('json', negatable: false, help: 'Print machine-readable JSON.');
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram publisher-backend firebase data import --input <file> [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (results.option('input')?.trim().isNotEmpty != true) {
      throw const FormatException(
        'publisher-backend firebase data import requires --input <file>.',
      );
    }
    final resolved = await _resolvePublisherBackendFirebaseInputs(results);
    final result = await _publisherBackendStarter.firebaseDataImport(
      PublisherBackendFirebaseDataImportRequest(
        miniProgramRootPath: resolved.miniProgramRootPath,
        environment: resolved.environment,
        inputPath: results.option('input')!,
        includeRedemptions: results.flag('include-redemptions'),
        dryRun: results.flag('dry-run'),
      ),
    );
    if (results.flag('json')) {
      _stdout.writeln(
        _prettyJson(_publisherBackendFirebaseDataImportJson(result)),
      );
    } else {
      _stdout.writeln(_formatPublisherBackendFirebaseDataImportResult(result));
    }
    return result.succeeded ? 0 : 1;
  }

  Future<int> _runPublisherBackendFirebaseDataRedemptions(
    List<String> arguments,
  ) async {
    final parser = _publisherBackendFirebaseCommandParser()
      ..addOption('coupon-id', help: 'Optional coupon id filter.')
      ..addOption('user-id', help: 'Optional user id filter.')
      ..addOption('limit', defaultsTo: '50', help: 'Maximum records to return.')
      ..addFlag('json', negatable: false, help: 'Print machine-readable JSON.');
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram publisher-backend firebase data redemptions [options]',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    final limit = int.tryParse(results.option('limit') ?? '');
    if (limit == null || limit < 1 || limit > 500) {
      throw const FormatException(
        'publisher-backend firebase data redemptions --limit must be between 1 and 500.',
      );
    }
    final resolved = await _resolvePublisherBackendFirebaseInputs(results);
    final result = await _publisherBackendStarter.firebaseDataRedemptions(
      PublisherBackendFirebaseDataRedemptionsRequest(
        miniProgramRootPath: resolved.miniProgramRootPath,
        environment: resolved.environment,
        couponId: results.option('coupon-id'),
        userId: results.option('user-id'),
        limit: limit,
      ),
    );
    if (results.flag('json')) {
      _stdout.writeln(
        _prettyJson(_publisherBackendFirebaseDataRedemptionsJson(result)),
      );
    } else {
      _stdout.writeln(
        _formatPublisherBackendFirebaseDataRedemptionsResult(result),
      );
    }
    return result.available ? 0 : 1;
  }

  Future<int> _runPublisherBackendFirebaseDestroy(
    List<String> arguments,
  ) async {
    final parser = _publisherBackendFirebaseCommandParser()
      ..addFlag(
        'yes',
        negatable: false,
        help: 'Confirm deletion of the Firebase Function.',
      )
      ..addFlag(
        'confirm-data-loss',
        negatable: false,
        help:
            'Allow deleting the Firebase Function when Firestore app records or redemptions exist. Firestore data is not deleted.',
      )
      ..addFlag('json', negatable: false, help: 'Print machine-readable JSON.');
    final results = parser.parse(arguments);
    if (results.flag('help')) {
      _stdout.writeln(
        'Usage: miniprogram publisher-backend firebase destroy [options] --yes',
      );
      _stdout.writeln(parser.usage);
      return 0;
    }
    if (!results.flag('yes')) {
      throw const FormatException(
        'publisher-backend firebase destroy is destructive and requires --yes.',
      );
    }
    final resolved = await _resolvePublisherBackendFirebaseInputs(results);
    final result = await _publisherBackendStarter.firebaseDestroy(
      PublisherBackendFirebaseDestroyRequest(
        miniProgramRootPath: resolved.miniProgramRootPath,
        environment: resolved.environment,
        confirmDataLoss: results.flag('confirm-data-loss'),
      ),
    );
    if (results.flag('json')) {
      _stdout.writeln(
        _prettyJson(_publisherBackendFirebaseDestroyJson(result)),
      );
    } else {
      _stdout.writeln(_formatPublisherBackendFirebaseDestroyResult(result));
    }
    return result.deleted ? 0 : 1;
  }

  ArgParser _publisherBackendFirebaseCommandParser() => ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show usage information.',
    )
    ..addOption('env', help: 'Named Firebase cloud environment override.')
    ..addOption(
      'mini-program-root',
      help: 'Exact mini-program root. Defaults to the current directory.',
    );

  ArgParser _publisherBackendFirebaseAccessKeyParser() =>
      _publisherBackendFirebaseCommandParser();

  Future<_PublisherBackendFirebaseInputs>
  _resolvePublisherBackendFirebaseInputs(ArgResults results) async {
    if (results.rest.isNotEmpty) {
      throw const FormatException(
        'publisher-backend firebase commands do not accept positional arguments.',
      );
    }
    final miniProgramRootPath = await _resolveCurrentMiniProgramRootPath(
      explicitMiniProgramRootPath: results.option('mini-program-root'),
    );
    final resolvedEnvironment = await _requireEnvironmentState(
      additionalSearchRoots: <String>[miniProgramRootPath],
    );
    final environment = _resolveConfiguredCloudEnvironment(
      state: resolvedEnvironment.state,
      explicitEnvironmentName: results.option('env'),
    );
    if (environment.provider != 'firebase') {
      throw FormatException(
        'publisher-backend firebase requires a firebase environment. '
        'Environment "${environment.name}" uses provider "${environment.provider}".',
      );
    }
    return _PublisherBackendFirebaseInputs(
      miniProgramRootPath: miniProgramRootPath,
      environment: environment,
    );
  }

  Future<_MiniProgramManifestInfo> _readMiniProgramManifestInfo(
    String miniProgramRootPath,
  ) async {
    final manifestFile = File(p.join(miniProgramRootPath, 'manifest.json'));
    if (!await manifestFile.exists()) {
      throw PublisherBackendException(
        'Mini-program root is missing manifest.json: $miniProgramRootPath',
      );
    }
    final decoded = jsonDecode(await manifestFile.readAsString());
    if (decoded is! Map) {
      throw PublisherBackendException(
        'manifest.json must contain a JSON object: ${manifestFile.path}',
      );
    }
    final appId = decoded['id']?.toString().trim() ?? '';
    if (appId.isEmpty) {
      throw PublisherBackendException(
        'manifest.json is missing required id: ${manifestFile.path}',
      );
    }
    final title = decoded['title']?.toString().trim();
    return _MiniProgramManifestInfo(
      appId: appId,
      title: title == null || title.isEmpty ? null : title,
    );
  }
}
