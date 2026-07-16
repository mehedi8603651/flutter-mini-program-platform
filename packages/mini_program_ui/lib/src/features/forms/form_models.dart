import '../../core/authoring_validation.dart';
import '../../core/mp_json.dart';

/// Serializable option used by Mp dropdown and radioGroup controls.
final class MpOption implements MpJsonEncodable {
  /// Creates a serializable form option.
  const MpOption({required this.value, required this.label});

  /// Wire value submitted through form state.
  final String value;

  /// User-facing label rendered in the SDK.
  final String label;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'label': requiredAuthoringString(label, 'label'),
    'value': requiredAuthoringString(value, 'value'),
  };
}
