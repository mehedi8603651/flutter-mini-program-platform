part of '../publisher_backend_starter.dart';

extension _PublisherBackendStarterFirebaseHelpers on PublisherBackendStarter {
  Future<bool> _firebaseBackendPathsExist(String backendRootPath) async {
    final firebaseJsonFile = File(p.join(backendRootPath, 'firebase.json'));
    final packageJsonFile = File(
      p.join(backendRootPath, 'functions', 'package.json'),
    );
    final indexFile = File(p.join(backendRootPath, 'functions', 'index.js'));
    final routerFile = File(p.join(backendRootPath, 'functions', 'router.js'));
    return await firebaseJsonFile.exists() &&
        await packageJsonFile.exists() &&
        await indexFile.exists() &&
        await routerFile.exists();
  }

  String _firebaseStatePath(String miniProgramRootPath) => p.join(
    miniProgramRootPath,
    '.mini_program',
    'publisher_backend.firebase.json',
  );

  Future<PublisherBackendFirebaseState?> _readFirebaseState(
    String miniProgramRootPath,
  ) async {
    final file = File(_firebaseStatePath(miniProgramRootPath));
    if (!await file.exists()) {
      return null;
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      throw const PublisherBackendException(
        'publisher_backend.firebase.json must contain a JSON object.',
      );
    }
    return PublisherBackendFirebaseState.fromJson(
      decoded.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  Future<void> _runFirebaseCommand(
    List<String> commandArguments, {
    required String workingDirectory,
  }) async {
    final result = await _shellRunner(
      'firebase',
      commandArguments,
      workingDirectory: workingDirectory,
    );
    _requireSuccess(
      executable: 'firebase',
      arguments: commandArguments,
      result: result,
      toolLabel: 'Firebase CLI',
    );
  }

  Future<bool> _ensureFirebaseDependencies(
    _PublisherBackendFirebaseSettings settings,
  ) async {
    final nodeModulesDirectory = Directory(
      p.join(settings.functionsRootPath, 'node_modules'),
    );
    if (await nodeModulesDirectory.exists()) {
      return false;
    }
    final arguments = <String>['install'];
    final result = await _shellRunner(
      'npm',
      arguments,
      workingDirectory: settings.functionsRootPath,
    );
    _requireSuccess(
      executable: 'npm',
      arguments: arguments,
      result: result,
      toolLabel: 'npm',
    );
    return true;
  }

  Future<_FirebasePublicInvokerResult> _ensureFirebasePublicInvoker(
    _PublisherBackendFirebaseSettings settings,
  ) async {
    final serviceName = _firebaseCloudRunServiceName(settings.functionName);
    final baseUri = Uri.parse(
      'https://run.googleapis.com/v2/projects/${settings.projectId}'
      '/locations/${settings.region}/services/$serviceName',
    );
    final policyResponse = await _firebaseAuthorizedRequest(
      'GET',
      Uri.parse('$baseUri:getIamPolicy'),
    );
    if (policyResponse.statusCode >= 400) {
      throw PublisherBackendException(
        'Could not read Cloud Run IAM policy for Firebase function '
        '"${settings.functionName}" (${policyResponse.statusCode}). '
        'Deploy may have succeeded, but public smoke checks can return 403. '
        'Grant Cloud Run Invoker to allUsers in the Firebase/Cloud console.',
      );
    }
    final decoded = policyResponse.body.trim().isEmpty
        ? <String, Object?>{}
        : jsonDecode(policyResponse.body);
    if (decoded is! Map) {
      throw const PublisherBackendException(
        'Cloud Run IAM policy response was not a JSON object.',
      );
    }
    final policy = decoded.map((key, value) => MapEntry(key.toString(), value));
    final bindings = _jsonObjectList(policy['bindings']);
    final invokerBinding = bindings.firstWhere(
      (binding) => binding['role'] == 'roles/run.invoker',
      orElse: () => <String, Object?>{},
    );
    final rawMembers = invokerBinding['members'];
    final members = rawMembers is List
        ? rawMembers.map((member) => member.toString()).toList()
        : <String>[];
    if (members.contains('allUsers')) {
      return const _FirebasePublicInvokerResult(
        configured: true,
        changed: false,
      );
    }
    if (invokerBinding.isEmpty) {
      bindings.add(<String, Object?>{
        'role': 'roles/run.invoker',
        'members': <String>['allUsers'],
      });
    } else {
      invokerBinding['members'] = <String>[...members, 'allUsers'];
    }
    final body = jsonEncode(<String, Object?>{
      'policy': <String, Object?>{
        if (policy['etag'] != null) 'etag': policy['etag'],
        'bindings': bindings,
      },
    });
    final response = await _firebaseAuthorizedRequest(
      'POST',
      Uri.parse('$baseUri:setIamPolicy'),
      body: body,
    );
    if (response.statusCode >= 400) {
      throw PublisherBackendException(
        'Could not grant public Cloud Run Invoker for Firebase function '
        '"${settings.functionName}" (${response.statusCode}). '
        'Smoke checks may return 403 until allUsers has roles/run.invoker.',
      );
    }
    return const _FirebasePublicInvokerResult(configured: true, changed: true);
  }

  Future<_FirebaseAuthTokenCreatorResult> _ensureFirebaseAuthTokenCreator(
    _PublisherBackendFirebaseSettings settings,
  ) async {
    final serviceAccountEmail =
        await _firebaseFunctionServiceAccountEmail(settings) ??
        await _firebaseDefaultComputeServiceAccountEmail(settings);
    final member = 'serviceAccount:$serviceAccountEmail';
    final baseUri = Uri.parse(
      'https://cloudresourcemanager.googleapis.com/v1/projects/'
      '${settings.projectId}',
    );
    final policyResponse = await _firebaseAuthorizedRequest(
      'POST',
      Uri.parse('$baseUri:getIamPolicy'),
      body: jsonEncode(<String, Object?>{}),
    );
    if (policyResponse.statusCode >= 400) {
      throw PublisherBackendException(
        'Could not read project IAM policy for Firebase auth service account '
        '"$serviceAccountEmail" (${policyResponse.statusCode}). '
        'Publisher-owned email auth may fail until the service account can '
        'sign custom tokens.',
      );
    }
    final decoded = policyResponse.body.trim().isEmpty
        ? <String, Object?>{}
        : jsonDecode(policyResponse.body);
    if (decoded is! Map) {
      throw const PublisherBackendException(
        'Service account IAM policy response was not a JSON object.',
      );
    }
    final policy = decoded.map((key, value) => MapEntry(key.toString(), value));
    final bindings = _jsonObjectList(policy['bindings']);
    final tokenCreatorBinding = bindings.firstWhere(
      (binding) => binding['role'] == 'roles/iam.serviceAccountTokenCreator',
      orElse: () => <String, Object?>{},
    );
    final rawMembers = tokenCreatorBinding['members'];
    final members = rawMembers is List
        ? rawMembers.map((member) => member.toString()).toList()
        : <String>[];
    if (members.contains(member)) {
      return _FirebaseAuthTokenCreatorResult(
        configured: true,
        changed: false,
        serviceAccountEmail: serviceAccountEmail,
      );
    }
    if (tokenCreatorBinding.isEmpty) {
      bindings.add(<String, Object?>{
        'role': 'roles/iam.serviceAccountTokenCreator',
        'members': <String>[member],
      });
    } else {
      tokenCreatorBinding['members'] = <String>[...members, member];
    }
    final body = jsonEncode(<String, Object?>{
      'policy': <String, Object?>{
        if (policy['etag'] != null) 'etag': policy['etag'],
        'bindings': bindings,
      },
    });
    final response = await _firebaseAuthorizedRequest(
      'POST',
      Uri.parse('$baseUri:setIamPolicy'),
      body: body,
    );
    if (response.statusCode >= 400) {
      throw PublisherBackendException(
        'Could not grant roles/iam.serviceAccountTokenCreator to Firebase auth '
        'service account "$serviceAccountEmail" (${response.statusCode}). '
        'Grant this role to the service account before running auth '
        'smoke.',
      );
    }
    return _FirebaseAuthTokenCreatorResult(
      configured: true,
      changed: true,
      serviceAccountEmail: serviceAccountEmail,
    );
  }

  Future<String?> _firebaseFunctionServiceAccountEmail(
    _PublisherBackendFirebaseSettings settings,
  ) async {
    final response = await _firebaseAuthorizedRequest(
      'GET',
      Uri.parse(
        'https://cloudfunctions.googleapis.com/v2/projects/${settings.projectId}'
        '/locations/${settings.region}/functions/${settings.functionName}',
      ),
    );
    if (response.statusCode == 404) {
      return null;
    }
    if (response.statusCode >= 400) {
      throw PublisherBackendException(
        'Could not read Firebase function service account '
        '(${response.statusCode}).',
      );
    }
    final decoded = response.body.trim().isEmpty
        ? <String, Object?>{}
        : jsonDecode(response.body);
    if (decoded is! Map) {
      throw const PublisherBackendException(
        'Firebase function response was not a JSON object.',
      );
    }
    final serviceConfig = decoded['serviceConfig'];
    if (serviceConfig is Map) {
      final email = serviceConfig['serviceAccountEmail']?.toString().trim();
      if (email != null && email.isNotEmpty) {
        return email;
      }
    }
    return null;
  }

  Future<String> _firebaseDefaultComputeServiceAccountEmail(
    _PublisherBackendFirebaseSettings settings,
  ) async {
    final response = await _firebaseAuthorizedRequest(
      'GET',
      Uri.parse(
        'https://cloudresourcemanager.googleapis.com/v1/projects/'
        '${settings.projectId}',
      ),
    );
    if (response.statusCode >= 400) {
      throw PublisherBackendException(
        'Could not read Firebase project number (${response.statusCode}).',
      );
    }
    final decoded = response.body.trim().isEmpty
        ? <String, Object?>{}
        : jsonDecode(response.body);
    if (decoded is! Map) {
      throw const PublisherBackendException(
        'Firebase project response was not a JSON object.',
      );
    }
    final projectNumber = decoded['projectNumber']?.toString().trim();
    if (projectNumber == null || projectNumber.isEmpty) {
      throw const PublisherBackendException(
        'Firebase project response did not include projectNumber.',
      );
    }
    return '$projectNumber-compute@developer.gserviceaccount.com';
  }

  String _firebaseCloudRunServiceName(String functionName) {
    return functionName
        .replaceAll(RegExp(r'[^A-Za-z0-9-]+'), '-')
        .toLowerCase();
  }

  Future<_PublisherBackendFirebaseSeedData> _readFirebaseSeedData(
    _PublisherBackendFirebaseSettings settings,
  ) async {
    final dataRootPath = p.join(settings.functionsRootPath, 'data');
    final home = await _readJsonObjectFile(
      p.join(dataRootPath, 'home_bootstrap.json'),
      label: 'home_bootstrap.json',
    );
    final session = await _readJsonObjectFile(
      p.join(dataRootPath, 'session.json'),
      label: 'session.json',
    );
    final couponsRoot = await _readJsonObjectFile(
      p.join(dataRootPath, 'coupons_list.json'),
      label: 'coupons_list.json',
    );
    final rawCoupons = couponsRoot['coupons'];
    if (rawCoupons is! List) {
      throw const PublisherBackendException(
        'coupons_list.json must contain a "coupons" list.',
      );
    }
    final coupons = <Map<String, Object?>>[];
    for (final rawCoupon in rawCoupons) {
      if (rawCoupon is! Map) {
        throw const PublisherBackendException(
          'Every coupons_list.json coupon must be a JSON object.',
        );
      }
      final coupon = rawCoupon.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final couponId = coupon['id']?.toString().trim();
      if (couponId == null || couponId.isEmpty) {
        throw const PublisherBackendException(
          'Every coupons_list.json coupon must contain a non-empty "id".',
        );
      }
      coupons.add(coupon);
    }
    return _PublisherBackendFirebaseSeedData(
      home: home,
      session: session,
      coupons: coupons,
    );
  }

  List<_FirestoreSeedRecord> _buildFirestoreSeedRecords(
    _PublisherBackendFirebaseSettings settings,
    _PublisherBackendFirebaseSeedData seedData,
  ) {
    final appPath = 'miniPrograms/${settings.miniProgramId}';
    return <_FirestoreSeedRecord>[
      _FirestoreSeedRecord(
        documentPath: '$appPath/home/bootstrap',
        document: seedData.home,
      ),
      _FirestoreSeedRecord(
        documentPath: '$appPath/sessions/demo',
        document: seedData.session,
      ),
      for (var index = 0; index < seedData.coupons.length; index++)
        _FirestoreSeedRecord(
          documentPath: '$appPath/coupons/${seedData.coupons[index]['id']}',
          document: <String, Object?>{
            ...seedData.coupons[index],
            'sortIndex': index,
          },
        ),
    ];
  }

  Future<void> _writeFirestoreDocument({
    required String projectId,
    required String documentPath,
    required Map<String, Object?> document,
  }) async {
    final uri = _firestoreDocumentUri(
      projectId: projectId,
      documentPath: documentPath,
    );
    final response = await _firebaseAuthorizedRequest(
      'PATCH',
      uri,
      body: jsonEncode(_toFirestoreDocument(document)),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PublisherBackendException(
        'Firestore seed failed for "$documentPath" (${response.statusCode}).',
      );
    }
  }

  Future<Map<String, Object?>?> _readFirestoreDocument({
    required String projectId,
    required String documentPath,
  }) async {
    final uri = _firestoreDocumentUri(
      projectId: projectId,
      documentPath: documentPath,
    );
    final response = await _firebaseAuthorizedRequest('GET', uri);
    if (response.statusCode == 404) {
      return null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PublisherBackendException(
        'Firestore read failed for "$documentPath" (${response.statusCode}).',
      );
    }
    final decoded = response.body.trim().isEmpty
        ? <String, Object?>{}
        : jsonDecode(response.body);
    if (decoded is! Map) {
      throw const PublisherBackendException(
        'Firestore read response was not a JSON object.',
      );
    }
    return _fromFirestoreDocument(
      decoded.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  Future<int> _countFirestoreCollection({
    required String projectId,
    required String collectionPath,
  }) async {
    var total = 0;
    String? pageToken;
    do {
      final query = <String, String>{'pageSize': '300'};
      if (pageToken != null && pageToken.isNotEmpty) {
        query['pageToken'] = pageToken;
      }
      final uri = _firestoreCollectionUri(
        projectId: projectId,
        collectionPath: collectionPath,
        queryParameters: query,
      );
      final response = await _firebaseAuthorizedRequest('GET', uri);
      if (response.statusCode == 404) {
        return 0;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw PublisherBackendException(
          'Firestore data status failed for "$collectionPath" '
          '(${response.statusCode}).',
        );
      }
      final decoded = response.body.trim().isEmpty
          ? <String, Object?>{}
          : jsonDecode(response.body);
      if (decoded is! Map) {
        throw const PublisherBackendException(
          'Firestore data status response was not a JSON object.',
        );
      }
      final documents = decoded['documents'];
      if (documents is List) {
        total += documents.length;
      }
      pageToken = decoded['nextPageToken']?.toString();
    } while (pageToken != null && pageToken.isNotEmpty);
    return total;
  }

  Future<List<Map<String, Object?>>> _listFirestoreLogicalRecords({
    required _PublisherBackendFirebaseSettings settings,
    required String collection,
    required String recordType,
  }) async {
    final collectionPath = 'miniPrograms/${settings.miniProgramId}/$collection';
    final documents = await _listFirestoreCollectionDocuments(
      projectId: settings.projectId,
      collectionPath: collectionPath,
    );
    return documents.map((document) {
      final documentPath =
          _firestoreDocumentPathFromName(document['name']?.toString()) ??
          '$collectionPath/${_firestoreDocumentIdFromName(document['name']?.toString()) ?? ''}';
      final documentId =
          _firestoreDocumentIdFromName(document['name']?.toString()) ??
          documentPath.split('/').last;
      return <String, Object?>{
        'recordType': recordType,
        'collection': collection,
        'documentId': documentId,
        'documentPath': documentPath,
        'data': _fromFirestoreDocument(document),
      };
    }).toList();
  }

  Future<List<Map<String, Object?>>> _listFirestoreCollectionDocuments({
    required String projectId,
    required String collectionPath,
  }) async {
    final results = <Map<String, Object?>>[];
    String? pageToken;
    do {
      final query = <String, String>{'pageSize': '300'};
      if (pageToken != null && pageToken.isNotEmpty) {
        query['pageToken'] = pageToken;
      }
      final uri = _firestoreCollectionUri(
        projectId: projectId,
        collectionPath: collectionPath,
        queryParameters: query,
      );
      final response = await _firebaseAuthorizedRequest('GET', uri);
      if (response.statusCode == 404) {
        return results;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw PublisherBackendException(
          'Firestore list failed for "$collectionPath" (${response.statusCode}).',
        );
      }
      final decoded = response.body.trim().isEmpty
          ? <String, Object?>{}
          : jsonDecode(response.body);
      if (decoded is! Map) {
        throw const PublisherBackendException(
          'Firestore list response was not a JSON object.',
        );
      }
      final documents = decoded['documents'];
      if (documents is List) {
        results.addAll(
          documents.whereType<Map>().map(
            (document) =>
                document.map((key, value) => MapEntry(key.toString(), value)),
          ),
        );
      }
      pageToken = decoded['nextPageToken']?.toString();
    } while (pageToken != null && pageToken.isNotEmpty);
    return results;
  }

  Map<String, Object?> _fromFirestoreDocument(Map<String, Object?> document) {
    final fields = document['fields'];
    if (fields is! Map) {
      return <String, Object?>{};
    }
    return fields.map(
      (key, value) => MapEntry(
        key.toString(),
        value is Map
            ? _fromFirestoreValue(
                value.map((key, value) => MapEntry(key.toString(), value)),
              )
            : null,
      ),
    );
  }

  Object? _fromFirestoreValue(Map<String, Object?> value) {
    if (value.containsKey('nullValue')) {
      return null;
    }
    if (value.containsKey('booleanValue')) {
      return value['booleanValue'] == true;
    }
    if (value.containsKey('integerValue')) {
      return int.tryParse(value['integerValue']?.toString() ?? '') ??
          value['integerValue']?.toString();
    }
    if (value.containsKey('doubleValue')) {
      final raw = value['doubleValue'];
      return raw is num ? raw : num.tryParse(raw?.toString() ?? '');
    }
    if (value.containsKey('stringValue')) {
      return value['stringValue']?.toString() ?? '';
    }
    if (value.containsKey('timestampValue')) {
      return value['timestampValue']?.toString() ?? '';
    }
    if (value.containsKey('arrayValue')) {
      final arrayValue = value['arrayValue'];
      if (arrayValue is! Map) {
        return <Object?>[];
      }
      final values = arrayValue['values'];
      if (values is! List) {
        return <Object?>[];
      }
      return values.map((nested) {
        if (nested is! Map) {
          return null;
        }
        return _fromFirestoreValue(
          nested.map((key, value) => MapEntry(key.toString(), value)),
        );
      }).toList();
    }
    if (value.containsKey('mapValue')) {
      final mapValue = value['mapValue'];
      if (mapValue is! Map) {
        return <String, Object?>{};
      }
      final fields = mapValue['fields'];
      if (fields is! Map) {
        return <String, Object?>{};
      }
      return fields.map((key, nested) {
        if (nested is! Map) {
          return MapEntry(key.toString(), null);
        }
        return MapEntry(
          key.toString(),
          _fromFirestoreValue(
            nested.map((key, value) => MapEntry(key.toString(), value)),
          ),
        );
      });
    }
    if (value.containsKey('referenceValue')) {
      return value['referenceValue']?.toString() ?? '';
    }
    if (value.containsKey('bytesValue')) {
      return value['bytesValue']?.toString() ?? '';
    }
    if (value.containsKey('geoPointValue')) {
      final point = value['geoPointValue'];
      return point is Map
          ? point.map((key, value) => MapEntry(key.toString(), value))
          : <String, Object?>{};
    }
    return null;
  }

  Future<_PublisherBackendFirebaseDataImportPlan> _readFirebaseDataImportPlan({
    required _PublisherBackendFirebaseSettings settings,
    required String inputPath,
    required bool includeRedemptions,
  }) async {
    final inputFile = File(inputPath);
    if (!await inputFile.exists()) {
      throw PublisherBackendException(
        'Firebase publisher backend data import file was not found: $inputPath',
      );
    }
    final decoded = jsonDecode(await inputFile.readAsString());
    if (decoded is! Map) {
      throw PublisherBackendException(
        'Firebase publisher backend data import file must be a JSON object: '
        '$inputPath',
      );
    }
    final export = decoded.map((key, value) => MapEntry(key.toString(), value));
    if (export['schemaVersion'] != 1) {
      throw const PublisherBackendException(
        'Firebase publisher backend data import file has an unsupported schemaVersion.',
      );
    }
    final miniProgramId = export['miniProgramId']?.toString().trim();
    if (miniProgramId != settings.miniProgramId) {
      throw PublisherBackendException(
        'Firebase publisher backend data import file belongs to mini-program '
        '"$miniProgramId", not "${settings.miniProgramId}".',
      );
    }
    final rawRecords = export['records'];
    if (rawRecords is! List) {
      throw const PublisherBackendException(
        'Firebase publisher backend data import file is missing a records array.',
      );
    }

    final records = <_FirestoreImportRecord>[];
    var appRecordCount = 0;
    var redemptionCount = 0;
    var skippedRedemptionCount = 0;
    for (final rawRecord in rawRecords) {
      if (rawRecord is! Map) {
        throw const PublisherBackendException(
          'Firebase publisher backend data import records must be JSON objects.',
        );
      }
      final record = rawRecord.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final collection = record['collection']?.toString().trim() ?? '';
      final documentId = record['documentId']?.toString().trim() ?? '';
      if (!_firebaseDataCollections.contains(collection)) {
        throw PublisherBackendException(
          'Firebase publisher backend data import record has unsupported '
          'collection "$collection".',
        );
      }
      if (documentId.isEmpty || documentId.contains('/')) {
        throw PublisherBackendException(
          'Firebase publisher backend data import record has invalid documentId '
          '"$documentId".',
        );
      }
      final rawData = record['data'];
      if (rawData is! Map) {
        throw const PublisherBackendException(
          'Firebase publisher backend data import records must contain data objects.',
        );
      }
      if (collection == 'redemptions') {
        if (!includeRedemptions) {
          skippedRedemptionCount++;
          continue;
        }
        redemptionCount++;
      } else {
        appRecordCount++;
      }
      records.add(
        _FirestoreImportRecord(
          documentPath:
              'miniPrograms/${settings.miniProgramId}/$collection/$documentId',
          data: rawData.map((key, value) => MapEntry(key.toString(), value)),
        ),
      );
    }
    return _PublisherBackendFirebaseDataImportPlan(
      records: records,
      appRecordCount: appRecordCount,
      redemptionCount: redemptionCount,
      skippedRedemptionCount: skippedRedemptionCount,
    );
  }

  Future<http.Response> _firebaseAuthorizedRequest(
    String method,
    Uri uri, {
    Object? body,
  }) async {
    Object? lastError;
    var refreshedAfterUnauthorized = false;
    for (var attempt = 0; attempt < 3; attempt++) {
      final token = await _firebaseAccessTokenProvider();
      if (token == null || token.trim().isEmpty) {
        throw const PublisherBackendException(
          'Firebase CLI access token was not found. Run `firebase login`, or set '
          'FIREBASE_TOKEN for non-interactive environments.',
        );
      }
      try {
        final response = await _httpRequester(
          method,
          uri,
          headers: <String, String>{
            'authorization': 'Bearer ${token.trim()}',
            if (body != null) 'content-type': 'application/json',
          },
          body: body,
        );
        if (response.statusCode == 401 && !refreshedAfterUnauthorized) {
          refreshedAfterUnauthorized = true;
          if (attempt < 2) {
            await _delay(const Duration(milliseconds: 300));
            continue;
          }
        }
        return response;
      } on http.ClientException catch (error) {
        lastError = error;
      } on SocketException catch (error) {
        lastError = error;
      } on TlsException catch (error) {
        lastError = error;
      }
      if (attempt < 2) {
        await _delay(Duration(milliseconds: 300 * (1 << attempt)));
      }
    }
    throw PublisherBackendException('Firebase HTTP request failed: $lastError');
  }

  Map<String, Object?> _toFirestoreDocument(Map<String, Object?> document) {
    return <String, Object?>{
      'fields': document.map(
        (key, value) => MapEntry(key, _toFirestoreValue(value)),
      ),
    };
  }

  Map<String, Object?> _toFirestoreValue(Object? value) {
    if (value == null) {
      return <String, Object?>{'nullValue': null};
    }
    if (value is bool) {
      return <String, Object?>{'booleanValue': value};
    }
    if (value is int) {
      return <String, Object?>{'integerValue': value.toString()};
    }
    if (value is num) {
      return <String, Object?>{'doubleValue': value};
    }
    if (value is String) {
      return <String, Object?>{'stringValue': value};
    }
    if (value is List) {
      return <String, Object?>{
        'arrayValue': <String, Object?>{
          'values': value.map(_toFirestoreValue).toList(),
        },
      };
    }
    if (value is Map) {
      return <String, Object?>{
        'mapValue': <String, Object?>{
          'fields': value.map(
            (key, nestedValue) =>
                MapEntry(key.toString(), _toFirestoreValue(nestedValue)),
          ),
        },
      };
    }
    return <String, Object?>{'stringValue': value.toString()};
  }

  List<Map<String, Object?>> _jsonObjectList(Object? value) {
    if (value is! List) {
      return <Map<String, Object?>>[];
    }
    return value
        .whereType<Map>()
        .map(
          (entry) => entry.map((key, value) => MapEntry(key.toString(), value)),
        )
        .toList();
  }

  String _firebaseRedemptionDocumentPath({
    required _PublisherBackendFirebaseSettings settings,
    required String couponId,
    required String userId,
  }) {
    return 'miniPrograms/${settings.miniProgramId}/redemptions/'
        '${_safeFirestoreDocumentId(userId)}_${_safeFirestoreDocumentId(couponId)}';
  }

  bool _firebaseAuthSessionLooksValid(Map<String, Object?> body) {
    final user = body['user'];
    final idToken = body['idToken']?.toString().trim() ?? '';
    final refreshToken = body['refreshToken']?.toString().trim() ?? '';
    final expiresIn = body['expiresIn'];
    final expiresAtUtc = body['expiresAtUtc']?.toString().trim() ?? '';
    final expiresInSeconds = switch (expiresIn) {
      int value => value,
      String value => int.tryParse(value),
      _ => null,
    };
    final expiryConfigured =
        (expiresInSeconds != null && expiresInSeconds > 0) ||
        expiresAtUtc.isNotEmpty;
    return body['authenticated'] == true &&
        user is Map &&
        (user['uid']?.toString().trim().isNotEmpty ?? false) &&
        idToken.isNotEmpty &&
        refreshToken.isNotEmpty &&
        expiryConfigured;
  }
}
