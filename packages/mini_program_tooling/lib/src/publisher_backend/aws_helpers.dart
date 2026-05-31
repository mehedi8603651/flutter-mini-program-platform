part of '../publisher_backend_starter.dart';

extension _PublisherBackendStarterAwsHelpers on PublisherBackendStarter {
  Future<PublisherBackendAwsState?> _readAwsState(
    String miniProgramRootPath,
  ) async {
    final file = File(_awsStatePath(miniProgramRootPath));
    if (!await file.exists()) {
      return null;
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      throw const PublisherBackendException(
        'publisher_backend.aws.json must contain a JSON object.',
      );
    }
    return PublisherBackendAwsState.fromJson(
      decoded.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  Future<void> _runSamCommand(
    _PublisherBackendAwsSettings settings,
    List<String> commandArguments, {
    required String workingDirectory,
  }) async {
    final arguments = <String>[
      ...commandArguments,
      if (settings.awsProfile != null) '--profile',
      if (settings.awsProfile != null) settings.awsProfile!,
    ];
    final result = await _shellRunner(
      'sam',
      arguments,
      workingDirectory: workingDirectory,
    );
    _requireSuccess(
      executable: 'sam',
      arguments: arguments,
      result: result,
      toolLabel: 'AWS SAM CLI',
    );
  }

  Future<void> _runAwsCommand(
    _PublisherBackendAwsSettings settings,
    List<String> commandArguments,
  ) async {
    final arguments = <String>[
      ..._awsGlobalArguments(settings),
      ...commandArguments,
    ];
    final result = await _shellRunner('aws', arguments);
    _requireSuccess(
      executable: 'aws',
      arguments: arguments,
      result: result,
      toolLabel: 'AWS CLI',
    );
  }

  Future<Map<String, dynamic>> _runAwsJsonCommand(
    _PublisherBackendAwsSettings settings,
    List<String> commandArguments, {
    bool allowEmptyJsonOutput = false,
  }) async {
    final arguments = <String>[
      ..._awsGlobalArguments(settings),
      ...commandArguments,
      '--output',
      'json',
    ];
    final result = await _shellRunner('aws', arguments);
    _requireSuccess(
      executable: 'aws',
      arguments: arguments,
      result: result,
      toolLabel: 'AWS CLI',
    );
    final stdoutText = '${result.stdout}'.trim();
    if (stdoutText.isEmpty) {
      if (allowEmptyJsonOutput) {
        return <String, dynamic>{};
      }
      throw PublisherBackendException(
        'AWS CLI returned no JSON output for command: aws ${arguments.join(' ')}',
      );
    }
    final decoded = jsonDecode(stdoutText);
    if (decoded is! Map) {
      throw PublisherBackendException(
        'AWS CLI returned non-object JSON for command: aws ${arguments.join(' ')}',
      );
    }
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }

  Future<Map<String, dynamic>?> _describeStack(
    _PublisherBackendAwsSettings settings,
  ) async {
    final arguments = <String>[
      ..._awsGlobalArguments(settings),
      'cloudformation',
      'describe-stacks',
      '--stack-name',
      settings.stackName,
      '--output',
      'json',
    ];
    final result = await _shellRunner('aws', arguments);
    if (result.exitCode != 0) {
      final stderrText = '${result.stderr}'.trim();
      if (stderrText.contains('does not exist') ||
          stderrText.contains('Stack with id') ||
          stderrText.contains('ValidationError')) {
        return null;
      }
      _requireSuccess(
        executable: 'aws',
        arguments: arguments,
        result: result,
        toolLabel: 'AWS CLI',
      );
    }
    final stdoutText = '${result.stdout}'.trim();
    if (stdoutText.isEmpty) {
      return null;
    }
    final decoded = jsonDecode(stdoutText);
    if (decoded is! Map) {
      throw const PublisherBackendException(
        'AWS CLI returned non-object JSON for stack describe command.',
      );
    }
    final stacks = decoded['Stacks'];
    if (stacks is! List || stacks.isEmpty || stacks.first is! Map) {
      return null;
    }
    return (stacks.first as Map).map(
      (key, value) => MapEntry(key.toString(), value),
    );
  }

  Future<String?> _resolveLambdaFunctionName(
    _PublisherBackendAwsSettings settings,
  ) async {
    final response = await _runAwsJsonCommand(settings, <String>[
      'cloudformation',
      'describe-stack-resources',
      '--stack-name',
      settings.stackName,
    ]);
    final resources = response['StackResources'];
    if (resources is! List) {
      return null;
    }
    for (final resource in resources) {
      if (resource is! Map) {
        continue;
      }
      final mapped = resource.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      if (mapped['ResourceType'] == 'AWS::Lambda::Function') {
        final physicalId = mapped['PhysicalResourceId']?.toString().trim();
        if (physicalId != null && physicalId.isNotEmpty) {
          return physicalId;
        }
      }
    }
    return null;
  }

  Future<_PublisherBackendAwsSeedData> _readAwsSeedData(
    _PublisherBackendAwsSettings settings,
  ) async {
    final dataRootPath = p.join(settings.backendRootPath, 'src', 'data');
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
    return _PublisherBackendAwsSeedData(
      home: home,
      session: session,
      coupons: coupons,
    );
  }

  List<Map<String, Object?>> _buildDynamoDbSeedItems(
    _PublisherBackendAwsSettings settings,
    _PublisherBackendAwsSeedData seedData,
  ) {
    final now = _clock().toUtc().toIso8601String();
    final appPk = _appPartitionKey(settings.miniProgramId);
    final items = <Map<String, Object?>>[
      _dynamoDbSeedItem(
        pk: appPk,
        sk: 'HOME#bootstrap',
        recordType: 'home',
        payload: seedData.home,
        updatedAtUtc: now,
      ),
      _dynamoDbSeedItem(
        pk: appPk,
        sk: 'SESSION#demo',
        recordType: 'session',
        payload: seedData.session,
        updatedAtUtc: now,
      ),
    ];
    for (var i = 0; i < seedData.coupons.length; i++) {
      final coupon = seedData.coupons[i];
      final couponId = coupon['id']!.toString();
      items.add(
        _dynamoDbSeedItem(
          pk: appPk,
          sk: 'COUPON#$couponId',
          recordType: 'coupon',
          payload: coupon,
          updatedAtUtc: now,
          extraAttributes: <String, Object?>{
            'couponId': couponId,
            'sortIndex': i,
          },
        ),
      );
    }
    return items;
  }

  Map<String, Object?> _dynamoDbSeedItem({
    required String pk,
    required String sk,
    required String recordType,
    required Map<String, Object?> payload,
    required String updatedAtUtc,
    Map<String, Object?> extraAttributes = const <String, Object?>{},
  }) {
    return <String, Object?>{
      'pk': pk,
      'sk': sk,
      'recordType': recordType,
      'payload': payload,
      'updatedAtUtc': updatedAtUtc,
      ...extraAttributes,
    };
  }

  Future<_PublisherBackendAwsDataImportPlan> _readAwsDataImportPlan({
    required _PublisherBackendAwsSettings settings,
    required String inputPath,
    required bool includeRedemptions,
  }) async {
    final inputFile = File(inputPath);
    if (!await inputFile.exists()) {
      throw PublisherBackendException(
        'AWS publisher backend data import file was not found: $inputPath',
      );
    }
    final decoded = jsonDecode(await inputFile.readAsString());
    if (decoded is! Map) {
      throw PublisherBackendException(
        'AWS publisher backend data import file must be a JSON object: '
        '$inputPath',
      );
    }
    final export = decoded.map((key, value) => MapEntry(key.toString(), value));
    if (export['schemaVersion'] != 1) {
      throw PublisherBackendException(
        'AWS publisher backend data import file has an unsupported schemaVersion.',
      );
    }
    final rawItems = export['items'];
    if (rawItems is! List) {
      throw PublisherBackendException(
        'AWS publisher backend data import file is missing an items array.',
      );
    }

    final appPk = _appPartitionKey(settings.miniProgramId);
    final redemptionsPk = _redemptionsPartitionKey(settings.miniProgramId);
    final items = <Map<String, Object?>>[];
    var appRecordCount = 0;
    var redemptionCount = 0;
    var skippedRedemptionCount = 0;
    for (final rawItem in rawItems) {
      if (rawItem is! Map) {
        throw PublisherBackendException(
          'AWS publisher backend data import items must be JSON objects.',
        );
      }
      final item = rawItem.map((key, value) => MapEntry(key.toString(), value));
      final pk = item['pk']?.toString().trim() ?? '';
      final sk = item['sk']?.toString().trim() ?? '';
      if (pk.isEmpty || sk.isEmpty) {
        throw PublisherBackendException(
          'AWS publisher backend data import items must include pk and sk.',
        );
      }
      if (pk == redemptionsPk) {
        if (!includeRedemptions) {
          skippedRedemptionCount++;
          continue;
        }
        redemptionCount++;
      } else if (pk == appPk) {
        appRecordCount++;
      } else {
        throw PublisherBackendException(
          'AWS publisher backend data import item "$pk $sk" does not belong '
          'to mini-program "${settings.miniProgramId}".',
        );
      }
      items.add(item);
    }
    return _PublisherBackendAwsDataImportPlan(
      items: items,
      appRecordCount: appRecordCount,
      redemptionCount: redemptionCount,
      skippedRedemptionCount: skippedRedemptionCount,
    );
  }

  List<Map<String, Object?>> _sortedDynamoDbExportItems(
    List<Map<String, Object?>> items,
  ) {
    final sorted = items
        .map((item) => Map<String, Object?>.from(item))
        .toList();
    sorted.sort((left, right) {
      final pkCompare = (left['pk']?.toString() ?? '').compareTo(
        right['pk']?.toString() ?? '',
      );
      if (pkCompare != 0) {
        return pkCompare;
      }
      return (left['sk']?.toString() ?? '').compareTo(
        right['sk']?.toString() ?? '',
      );
    });
    return sorted;
  }

  List<Map<String, Object?>> _filterRedemptionRecords(
    List<Map<String, Object?>> records, {
    String? couponId,
    String? userId,
  }) {
    final couponFilter = couponId?.trim();
    final userFilter = userId?.trim();
    final filtered = records
        .where((record) {
          if (couponFilter != null && couponFilter.isNotEmpty) {
            final recordCouponId = _redemptionRecordValue(record, 'couponId');
            if (recordCouponId != couponFilter) {
              return false;
            }
          }
          if (userFilter != null && userFilter.isNotEmpty) {
            final recordUserId = _redemptionRecordValue(record, 'userId');
            if (recordUserId != userFilter) {
              return false;
            }
          }
          return true;
        })
        .map((record) => Map<String, Object?>.from(record))
        .toList();
    filtered.sort((left, right) {
      final rightTime =
          _redemptionRecordValue(right, 'createdAtUtc') ??
          _redemptionRecordValue(right, 'redeemedAtUtc') ??
          '';
      final leftTime =
          _redemptionRecordValue(left, 'createdAtUtc') ??
          _redemptionRecordValue(left, 'redeemedAtUtc') ??
          '';
      return rightTime.compareTo(leftTime);
    });
    return filtered;
  }

  Future<void> _batchWriteDynamoDbItems({
    required _PublisherBackendAwsSettings settings,
    required String tableName,
    required List<Map<String, Object?>> items,
  }) async {
    for (var index = 0; index < items.length; index += 25) {
      final chunk = items.skip(index).take(25).toList();
      var requestItems = <String, Object?>{
        tableName: chunk
            .map(
              (item) => <String, Object?>{
                'PutRequest': <String, Object?>{
                  'Item': item.map(
                    (key, value) =>
                        MapEntry(key, _toDynamoDbAttributeValue(value)),
                  ),
                },
              },
            )
            .toList(),
      };
      for (
        var attempt = 1;
        attempt <= _dynamoDbBatchWriteMaxAttempts;
        attempt++
      ) {
        final response = await _runAwsJsonCommand(settings, <String>[
          'dynamodb',
          'batch-write-item',
          '--request-items',
          jsonEncode(requestItems),
        ]);
        final unprocessed = _dynamoDbRequestItems(response['UnprocessedItems']);
        if (!_hasDynamoDbRequestItems(unprocessed)) {
          break;
        }
        if (attempt == _dynamoDbBatchWriteMaxAttempts) {
          throw PublisherBackendException(
            'DynamoDB seed left unprocessed items for table "$tableName" after '
            '$_dynamoDbBatchWriteMaxAttempts attempts.',
          );
        }
        requestItems = unprocessed;
        await _delay(Duration(milliseconds: 200 * (1 << (attempt - 1))));
      }
    }
  }

  Map<String, Object?> _dynamoDbRequestItems(Object? value) {
    if (value is! Map) {
      return const <String, Object?>{};
    }
    return value.map((key, nestedValue) {
      return MapEntry(key.toString(), nestedValue);
    });
  }

  Future<Map<String, dynamic>> _describeDynamoDbTable(
    _PublisherBackendAwsSettings settings,
    String tableName,
  ) async {
    final response = await _runAwsJsonCommand(settings, <String>[
      'dynamodb',
      'describe-table',
      '--table-name',
      tableName,
    ]);
    final table = response['Table'];
    if (table is! Map) {
      throw PublisherBackendException(
        'AWS CLI returned no DynamoDB table details for "$tableName".',
      );
    }
    return table.map((key, value) => MapEntry(key.toString(), value));
  }

  Future<int> _queryDynamoDbCount({
    required _PublisherBackendAwsSettings settings,
    required String tableName,
    required String partitionKey,
  }) async {
    var total = 0;
    Map<String, Object?>? exclusiveStartKey;
    do {
      final arguments = <String>[
        'dynamodb',
        'query',
        '--table-name',
        tableName,
        '--key-condition-expression',
        'pk = :pk',
        '--expression-attribute-values',
        jsonEncode(<String, Object?>{
          ':pk': <String, Object?>{'S': partitionKey},
        }),
        '--select',
        'COUNT',
        '--consistent-read',
        if (exclusiveStartKey != null) ...<String>[
          '--exclusive-start-key',
          jsonEncode(exclusiveStartKey),
        ],
      ];
      final response = await _runAwsJsonCommand(settings, arguments);
      total += _dynamoDbCountValue(response['Count']);
      final lastEvaluatedKey = response['LastEvaluatedKey'];
      exclusiveStartKey = lastEvaluatedKey is Map && lastEvaluatedKey.isNotEmpty
          ? lastEvaluatedKey.map(
              (key, value) => MapEntry(key.toString(), value),
            )
          : null;
    } while (exclusiveStartKey != null);
    return total;
  }

  Future<List<Map<String, Object?>>> _queryDynamoDbItems({
    required _PublisherBackendAwsSettings settings,
    required String tableName,
    required String partitionKey,
  }) async {
    final items = <Map<String, Object?>>[];
    Map<String, Object?>? exclusiveStartKey;
    do {
      final arguments = <String>[
        'dynamodb',
        'query',
        '--table-name',
        tableName,
        '--key-condition-expression',
        'pk = :pk',
        '--expression-attribute-values',
        jsonEncode(<String, Object?>{
          ':pk': <String, Object?>{'S': partitionKey},
        }),
        '--consistent-read',
        if (exclusiveStartKey != null) ...<String>[
          '--exclusive-start-key',
          jsonEncode(exclusiveStartKey),
        ],
      ];
      final response = await _runAwsJsonCommand(settings, arguments);
      final rawItems = response['Items'];
      if (rawItems is List) {
        for (final rawItem in rawItems) {
          items.add(_fromDynamoDbItem(rawItem));
        }
      }
      final lastEvaluatedKey = response['LastEvaluatedKey'];
      exclusiveStartKey = lastEvaluatedKey is Map && lastEvaluatedKey.isNotEmpty
          ? lastEvaluatedKey.map(
              (key, value) => MapEntry(key.toString(), value),
            )
          : null;
    } while (exclusiveStartKey != null);
    return items;
  }

  int _dynamoDbCountValue(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Map<String, Object?> _fromDynamoDbItem(Object? rawItem) {
    if (rawItem is! Map) {
      throw const PublisherBackendException(
        'AWS CLI returned a non-object DynamoDB item.',
      );
    }
    return rawItem.map(
      (key, value) =>
          MapEntry(key.toString(), _fromDynamoDbAttributeValue(value)),
    );
  }

  Object? _fromDynamoDbAttributeValue(Object? value) {
    if (value is! Map) {
      return value;
    }
    if (value.containsKey('S')) {
      return value['S']?.toString();
    }
    if (value.containsKey('N')) {
      return _fromDynamoDbNumber(value['N']);
    }
    if (value.containsKey('BOOL')) {
      final raw = value['BOOL'];
      return raw is bool ? raw : raw?.toString() == 'true';
    }
    if (value.containsKey('NULL')) {
      return null;
    }
    if (value.containsKey('L')) {
      final raw = value['L'];
      if (raw is List) {
        return raw.map(_fromDynamoDbAttributeValue).toList();
      }
      return const <Object?>[];
    }
    if (value.containsKey('M')) {
      final raw = value['M'];
      if (raw is Map) {
        return raw.map(
          (key, nestedValue) => MapEntry(
            key.toString(),
            _fromDynamoDbAttributeValue(nestedValue),
          ),
        );
      }
      return const <String, Object?>{};
    }
    if (value.containsKey('SS')) {
      final raw = value['SS'];
      return raw is List
          ? raw.map((entry) => entry?.toString()).toList()
          : const <String>[];
    }
    if (value.containsKey('NS')) {
      final raw = value['NS'];
      return raw is List
          ? raw.map(_fromDynamoDbNumber).toList()
          : const <num>[];
    }
    return value.map(
      (key, nestedValue) =>
          MapEntry(key.toString(), _fromDynamoDbAttributeValue(nestedValue)),
    );
  }

  Object? _fromDynamoDbNumber(Object? value) {
    final raw = value?.toString();
    if (raw == null) {
      return null;
    }
    final integer = int.tryParse(raw);
    if (integer != null) {
      return integer;
    }
    return double.tryParse(raw) ?? raw;
  }

  Map<String, Object?> _toDynamoDbAttributeValue(Object? value) {
    if (value == null) {
      return const <String, Object?>{'NULL': true};
    }
    if (value is bool) {
      return <String, Object?>{'BOOL': value};
    }
    if (value is num) {
      return <String, Object?>{'N': value.toString()};
    }
    if (value is String) {
      return <String, Object?>{'S': value};
    }
    if (value is List) {
      return <String, Object?>{
        'L': value.map(_toDynamoDbAttributeValue).toList(),
      };
    }
    if (value is Map) {
      return <String, Object?>{
        'M': value.map(
          (key, nestedValue) =>
              MapEntry(key.toString(), _toDynamoDbAttributeValue(nestedValue)),
        ),
      };
    }
    return <String, Object?>{'S': value.toString()};
  }

  Map<String, String> _extractStackOutputs(Map<String, dynamic> stack) {
    final outputs = <String, String>{};
    final rawOutputs = stack['Outputs'];
    if (rawOutputs is! List) {
      return outputs;
    }
    for (final output in rawOutputs) {
      if (output is! Map) {
        continue;
      }
      final mapped = output.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final key = mapped['OutputKey']?.toString().trim();
      final value = mapped['OutputValue']?.toString().trim();
      if (key == null || key.isEmpty || value == null || value.isEmpty) {
        continue;
      }
      outputs[key] = value;
    }
    final sortedKeys = outputs.keys.toList()..sort();
    return <String, String>{for (final key in sortedKeys) key: outputs[key]!};
  }

  List<String> _awsGlobalArguments(_PublisherBackendAwsSettings settings) {
    final arguments = <String>['--region', settings.region];
    if (settings.awsProfile case final profile?
        when profile.trim().isNotEmpty) {
      arguments.addAll(<String>['--profile', profile]);
    }
    return arguments;
  }
}
