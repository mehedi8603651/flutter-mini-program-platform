part of '../publisher_backend_starter.dart';

extension _PublisherBackendStarterRuntimeSmokeHelpers
    on PublisherBackendStarter {
  void _requireSuccess({
    required String executable,
    required List<String> arguments,
    required ProcessResult result,
    required String toolLabel,
  }) {
    if (result.exitCode == 0) {
      return;
    }
    final stdoutText = '${result.stdout}'.trim();
    final stderrText = '${result.stderr}'.trim();
    throw PublisherBackendException(
      '$toolLabel command failed.\n'
      'Command: $executable ${arguments.join(' ')}\n'
      'stdout: ${stdoutText.isEmpty ? '(empty)' : stdoutText}\n'
      'stderr: ${stderrText.isEmpty ? '(empty)' : stderrText}',
    );
  }

  Future<bool> _isProcessAlive(int pid) async {
    if (Platform.isWindows) {
      final result = await _shellRunner('tasklist', <String>[
        '/FI',
        'PID eq $pid',
        '/FO',
        'CSV',
        '/NH',
      ]);
      if (result.exitCode != 0) {
        return false;
      }
      final output = '${result.stdout}'.trim();
      return output.isNotEmpty &&
          !output.toLowerCase().contains('no tasks are running');
    }
    final result = await _shellRunner('ps', <String>['-p', '$pid']);
    if (result.exitCode != 0) {
      return false;
    }
    return const LineSplitter().convert('${result.stdout}'.trim()).length > 1;
  }

  Future<ProcessResult> _terminateProcess(int pid) {
    if (Platform.isWindows) {
      return _shellRunner('taskkill', <String>['/PID', '$pid', '/T', '/F']);
    }
    return _shellRunner('kill', <String>['$pid']);
  }

  Future<_PublisherBackendHealth> _probeHealth(
    Uri uri, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    try {
      final response = await _healthGetter(uri).timeout(timeout);
      return _PublisherBackendHealth(
        healthy: response.statusCode == 200,
        statusCode: response.statusCode,
        error: response.statusCode == 200
            ? null
            : 'Health endpoint returned ${response.statusCode}.',
      );
    } on TimeoutException {
      return const _PublisherBackendHealth(
        healthy: false,
        error: 'Health check timed out.',
      );
    } catch (error) {
      return _PublisherBackendHealth(healthy: false, error: '$error');
    }
  }

  Future<PublisherBackendAwsSmokeRouteResult> _probeSmokeRoute({
    required String method,
    required String path,
    required Uri uri,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      final response = await _healthGetter(uri).timeout(timeout);
      final passed = response.statusCode == 200;
      return PublisherBackendAwsSmokeRouteResult(
        method: method,
        path: path,
        uri: uri,
        passed: passed,
        statusCode: response.statusCode,
        error: passed ? null : 'Route returned ${response.statusCode}.',
      );
    } on TimeoutException {
      return PublisherBackendAwsSmokeRouteResult(
        method: method,
        path: path,
        uri: uri,
        passed: false,
        error: 'Route check timed out.',
      );
    } catch (error) {
      return PublisherBackendAwsSmokeRouteResult(
        method: method,
        path: path,
        uri: uri,
        passed: false,
        error: '$error',
      );
    }
  }

  Future<PublisherBackendAwsSmokeRouteResult> _probeSmokeWriteRoute({
    required Uri uri,
    required String couponId,
    required String userId,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    const path = '/coupon/redeem';
    try {
      final response = await _postRequester(
        uri,
        headers: const <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(<String, String>{
          'couponId': couponId,
          'userId': userId,
        }),
      ).timeout(timeout);
      final responseStatus = _responseStatus(response.body);
      final passed =
          response.statusCode == 200 &&
          (responseStatus == 'redeemed' ||
              responseStatus == 'already_redeemed');
      return PublisherBackendAwsSmokeRouteResult(
        method: 'POST',
        path: path,
        uri: uri,
        passed: passed,
        statusCode: response.statusCode,
        responseStatus: responseStatus,
        error: passed
            ? null
            : response.statusCode == 200
            ? 'Write route returned 200 without redeemed status.'
            : 'Route returned ${response.statusCode}.',
      );
    } on TimeoutException {
      return PublisherBackendAwsSmokeRouteResult(
        method: 'POST',
        path: path,
        uri: uri,
        passed: false,
        error: 'Route check timed out.',
      );
    } catch (error) {
      return PublisherBackendAwsSmokeRouteResult(
        method: 'POST',
        path: path,
        uri: uri,
        passed: false,
        error: '$error',
      );
    }
  }

  Future<PublisherBackendFirebaseSmokeRouteResult> _probeFirebaseSmokeRoute({
    required String method,
    required String path,
    required Uri uri,
    String? accessKey,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      final response = accessKey?.trim().isNotEmpty == true
          ? await _httpRequester(
              method,
              uri,
              headers: _firebaseSmokeHeaders(accessKey: accessKey),
            ).timeout(timeout)
          : await _healthGetter(uri).timeout(timeout);
      final passed = response.statusCode == 200;
      return PublisherBackendFirebaseSmokeRouteResult(
        method: method,
        path: path,
        uri: uri,
        passed: passed,
        statusCode: response.statusCode,
        error: passed ? null : 'Route returned ${response.statusCode}.',
      );
    } on TimeoutException {
      return PublisherBackendFirebaseSmokeRouteResult(
        method: method,
        path: path,
        uri: uri,
        passed: false,
        error: 'Route check timed out.',
      );
    } catch (error) {
      return PublisherBackendFirebaseSmokeRouteResult(
        method: method,
        path: path,
        uri: uri,
        passed: false,
        error: '$error',
      );
    }
  }

  Future<PublisherBackendFirebaseSmokeRouteResult>
  _probeFirebaseProtectedSessionGuard({
    required Uri uri,
    String? accessKey,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    const path = '/auth/session';
    try {
      final response = await _httpRequester(
        'GET',
        uri,
        headers: _firebaseSmokeHeaders(accessKey: accessKey),
      ).timeout(timeout);
      final body = _jsonObjectFromBody(response.body);
      final errorCode = body['errorCode']?.toString();
      final passed = response.statusCode == 401 && errorCode == 'auth_required';
      return PublisherBackendFirebaseSmokeRouteResult(
        method: 'GET',
        path: path,
        uri: uri,
        passed: passed,
        statusCode: response.statusCode,
        responseStatus: errorCode,
        error: passed
            ? null
            : 'Protected session route did not return auth_required.',
      );
    } on TimeoutException {
      return PublisherBackendFirebaseSmokeRouteResult(
        method: 'GET',
        path: path,
        uri: uri,
        passed: false,
        error: 'Route check timed out.',
      );
    } catch (error) {
      return PublisherBackendFirebaseSmokeRouteResult(
        method: 'GET',
        path: path,
        uri: uri,
        passed: false,
        error: '$error',
      );
    }
  }

  Future<List<PublisherBackendFirebaseSmokeRouteResult>>
  _probeFirebaseSmokeAuthRoutes({
    required Uri baseUri,
    required String email,
    required String password,
    required bool createUser,
    String? accessKey,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final routes = <PublisherBackendFirebaseSmokeRouteResult>[];
    if (createUser) {
      final signUp = await _probeFirebaseEmailAuthPost(
        path: '/auth/email/sign-up',
        uri: _resolveBackendRoute(baseUri, '/auth/email/sign-up'),
        body: <String, String>{'email': email, 'password': password},
        timeout: timeout,
        accessKey: accessKey,
        acceptExistingEmail: true,
      );
      routes.add(signUp.route);
      if (!routes.last.passed) {
        return routes;
      }
    }

    final signIn = await _probeFirebaseEmailAuthPost(
      path: '/auth/email/sign-in',
      uri: _resolveBackendRoute(baseUri, '/auth/email/sign-in'),
      body: <String, String>{'email': email, 'password': password},
      timeout: timeout,
      accessKey: accessKey,
    );
    routes.add(signIn.route);
    if (!signIn.route.passed) {
      return routes;
    }
    final idToken = signIn.idToken;
    final refreshToken = signIn.refreshToken;
    if (idToken == null || refreshToken == null) {
      return routes;
    }

    final refresh = await _probeFirebaseEmailAuthPost(
      path: '/auth/refresh',
      uri: _resolveBackendRoute(baseUri, '/auth/refresh'),
      body: <String, String>{'refreshToken': refreshToken},
      timeout: timeout,
      accessKey: accessKey,
      previousRefreshToken: refreshToken,
    );
    routes.add(refresh.route);
    if (!refresh.route.passed) {
      return routes;
    }
    final refreshedIdToken = refresh.idToken;
    final refreshedRefreshToken = refresh.refreshToken;
    if (refreshedIdToken == null || refreshedRefreshToken == null) {
      return routes;
    }

    routes.add(
      await _probeFirebaseAuthSessionRoute(
        uri: _resolveBackendRoute(baseUri, '/auth/session'),
        idToken: refreshedIdToken,
        expectAuthenticated: true,
        timeout: timeout,
        accessKey: accessKey,
      ),
    );
    if (!routes.last.passed) {
      return routes;
    }

    final signOut = await _probeFirebaseAuthSignOut(
      uri: _resolveBackendRoute(baseUri, '/auth/sign-out'),
      refreshToken: refreshedRefreshToken,
      timeout: timeout,
      accessKey: accessKey,
    );
    routes.add(signOut);
    if (!signOut.passed) {
      return routes;
    }

    routes.add(
      await _probeFirebaseAuthSessionRoute(
        uri: _resolveBackendRoute(baseUri, '/auth/session'),
        idToken: refreshedIdToken,
        expectAuthenticated: false,
        timeout: timeout,
        accessKey: accessKey,
      ),
    );
    return routes;
  }

  Future<_FirebaseAuthSmokePostResult> _probeFirebaseEmailAuthPost({
    required String path,
    required Uri uri,
    required Map<String, String> body,
    required Duration timeout,
    String? accessKey,
    bool acceptExistingEmail = false,
    String? previousRefreshToken,
  }) async {
    try {
      final response = await _postRequester(
        uri,
        headers: _firebaseSmokeHeaders(
          accessKey: accessKey,
          contentTypeJson: true,
        ),
        body: jsonEncode(body),
      ).timeout(timeout);
      final decoded = _jsonObjectFromBody(response.body);
      final errorCode = decoded['errorCode']?.toString();
      final existingEmailAccepted =
          acceptExistingEmail &&
          response.statusCode == 409 &&
          errorCode == 'email_already_exists';
      final sessionValid = _firebaseAuthSessionLooksValid(decoded);
      final rotated =
          previousRefreshToken == null ||
          decoded['refreshToken']?.toString() != previousRefreshToken;
      final passed =
          existingEmailAccepted ||
          (response.statusCode >= 200 &&
              response.statusCode < 300 &&
              sessionValid &&
              rotated);
      final status = existingEmailAccepted
          ? 'email_already_exists'
          : sessionValid
          ? previousRefreshToken == null
                ? 'authenticated'
                : 'refreshed'
          : errorCode;
      return _FirebaseAuthSmokePostResult(
        route: PublisherBackendFirebaseSmokeRouteResult(
          method: 'POST',
          path: path,
          uri: uri,
          passed: passed,
          statusCode: response.statusCode,
          responseStatus: status,
          error: passed
              ? null
              : previousRefreshToken != null && sessionValid && !rotated
              ? 'Refresh route did not rotate the publisher refresh token.'
              : 'Auth route did not return a valid SDK session.',
        ),
        idToken: decoded['idToken']?.toString(),
        refreshToken: decoded['refreshToken']?.toString(),
      );
    } on TimeoutException {
      return _FirebaseAuthSmokePostResult(
        route: PublisherBackendFirebaseSmokeRouteResult(
          method: 'POST',
          path: path,
          uri: uri,
          passed: false,
          error: 'Route check timed out.',
        ),
      );
    } catch (error) {
      return _FirebaseAuthSmokePostResult(
        route: PublisherBackendFirebaseSmokeRouteResult(
          method: 'POST',
          path: path,
          uri: uri,
          passed: false,
          error: '$error',
        ),
      );
    }
  }

  Future<PublisherBackendFirebaseSmokeRouteResult>
  _probeFirebaseAuthSessionRoute({
    required Uri uri,
    required String idToken,
    required bool expectAuthenticated,
    required Duration timeout,
    String? accessKey,
  }) async {
    const path = '/auth/session';
    try {
      final response = await _httpRequester(
        'GET',
        uri,
        headers: _firebaseSmokeHeaders(
          accessKey: accessKey,
          authorization: 'Bearer $idToken',
        ),
      ).timeout(timeout);
      final decoded = _jsonObjectFromBody(response.body);
      final authenticated = decoded['authenticated'] == true;
      final errorCode = decoded['errorCode']?.toString();
      final passed = expectAuthenticated
          ? response.statusCode == 200 && authenticated
          : response.statusCode == 401 &&
                (errorCode == 'auth_invalid_token' ||
                    errorCode == 'auth_session_revoked' ||
                    errorCode == 'auth_required');
      return PublisherBackendFirebaseSmokeRouteResult(
        method: 'GET',
        path: path,
        uri: uri,
        passed: passed,
        statusCode: response.statusCode,
        responseStatus: authenticated ? 'authenticated' : errorCode,
        error: passed
            ? null
            : expectAuthenticated
            ? 'Protected session route did not accept the signed-in token.'
            : 'Protected session route accepted a signed-out token.',
      );
    } on TimeoutException {
      return PublisherBackendFirebaseSmokeRouteResult(
        method: 'GET',
        path: path,
        uri: uri,
        passed: false,
        error: 'Route check timed out.',
      );
    } catch (error) {
      return PublisherBackendFirebaseSmokeRouteResult(
        method: 'GET',
        path: path,
        uri: uri,
        passed: false,
        error: '$error',
      );
    }
  }

  Future<PublisherBackendFirebaseSmokeRouteResult> _probeFirebaseAuthSignOut({
    required Uri uri,
    required String refreshToken,
    required Duration timeout,
    String? accessKey,
  }) async {
    const path = '/auth/sign-out';
    try {
      final response = await _postRequester(
        uri,
        headers: _firebaseSmokeHeaders(
          accessKey: accessKey,
          contentTypeJson: true,
        ),
        body: jsonEncode(<String, String>{'refreshToken': refreshToken}),
      ).timeout(timeout);
      final decoded = _jsonObjectFromBody(response.body);
      final status = decoded['status']?.toString();
      final passed =
          response.statusCode >= 200 &&
          response.statusCode < 300 &&
          status == 'signed_out';
      return PublisherBackendFirebaseSmokeRouteResult(
        method: 'POST',
        path: path,
        uri: uri,
        passed: passed,
        statusCode: response.statusCode,
        responseStatus: status ?? decoded['errorCode']?.toString(),
        error: passed ? null : 'Sign-out route did not revoke the session.',
      );
    } on TimeoutException {
      return PublisherBackendFirebaseSmokeRouteResult(
        method: 'POST',
        path: path,
        uri: uri,
        passed: false,
        error: 'Route check timed out.',
      );
    } catch (error) {
      return PublisherBackendFirebaseSmokeRouteResult(
        method: 'POST',
        path: path,
        uri: uri,
        passed: false,
        error: '$error',
      );
    }
  }

  Future<PublisherBackendFirebaseSmokeRouteResult>
  _probeFirebaseSmokeWriteRoute({
    required _PublisherBackendFirebaseSettings settings,
    required Uri uri,
    required String couponId,
    required String userId,
    String? accessKey,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    const path = '/coupon/redeem';
    final redemptionDocumentPath = _firebaseRedemptionDocumentPath(
      settings: settings,
      couponId: couponId,
      userId: userId,
    );
    try {
      final response = await _postRequester(
        uri,
        headers: _firebaseSmokeHeaders(
          accessKey: accessKey,
          contentTypeJson: true,
        ),
        body: jsonEncode(<String, String>{
          'couponId': couponId,
          'userId': userId,
        }),
      ).timeout(timeout);
      final responseStatus = _responseStatus(response.body);
      final routeAccepted =
          response.statusCode == 200 &&
          (responseStatus == 'redeemed' ||
              responseStatus == 'already_redeemed');
      if (!routeAccepted) {
        return PublisherBackendFirebaseSmokeRouteResult(
          method: 'POST',
          path: path,
          uri: uri,
          passed: false,
          statusCode: response.statusCode,
          responseStatus: responseStatus,
          redemptionVerified: false,
          redemptionDocumentPath: redemptionDocumentPath,
          error: response.statusCode == 200
              ? 'Write route returned 200 without redeemed status.'
              : 'Route returned ${response.statusCode}.',
        );
      }

      final verification = await _verifyFirebaseRedemptionDocument(
        settings: settings,
        documentPath: redemptionDocumentPath,
        couponId: couponId,
        userId: userId,
      );
      return PublisherBackendFirebaseSmokeRouteResult(
        method: 'POST',
        path: path,
        uri: uri,
        passed: verification.verified,
        statusCode: response.statusCode,
        responseStatus: responseStatus,
        redemptionVerified: verification.verified,
        redemptionDocumentPath: redemptionDocumentPath,
        verificationError: verification.error,
        error: verification.verified
            ? null
            : 'Write route succeeded but Firestore redemption verification failed.',
      );
    } on TimeoutException {
      return PublisherBackendFirebaseSmokeRouteResult(
        method: 'POST',
        path: path,
        uri: uri,
        passed: false,
        redemptionVerified: false,
        redemptionDocumentPath: redemptionDocumentPath,
        error: 'Route check timed out.',
      );
    } catch (error) {
      return PublisherBackendFirebaseSmokeRouteResult(
        method: 'POST',
        path: path,
        uri: uri,
        passed: false,
        redemptionVerified: false,
        redemptionDocumentPath: redemptionDocumentPath,
        error: '$error',
      );
    }
  }

  Future<_FirebaseRedemptionVerification> _verifyFirebaseRedemptionDocument({
    required _PublisherBackendFirebaseSettings settings,
    required String documentPath,
    required String couponId,
    required String userId,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final document = await _readFirestoreDocument(
          projectId: settings.projectId,
          documentPath: documentPath,
        );
        if (document == null) {
          lastError = 'Firestore document was not found.';
        } else {
          final documentCouponId = document['couponId']?.toString();
          final documentUserId = document['userId']?.toString();
          final documentStatus = document['status']?.toString();
          if (documentCouponId == couponId &&
              documentUserId == userId &&
              documentStatus == 'redeemed') {
            return const _FirebaseRedemptionVerification(verified: true);
          }
          lastError =
              'Firestore document did not match expected coupon/user/status.';
        }
      } on Object catch (error) {
        lastError = error;
      }
      if (attempt < 2) {
        await _delay(Duration(milliseconds: 250 * (1 << attempt)));
      }
    }
    return _FirebaseRedemptionVerification(
      verified: false,
      error: '$lastError',
    );
  }

  Map<String, Object?> _jsonObjectFromBody(String body) {
    try {
      final decoded = body.trim().isEmpty
          ? <String, Object?>{}
          : jsonDecode(body);
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {
      return const <String, Object?>{};
    }
    return const <String, Object?>{};
  }

  Map<String, String> _firebaseSmokeHeaders({
    String? accessKey,
    String? authorization,
    bool contentTypeJson = false,
  }) {
    final headers = <String, String>{
      if (contentTypeJson) 'Content-Type': 'application/json',
      if (authorization?.trim().isNotEmpty == true)
        'authorization': authorization!.trim(),
    };
    final normalizedAccessKey = accessKey?.trim();
    if (normalizedAccessKey != null && normalizedAccessKey.isNotEmpty) {
      headers['x-mini-program-access-key'] = normalizedAccessKey;
    }
    return headers;
  }

  Future<_PublisherBackendHealth> _waitForHealthCheck(
    Uri uri, {
    required Duration timeout,
    Duration attemptTimeout = const Duration(seconds: 1),
    Duration retryDelay = const Duration(milliseconds: 250),
  }) async {
    final deadline = _clock().add(timeout);
    _PublisherBackendHealth lastResult = const _PublisherBackendHealth(
      healthy: false,
      error: 'Health check did not start responding yet.',
    );
    while (_clock().isBefore(deadline)) {
      lastResult = await _probeHealth(uri, timeout: attemptTimeout);
      if (lastResult.healthy) {
        return lastResult;
      }
      await _delay(retryDelay);
    }
    return lastResult;
  }

  Future<bool> _waitForBackendUnavailable(
    Uri uri, {
    required Duration timeout,
  }) async {
    final deadline = _clock().add(timeout);
    while (_clock().isBefore(deadline)) {
      final result = await _probeHealth(
        uri,
        timeout: const Duration(milliseconds: 750),
      );
      if (!result.healthy) {
        return true;
      }
      await _delay(const Duration(milliseconds: 250));
    }
    final finalProbe = await _probeHealth(
      uri,
      timeout: const Duration(milliseconds: 750),
    );
    return !finalProbe.healthy;
  }

  Future<String> _readLogTail(String filePath, {int lineCount = 20}) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return '';
    }
    final lines = await file.readAsLines();
    if (lines.isEmpty) {
      return '';
    }
    return lines
        .skip(lines.length > lineCount ? lines.length - lineCount : 0)
        .join('\n');
  }
}
