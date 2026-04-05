import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pub_semver/pub_semver.dart';

part 'sdk_version.freezed.dart';
part 'sdk_version.g.dart';

/// Semver range expression describing which SDK versions a manifest supports.
@freezed
abstract class SdkVersionRange with _$SdkVersionRange {
  @JsonSerializable(checked: true)
  const factory SdkVersionRange({required String value}) = _SdkVersionRange;

  factory SdkVersionRange.fromJson(Map<String, dynamic> json) =>
      _$SdkVersionRangeFromJson(json);
}

extension SdkVersionRangeX on SdkVersionRange {
  /// Whether the underlying semver range string parses successfully.
  bool get isValid => tryParseConstraint() != null;

  /// Whether a concrete SDK version is allowed by this semver range.
  bool allows(String sdkVersion) {
    final constraint = tryParseConstraint();
    final version = tryParseVersion(sdkVersion);
    return constraint != null && version != null && constraint.allows(version);
  }

  /// Parses the semver range or returns `null` when the expression is invalid.
  VersionConstraint? tryParseConstraint() {
    try {
      return VersionConstraint.parse(value);
    } on FormatException {
      return null;
    }
  }

  /// Parses a concrete SDK version or returns `null` when it is invalid.
  Version? tryParseVersion(String sdkVersion) {
    try {
      return Version.parse(sdkVersion);
    } on FormatException {
      return null;
    }
  }
}

/// Converts between a manifest wire string and [SdkVersionRange].
class SdkVersionRangeConverter
    implements JsonConverter<SdkVersionRange, String> {
  const SdkVersionRangeConverter();

  @override
  SdkVersionRange fromJson(String json) => SdkVersionRange(value: json);

  @override
  String toJson(SdkVersionRange object) => object.value;
}
