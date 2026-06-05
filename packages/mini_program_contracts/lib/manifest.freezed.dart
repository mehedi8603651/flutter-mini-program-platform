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
mixin _$MiniProgramCacheRule {

 MiniProgramCacheMode get mode;@JsonKey(includeIfNull: false) int? get maxStaleSeconds;
/// Create a copy of MiniProgramCacheRule
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MiniProgramCacheRuleCopyWith<MiniProgramCacheRule> get copyWith => _$MiniProgramCacheRuleCopyWithImpl<MiniProgramCacheRule>(this as MiniProgramCacheRule, _$identity);

  /// Serializes this MiniProgramCacheRule to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MiniProgramCacheRule&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.maxStaleSeconds, maxStaleSeconds) || other.maxStaleSeconds == maxStaleSeconds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,mode,maxStaleSeconds);

@override
String toString() {
  return 'MiniProgramCacheRule(mode: $mode, maxStaleSeconds: $maxStaleSeconds)';
}


}

/// @nodoc
abstract mixin class $MiniProgramCacheRuleCopyWith<$Res>  {
  factory $MiniProgramCacheRuleCopyWith(MiniProgramCacheRule value, $Res Function(MiniProgramCacheRule) _then) = _$MiniProgramCacheRuleCopyWithImpl;
@useResult
$Res call({
 MiniProgramCacheMode mode,@JsonKey(includeIfNull: false) int? maxStaleSeconds
});




}
/// @nodoc
class _$MiniProgramCacheRuleCopyWithImpl<$Res>
    implements $MiniProgramCacheRuleCopyWith<$Res> {
  _$MiniProgramCacheRuleCopyWithImpl(this._self, this._then);

  final MiniProgramCacheRule _self;
  final $Res Function(MiniProgramCacheRule) _then;

/// Create a copy of MiniProgramCacheRule
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? mode = null,Object? maxStaleSeconds = freezed,}) {
  return _then(_self.copyWith(
mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as MiniProgramCacheMode,maxStaleSeconds: freezed == maxStaleSeconds ? _self.maxStaleSeconds : maxStaleSeconds // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [MiniProgramCacheRule].
extension MiniProgramCacheRulePatterns on MiniProgramCacheRule {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MiniProgramCacheRule value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MiniProgramCacheRule() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MiniProgramCacheRule value)  $default,){
final _that = this;
switch (_that) {
case _MiniProgramCacheRule():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MiniProgramCacheRule value)?  $default,){
final _that = this;
switch (_that) {
case _MiniProgramCacheRule() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( MiniProgramCacheMode mode, @JsonKey(includeIfNull: false)  int? maxStaleSeconds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MiniProgramCacheRule() when $default != null:
return $default(_that.mode,_that.maxStaleSeconds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( MiniProgramCacheMode mode, @JsonKey(includeIfNull: false)  int? maxStaleSeconds)  $default,) {final _that = this;
switch (_that) {
case _MiniProgramCacheRule():
return $default(_that.mode,_that.maxStaleSeconds);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( MiniProgramCacheMode mode, @JsonKey(includeIfNull: false)  int? maxStaleSeconds)?  $default,) {final _that = this;
switch (_that) {
case _MiniProgramCacheRule() when $default != null:
return $default(_that.mode,_that.maxStaleSeconds);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(checked: true, explicitToJson: true)
class _MiniProgramCacheRule implements MiniProgramCacheRule {
  const _MiniProgramCacheRule({this.mode = MiniProgramCacheMode.staleWhileError, @JsonKey(includeIfNull: false) this.maxStaleSeconds}): assert(maxStaleSeconds == null || maxStaleSeconds > 0, 'maxStaleSeconds must be greater than zero when provided.');
  factory _MiniProgramCacheRule.fromJson(Map<String, dynamic> json) => _$MiniProgramCacheRuleFromJson(json);

@override@JsonKey() final  MiniProgramCacheMode mode;
@override@JsonKey(includeIfNull: false) final  int? maxStaleSeconds;

/// Create a copy of MiniProgramCacheRule
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MiniProgramCacheRuleCopyWith<_MiniProgramCacheRule> get copyWith => __$MiniProgramCacheRuleCopyWithImpl<_MiniProgramCacheRule>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MiniProgramCacheRuleToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MiniProgramCacheRule&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.maxStaleSeconds, maxStaleSeconds) || other.maxStaleSeconds == maxStaleSeconds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,mode,maxStaleSeconds);

@override
String toString() {
  return 'MiniProgramCacheRule(mode: $mode, maxStaleSeconds: $maxStaleSeconds)';
}


}

/// @nodoc
abstract mixin class _$MiniProgramCacheRuleCopyWith<$Res> implements $MiniProgramCacheRuleCopyWith<$Res> {
  factory _$MiniProgramCacheRuleCopyWith(_MiniProgramCacheRule value, $Res Function(_MiniProgramCacheRule) _then) = __$MiniProgramCacheRuleCopyWithImpl;
@override @useResult
$Res call({
 MiniProgramCacheMode mode,@JsonKey(includeIfNull: false) int? maxStaleSeconds
});




}
/// @nodoc
class __$MiniProgramCacheRuleCopyWithImpl<$Res>
    implements _$MiniProgramCacheRuleCopyWith<$Res> {
  __$MiniProgramCacheRuleCopyWithImpl(this._self, this._then);

  final _MiniProgramCacheRule _self;
  final $Res Function(_MiniProgramCacheRule) _then;

/// Create a copy of MiniProgramCacheRule
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? mode = null,Object? maxStaleSeconds = freezed,}) {
  return _then(_MiniProgramCacheRule(
mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as MiniProgramCacheMode,maxStaleSeconds: freezed == maxStaleSeconds ? _self.maxStaleSeconds : maxStaleSeconds // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$MiniProgramCachePolicy {

@MiniProgramCacheRuleConverter() MiniProgramCacheRule get manifest;@MiniProgramCacheRuleConverter() MiniProgramCacheRule get entryScreen;
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
@MiniProgramCacheRuleConverter() MiniProgramCacheRule manifest,@MiniProgramCacheRuleConverter() MiniProgramCacheRule entryScreen
});


$MiniProgramCacheRuleCopyWith<$Res> get manifest;$MiniProgramCacheRuleCopyWith<$Res> get entryScreen;

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
as MiniProgramCacheRule,entryScreen: null == entryScreen ? _self.entryScreen : entryScreen // ignore: cast_nullable_to_non_nullable
as MiniProgramCacheRule,
  ));
}
/// Create a copy of MiniProgramCachePolicy
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MiniProgramCacheRuleCopyWith<$Res> get manifest {
  
  return $MiniProgramCacheRuleCopyWith<$Res>(_self.manifest, (value) {
    return _then(_self.copyWith(manifest: value));
  });
}/// Create a copy of MiniProgramCachePolicy
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MiniProgramCacheRuleCopyWith<$Res> get entryScreen {
  
  return $MiniProgramCacheRuleCopyWith<$Res>(_self.entryScreen, (value) {
    return _then(_self.copyWith(entryScreen: value));
  });
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@MiniProgramCacheRuleConverter()  MiniProgramCacheRule manifest, @MiniProgramCacheRuleConverter()  MiniProgramCacheRule entryScreen)?  $default,{required TResult orElse(),}) {final _that = this;
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@MiniProgramCacheRuleConverter()  MiniProgramCacheRule manifest, @MiniProgramCacheRuleConverter()  MiniProgramCacheRule entryScreen)  $default,) {final _that = this;
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@MiniProgramCacheRuleConverter()  MiniProgramCacheRule manifest, @MiniProgramCacheRuleConverter()  MiniProgramCacheRule entryScreen)?  $default,) {final _that = this;
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
  const _MiniProgramCachePolicy({@MiniProgramCacheRuleConverter() this.manifest = const MiniProgramCacheRule(), @MiniProgramCacheRuleConverter() this.entryScreen = const MiniProgramCacheRule()});
  factory _MiniProgramCachePolicy.fromJson(Map<String, dynamic> json) => _$MiniProgramCachePolicyFromJson(json);

@override@JsonKey()@MiniProgramCacheRuleConverter() final  MiniProgramCacheRule manifest;
@override@JsonKey()@MiniProgramCacheRuleConverter() final  MiniProgramCacheRule entryScreen;

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
@MiniProgramCacheRuleConverter() MiniProgramCacheRule manifest,@MiniProgramCacheRuleConverter() MiniProgramCacheRule entryScreen
});


@override $MiniProgramCacheRuleCopyWith<$Res> get manifest;@override $MiniProgramCacheRuleCopyWith<$Res> get entryScreen;

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
as MiniProgramCacheRule,entryScreen: null == entryScreen ? _self.entryScreen : entryScreen // ignore: cast_nullable_to_non_nullable
as MiniProgramCacheRule,
  ));
}

/// Create a copy of MiniProgramCachePolicy
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MiniProgramCacheRuleCopyWith<$Res> get manifest {
  
  return $MiniProgramCacheRuleCopyWith<$Res>(_self.manifest, (value) {
    return _then(_self.copyWith(manifest: value));
  });
}/// Create a copy of MiniProgramCachePolicy
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MiniProgramCacheRuleCopyWith<$Res> get entryScreen {
  
  return $MiniProgramCacheRuleCopyWith<$Res>(_self.entryScreen, (value) {
    return _then(_self.copyWith(entryScreen: value));
  });
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

 String get id; String get version; String get entry; String get contractVersion;@SdkVersionRangeConverter() SdkVersionRange get sdkVersionRange;@CapabilityIdListConverter() List<CapabilityId> get requiredCapabilities;@MiniProgramScreenFormatConverter() MiniProgramScreenFormat get screenFormat; int? get screenSchemaVersion; List<FeatureFlagKey> get featureFlags; MiniProgramCachePolicy get cachePolicy; MiniProgramFallback? get fallback;
/// Create a copy of MiniProgramManifest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MiniProgramManifestCopyWith<MiniProgramManifest> get copyWith => _$MiniProgramManifestCopyWithImpl<MiniProgramManifest>(this as MiniProgramManifest, _$identity);

  /// Serializes this MiniProgramManifest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MiniProgramManifest&&(identical(other.id, id) || other.id == id)&&(identical(other.version, version) || other.version == version)&&(identical(other.entry, entry) || other.entry == entry)&&(identical(other.contractVersion, contractVersion) || other.contractVersion == contractVersion)&&(identical(other.sdkVersionRange, sdkVersionRange) || other.sdkVersionRange == sdkVersionRange)&&const DeepCollectionEquality().equals(other.requiredCapabilities, requiredCapabilities)&&(identical(other.screenFormat, screenFormat) || other.screenFormat == screenFormat)&&(identical(other.screenSchemaVersion, screenSchemaVersion) || other.screenSchemaVersion == screenSchemaVersion)&&const DeepCollectionEquality().equals(other.featureFlags, featureFlags)&&(identical(other.cachePolicy, cachePolicy) || other.cachePolicy == cachePolicy)&&(identical(other.fallback, fallback) || other.fallback == fallback));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,version,entry,contractVersion,sdkVersionRange,const DeepCollectionEquality().hash(requiredCapabilities),screenFormat,screenSchemaVersion,const DeepCollectionEquality().hash(featureFlags),cachePolicy,fallback);

@override
String toString() {
  return 'MiniProgramManifest(id: $id, version: $version, entry: $entry, contractVersion: $contractVersion, sdkVersionRange: $sdkVersionRange, requiredCapabilities: $requiredCapabilities, screenFormat: $screenFormat, screenSchemaVersion: $screenSchemaVersion, featureFlags: $featureFlags, cachePolicy: $cachePolicy, fallback: $fallback)';
}


}

/// @nodoc
abstract mixin class $MiniProgramManifestCopyWith<$Res>  {
  factory $MiniProgramManifestCopyWith(MiniProgramManifest value, $Res Function(MiniProgramManifest) _then) = _$MiniProgramManifestCopyWithImpl;
@useResult
$Res call({
 String id, String version, String entry, String contractVersion,@SdkVersionRangeConverter() SdkVersionRange sdkVersionRange,@CapabilityIdListConverter() List<CapabilityId> requiredCapabilities,@MiniProgramScreenFormatConverter() MiniProgramScreenFormat screenFormat, int? screenSchemaVersion, List<FeatureFlagKey> featureFlags, MiniProgramCachePolicy cachePolicy, MiniProgramFallback? fallback
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? version = null,Object? entry = null,Object? contractVersion = null,Object? sdkVersionRange = null,Object? requiredCapabilities = null,Object? screenFormat = null,Object? screenSchemaVersion = freezed,Object? featureFlags = null,Object? cachePolicy = null,Object? fallback = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,entry: null == entry ? _self.entry : entry // ignore: cast_nullable_to_non_nullable
as String,contractVersion: null == contractVersion ? _self.contractVersion : contractVersion // ignore: cast_nullable_to_non_nullable
as String,sdkVersionRange: null == sdkVersionRange ? _self.sdkVersionRange : sdkVersionRange // ignore: cast_nullable_to_non_nullable
as SdkVersionRange,requiredCapabilities: null == requiredCapabilities ? _self.requiredCapabilities : requiredCapabilities // ignore: cast_nullable_to_non_nullable
as List<CapabilityId>,screenFormat: null == screenFormat ? _self.screenFormat : screenFormat // ignore: cast_nullable_to_non_nullable
as MiniProgramScreenFormat,screenSchemaVersion: freezed == screenSchemaVersion ? _self.screenSchemaVersion : screenSchemaVersion // ignore: cast_nullable_to_non_nullable
as int?,featureFlags: null == featureFlags ? _self.featureFlags : featureFlags // ignore: cast_nullable_to_non_nullable
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String version,  String entry,  String contractVersion, @SdkVersionRangeConverter()  SdkVersionRange sdkVersionRange, @CapabilityIdListConverter()  List<CapabilityId> requiredCapabilities, @MiniProgramScreenFormatConverter()  MiniProgramScreenFormat screenFormat,  int? screenSchemaVersion,  List<FeatureFlagKey> featureFlags,  MiniProgramCachePolicy cachePolicy,  MiniProgramFallback? fallback)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MiniProgramManifest() when $default != null:
return $default(_that.id,_that.version,_that.entry,_that.contractVersion,_that.sdkVersionRange,_that.requiredCapabilities,_that.screenFormat,_that.screenSchemaVersion,_that.featureFlags,_that.cachePolicy,_that.fallback);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String version,  String entry,  String contractVersion, @SdkVersionRangeConverter()  SdkVersionRange sdkVersionRange, @CapabilityIdListConverter()  List<CapabilityId> requiredCapabilities, @MiniProgramScreenFormatConverter()  MiniProgramScreenFormat screenFormat,  int? screenSchemaVersion,  List<FeatureFlagKey> featureFlags,  MiniProgramCachePolicy cachePolicy,  MiniProgramFallback? fallback)  $default,) {final _that = this;
switch (_that) {
case _MiniProgramManifest():
return $default(_that.id,_that.version,_that.entry,_that.contractVersion,_that.sdkVersionRange,_that.requiredCapabilities,_that.screenFormat,_that.screenSchemaVersion,_that.featureFlags,_that.cachePolicy,_that.fallback);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String version,  String entry,  String contractVersion, @SdkVersionRangeConverter()  SdkVersionRange sdkVersionRange, @CapabilityIdListConverter()  List<CapabilityId> requiredCapabilities, @MiniProgramScreenFormatConverter()  MiniProgramScreenFormat screenFormat,  int? screenSchemaVersion,  List<FeatureFlagKey> featureFlags,  MiniProgramCachePolicy cachePolicy,  MiniProgramFallback? fallback)?  $default,) {final _that = this;
switch (_that) {
case _MiniProgramManifest() when $default != null:
return $default(_that.id,_that.version,_that.entry,_that.contractVersion,_that.sdkVersionRange,_that.requiredCapabilities,_that.screenFormat,_that.screenSchemaVersion,_that.featureFlags,_that.cachePolicy,_that.fallback);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(checked: true, explicitToJson: true)
class _MiniProgramManifest implements MiniProgramManifest {
  const _MiniProgramManifest({required this.id, required this.version, required this.entry, required this.contractVersion, @SdkVersionRangeConverter() required this.sdkVersionRange, @CapabilityIdListConverter() required final  List<CapabilityId> requiredCapabilities, @MiniProgramScreenFormatConverter() this.screenFormat = MiniProgramScreenFormats.mp, this.screenSchemaVersion = 1, final  List<FeatureFlagKey> featureFlags = const <FeatureFlagKey>[], this.cachePolicy = const MiniProgramCachePolicy(), this.fallback}): assert(screenFormat != 'mp' || screenSchemaVersion != null, 'screenSchemaVersion is required when screenFormat is "mp".'),assert(screenSchemaVersion == null || screenSchemaVersion > 0, 'screenSchemaVersion must be greater than zero when provided.'),_requiredCapabilities = requiredCapabilities,_featureFlags = featureFlags;
  factory _MiniProgramManifest.fromJson(Map<String, dynamic> json) => _$MiniProgramManifestFromJson(json);

@override final  String id;
@override final  String version;
@override final  String entry;
@override final  String contractVersion;
@override@SdkVersionRangeConverter() final  SdkVersionRange sdkVersionRange;
 final  List<CapabilityId> _requiredCapabilities;
@override@CapabilityIdListConverter() List<CapabilityId> get requiredCapabilities {
  if (_requiredCapabilities is EqualUnmodifiableListView) return _requiredCapabilities;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_requiredCapabilities);
}

@override@JsonKey()@MiniProgramScreenFormatConverter() final  MiniProgramScreenFormat screenFormat;
@override@JsonKey() final  int? screenSchemaVersion;
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MiniProgramManifest&&(identical(other.id, id) || other.id == id)&&(identical(other.version, version) || other.version == version)&&(identical(other.entry, entry) || other.entry == entry)&&(identical(other.contractVersion, contractVersion) || other.contractVersion == contractVersion)&&(identical(other.sdkVersionRange, sdkVersionRange) || other.sdkVersionRange == sdkVersionRange)&&const DeepCollectionEquality().equals(other._requiredCapabilities, _requiredCapabilities)&&(identical(other.screenFormat, screenFormat) || other.screenFormat == screenFormat)&&(identical(other.screenSchemaVersion, screenSchemaVersion) || other.screenSchemaVersion == screenSchemaVersion)&&const DeepCollectionEquality().equals(other._featureFlags, _featureFlags)&&(identical(other.cachePolicy, cachePolicy) || other.cachePolicy == cachePolicy)&&(identical(other.fallback, fallback) || other.fallback == fallback));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,version,entry,contractVersion,sdkVersionRange,const DeepCollectionEquality().hash(_requiredCapabilities),screenFormat,screenSchemaVersion,const DeepCollectionEquality().hash(_featureFlags),cachePolicy,fallback);

@override
String toString() {
  return 'MiniProgramManifest(id: $id, version: $version, entry: $entry, contractVersion: $contractVersion, sdkVersionRange: $sdkVersionRange, requiredCapabilities: $requiredCapabilities, screenFormat: $screenFormat, screenSchemaVersion: $screenSchemaVersion, featureFlags: $featureFlags, cachePolicy: $cachePolicy, fallback: $fallback)';
}


}

/// @nodoc
abstract mixin class _$MiniProgramManifestCopyWith<$Res> implements $MiniProgramManifestCopyWith<$Res> {
  factory _$MiniProgramManifestCopyWith(_MiniProgramManifest value, $Res Function(_MiniProgramManifest) _then) = __$MiniProgramManifestCopyWithImpl;
@override @useResult
$Res call({
 String id, String version, String entry, String contractVersion,@SdkVersionRangeConverter() SdkVersionRange sdkVersionRange,@CapabilityIdListConverter() List<CapabilityId> requiredCapabilities,@MiniProgramScreenFormatConverter() MiniProgramScreenFormat screenFormat, int? screenSchemaVersion, List<FeatureFlagKey> featureFlags, MiniProgramCachePolicy cachePolicy, MiniProgramFallback? fallback
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? version = null,Object? entry = null,Object? contractVersion = null,Object? sdkVersionRange = null,Object? requiredCapabilities = null,Object? screenFormat = null,Object? screenSchemaVersion = freezed,Object? featureFlags = null,Object? cachePolicy = null,Object? fallback = freezed,}) {
  return _then(_MiniProgramManifest(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,entry: null == entry ? _self.entry : entry // ignore: cast_nullable_to_non_nullable
as String,contractVersion: null == contractVersion ? _self.contractVersion : contractVersion // ignore: cast_nullable_to_non_nullable
as String,sdkVersionRange: null == sdkVersionRange ? _self.sdkVersionRange : sdkVersionRange // ignore: cast_nullable_to_non_nullable
as SdkVersionRange,requiredCapabilities: null == requiredCapabilities ? _self._requiredCapabilities : requiredCapabilities // ignore: cast_nullable_to_non_nullable
as List<CapabilityId>,screenFormat: null == screenFormat ? _self.screenFormat : screenFormat // ignore: cast_nullable_to_non_nullable
as MiniProgramScreenFormat,screenSchemaVersion: freezed == screenSchemaVersion ? _self.screenSchemaVersion : screenSchemaVersion // ignore: cast_nullable_to_non_nullable
as int?,featureFlags: null == featureFlags ? _self._featureFlags : featureFlags // ignore: cast_nullable_to_non_nullable
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
