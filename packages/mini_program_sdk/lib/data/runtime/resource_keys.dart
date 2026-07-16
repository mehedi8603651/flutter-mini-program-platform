part of '../mini_program_data_resource.dart';

String _cacheKey(String version, String resourceId) =>
    '_sdk_json_${version.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_')}_$resourceId';

String _resourceKey(String appId, String version, String resourceId) =>
    '$appId\u0000$version\u0000$resourceId';
