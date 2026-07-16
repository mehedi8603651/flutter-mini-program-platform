part of '../mini_program_data_resource.dart';

class _LoadedDataResource {
  const _LoadedDataResource({required this.assetPath, required this.value});

  final String assetPath;
  final Object? value;
}

void _replaceDataResource(
  MiniProgramDataResourceManager manager,
  String key,
  _LoadedDataResource resource,
) {
  manager._resources[key] = resource;
  manager._indexes.removeWhere(
    (indexKey, _) => indexKey.startsWith('$key\u0000'),
  );
}
