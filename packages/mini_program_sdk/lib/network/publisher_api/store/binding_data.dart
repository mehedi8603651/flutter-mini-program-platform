part of '../../mini_program_backend_store.dart';

extension _MiniProgramBackendBindingData on MiniProgramBackendStore {
  Map<String, dynamic> _buildBindingData() {
    return <String, dynamic>{
      ..._snapshots.map(
        (key, value) => MapEntry<String, dynamic>(key, value.toBindingData()),
      ),
      ..._pagedSnapshots.map(
        (key, value) => MapEntry<String, dynamic>(key, value.toBindingData()),
      ),
    };
  }
}
