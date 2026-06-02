part of '../publisher_backend_starter.dart';

extension _PublisherBackendStarterFirebaseOperations
    on PublisherBackendStarter {
  Future<PublisherBackendFirebaseDeployResult> _firebaseDeployImpl(
    PublisherBackendFirebaseDeployRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendFirebaseSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
    );
    await _assertFirebaseBackendPaths(settings.backendRootPath);
    final dependenciesInstalled = await _ensureFirebaseDependencies(settings);
    await _writeFirebaseEnvFile(settings);
    await _runFirebaseCommand(<String>[
      'deploy',
      '--only',
      'functions:${settings.functionName}',
      '--project',
      settings.projectId,
    ], workingDirectory: settings.backendRootPath);

    var publicInvokerConfigured = false;
    var publicInvokerChanged = false;
    String? publicInvokerError;
    if (request.configurePublicInvoker) {
      try {
        final publicInvoker = await _ensureFirebasePublicInvoker(settings);
        publicInvokerConfigured = publicInvoker.configured;
        publicInvokerChanged = publicInvoker.changed;
      } on PublisherBackendException catch (error) {
        publicInvokerError = error.message;
      }
    }

    var authTokenCreatorConfigured = false;
    var authTokenCreatorChanged = false;
    String? authTokenCreatorServiceAccount;
    String? authTokenCreatorError;
    if (settings.authWebApiKey?.trim().isNotEmpty == true) {
      try {
        final tokenCreator = await _ensureFirebaseAuthTokenCreator(settings);
        authTokenCreatorConfigured = tokenCreator.configured;
        authTokenCreatorChanged = tokenCreator.changed;
        authTokenCreatorServiceAccount = tokenCreator.serviceAccountEmail;
      } on PublisherBackendException catch (error) {
        authTokenCreatorError = error.message;
      }
    }

    final outputs = settings.outputs;
    final health = await _waitForHealthCheck(
      Uri.parse(settings.healthUrl),
      timeout: _firebaseDeployHealthWaitTimeout,
      attemptTimeout: _firebaseDeployHealthAttemptTimeout,
      retryDelay: _firebaseDeployHealthRetryDelay,
    );
    final deployedAtUtc = _clock().toUtc().toIso8601String();
    final state = PublisherBackendFirebaseState(
      schemaVersion: 1,
      miniProgramRootPath: rootPath,
      backendRootPath: settings.backendRootPath,
      functionsRootPath: settings.functionsRootPath,
      environmentName: request.environment.name,
      projectId: settings.projectId,
      region: settings.region,
      functionName: settings.functionName,
      functionUrl: settings.functionUrl,
      outputs: outputs,
      deployedAtUtc: deployedAtUtc,
    );
    await _writeFirebaseState(rootPath, state);
    return PublisherBackendFirebaseDeployResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      projectId: settings.projectId,
      region: settings.region,
      functionName: settings.functionName,
      backendRootPath: settings.backendRootPath,
      functionsRootPath: settings.functionsRootPath,
      miniProgramRootPath: rootPath,
      backendBaseUrl: settings.functionUrl,
      healthUrl: settings.healthUrl,
      healthy: health.healthy,
      healthStatusCode: health.statusCode,
      healthError: health.error,
      publicInvokerConfigured: publicInvokerConfigured,
      publicInvokerChanged: publicInvokerChanged,
      publicInvokerError: publicInvokerError,
      authTokenCreatorConfigured: authTokenCreatorConfigured,
      authTokenCreatorChanged: authTokenCreatorChanged,
      authTokenCreatorServiceAccount: authTokenCreatorServiceAccount,
      authTokenCreatorError: authTokenCreatorError,
      deployedAtUtc: deployedAtUtc,
      dependenciesInstalled: dependenciesInstalled,
      outputs: outputs,
    );
  }

  Future<PublisherBackendFirebaseStatusResult> _firebaseStatusImpl(
    PublisherBackendFirebaseStatusRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendFirebaseSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
    );
    final state = await _readFirebaseState(rootPath);
    final scaffoldExists = await _firebaseBackendPathsExist(
      settings.backendRootPath,
    );
    final health = scaffoldExists
        ? await _probeHealth(Uri.parse(settings.healthUrl))
        : const _PublisherBackendHealth(
            healthy: false,
            error:
                'Firebase Functions publisher backend scaffold was not found.',
          );
    return PublisherBackendFirebaseStatusResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      projectId: settings.projectId,
      region: settings.region,
      functionName: settings.functionName,
      backendRootPath: settings.backendRootPath,
      functionsRootPath: settings.functionsRootPath,
      backendBaseUrl: settings.functionUrl,
      healthUrl: settings.healthUrl,
      scaffoldExists: scaffoldExists,
      state: state,
      healthy: health.healthy,
      healthStatusCode: health.statusCode,
      healthError: health.error,
      outputs: settings.outputs,
    );
  }

  Future<PublisherBackendFirebaseOutputsResult> _firebaseOutputsImpl(
    PublisherBackendFirebaseOutputsRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendFirebaseSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
    );
    return PublisherBackendFirebaseOutputsResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      projectId: settings.projectId,
      region: settings.region,
      functionName: settings.functionName,
      outputs: settings.outputs,
    );
  }

  Future<PublisherBackendFirebaseAuthStatusResult> _firebaseAuthStatusImpl(
    PublisherBackendFirebaseAuthStatusRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendFirebaseSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
    );
    final authServiceFile = File(
      p.join(settings.functionsRootPath, 'auth_service.js'),
    );
    final routerFile = File(p.join(settings.functionsRootPath, 'router.js'));
    final packageJsonFile = File(
      p.join(settings.functionsRootPath, 'package.json'),
    );
    final envFile = File(p.join(settings.functionsRootPath, '.env'));

    final scaffoldExists = await _firebaseBackendPathsExist(
      settings.backendRootPath,
    );
    final authServiceFileExists = await authServiceFile.exists();
    final routerFileExists = await routerFile.exists();
    final packageJsonFileExists = await packageJsonFile.exists();
    final envFileExists = await envFile.exists();
    final routerSource = routerFileExists
        ? await routerFile.readAsString()
        : '';
    final packageSource = packageJsonFileExists
        ? await packageJsonFile.readAsString()
        : '';
    final envSource = envFileExists ? await envFile.readAsString() : '';

    const authRouteSnippets = <String>[
      'GET /auth/session',
      'POST /auth/email/sign-up',
      'POST /auth/email/sign-in',
      'POST /auth/refresh',
      'POST /auth/sign-out',
    ];
    final routerAuthRoutesReady = authRouteSnippets.every(
      routerSource.contains,
    );
    final routerAllowsAuthorizationHeader = routerSource.toLowerCase().contains(
      'authorization',
    );
    final packageJsonHasFirebaseAdmin = packageSource.contains(
      '"firebase-admin"',
    );
    final packageJsonHasFirebaseFunctions = packageSource.contains(
      '"firebase-functions"',
    );
    final envAuthKeyConfigured = envSource
        .split('\n')
        .map((line) => line.trim())
        .any(
          (line) =>
              line.startsWith('PUBLISHER_AUTH_WEB_API_KEY=') &&
              line.substring('PUBLISHER_AUTH_WEB_API_KEY='.length).isNotEmpty,
        );
    final envUsesReservedAuthKey = envSource
        .split('\n')
        .map((line) => line.trim())
        .any((line) => line.startsWith('FIREBASE_AUTH_WEB_API_KEY='));

    final issues = <String>[];
    final warnings = <String>[];
    if (settings.authWebApiKey?.trim().isNotEmpty != true) {
      issues.add(
        'Firebase environment is missing --auth-web-api-key. Re-run `miniprogram env configure ${settings.environmentName} --provider firebase ... --auth-web-api-key <firebase-web-api-key>`.',
      );
    }
    if (!scaffoldExists) {
      issues.add(
        'Firebase Functions scaffold is missing. Run `miniprogram publisher-backend scaffold --template firebase-functions --storage firestore` first.',
      );
    }
    if (!authServiceFileExists) {
      issues.add(
        'Generated auth service is missing: ${authServiceFile.path}. Re-scaffold with current tooling or copy the 0.3.43+ Firebase auth files.',
      );
    }
    if (!routerFileExists) {
      issues.add('Generated router is missing: ${routerFile.path}.');
    } else {
      if (!routerAuthRoutesReady) {
        issues.add(
          'Generated router is missing one or more publisher auth routes.',
        );
      }
      if (!routerAllowsAuthorizationHeader) {
        issues.add('Generated router CORS headers do not allow Authorization.');
      }
    }
    if (!packageJsonFileExists) {
      issues.add('Functions package.json is missing: ${packageJsonFile.path}.');
    } else {
      if (!packageJsonHasFirebaseAdmin) {
        issues.add('Functions package.json is missing firebase-admin.');
      }
      if (!packageJsonHasFirebaseFunctions) {
        issues.add('Functions package.json is missing firebase-functions.');
      }
    }
    if (!envFileExists) {
      warnings.add(
        'Functions .env was not found yet. `publisher-backend firebase deploy` writes PUBLISHER_AUTH_WEB_API_KEY before deployment.',
      );
    } else if (!envAuthKeyConfigured) {
      warnings.add(
        'Functions .env does not contain PUBLISHER_AUTH_WEB_API_KEY. Re-run `publisher-backend firebase deploy` after configuring --auth-web-api-key.',
      );
    }
    if (envUsesReservedAuthKey) {
      issues.add(
        'Functions .env still contains reserved FIREBASE_AUTH_WEB_API_KEY. Remove it and use PUBLISHER_AUTH_WEB_API_KEY.',
      );
    }

    return PublisherBackendFirebaseAuthStatusResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      projectId: settings.projectId,
      region: settings.region,
      functionName: settings.functionName,
      miniProgramId: settings.miniProgramId,
      backendRootPath: settings.backendRootPath,
      functionsRootPath: settings.functionsRootPath,
      authWebApiKeyConfigured:
          settings.authWebApiKey?.trim().isNotEmpty == true,
      scaffoldExists: scaffoldExists,
      authServiceFileExists: authServiceFileExists,
      routerFileExists: routerFileExists,
      routerAuthRoutesReady: routerAuthRoutesReady,
      routerAllowsAuthorizationHeader: routerAllowsAuthorizationHeader,
      packageJsonFileExists: packageJsonFileExists,
      packageJsonHasFirebaseAdmin: packageJsonHasFirebaseAdmin,
      packageJsonHasFirebaseFunctions: packageJsonHasFirebaseFunctions,
      envFilePath: envFile.path,
      envFileExists: envFileExists,
      envAuthKeyConfigured: envAuthKeyConfigured,
      envUsesReservedAuthKey: envUsesReservedAuthKey,
      ready: issues.isEmpty,
      deployEnvReady:
          envFileExists && envAuthKeyConfigured && !envUsesReservedAuthKey,
      issues: issues,
      warnings: warnings,
    );
  }

  Future<PublisherBackendFirebaseAccessKeyCreateResult>
  _firebaseAccessKeyCreateImpl(
    PublisherBackendFirebaseAccessKeyCreateRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendFirebaseSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
    );
    final keyId = _normalizeFirebaseAccessKeyId(request.keyId);
    final expiresAtUtc = _normalizeFirebaseAccessKeyExpiry(
      request.expiresAtUtc,
    );
    final existing = await _readFirestoreDocument(
      projectId: settings.projectId,
      documentPath: _firebaseAccessKeyDocumentPath(settings, keyId),
    );
    final existingActive = existing == null
        ? false
        : _firebaseAccessKeyEntryFromDocument(keyId, existing).currentlyActive;
    if (existingActive) {
      throw PublisherBackendException(
        'Firebase publisher backend access key "$keyId" already exists for '
        '${settings.miniProgramId}. Revoke or rotate it first.',
      );
    }

    final accessKey = _normalizePublisherBackendAccessKey(
      request.accessKey ?? _generatePublisherBackendAccessKey(),
    );
    final createdAtUtc = _clock().toUtc().toIso8601String();
    await _writeFirestoreDocument(
      projectId: settings.projectId,
      documentPath: _firebaseAccessKeyDocumentPath(settings, keyId),
      document: <String, Object?>{
        'keyId': keyId,
        'keyHash': _sha256Hex(accessKey),
        'lastFour': _lastFour(accessKey),
        'active': true,
        'createdAtUtc': createdAtUtc,
        'updatedAtUtc': createdAtUtc,
        if (expiresAtUtc != null) 'expiresAtUtc': expiresAtUtc,
      },
    );
    return PublisherBackendFirebaseAccessKeyCreateResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      projectId: settings.projectId,
      region: settings.region,
      functionName: settings.functionName,
      miniProgramId: settings.miniProgramId,
      backendBaseUrl: settings.functionUrl,
      keyId: keyId,
      accessKey: accessKey,
      createdAtUtc: createdAtUtc,
      expiresAtUtc: expiresAtUtc,
    );
  }

  Future<PublisherBackendFirebaseAccessKeyListResult>
  _firebaseAccessKeyListImpl(
    PublisherBackendFirebaseAccessKeyListRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendFirebaseSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
    );
    final documents = await _listFirestoreCollectionDocuments(
      projectId: settings.projectId,
      collectionPath: 'miniPrograms/${settings.miniProgramId}/accessKeys',
    );
    final keys = documents.map((document) {
      final keyId =
          _firestoreDocumentIdFromName(document['name']?.toString()) ??
          document['keyId']?.toString().trim() ??
          'unknown';
      return _firebaseAccessKeyEntryFromDocument(
        keyId,
        _fromFirestoreDocument(document),
      );
    }).toList()..sort((a, b) => a.keyId.compareTo(b.keyId));
    return PublisherBackendFirebaseAccessKeyListResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      projectId: settings.projectId,
      region: settings.region,
      functionName: settings.functionName,
      miniProgramId: settings.miniProgramId,
      backendBaseUrl: settings.functionUrl,
      keys: keys,
    );
  }

  Future<PublisherBackendFirebaseAccessKeyRevokeResult>
  _firebaseAccessKeyRevokeImpl(
    PublisherBackendFirebaseAccessKeyRevokeRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendFirebaseSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
    );
    final keyId = _normalizeFirebaseAccessKeyId(request.keyId);
    final documentPath = _firebaseAccessKeyDocumentPath(settings, keyId);
    final existing = await _readFirestoreDocument(
      projectId: settings.projectId,
      documentPath: documentPath,
    );
    if (existing == null) {
      throw PublisherBackendException(
        'No Firebase publisher backend access key "$keyId" was found for '
        '${settings.miniProgramId}.',
      );
    }
    final revokedAtUtc = _clock().toUtc().toIso8601String();
    await _writeFirestoreDocument(
      projectId: settings.projectId,
      documentPath: documentPath,
      document: <String, Object?>{
        ...existing,
        'keyId': keyId,
        'active': false,
        'revokedAtUtc': revokedAtUtc,
        'updatedAtUtc': revokedAtUtc,
      },
    );
    return PublisherBackendFirebaseAccessKeyRevokeResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      projectId: settings.projectId,
      region: settings.region,
      functionName: settings.functionName,
      miniProgramId: settings.miniProgramId,
      backendBaseUrl: settings.functionUrl,
      keyId: keyId,
      revokedAtUtc: revokedAtUtc,
    );
  }

  Future<PublisherBackendFirebaseAccessKeyRotateResult>
  _firebaseAccessKeyRotateImpl(
    PublisherBackendFirebaseAccessKeyRotateRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendFirebaseSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
    );
    final oldKeyId = _normalizeFirebaseAccessKeyId(request.keyId);
    final newKeyId = _normalizeFirebaseAccessKeyId(
      request.newKeyId?.trim().isNotEmpty == true
          ? request.newKeyId!.trim()
          : request.keyId,
    );
    final expiresAtUtc = _normalizeFirebaseAccessKeyExpiry(
      request.expiresAtUtc,
    );
    final oldDocumentPath = _firebaseAccessKeyDocumentPath(settings, oldKeyId);
    final oldDocument = await _readFirestoreDocument(
      projectId: settings.projectId,
      documentPath: oldDocumentPath,
    );
    if (oldDocument == null) {
      throw PublisherBackendException(
        'No Firebase publisher backend access key "$oldKeyId" was found for '
        '${settings.miniProgramId}.',
      );
    }
    if (newKeyId != oldKeyId) {
      final existingNewKey = await _readFirestoreDocument(
        projectId: settings.projectId,
        documentPath: _firebaseAccessKeyDocumentPath(settings, newKeyId),
      );
      if (existingNewKey != null &&
          _firebaseAccessKeyEntryFromDocument(
            newKeyId,
            existingNewKey,
          ).currentlyActive) {
        throw PublisherBackendException(
          'Firebase publisher backend access key "$newKeyId" already exists '
          'for ${settings.miniProgramId}.',
        );
      }
    }

    final accessKey = _normalizePublisherBackendAccessKey(
      request.accessKey ?? _generatePublisherBackendAccessKey(),
    );
    final rotatedAtUtc = _clock().toUtc().toIso8601String();
    await _writeFirestoreDocument(
      projectId: settings.projectId,
      documentPath: oldDocumentPath,
      document: <String, Object?>{
        ...oldDocument,
        'keyId': oldKeyId,
        'active': false,
        'revokedAtUtc': rotatedAtUtc,
        'updatedAtUtc': rotatedAtUtc,
      },
    );
    await _writeFirestoreDocument(
      projectId: settings.projectId,
      documentPath: _firebaseAccessKeyDocumentPath(settings, newKeyId),
      document: <String, Object?>{
        'keyId': newKeyId,
        'keyHash': _sha256Hex(accessKey),
        'lastFour': _lastFour(accessKey),
        'active': true,
        'createdAtUtc': newKeyId == oldKeyId
            ? (oldDocument['createdAtUtc']?.toString() ?? rotatedAtUtc)
            : rotatedAtUtc,
        'updatedAtUtc': rotatedAtUtc,
        'rotatedAtUtc': rotatedAtUtc,
        if (expiresAtUtc != null) 'expiresAtUtc': expiresAtUtc,
      },
    );
    return PublisherBackendFirebaseAccessKeyRotateResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      projectId: settings.projectId,
      region: settings.region,
      functionName: settings.functionName,
      miniProgramId: settings.miniProgramId,
      backendBaseUrl: settings.functionUrl,
      revokedKeyId: oldKeyId,
      newKeyId: newKeyId,
      accessKey: accessKey,
      rotatedAtUtc: rotatedAtUtc,
      expiresAtUtc: expiresAtUtc,
    );
  }

  Future<PublisherBackendFirebaseSmokeResult> _firebaseSmokeImpl(
    PublisherBackendFirebaseSmokeRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendFirebaseSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
    );
    if (!await _firebaseBackendPathsExist(settings.backendRootPath)) {
      return PublisherBackendFirebaseSmokeResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        projectId: settings.projectId,
        region: settings.region,
        functionName: settings.functionName,
        backendBaseUrl: settings.functionUrl,
        passed: false,
        routes: const <PublisherBackendFirebaseSmokeRouteResult>[],
        includeWrite: request.includeWrite,
        writeCouponId: request.writeCouponId,
        writeUserId: request.writeUserId,
        includeAuth: request.includeAuth,
        authCreateUser: request.authCreateUser,
        authEmail: request.includeAuth ? request.authEmail : null,
        accessKeyProvided: request.accessKey?.trim().isNotEmpty == true,
        error:
            'Firebase Functions publisher backend was not found. Run '
            '`miniprogram publisher-backend scaffold --template firebase-functions --storage firestore` first.',
      );
    }

    final baseUri = Uri.parse(settings.functionUrl);
    final routes = <PublisherBackendFirebaseSmokeRouteResult>[];
    for (final path in _publisherBackendFirebaseSmokeRoutePaths) {
      routes.add(
        await _probeFirebaseSmokeRoute(
          method: 'GET',
          path: path,
          uri: _resolveBackendRoute(baseUri, path),
          accessKey: request.accessKey,
        ),
      );
    }
    if (request.includeWrite) {
      routes.add(
        await _probeFirebaseSmokeWriteRoute(
          settings: settings,
          uri: _resolveBackendRoute(baseUri, '/coupon/redeem'),
          couponId: request.writeCouponId,
          userId: request.writeUserId,
          accessKey: request.accessKey,
        ),
      );
    }
    if (request.includeAuth) {
      routes.addAll(
        await _probeFirebaseSmokeAuthRoutes(
          baseUri: baseUri,
          email: request.authEmail?.trim() ?? '',
          password: request.authPassword ?? '',
          createUser: request.authCreateUser,
          accessKey: request.accessKey,
        ),
      );
    } else {
      routes.add(
        await _probeFirebaseProtectedSessionGuard(
          uri: _resolveBackendRoute(baseUri, '/auth/session'),
          accessKey: request.accessKey,
        ),
      );
    }
    return PublisherBackendFirebaseSmokeResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      projectId: settings.projectId,
      region: settings.region,
      functionName: settings.functionName,
      backendBaseUrl: settings.functionUrl,
      passed: routes.every((route) => route.passed),
      routes: routes,
      includeWrite: request.includeWrite,
      writeCouponId: request.writeCouponId,
      writeUserId: request.writeUserId,
      includeAuth: request.includeAuth,
      authCreateUser: request.authCreateUser,
      authEmail: request.includeAuth ? request.authEmail : null,
      accessKeyProvided: request.accessKey?.trim().isNotEmpty == true,
    );
  }

  Future<PublisherBackendFirebaseSeedResult> _firebaseSeedImpl(
    PublisherBackendFirebaseSeedRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendFirebaseSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
    );
    if (!await _firebaseBackendPathsExist(settings.backendRootPath)) {
      return PublisherBackendFirebaseSeedResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        projectId: settings.projectId,
        region: settings.region,
        functionName: settings.functionName,
        miniProgramId: settings.miniProgramId,
        seeded: false,
        itemCount: 0,
        appRecordCount: 0,
        couponCount: 0,
        authSessionCount: 0,
        storageMode: _publisherBackendStorageFirestore,
        backendBaseUrl: settings.functionUrl,
        error:
            'Firebase Functions publisher backend was not found. Run '
            '`miniprogram publisher-backend scaffold --template firebase-functions --storage firestore` first.',
      );
    }

    final seedData = await _readFirebaseSeedData(settings);
    final records = _buildFirestoreSeedRecords(settings, seedData);
    for (final record in records) {
      await _writeFirestoreDocument(
        projectId: settings.projectId,
        documentPath: record.documentPath,
        document: record.document,
      );
    }
    return PublisherBackendFirebaseSeedResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      projectId: settings.projectId,
      region: settings.region,
      functionName: settings.functionName,
      miniProgramId: settings.miniProgramId,
      seeded: true,
      itemCount: records.length,
      appRecordCount: records.length,
      couponCount: seedData.coupons.length,
      authSessionCount: 1,
      storageMode: _publisherBackendStorageFirestore,
      backendBaseUrl: settings.functionUrl,
    );
  }

  Future<PublisherBackendFirebaseDataStatusResult> _firebaseDataStatusImpl(
    PublisherBackendFirebaseDataStatusRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendFirebaseSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
    );
    if (!await _firebaseBackendPathsExist(settings.backendRootPath)) {
      return PublisherBackendFirebaseDataStatusResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        projectId: settings.projectId,
        region: settings.region,
        functionName: settings.functionName,
        miniProgramId: settings.miniProgramId,
        storageMode: _publisherBackendStorageFirestore,
        backendBaseUrl: settings.functionUrl,
        available: false,
        error:
            'Firebase Functions publisher backend was not found. Run '
            '`miniprogram publisher-backend scaffold --template firebase-functions --storage firestore` first.',
      );
    }

    try {
      final homeCount = await _countFirestoreCollection(
        projectId: settings.projectId,
        collectionPath: 'miniPrograms/${settings.miniProgramId}/home',
      );
      final sessionCount = await _countFirestoreCollection(
        projectId: settings.projectId,
        collectionPath: 'miniPrograms/${settings.miniProgramId}/sessions',
      );
      final couponCount = await _countFirestoreCollection(
        projectId: settings.projectId,
        collectionPath: 'miniPrograms/${settings.miniProgramId}/coupons',
      );
      final redemptionCount = await _countFirestoreCollection(
        projectId: settings.projectId,
        collectionPath: 'miniPrograms/${settings.miniProgramId}/redemptions',
      );
      return PublisherBackendFirebaseDataStatusResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        projectId: settings.projectId,
        region: settings.region,
        functionName: settings.functionName,
        miniProgramId: settings.miniProgramId,
        storageMode: _publisherBackendStorageFirestore,
        backendBaseUrl: settings.functionUrl,
        available: true,
        homeRecordCount: homeCount,
        authSessionCount: sessionCount,
        couponCount: couponCount,
        redemptionCount: redemptionCount,
        appRecordCount: homeCount + sessionCount + couponCount,
      );
    } on PublisherBackendException catch (error) {
      return PublisherBackendFirebaseDataStatusResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        projectId: settings.projectId,
        region: settings.region,
        functionName: settings.functionName,
        miniProgramId: settings.miniProgramId,
        storageMode: _publisherBackendStorageFirestore,
        backendBaseUrl: settings.functionUrl,
        available: false,
        error: error.message,
      );
    }
  }

  Future<PublisherBackendFirebaseDataExportResult> _firebaseDataExportImpl(
    PublisherBackendFirebaseDataExportRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendFirebaseSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
    );
    if (!await _firebaseBackendPathsExist(settings.backendRootPath)) {
      return PublisherBackendFirebaseDataExportResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        projectId: settings.projectId,
        region: settings.region,
        functionName: settings.functionName,
        miniProgramId: settings.miniProgramId,
        storageMode: _publisherBackendStorageFirestore,
        backendBaseUrl: settings.functionUrl,
        exported: false,
        includeRedemptions: request.includeRedemptions,
        appRecordCount: 0,
        redemptionCount: 0,
        itemCount: 0,
        error:
            'Firebase Functions publisher backend was not found. Run '
            '`miniprogram publisher-backend scaffold --template firebase-functions --storage firestore` first.',
      );
    }

    final appRecords = <Map<String, Object?>>[
      ...await _listFirestoreLogicalRecords(
        settings: settings,
        collection: 'home',
        recordType: 'home',
      ),
      ...await _listFirestoreLogicalRecords(
        settings: settings,
        collection: 'sessions',
        recordType: 'session',
      ),
      ...await _listFirestoreLogicalRecords(
        settings: settings,
        collection: 'coupons',
        recordType: 'coupon',
      ),
    ];
    final redemptionRecords = request.includeRedemptions
        ? await _listFirestoreLogicalRecords(
            settings: settings,
            collection: 'redemptions',
            recordType: 'redemption',
          )
        : <Map<String, Object?>>[];
    final records = <Map<String, Object?>>[...appRecords, ...redemptionRecords]
      ..sort(_compareFirestoreLogicalRecords);
    final exportedAtUtc = _clock().toUtc().toIso8601String();
    final outputPath = _resolveFirebaseDataExportPath(
      settings,
      request.outputPath,
    );
    final exportFile = File(outputPath);
    await exportFile.parent.create(recursive: true);
    await exportFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'schemaVersion': 1,
        'command': 'publisher-backend firebase data export',
        'provider': request.environment.provider,
        'environmentName': request.environment.name,
        'projectId': settings.projectId,
        'region': settings.region,
        'functionName': settings.functionName,
        'miniProgramId': settings.miniProgramId,
        'storageMode': _publisherBackendStorageFirestore,
        'exportedAtUtc': exportedAtUtc,
        'includeRedemptions': request.includeRedemptions,
        'appRecordCount': appRecords.length,
        'redemptionCount': redemptionRecords.length,
        'itemCount': records.length,
        'records': records,
      }),
    );
    return PublisherBackendFirebaseDataExportResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      projectId: settings.projectId,
      region: settings.region,
      functionName: settings.functionName,
      miniProgramId: settings.miniProgramId,
      storageMode: _publisherBackendStorageFirestore,
      backendBaseUrl: settings.functionUrl,
      exported: true,
      includeRedemptions: request.includeRedemptions,
      appRecordCount: appRecords.length,
      redemptionCount: redemptionRecords.length,
      itemCount: records.length,
      outputPath: outputPath,
      exportedAtUtc: exportedAtUtc,
    );
  }

  Future<PublisherBackendFirebaseDataImportResult> _firebaseDataImportImpl(
    PublisherBackendFirebaseDataImportRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendFirebaseSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
    );
    final inputPath = p.normalize(p.absolute(request.inputPath));
    if (!await _firebaseBackendPathsExist(settings.backendRootPath)) {
      return PublisherBackendFirebaseDataImportResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        projectId: settings.projectId,
        region: settings.region,
        functionName: settings.functionName,
        miniProgramId: settings.miniProgramId,
        storageMode: _publisherBackendStorageFirestore,
        backendBaseUrl: settings.functionUrl,
        succeeded: false,
        imported: false,
        dryRun: request.dryRun,
        includeRedemptions: request.includeRedemptions,
        appRecordCount: 0,
        redemptionCount: 0,
        skippedRedemptionCount: 0,
        itemCount: 0,
        inputPath: inputPath,
        error:
            'Firebase Functions publisher backend was not found. Run '
            '`miniprogram publisher-backend scaffold --template firebase-functions --storage firestore` first.',
      );
    }

    final importPlan = await _readFirebaseDataImportPlan(
      settings: settings,
      inputPath: inputPath,
      includeRedemptions: request.includeRedemptions,
    );
    if (!request.dryRun) {
      for (final record in importPlan.records) {
        await _writeFirestoreDocument(
          projectId: settings.projectId,
          documentPath: record.documentPath,
          document: record.data,
        );
      }
    }
    return PublisherBackendFirebaseDataImportResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      projectId: settings.projectId,
      region: settings.region,
      functionName: settings.functionName,
      miniProgramId: settings.miniProgramId,
      storageMode: _publisherBackendStorageFirestore,
      backendBaseUrl: settings.functionUrl,
      succeeded: true,
      imported: !request.dryRun,
      dryRun: request.dryRun,
      includeRedemptions: request.includeRedemptions,
      appRecordCount: importPlan.appRecordCount,
      redemptionCount: importPlan.redemptionCount,
      skippedRedemptionCount: importPlan.skippedRedemptionCount,
      itemCount: importPlan.records.length,
      inputPath: inputPath,
    );
  }

  Future<PublisherBackendFirebaseDataRedemptionsResult>
  _firebaseDataRedemptionsImpl(
    PublisherBackendFirebaseDataRedemptionsRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendFirebaseSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
    );
    if (!await _firebaseBackendPathsExist(settings.backendRootPath)) {
      return PublisherBackendFirebaseDataRedemptionsResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        projectId: settings.projectId,
        region: settings.region,
        functionName: settings.functionName,
        miniProgramId: settings.miniProgramId,
        storageMode: _publisherBackendStorageFirestore,
        backendBaseUrl: settings.functionUrl,
        available: false,
        limit: request.limit,
        matchedCount: 0,
        returnedCount: 0,
        records: const <Map<String, Object?>>[],
        couponId: request.couponId,
        userId: request.userId,
        error:
            'Firebase Functions publisher backend was not found. Run '
            '`miniprogram publisher-backend scaffold --template firebase-functions --storage firestore` first.',
      );
    }

    final records = await _listFirestoreLogicalRecords(
      settings: settings,
      collection: 'redemptions',
      recordType: 'redemption',
    );
    final matched = _filterRedemptionRecords(
      records,
      couponId: request.couponId,
      userId: request.userId,
    );
    final returned = matched.take(request.limit).toList();
    return PublisherBackendFirebaseDataRedemptionsResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      projectId: settings.projectId,
      region: settings.region,
      functionName: settings.functionName,
      miniProgramId: settings.miniProgramId,
      storageMode: _publisherBackendStorageFirestore,
      backendBaseUrl: settings.functionUrl,
      available: true,
      limit: request.limit,
      matchedCount: matched.length,
      returnedCount: returned.length,
      records: returned,
      couponId: request.couponId,
      userId: request.userId,
    );
  }

  Future<PublisherBackendFirebaseDestroyResult> _firebaseDestroyImpl(
    PublisherBackendFirebaseDestroyRequest request,
  ) async {
    final rootPath = await _requireMiniProgramRoot(request.miniProgramRootPath);
    final settings = _PublisherBackendFirebaseSettings.fromEnvironment(
      environment: request.environment,
      miniProgramRootPath: rootPath,
    );
    int? appRecordCount;
    int? redemptionCount;
    try {
      final status = await firebaseDataStatus(
        PublisherBackendFirebaseDataStatusRequest(
          miniProgramRootPath: rootPath,
          environment: request.environment,
        ),
      );
      appRecordCount = status.appRecordCount;
      redemptionCount = status.redemptionCount;
    } on Object catch (error) {
      if (!request.confirmDataLoss) {
        return PublisherBackendFirebaseDestroyResult(
          provider: request.environment.provider,
          environmentName: request.environment.name,
          projectId: settings.projectId,
          region: settings.region,
          functionName: settings.functionName,
          miniProgramId: settings.miniProgramId,
          backendBaseUrl: settings.functionUrl,
          deleted: false,
          dataLossConfirmed: false,
          appRecordCount: appRecordCount,
          redemptionCount: redemptionCount,
          blockedByData: true,
          error:
              'Could not inspect Firestore data before deleting the Firebase '
              'function. Export data first or pass --confirm-data-loss to '
              'continue. Detail: $error',
        );
      }
    }
    final totalRecords = (appRecordCount ?? 0) + (redemptionCount ?? 0);
    if (totalRecords > 0 && !request.confirmDataLoss) {
      return PublisherBackendFirebaseDestroyResult(
        provider: request.environment.provider,
        environmentName: request.environment.name,
        projectId: settings.projectId,
        region: settings.region,
        functionName: settings.functionName,
        miniProgramId: settings.miniProgramId,
        backendBaseUrl: settings.functionUrl,
        deleted: false,
        dataLossConfirmed: false,
        appRecordCount: appRecordCount,
        redemptionCount: redemptionCount,
        blockedByData: true,
        error:
            'Firestore has $totalRecords publisher backend record(s). '
            'Run `miniprogram publisher-backend firebase data export` first, '
            'then pass --confirm-data-loss if you still want to delete the '
            'Firebase function. Firestore data will not be deleted.',
      );
    }

    await _runFirebaseCommand(<String>[
      'functions:delete',
      settings.functionName,
      '--region',
      settings.region,
      '--project',
      settings.projectId,
      '--force',
    ], workingDirectory: settings.backendRootPath);
    await _clearFirebaseState(rootPath);
    return PublisherBackendFirebaseDestroyResult(
      provider: request.environment.provider,
      environmentName: request.environment.name,
      projectId: settings.projectId,
      region: settings.region,
      functionName: settings.functionName,
      miniProgramId: settings.miniProgramId,
      backendBaseUrl: settings.functionUrl,
      deleted: true,
      dataLossConfirmed: request.confirmDataLoss,
      appRecordCount: appRecordCount,
      redemptionCount: redemptionCount,
      deletedAtUtc: _clock().toUtc().toIso8601String(),
    );
  }
}
