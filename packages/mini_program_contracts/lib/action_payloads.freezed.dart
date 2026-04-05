// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'action_payloads.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OpenNativeScreenActionPayload {

 String get route; Map<String, dynamic> get args; bool get expectResult;
/// Create a copy of OpenNativeScreenActionPayload
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OpenNativeScreenActionPayloadCopyWith<OpenNativeScreenActionPayload> get copyWith => _$OpenNativeScreenActionPayloadCopyWithImpl<OpenNativeScreenActionPayload>(this as OpenNativeScreenActionPayload, _$identity);

  /// Serializes this OpenNativeScreenActionPayload to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OpenNativeScreenActionPayload&&(identical(other.route, route) || other.route == route)&&const DeepCollectionEquality().equals(other.args, args)&&(identical(other.expectResult, expectResult) || other.expectResult == expectResult));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,route,const DeepCollectionEquality().hash(args),expectResult);

@override
String toString() {
  return 'OpenNativeScreenActionPayload(route: $route, args: $args, expectResult: $expectResult)';
}


}

/// @nodoc
abstract mixin class $OpenNativeScreenActionPayloadCopyWith<$Res>  {
  factory $OpenNativeScreenActionPayloadCopyWith(OpenNativeScreenActionPayload value, $Res Function(OpenNativeScreenActionPayload) _then) = _$OpenNativeScreenActionPayloadCopyWithImpl;
@useResult
$Res call({
 String route, Map<String, dynamic> args, bool expectResult
});




}
/// @nodoc
class _$OpenNativeScreenActionPayloadCopyWithImpl<$Res>
    implements $OpenNativeScreenActionPayloadCopyWith<$Res> {
  _$OpenNativeScreenActionPayloadCopyWithImpl(this._self, this._then);

  final OpenNativeScreenActionPayload _self;
  final $Res Function(OpenNativeScreenActionPayload) _then;

/// Create a copy of OpenNativeScreenActionPayload
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? route = null,Object? args = null,Object? expectResult = null,}) {
  return _then(_self.copyWith(
route: null == route ? _self.route : route // ignore: cast_nullable_to_non_nullable
as String,args: null == args ? _self.args : args // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,expectResult: null == expectResult ? _self.expectResult : expectResult // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [OpenNativeScreenActionPayload].
extension OpenNativeScreenActionPayloadPatterns on OpenNativeScreenActionPayload {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OpenNativeScreenActionPayload value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OpenNativeScreenActionPayload() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OpenNativeScreenActionPayload value)  $default,){
final _that = this;
switch (_that) {
case _OpenNativeScreenActionPayload():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OpenNativeScreenActionPayload value)?  $default,){
final _that = this;
switch (_that) {
case _OpenNativeScreenActionPayload() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String route,  Map<String, dynamic> args,  bool expectResult)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OpenNativeScreenActionPayload() when $default != null:
return $default(_that.route,_that.args,_that.expectResult);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String route,  Map<String, dynamic> args,  bool expectResult)  $default,) {final _that = this;
switch (_that) {
case _OpenNativeScreenActionPayload():
return $default(_that.route,_that.args,_that.expectResult);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String route,  Map<String, dynamic> args,  bool expectResult)?  $default,) {final _that = this;
switch (_that) {
case _OpenNativeScreenActionPayload() when $default != null:
return $default(_that.route,_that.args,_that.expectResult);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(checked: true, explicitToJson: true)
class _OpenNativeScreenActionPayload implements OpenNativeScreenActionPayload {
  const _OpenNativeScreenActionPayload({required this.route, final  Map<String, dynamic> args = const <String, dynamic>{}, this.expectResult = false}): _args = args;
  factory _OpenNativeScreenActionPayload.fromJson(Map<String, dynamic> json) => _$OpenNativeScreenActionPayloadFromJson(json);

@override final  String route;
 final  Map<String, dynamic> _args;
@override@JsonKey() Map<String, dynamic> get args {
  if (_args is EqualUnmodifiableMapView) return _args;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_args);
}

@override@JsonKey() final  bool expectResult;

/// Create a copy of OpenNativeScreenActionPayload
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OpenNativeScreenActionPayloadCopyWith<_OpenNativeScreenActionPayload> get copyWith => __$OpenNativeScreenActionPayloadCopyWithImpl<_OpenNativeScreenActionPayload>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OpenNativeScreenActionPayloadToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OpenNativeScreenActionPayload&&(identical(other.route, route) || other.route == route)&&const DeepCollectionEquality().equals(other._args, _args)&&(identical(other.expectResult, expectResult) || other.expectResult == expectResult));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,route,const DeepCollectionEquality().hash(_args),expectResult);

@override
String toString() {
  return 'OpenNativeScreenActionPayload(route: $route, args: $args, expectResult: $expectResult)';
}


}

/// @nodoc
abstract mixin class _$OpenNativeScreenActionPayloadCopyWith<$Res> implements $OpenNativeScreenActionPayloadCopyWith<$Res> {
  factory _$OpenNativeScreenActionPayloadCopyWith(_OpenNativeScreenActionPayload value, $Res Function(_OpenNativeScreenActionPayload) _then) = __$OpenNativeScreenActionPayloadCopyWithImpl;
@override @useResult
$Res call({
 String route, Map<String, dynamic> args, bool expectResult
});




}
/// @nodoc
class __$OpenNativeScreenActionPayloadCopyWithImpl<$Res>
    implements _$OpenNativeScreenActionPayloadCopyWith<$Res> {
  __$OpenNativeScreenActionPayloadCopyWithImpl(this._self, this._then);

  final _OpenNativeScreenActionPayload _self;
  final $Res Function(_OpenNativeScreenActionPayload) _then;

/// Create a copy of OpenNativeScreenActionPayload
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? route = null,Object? args = null,Object? expectResult = null,}) {
  return _then(_OpenNativeScreenActionPayload(
route: null == route ? _self.route : route // ignore: cast_nullable_to_non_nullable
as String,args: null == args ? _self._args : args // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,expectResult: null == expectResult ? _self.expectResult : expectResult // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$CallSecureApiActionPayload {

 String get endpoint; String get method; Map<String, dynamic> get body;
/// Create a copy of CallSecureApiActionPayload
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CallSecureApiActionPayloadCopyWith<CallSecureApiActionPayload> get copyWith => _$CallSecureApiActionPayloadCopyWithImpl<CallSecureApiActionPayload>(this as CallSecureApiActionPayload, _$identity);

  /// Serializes this CallSecureApiActionPayload to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CallSecureApiActionPayload&&(identical(other.endpoint, endpoint) || other.endpoint == endpoint)&&(identical(other.method, method) || other.method == method)&&const DeepCollectionEquality().equals(other.body, body));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,endpoint,method,const DeepCollectionEquality().hash(body));

@override
String toString() {
  return 'CallSecureApiActionPayload(endpoint: $endpoint, method: $method, body: $body)';
}


}

/// @nodoc
abstract mixin class $CallSecureApiActionPayloadCopyWith<$Res>  {
  factory $CallSecureApiActionPayloadCopyWith(CallSecureApiActionPayload value, $Res Function(CallSecureApiActionPayload) _then) = _$CallSecureApiActionPayloadCopyWithImpl;
@useResult
$Res call({
 String endpoint, String method, Map<String, dynamic> body
});




}
/// @nodoc
class _$CallSecureApiActionPayloadCopyWithImpl<$Res>
    implements $CallSecureApiActionPayloadCopyWith<$Res> {
  _$CallSecureApiActionPayloadCopyWithImpl(this._self, this._then);

  final CallSecureApiActionPayload _self;
  final $Res Function(CallSecureApiActionPayload) _then;

/// Create a copy of CallSecureApiActionPayload
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? endpoint = null,Object? method = null,Object? body = null,}) {
  return _then(_self.copyWith(
endpoint: null == endpoint ? _self.endpoint : endpoint // ignore: cast_nullable_to_non_nullable
as String,method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}

}


/// Adds pattern-matching-related methods to [CallSecureApiActionPayload].
extension CallSecureApiActionPayloadPatterns on CallSecureApiActionPayload {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CallSecureApiActionPayload value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CallSecureApiActionPayload() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CallSecureApiActionPayload value)  $default,){
final _that = this;
switch (_that) {
case _CallSecureApiActionPayload():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CallSecureApiActionPayload value)?  $default,){
final _that = this;
switch (_that) {
case _CallSecureApiActionPayload() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String endpoint,  String method,  Map<String, dynamic> body)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CallSecureApiActionPayload() when $default != null:
return $default(_that.endpoint,_that.method,_that.body);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String endpoint,  String method,  Map<String, dynamic> body)  $default,) {final _that = this;
switch (_that) {
case _CallSecureApiActionPayload():
return $default(_that.endpoint,_that.method,_that.body);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String endpoint,  String method,  Map<String, dynamic> body)?  $default,) {final _that = this;
switch (_that) {
case _CallSecureApiActionPayload() when $default != null:
return $default(_that.endpoint,_that.method,_that.body);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(checked: true, explicitToJson: true)
class _CallSecureApiActionPayload implements CallSecureApiActionPayload {
  const _CallSecureApiActionPayload({required this.endpoint, this.method = 'POST', final  Map<String, dynamic> body = const <String, dynamic>{}}): _body = body;
  factory _CallSecureApiActionPayload.fromJson(Map<String, dynamic> json) => _$CallSecureApiActionPayloadFromJson(json);

@override final  String endpoint;
@override@JsonKey() final  String method;
 final  Map<String, dynamic> _body;
@override@JsonKey() Map<String, dynamic> get body {
  if (_body is EqualUnmodifiableMapView) return _body;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_body);
}


/// Create a copy of CallSecureApiActionPayload
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CallSecureApiActionPayloadCopyWith<_CallSecureApiActionPayload> get copyWith => __$CallSecureApiActionPayloadCopyWithImpl<_CallSecureApiActionPayload>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CallSecureApiActionPayloadToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CallSecureApiActionPayload&&(identical(other.endpoint, endpoint) || other.endpoint == endpoint)&&(identical(other.method, method) || other.method == method)&&const DeepCollectionEquality().equals(other._body, _body));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,endpoint,method,const DeepCollectionEquality().hash(_body));

@override
String toString() {
  return 'CallSecureApiActionPayload(endpoint: $endpoint, method: $method, body: $body)';
}


}

/// @nodoc
abstract mixin class _$CallSecureApiActionPayloadCopyWith<$Res> implements $CallSecureApiActionPayloadCopyWith<$Res> {
  factory _$CallSecureApiActionPayloadCopyWith(_CallSecureApiActionPayload value, $Res Function(_CallSecureApiActionPayload) _then) = __$CallSecureApiActionPayloadCopyWithImpl;
@override @useResult
$Res call({
 String endpoint, String method, Map<String, dynamic> body
});




}
/// @nodoc
class __$CallSecureApiActionPayloadCopyWithImpl<$Res>
    implements _$CallSecureApiActionPayloadCopyWith<$Res> {
  __$CallSecureApiActionPayloadCopyWithImpl(this._self, this._then);

  final _CallSecureApiActionPayload _self;
  final $Res Function(_CallSecureApiActionPayload) _then;

/// Create a copy of CallSecureApiActionPayload
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? endpoint = null,Object? method = null,Object? body = null,}) {
  return _then(_CallSecureApiActionPayload(
endpoint: null == endpoint ? _self.endpoint : endpoint // ignore: cast_nullable_to_non_nullable
as String,method: null == method ? _self.method : method // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self._body : body // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}


}


/// @nodoc
mixin _$TrackEventActionPayload {

 String get name; Map<String, dynamic> get properties;
/// Create a copy of TrackEventActionPayload
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TrackEventActionPayloadCopyWith<TrackEventActionPayload> get copyWith => _$TrackEventActionPayloadCopyWithImpl<TrackEventActionPayload>(this as TrackEventActionPayload, _$identity);

  /// Serializes this TrackEventActionPayload to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TrackEventActionPayload&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other.properties, properties));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,const DeepCollectionEquality().hash(properties));

@override
String toString() {
  return 'TrackEventActionPayload(name: $name, properties: $properties)';
}


}

/// @nodoc
abstract mixin class $TrackEventActionPayloadCopyWith<$Res>  {
  factory $TrackEventActionPayloadCopyWith(TrackEventActionPayload value, $Res Function(TrackEventActionPayload) _then) = _$TrackEventActionPayloadCopyWithImpl;
@useResult
$Res call({
 String name, Map<String, dynamic> properties
});




}
/// @nodoc
class _$TrackEventActionPayloadCopyWithImpl<$Res>
    implements $TrackEventActionPayloadCopyWith<$Res> {
  _$TrackEventActionPayloadCopyWithImpl(this._self, this._then);

  final TrackEventActionPayload _self;
  final $Res Function(TrackEventActionPayload) _then;

/// Create a copy of TrackEventActionPayload
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? properties = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,properties: null == properties ? _self.properties : properties // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}

}


/// Adds pattern-matching-related methods to [TrackEventActionPayload].
extension TrackEventActionPayloadPatterns on TrackEventActionPayload {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TrackEventActionPayload value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TrackEventActionPayload() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TrackEventActionPayload value)  $default,){
final _that = this;
switch (_that) {
case _TrackEventActionPayload():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TrackEventActionPayload value)?  $default,){
final _that = this;
switch (_that) {
case _TrackEventActionPayload() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  Map<String, dynamic> properties)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TrackEventActionPayload() when $default != null:
return $default(_that.name,_that.properties);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  Map<String, dynamic> properties)  $default,) {final _that = this;
switch (_that) {
case _TrackEventActionPayload():
return $default(_that.name,_that.properties);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  Map<String, dynamic> properties)?  $default,) {final _that = this;
switch (_that) {
case _TrackEventActionPayload() when $default != null:
return $default(_that.name,_that.properties);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(checked: true, explicitToJson: true)
class _TrackEventActionPayload implements TrackEventActionPayload {
  const _TrackEventActionPayload({required this.name, final  Map<String, dynamic> properties = const <String, dynamic>{}}): _properties = properties;
  factory _TrackEventActionPayload.fromJson(Map<String, dynamic> json) => _$TrackEventActionPayloadFromJson(json);

@override final  String name;
 final  Map<String, dynamic> _properties;
@override@JsonKey() Map<String, dynamic> get properties {
  if (_properties is EqualUnmodifiableMapView) return _properties;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_properties);
}


/// Create a copy of TrackEventActionPayload
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TrackEventActionPayloadCopyWith<_TrackEventActionPayload> get copyWith => __$TrackEventActionPayloadCopyWithImpl<_TrackEventActionPayload>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TrackEventActionPayloadToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TrackEventActionPayload&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other._properties, _properties));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,const DeepCollectionEquality().hash(_properties));

@override
String toString() {
  return 'TrackEventActionPayload(name: $name, properties: $properties)';
}


}

/// @nodoc
abstract mixin class _$TrackEventActionPayloadCopyWith<$Res> implements $TrackEventActionPayloadCopyWith<$Res> {
  factory _$TrackEventActionPayloadCopyWith(_TrackEventActionPayload value, $Res Function(_TrackEventActionPayload) _then) = __$TrackEventActionPayloadCopyWithImpl;
@override @useResult
$Res call({
 String name, Map<String, dynamic> properties
});




}
/// @nodoc
class __$TrackEventActionPayloadCopyWithImpl<$Res>
    implements _$TrackEventActionPayloadCopyWith<$Res> {
  __$TrackEventActionPayloadCopyWithImpl(this._self, this._then);

  final _TrackEventActionPayload _self;
  final $Res Function(_TrackEventActionPayload) _then;

/// Create a copy of TrackEventActionPayload
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? properties = null,}) {
  return _then(_TrackEventActionPayload(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,properties: null == properties ? _self._properties : properties // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}


}

// dart format on
