// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sdk_version.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SdkVersionRange {

 String get value;
/// Create a copy of SdkVersionRange
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SdkVersionRangeCopyWith<SdkVersionRange> get copyWith => _$SdkVersionRangeCopyWithImpl<SdkVersionRange>(this as SdkVersionRange, _$identity);

  /// Serializes this SdkVersionRange to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SdkVersionRange&&(identical(other.value, value) || other.value == value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,value);

@override
String toString() {
  return 'SdkVersionRange(value: $value)';
}


}

/// @nodoc
abstract mixin class $SdkVersionRangeCopyWith<$Res>  {
  factory $SdkVersionRangeCopyWith(SdkVersionRange value, $Res Function(SdkVersionRange) _then) = _$SdkVersionRangeCopyWithImpl;
@useResult
$Res call({
 String value
});




}
/// @nodoc
class _$SdkVersionRangeCopyWithImpl<$Res>
    implements $SdkVersionRangeCopyWith<$Res> {
  _$SdkVersionRangeCopyWithImpl(this._self, this._then);

  final SdkVersionRange _self;
  final $Res Function(SdkVersionRange) _then;

/// Create a copy of SdkVersionRange
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? value = null,}) {
  return _then(_self.copyWith(
value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [SdkVersionRange].
extension SdkVersionRangePatterns on SdkVersionRange {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SdkVersionRange value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SdkVersionRange() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SdkVersionRange value)  $default,){
final _that = this;
switch (_that) {
case _SdkVersionRange():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SdkVersionRange value)?  $default,){
final _that = this;
switch (_that) {
case _SdkVersionRange() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String value)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SdkVersionRange() when $default != null:
return $default(_that.value);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String value)  $default,) {final _that = this;
switch (_that) {
case _SdkVersionRange():
return $default(_that.value);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String value)?  $default,) {final _that = this;
switch (_that) {
case _SdkVersionRange() when $default != null:
return $default(_that.value);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(checked: true)
class _SdkVersionRange implements SdkVersionRange {
  const _SdkVersionRange({required this.value});
  factory _SdkVersionRange.fromJson(Map<String, dynamic> json) => _$SdkVersionRangeFromJson(json);

@override final  String value;

/// Create a copy of SdkVersionRange
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SdkVersionRangeCopyWith<_SdkVersionRange> get copyWith => __$SdkVersionRangeCopyWithImpl<_SdkVersionRange>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SdkVersionRangeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SdkVersionRange&&(identical(other.value, value) || other.value == value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,value);

@override
String toString() {
  return 'SdkVersionRange(value: $value)';
}


}

/// @nodoc
abstract mixin class _$SdkVersionRangeCopyWith<$Res> implements $SdkVersionRangeCopyWith<$Res> {
  factory _$SdkVersionRangeCopyWith(_SdkVersionRange value, $Res Function(_SdkVersionRange) _then) = __$SdkVersionRangeCopyWithImpl;
@override @useResult
$Res call({
 String value
});




}
/// @nodoc
class __$SdkVersionRangeCopyWithImpl<$Res>
    implements _$SdkVersionRangeCopyWith<$Res> {
  __$SdkVersionRangeCopyWithImpl(this._self, this._then);

  final _SdkVersionRange _self;
  final $Res Function(_SdkVersionRange) _then;

/// Create a copy of SdkVersionRange
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? value = null,}) {
  return _then(_SdkVersionRange(
value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
