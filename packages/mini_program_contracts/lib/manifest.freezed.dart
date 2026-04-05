// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'manifest.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MiniProgramCachePolicy {

 MiniProgramCacheMode get manifest; MiniProgramCacheMode get entryScreen;
/// Create a copy of MiniProgramCachePolicy
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MiniProgramCachePolicyCopyWith<MiniProgramCachePolicy> get copyWith => _$MiniProgramCachePolicyCopyWithImpl<MiniProgramCachePolicy>(this as MiniProgramCachePolicy, _$identity);

  /// Serializes this MiniProgramCachePolicy to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MiniProgramCachePolicy&&(identical(other.manifest, manifest) || other.manifest == manifest)&&(identical(other.entryScreen, entryScreen) || other.entryScreen == entryScreen));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,manifest,entryScreen);

@override
String toString() {
  return 'MiniProgramCachePolicy(manifest: $manifest, entryScreen: $entryScreen)';
}


}

/// @nodoc
abstract mixin class $MiniProgramCachePolicyCopyWith<$Res>  {
  factory $MiniProgramCachePolicyCopyWith(MiniProgramCachePolicy value, $Res Function(MiniProgramCachePolicy) _then) = _$MiniProgramCachePolicyCopyWithImpl;
@useResult
$Res call({
 MiniProgramCacheMode manifest, MiniProgramCacheMode entryScreen
});




}
/// @nodoc
class _$MiniProgramCachePolicyCopyWithImpl<$Res>
    implements $MiniProgramCachePolicyCopyWith<$Res> {
  _$MiniProgramCachePolicyCopyWithImpl(this._self, this._then);

  final MiniProgramCachePolicy _self;
  final $Res Function(MiniProgramCachePolicy) _then;

/// Create a copy of MiniProgramCachePolicy
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? manifest = null,Object? entryScreen = null,}) {
  return _then(_self.copyWith(
manifest: null == manifest ? _self.manifest : manifest // ignore: cast_nullable_to_non_nullable
as MiniProgramCacheMode,entryScreen: null == entryScreen ? _self.entryScreen : entryScreen // ignore: cast_nullable_to_non_nullable
as MiniProgramCacheMode,
  ));
}

}


/// Adds pattern-matching-related methods to [MiniProgramCachePolicy].
extension MiniProgramCachePolicyPatterns on MiniProgramCachePolicy {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MiniProgramCachePolicy value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MiniProgramCachePolicy() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MiniProgramCachePolicy value)  $default,){
final _that = this;
switch (_that) {
case _MiniProgramCachePolicy():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MiniProgramCachePolicy value)?  $default,){
final _that = this;
switch (_that) {
case _MiniProgramCachePolicy() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( MiniProgramCacheMode manifest,  MiniProgramCacheMode entryScreen)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MiniProgramCachePolicy() when $default != null:
return $default(_that.manifest,_that.entryScreen);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( MiniProgramCacheMode manifest,  MiniProgramCacheMode entryScreen)  $default,) {final _that = this;
switch (_that) {
case _MiniProgramCachePolicy():
return $default(_that.manifest,_that.entryScreen);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( MiniProgramCacheMode manifest,  MiniProgramCacheMode entryScreen)?  $default,) {final _that = this;
switch (_that) {
case _MiniProgramCachePolicy() when $default != null:
return $default(_that.manifest,_that.entryScreen);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(checked: true, explicitToJson: true)
class _MiniProgramCachePolicy implements MiniProgramCachePolicy {
  const _MiniProgramCachePolicy({this.manifest = MiniProgramCacheMode.staleWhileError, this.entryScreen = MiniProgramCacheMode.staleWhileError});
  factory _MiniProgramCachePolicy.fromJson(Map<String, dynamic> json) => _$MiniProgramCachePolicyFromJson(json);

@override@JsonKey() final  MiniProgramCacheMode manifest;
@override@JsonKey() final  MiniProgramCacheMode entryScreen;

/// Create a copy of MiniProgramCachePolicy
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MiniProgramCachePolicyCopyWith<_MiniProgramCachePolicy> get copyWith => __$MiniProgramCachePolicyCopyWithImpl<_MiniProgramCachePolicy>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MiniProgramCachePolicyToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MiniProgramCachePolicy&&(identical(other.manifest, manifest) || other.manifest == manifest)&&(identical(other.entryScreen, entryScreen) || other.entryScreen == entryScreen));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,manifest,entryScreen);

@override
String toString() {
  return 'MiniProgramCachePolicy(manifest: $manifest, entryScreen: $entryScreen)';
}


}

/// @nodoc
abstract mixin class _$MiniProgramCachePolicyCopyWith<$Res> implements $MiniProgramCachePolicyCopyWith<$Res> {
  factory _$MiniProgramCachePolicyCopyWith(_MiniProgramCachePolicy value, $Res Function(_MiniProgramCachePolicy) _then) = __$MiniProgramCachePolicyCopyWithImpl;
@override @useResult
$Res call({
 MiniProgramCacheMode manifest, MiniProgramCacheMode entryScreen
});




}
/// @nodoc
class __$MiniProgramCachePolicyCopyWithImpl<$Res>
    implements _$MiniProgramCachePolicyCopyWith<$Res> {
  __$MiniProgramCachePolicyCopyWithImpl(this._self, this._then);

  final _MiniProgramCachePolicy _self;
  final $Res Function(_MiniProgramCachePolicy) _then;

/// Create a copy of MiniProgramCachePolicy
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? manifest = null,Object? entryScreen = null,}) {
  return _then(_MiniProgramCachePolicy(
manifest: null == manifest ? _self.manifest : manifest // ignore: cast_nullable_to_non_nullable
as MiniProgramCacheMode,entryScreen: null == entryScreen ? _self.entryScreen : entryScreen // ignore: cast_nullable_to_non_nullable
as MiniProgramCacheMode,
  ));
}


}


/// @nodoc
mixin _$MiniProgramFallback {

 MiniProgramFallbackStrategy get strategy; String? get route; String? get message;
/// Create a copy of MiniProgramFallback
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MiniProgramFallbackCopyWith<MiniProgramFallback> get copyWith => _$MiniProgramFallbackCopyWithImpl<MiniProgramFallback>(this as MiniProgramFallback, _$identity);

  /// Serializes this MiniProgramFallback to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MiniProgramFallback&&(identical(other.strategy, strategy) || other.strategy == strategy)&&(identical(other.route, route) || other.route == route)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,strategy,route,message);

@override
String toString() {
  return 'MiniProgramFallback(strategy: $strategy, route: $route, message: $message)';
}


}

/// @nodoc
abstract mixin class $MiniProgramFallbackCopyWith<$Res>  {
  factory $MiniProgramFallbackCopyWith(MiniProgramFallback value, $Res Function(MiniProgramFallback) _then) = _$MiniProgramFallbackCopyWithImpl;
@useResult
$Res call({
 MiniProgramFallbackStrategy strategy, String? route, String? message
});




}
/// @nodoc
class _$MiniProgramFallbackCopyWithImpl<$Res>
    implements $MiniProgramFallbackCopyWith<$Res> {
  _$MiniProgramFallbackCopyWithImpl(this._self, this._then);

  final MiniProgramFallback _self;
  final $Res Function(MiniProgramFallback) _then;

/// Create a copy of MiniProgramFallback
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? strategy = null,Object? route = freezed,Object? message = freezed,}) {
  return _then(_self.copyWith(
strategy: null == strategy ? _self.strategy : strategy // ignore: cast_nullable_to_non_nullable
as MiniProgramFallbackStrategy,route: freezed == route ? _self.route : route // ignore: cast_nullable_to_non_nullable
as String?,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [MiniProgramFallback].
extension MiniProgramFallbackPatterns on MiniProgramFallback {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MiniProgramFallback value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MiniProgramFallback() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MiniProgramFallback value)  $default,){
final _that = this;
switch (_that) {
case _MiniProgramFallback():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MiniProgramFallback value)?  $default,){
final _that = this;
switch (_that) {
case _MiniProgramFallback() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( MiniProgramFallbackStrategy strategy,  String? route,  String? message)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MiniProgramFallback() when $default != null:
return $default(_that.strategy,_that.route,_that.message);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( MiniProgramFallbackStrategy strategy,  String? route,  String? message)  $default,) {final _that = this;
switch (_that) {
case _MiniProgramFallback():
return $default(_that.strategy,_that.route,_that.message);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( MiniProgramFallbackStrategy strategy,  String? route,  String? message)?  $default,) {final _that = this;
switch (_that) {
case _MiniProgramFallback() when $default != null:
return $default(_that.strategy,_that.route,_that.message);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(checked: true, explicitToJson: true)
class _MiniProgramFallback implements MiniProgramFallback {
  const _MiniProgramFallback({required this.strategy, this.route, this.message});
  factory _MiniProgramFallback.fromJson(Map<String, dynamic> json) => _$MiniProgramFallbackFromJson(json);

@override final  MiniProgramFallbackStrategy strategy;
@override final  String? route;
@override final  String? message;

/// Create a copy of MiniProgramFallback
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MiniProgramFallbackCopyWith<_MiniProgramFallback> get copyWith => __$MiniProgramFallbackCopyWithImpl<_MiniProgramFallback>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MiniProgramFallbackToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MiniProgramFallback&&(identical(other.strategy, strategy) || other.strategy == strategy)&&(identical(other.route, route) || other.route == route)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,strategy,route,message);

@override
String toString() {
  return 'MiniProgramFallback(strategy: $strategy, route: $route, message: $message)';
}


}

/// @nodoc
abstract mixin class _$MiniProgramFallbackCopyWith<$Res> implements $MiniProgramFallbackCopyWith<$Res> {
  factory _$MiniProgramFallbackCopyWith(_MiniProgramFallback value, $Res Function(_MiniProgramFallback) _then) = __$MiniProgramFallbackCopyWithImpl;
@override @useResult
$Res call({
 MiniProgramFallbackStrategy strategy, String? route, String? message
});




}
/// @nodoc
class __$MiniProgramFallbackCopyWithImpl<$Res>
    implements _$MiniProgramFallbackCopyWith<$Res> {
  __$MiniProgramFallbackCopyWithImpl(this._self, this._then);

  final _MiniProgramFallback _self;
  final $Res Function(_MiniProgramFallback) _then;

/// Create a copy of MiniProgramFallback
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? strategy = null,Object? route = freezed,Object? message = freezed,}) {
  return _then(_MiniProgramFallback(
strategy: null == strategy ? _self.strategy : strategy // ignore: cast_nullable_to_non_nullable
as MiniProgramFallbackStrategy,route: freezed == route ? _self.route : route // ignore: cast_nullable_to_non_nullable
as String?,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$MiniProgramManifest {

 String get id; String get version; String get entry; String get contractVersion;@SdkVersionRangeConverter() SdkVersionRange get sdkVersionRange; List<Capability> get requiredCapabilities; List<FeatureFlagKey> get featureFlags; MiniProgramCachePolicy get cachePolicy; MiniProgramFallback? get fallback;
/// Create a copy of MiniProgramManifest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MiniProgramManifestCopyWith<MiniProgramManifest> get copyWith => _$MiniProgramManifestCopyWithImpl<MiniProgramManifest>(this as MiniProgramManifest, _$identity);

  /// Serializes this MiniProgramManifest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MiniProgramManifest&&(identical(other.id, id) || other.id == id)&&(identical(other.version, version) || other.version == version)&&(identical(other.entry, entry) || other.entry == entry)&&(identical(other.contractVersion, contractVersion) || other.contractVersion == contractVersion)&&(identical(other.sdkVersionRange, sdkVersionRange) || other.sdkVersionRange == sdkVersionRange)&&const DeepCollectionEquality().equals(other.requiredCapabilities, requiredCapabilities)&&const DeepCollectionEquality().equals(other.featureFlags, featureFlags)&&(identical(other.cachePolicy, cachePolicy) || other.cachePolicy == cachePolicy)&&(identical(other.fallback, fallback) || other.fallback == fallback));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,version,entry,contractVersion,sdkVersionRange,const DeepCollectionEquality().hash(requiredCapabilities),const DeepCollectionEquality().hash(featureFlags),cachePolicy,fallback);

@override
String toString() {
  return 'MiniProgramManifest(id: $id, version: $version, entry: $entry, contractVersion: $contractVersion, sdkVersionRange: $sdkVersionRange, requiredCapabilities: $requiredCapabilities, featureFlags: $featureFlags, cachePolicy: $cachePolicy, fallback: $fallback)';
}


}

/// @nodoc
abstract mixin class $MiniProgramManifestCopyWith<$Res>  {
  factory $MiniProgramManifestCopyWith(MiniProgramManifest value, $Res Function(MiniProgramManifest) _then) = _$MiniProgramManifestCopyWithImpl;
@useResult
$Res call({
 String id, String version, String entry, String contractVersion,@SdkVersionRangeConverter() SdkVersionRange sdkVersionRange, List<Capability> requiredCapabilities, List<FeatureFlagKey> featureFlags, MiniProgramCachePolicy cachePolicy, MiniProgramFallback? fallback
});


$SdkVersionRangeCopyWith<$Res> get sdkVersionRange;$MiniProgramCachePolicyCopyWith<$Res> get cachePolicy;$MiniProgramFallbackCopyWith<$Res>? get fallback;

}
/// @nodoc
class _$MiniProgramManifestCopyWithImpl<$Res>
    implements $MiniProgramManifestCopyWith<$Res> {
  _$MiniProgramManifestCopyWithImpl(this._self, this._then);

  final MiniProgramManifest _self;
  final $Res Function(MiniProgramManifest) _then;

/// Create a copy of MiniProgramManifest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? version = null,Object? entry = null,Object? contractVersion = null,Object? sdkVersionRange = null,Object? requiredCapabilities = null,Object? featureFlags = null,Object? cachePolicy = null,Object? fallback = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,entry: null == entry ? _self.entry : entry // ignore: cast_nullable_to_non_nullable
as String,contractVersion: null == contractVersion ? _self.contractVersion : contractVersion // ignore: cast_nullable_to_non_nullable
as String,sdkVersionRange: null == sdkVersionRange ? _self.sdkVersionRange : sdkVersionRange // ignore: cast_nullable_to_non_nullable
as SdkVersionRange,requiredCapabilities: null == requiredCapabilities ? _self.requiredCapabilities : requiredCapabilities // ignore: cast_nullable_to_non_nullable
as List<Capability>,featureFlags: null == featureFlags ? _self.featureFlags : featureFlags // ignore: cast_nullable_to_non_nullable
as List<FeatureFlagKey>,cachePolicy: null == cachePolicy ? _self.cachePolicy : cachePolicy // ignore: cast_nullable_to_non_nullable
as MiniProgramCachePolicy,fallback: freezed == fallback ? _self.fallback : fallback // ignore: cast_nullable_to_non_nullable
as MiniProgramFallback?,
  ));
}
/// Create a copy of MiniProgramManifest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SdkVersionRangeCopyWith<$Res> get sdkVersionRange {
  
  return $SdkVersionRangeCopyWith<$Res>(_self.sdkVersionRange, (value) {
    return _then(_self.copyWith(sdkVersionRange: value));
  });
}/// Create a copy of MiniProgramManifest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MiniProgramCachePolicyCopyWith<$Res> get cachePolicy {
  
  return $MiniProgramCachePolicyCopyWith<$Res>(_self.cachePolicy, (value) {
    return _then(_self.copyWith(cachePolicy: value));
  });
}/// Create a copy of MiniProgramManifest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MiniProgramFallbackCopyWith<$Res>? get fallback {
    if (_self.fallback == null) {
    return null;
  }

  return $MiniProgramFallbackCopyWith<$Res>(_self.fallback!, (value) {
    return _then(_self.copyWith(fallback: value));
  });
}
}


/// Adds pattern-matching-related methods to [MiniProgramManifest].
extension MiniProgramManifestPatterns on MiniProgramManifest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MiniProgramManifest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MiniProgramManifest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MiniProgramManifest value)  $default,){
final _that = this;
switch (_that) {
case _MiniProgramManifest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MiniProgramManifest value)?  $default,){
final _that = this;
switch (_that) {
case _MiniProgramManifest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String version,  String entry,  String contractVersion, @SdkVersionRangeConverter()  SdkVersionRange sdkVersionRange,  List<Capability> requiredCapabilities,  List<FeatureFlagKey> featureFlags,  MiniProgramCachePolicy cachePolicy,  MiniProgramFallback? fallback)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MiniProgramManifest() when $default != null:
return $default(_that.id,_that.version,_that.entry,_that.contractVersion,_that.sdkVersionRange,_that.requiredCapabilities,_that.featureFlags,_that.cachePolicy,_that.fallback);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String version,  String entry,  String contractVersion, @SdkVersionRangeConverter()  SdkVersionRange sdkVersionRange,  List<Capability> requiredCapabilities,  List<FeatureFlagKey> featureFlags,  MiniProgramCachePolicy cachePolicy,  MiniProgramFallback? fallback)  $default,) {final _that = this;
switch (_that) {
case _MiniProgramManifest():
return $default(_that.id,_that.version,_that.entry,_that.contractVersion,_that.sdkVersionRange,_that.requiredCapabilities,_that.featureFlags,_that.cachePolicy,_that.fallback);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String version,  String entry,  String contractVersion, @SdkVersionRangeConverter()  SdkVersionRange sdkVersionRange,  List<Capability> requiredCapabilities,  List<FeatureFlagKey> featureFlags,  MiniProgramCachePolicy cachePolicy,  MiniProgramFallback? fallback)?  $default,) {final _that = this;
switch (_that) {
case _MiniProgramManifest() when $default != null:
return $default(_that.id,_that.version,_that.entry,_that.contractVersion,_that.sdkVersionRange,_that.requiredCapabilities,_that.featureFlags,_that.cachePolicy,_that.fallback);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(checked: true, explicitToJson: true)
class _MiniProgramManifest implements MiniProgramManifest {
  const _MiniProgramManifest({required this.id, required this.version, required this.entry, required this.contractVersion, @SdkVersionRangeConverter() required this.sdkVersionRange, required final  List<Capability> requiredCapabilities, final  List<FeatureFlagKey> featureFlags = const <FeatureFlagKey>[], this.cachePolicy = const MiniProgramCachePolicy(), this.fallback}): _requiredCapabilities = requiredCapabilities,_featureFlags = featureFlags;
  factory _MiniProgramManifest.fromJson(Map<String, dynamic> json) => _$MiniProgramManifestFromJson(json);

@override final  String id;
@override final  String version;
@override final  String entry;
@override final  String contractVersion;
@override@SdkVersionRangeConverter() final  SdkVersionRange sdkVersionRange;
 final  List<Capability> _requiredCapabilities;
@override List<Capability> get requiredCapabilities {
  if (_requiredCapabilities is EqualUnmodifiableListView) return _requiredCapabilities;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_requiredCapabilities);
}

 final  List<FeatureFlagKey> _featureFlags;
@override@JsonKey() List<FeatureFlagKey> get featureFlags {
  if (_featureFlags is EqualUnmodifiableListView) return _featureFlags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_featureFlags);
}

@override@JsonKey() final  MiniProgramCachePolicy cachePolicy;
@override final  MiniProgramFallback? fallback;

/// Create a copy of MiniProgramManifest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MiniProgramManifestCopyWith<_MiniProgramManifest> get copyWith => __$MiniProgramManifestCopyWithImpl<_MiniProgramManifest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MiniProgramManifestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MiniProgramManifest&&(identical(other.id, id) || other.id == id)&&(identical(other.version, version) || other.version == version)&&(identical(other.entry, entry) || other.entry == entry)&&(identical(other.contractVersion, contractVersion) || other.contractVersion == contractVersion)&&(identical(other.sdkVersionRange, sdkVersionRange) || other.sdkVersionRange == sdkVersionRange)&&const DeepCollectionEquality().equals(other._requiredCapabilities, _requiredCapabilities)&&const DeepCollectionEquality().equals(other._featureFlags, _featureFlags)&&(identical(other.cachePolicy, cachePolicy) || other.cachePolicy == cachePolicy)&&(identical(other.fallback, fallback) || other.fallback == fallback));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,version,entry,contractVersion,sdkVersionRange,const DeepCollectionEquality().hash(_requiredCapabilities),const DeepCollectionEquality().hash(_featureFlags),cachePolicy,fallback);

@override
String toString() {
  return 'MiniProgramManifest(id: $id, version: $version, entry: $entry, contractVersion: $contractVersion, sdkVersionRange: $sdkVersionRange, requiredCapabilities: $requiredCapabilities, featureFlags: $featureFlags, cachePolicy: $cachePolicy, fallback: $fallback)';
}


}

/// @nodoc
abstract mixin class _$MiniProgramManifestCopyWith<$Res> implements $MiniProgramManifestCopyWith<$Res> {
  factory _$MiniProgramManifestCopyWith(_MiniProgramManifest value, $Res Function(_MiniProgramManifest) _then) = __$MiniProgramManifestCopyWithImpl;
@override @useResult
$Res call({
 String id, String version, String entry, String contractVersion,@SdkVersionRangeConverter() SdkVersionRange sdkVersionRange, List<Capability> requiredCapabilities, List<FeatureFlagKey> featureFlags, MiniProgramCachePolicy cachePolicy, MiniProgramFallback? fallback
});


@override $SdkVersionRangeCopyWith<$Res> get sdkVersionRange;@override $MiniProgramCachePolicyCopyWith<$Res> get cachePolicy;@override $MiniProgramFallbackCopyWith<$Res>? get fallback;

}
/// @nodoc
class __$MiniProgramManifestCopyWithImpl<$Res>
    implements _$MiniProgramManifestCopyWith<$Res> {
  __$MiniProgramManifestCopyWithImpl(this._self, this._then);

  final _MiniProgramManifest _self;
  final $Res Function(_MiniProgramManifest) _then;

/// Create a copy of MiniProgramManifest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? version = null,Object? entry = null,Object? contractVersion = null,Object? sdkVersionRange = null,Object? requiredCapabilities = null,Object? featureFlags = null,Object? cachePolicy = null,Object? fallback = freezed,}) {
  return _then(_MiniProgramManifest(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,entry: null == entry ? _self.entry : entry // ignore: cast_nullable_to_non_nullable
as String,contractVersion: null == contractVersion ? _self.contractVersion : contractVersion // ignore: cast_nullable_to_non_nullable
as String,sdkVersionRange: null == sdkVersionRange ? _self.sdkVersionRange : sdkVersionRange // ignore: cast_nullable_to_non_nullable
as SdkVersionRange,requiredCapabilities: null == requiredCapabilities ? _self._requiredCapabilities : requiredCapabilities // ignore: cast_nullable_to_non_nullable
as List<Capability>,featureFlags: null == featureFlags ? _self._featureFlags : featureFlags // ignore: cast_nullable_to_non_nullable
as List<FeatureFlagKey>,cachePolicy: null == cachePolicy ? _self.cachePolicy : cachePolicy // ignore: cast_nullable_to_non_nullable
as MiniProgramCachePolicy,fallback: freezed == fallback ? _self.fallback : fallback // ignore: cast_nullable_to_non_nullable
as MiniProgramFallback?,
  ));
}

/// Create a copy of MiniProgramManifest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SdkVersionRangeCopyWith<$Res> get sdkVersionRange {
  
  return $SdkVersionRangeCopyWith<$Res>(_self.sdkVersionRange, (value) {
    return _then(_self.copyWith(sdkVersionRange: value));
  });
}/// Create a copy of MiniProgramManifest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MiniProgramCachePolicyCopyWith<$Res> get cachePolicy {
  
  return $MiniProgramCachePolicyCopyWith<$Res>(_self.cachePolicy, (value) {
    return _then(_self.copyWith(cachePolicy: value));
  });
}/// Create a copy of MiniProgramManifest
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MiniProgramFallbackCopyWith<$Res>? get fallback {
    if (_self.fallback == null) {
    return null;
  }

  return $MiniProgramFallbackCopyWith<$Res>(_self.fallback!, (value) {
    return _then(_self.copyWith(fallback: value));
  });
}
}

// dart format on
