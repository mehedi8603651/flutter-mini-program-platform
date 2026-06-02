part of '../publisher_backend_starter_test.dart';

CloudEnvironmentConfiguration _awsEnvironment() {
  return CloudEnvironmentConfiguration(
    name: 'my-aws-prod',
    provider: 'aws',
    values: <String, dynamic>{
      'bucket': 'delivery-bucket',
      'region': 'ap-south-1',
      'samS3Bucket': 'sam-artifacts',
      'awsProfile': 'my-aws',
    },
    configuredAtUtc: DateTime.utc(2026).toIso8601String(),
    updatedAtUtc: DateTime.utc(2026).toIso8601String(),
  );
}

CloudEnvironmentConfiguration _firebaseEnvironment({
  Map<String, dynamic>? values,
}) {
  return CloudEnvironmentConfiguration(
    name: 'my-firebase-prod',
    provider: 'firebase',
    values:
        values ??
        <String, dynamic>{
          'projectId': 'coupon-prod',
          'region': 'asia-south1',
          'functionName': 'publisherBackend',
        },
    configuredAtUtc: DateTime.utc(2026).toIso8601String(),
    updatedAtUtc: DateTime.utc(2026).toIso8601String(),
  );
}

String _stackDescribeJson() => jsonEncode(<String, Object?>{
  'Stacks': <Object?>[
    <String, Object?>{
      'StackStatus': 'CREATE_COMPLETE',
      'Outputs': <Object?>[
        <String, Object?>{
          'OutputKey': 'PublisherBackendBaseUrl',
          'OutputValue':
              'https://abc.execute-api.ap-south-1.amazonaws.com/prod/',
        },
        <String, Object?>{
          'OutputKey': 'PublisherBackendHealthUrl',
          'OutputValue':
              'https://abc.execute-api.ap-south-1.amazonaws.com/prod/health',
        },
        <String, Object?>{
          'OutputKey': 'PublisherBackendFunctionName',
          'OutputValue': 'coupon-function',
        },
      ],
    },
  ],
});

String _stackDescribeJsonWithoutBaseUrl() => jsonEncode(<String, Object?>{
  'Stacks': <Object?>[
    <String, Object?>{
      'StackStatus': 'CREATE_COMPLETE',
      'Outputs': <Object?>[
        <String, Object?>{
          'OutputKey': 'PublisherBackendHealthUrl',
          'OutputValue':
              'https://abc.execute-api.ap-south-1.amazonaws.com/prod/health',
        },
      ],
    },
  ],
});

String _stackDescribeJsonWithDataTable() => jsonEncode(<String, Object?>{
  'Stacks': <Object?>[
    <String, Object?>{
      'StackStatus': 'CREATE_COMPLETE',
      'Outputs': <Object?>[
        <String, Object?>{
          'OutputKey': 'PublisherBackendBaseUrl',
          'OutputValue':
              'https://abc.execute-api.ap-south-1.amazonaws.com/prod/',
        },
        <String, Object?>{
          'OutputKey': 'PublisherBackendHealthUrl',
          'OutputValue':
              'https://abc.execute-api.ap-south-1.amazonaws.com/prod/health',
        },
        <String, Object?>{
          'OutputKey': 'PublisherBackendFunctionName',
          'OutputValue': 'coupon-function',
        },
        <String, Object?>{
          'OutputKey': 'PublisherBackendStorageMode',
          'OutputValue': 'dynamodb',
        },
        <String, Object?>{
          'OutputKey': 'PublisherBackendDataTableName',
          'OutputValue': 'coupon-data-table',
        },
      ],
    },
  ],
});

Map<String, Object?> _plainExportItem({
  required String pk,
  required String sk,
  required String recordType,
  required Map<String, Object?> payload,
}) {
  return <String, Object?>{
    'pk': pk,
    'sk': sk,
    'recordType': recordType,
    'payload': payload,
    'updatedAtUtc': '2026-05-23T12:00:00.000Z',
  };
}

Map<String, Object?> _redemptionItem({
  required String couponId,
  required String userId,
  required String createdAtUtc,
}) {
  return <String, Object?>{
    'pk': 'APP#coupon_app#REDEMPTIONS',
    'sk': 'USER#$userId#COUPON#$couponId',
    'recordType': 'redemption',
    'couponId': couponId,
    'userId': userId,
    'payload': <String, Object?>{
      'status': 'redeemed',
      'couponId': couponId,
      'userId': userId,
      'redeemedAtUtc': createdAtUtc,
    },
    'createdAtUtc': createdAtUtc,
  };
}

Map<String, Object?> _dynamoDbItem({
  required String pk,
  required String sk,
  required String recordType,
  required Map<String, Object?> payload,
}) {
  return <String, Object?>{
    'pk': pk,
    'sk': sk,
    'recordType': recordType,
    'payload': payload,
    'updatedAtUtc': '2026-05-23T12:00:00.000Z',
  };
}

String _dynamoDbQueryItemsJson(List<Map<String, Object?>> items) {
  return jsonEncode(<String, Object?>{
    'Items': items
        .map(
          (item) => item.map(
            (key, value) => MapEntry(key, _toDynamoDbTestAttribute(value)),
          ),
        )
        .toList(),
  });
}

String _firestoreDocumentsJson(int count) {
  return jsonEncode(<String, Object?>{
    'documents': List<Object?>.generate(
      count,
      (index) => <String, Object?>{
        'name': 'projects/test/databases/(default)/documents/doc-$index',
      },
    ),
  });
}

String _firestoreDocumentsJsonFrom(
  String appId,
  String collection,
  Map<String, Map<String, Object?>> documents,
) {
  return jsonEncode(<String, Object?>{
    'documents': documents.entries
        .map(
          (entry) => <String, Object?>{
            'name':
                'projects/test/databases/(default)/documents/miniPrograms/$appId/$collection/${entry.key}',
            'fields': entry.value.map(
              (key, value) => MapEntry(key, _toFirestoreTestValue(value)),
            ),
          },
        )
        .toList(),
  });
}

String _firestoreDocumentJson(Map<String, Object?> fields) {
  return jsonEncode(<String, Object?>{
    'fields': fields.map(
      (key, value) => MapEntry(key, _toFirestoreTestValue(value)),
    ),
  });
}

Map<String, Object?> _firebaseExportFixture({required bool includeRedemption}) {
  return <String, Object?>{
    'schemaVersion': 1,
    'command': 'publisher-backend firebase data export',
    'provider': 'firebase',
    'environmentName': 'my-firebase-prod',
    'projectId': 'coupon-prod',
    'region': 'asia-south1',
    'functionName': 'publisherBackend',
    'miniProgramId': 'coupon_app',
    'storageMode': 'firestore',
    'includeRedemptions': includeRedemption,
    'records': <Object?>[
      <String, Object?>{
        'recordType': 'home',
        'collection': 'home',
        'documentId': 'bootstrap',
        'documentPath': 'miniPrograms/coupon_app/home/bootstrap',
        'data': <String, Object?>{'title': 'Imported home'},
      },
      if (includeRedemption)
        <String, Object?>{
          'recordType': 'redemption',
          'collection': 'redemptions',
          'documentId': 'user_coupon',
          'documentPath': 'miniPrograms/coupon_app/redemptions/user_coupon',
          'data': <String, Object?>{
            'status': 'redeemed',
            'couponId': 'coupon-10',
            'userId': 'preview-user',
            'redeemedAtUtc': '2026-05-24T12:00:00Z',
          },
        },
    ],
  };
}

_TestFirestoreTimestamp _firestoreTimestamp(String value) =>
    _TestFirestoreTimestamp(value);

class _TestFirestoreTimestamp {
  const _TestFirestoreTimestamp(this.value);

  final String value;
}

Map<String, Object?> _toFirestoreTestValue(Object? value) {
  if (value == null) {
    return const <String, Object?>{'nullValue': null};
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
  if (value is _TestFirestoreTimestamp) {
    return <String, Object?>{'timestampValue': value.value};
  }
  if (value is List) {
    return <String, Object?>{
      'arrayValue': <String, Object?>{
        'values': value.map(_toFirestoreTestValue).toList(),
      },
    };
  }
  if (value is Map) {
    return <String, Object?>{
      'mapValue': <String, Object?>{
        'fields': value.map(
          (key, nestedValue) =>
              MapEntry(key.toString(), _toFirestoreTestValue(nestedValue)),
        ),
      },
    };
  }
  return <String, Object?>{'stringValue': value.toString()};
}

Map<String, Object?> _toDynamoDbTestAttribute(Object? value) {
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
    return <String, Object?>{'L': value.map(_toDynamoDbTestAttribute).toList()};
  }
  if (value is Map) {
    return <String, Object?>{
      'M': value.map(
        (key, nestedValue) =>
            MapEntry(key.toString(), _toDynamoDbTestAttribute(nestedValue)),
      ),
    };
  }
  return <String, Object?>{'S': value.toString()};
}

Future<ProcessResult> _runNodeScript(Directory tempDir, String source) async {
  final script = File(p.join(tempDir.path, 'node_handler_test.mjs'));
  await script.writeAsString(source);
  return Process.run('node', <String>[script.path]);
}

Future<int> _freePort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}
