// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'host_actions.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$HostActionRequest {

 String? get requestId;@JsonKey(name: 'action') String get actionName; Map<String, dynamic> get payload;
/// Create a copy of HostActionRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HostActionRequestCopyWith<HostActionRequest> get copyWith => _$HostActionRequestCopyWithImpl<HostActionRequest>(this as HostActionRequest, _$identity);

  /// Serializes this HostActionRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HostActionRequest&&(identical(other.requestId, requestId) || other.requestId == requestId)&&(identical(other.actionName, actionName) || other.actionName == actionName)&&const DeepCollectionEquality().equals(other.payload, payload));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,requestId,actionName,const DeepCollectionEquality().hash(payload));

@override
String toString() {
  return 'HostActionRequest(requestId: $requestId, actionName: $actionName, payload: $payload)';
}


}

/// @nodoc
abstract mixin class $HostActionRequestCopyWith<$Res>  {
  factory $HostActionRequestCopyWith(HostActionRequest value, $Res Function(HostActionRequest) _then) = _$HostActionRequestCopyWithImpl;
@useResult
$Res call({
 String? requestId,@JsonKey(name: 'action') String actionName, Map<String, dynamic> payload
});




}
/// @nodoc
class _$HostActionRequestCopyWithImpl<$Res>
    implements $HostActionRequestCopyWith<$Res> {
  _$HostActionRequestCopyWithImpl(this._self, this._then);

  final HostActionRequest _self;
  final $Res Function(HostActionRequest) _then;

/// Create a copy of HostActionRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? requestId = freezed,Object? actionName = null,Object? payload = null,}) {
  return _then(_self.copyWith(
requestId: freezed == requestId ? _self.requestId : requestId // ignore: cast_nullable_to_non_nullable
as String?,actionName: null == actionName ? _self.actionName : actionName // ignore: cast_nullable_to_non_nullable
as String,payload: null == payload ? _self.payload : payload // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}

}


/// Adds pattern-matching-related methods to [HostActionRequest].
extension HostActionRequestPatterns on HostActionRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HostActionRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HostActionRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HostActionRequest value)  $default,){
final _that = this;
switch (_that) {
case _HostActionRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HostActionRequest value)?  $default,){
final _that = this;
switch (_that) {
case _HostActionRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? requestId, @JsonKey(name: 'action')  String actionName,  Map<String, dynamic> payload)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HostActionRequest() when $default != null:
return $default(_that.requestId,_that.actionName,_that.payload);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? requestId, @JsonKey(name: 'action')  String actionName,  Map<String, dynamic> payload)  $default,) {final _that = this;
switch (_that) {
case _HostActionRequest():
return $default(_that.requestId,_that.actionName,_that.payload);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? requestId, @JsonKey(name: 'action')  String actionName,  Map<String, dynamic> payload)?  $default,) {final _that = this;
switch (_that) {
case _HostActionRequest() when $default != null:
return $default(_that.requestId,_that.actionName,_that.payload);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(checked: true, explicitToJson: true)
class _HostActionRequest extends HostActionRequest {
  const _HostActionRequest({this.requestId, @JsonKey(name: 'action') required this.actionName, final  Map<String, dynamic> payload = const <String, dynamic>{}}): _payload = payload,super._();
  factory _HostActionRequest.fromJson(Map<String, dynamic> json) => _$HostActionRequestFromJson(json);

@override final  String? requestId;
@override@JsonKey(name: 'action') final  String actionName;
 final  Map<String, dynamic> _payload;
@override@JsonKey() Map<String, dynamic> get payload {
  if (_payload is EqualUnmodifiableMapView) return _payload;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_payload);
}


/// Create a copy of HostActionRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HostActionRequestCopyWith<_HostActionRequest> get copyWith => __$HostActionRequestCopyWithImpl<_HostActionRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HostActionRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _HostActionRequest&&(identical(other.requestId, requestId) || other.requestId == requestId)&&(identical(other.actionName, actionName) || other.actionName == actionName)&&const DeepCollectionEquality().equals(other._payload, _payload));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,requestId,actionName,const DeepCollectionEquality().hash(_payload));

@override
String toString() {
  return 'HostActionRequest(requestId: $requestId, actionName: $actionName, payload: $payload)';
}


}

/// @nodoc
abstract mixin class _$HostActionRequestCopyWith<$Res> implements $HostActionRequestCopyWith<$Res> {
  factory _$HostActionRequestCopyWith(_HostActionRequest value, $Res Function(_HostActionRequest) _then) = __$HostActionRequestCopyWithImpl;
@override @useResult
$Res call({
 String? requestId,@JsonKey(name: 'action') String actionName, Map<String, dynamic> payload
});




}
/// @nodoc
class __$HostActionRequestCopyWithImpl<$Res>
    implements _$HostActionRequestCopyWith<$Res> {
  __$HostActionRequestCopyWithImpl(this._self, this._then);

  final _HostActionRequest _self;
  final $Res Function(_HostActionRequest) _then;

/// Create a copy of HostActionRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? requestId = freezed,Object? actionName = null,Object? payload = null,}) {
  return _then(_HostActionRequest(
requestId: freezed == requestId ? _self.requestId : requestId // ignore: cast_nullable_to_non_nullable
as String?,actionName: null == actionName ? _self.actionName : actionName // ignore: cast_nullable_to_non_nullable
as String,payload: null == payload ? _self._payload : payload // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}


}


/// @nodoc
mixin _$HostActionResult {

 String? get requestId;@JsonKey(name: 'action') String? get actionName; HostActionStatus get status; String? get message; String? get errorCode; Map<String, dynamic> get data;
/// Create a copy of HostActionResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HostActionResultCopyWith<HostActionResult> get copyWith => _$HostActionResultCopyWithImpl<HostActionResult>(this as HostActionResult, _$identity);

  /// Serializes this HostActionResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is HostActionResult&&(identical(other.requestId, requestId) || other.requestId == requestId)&&(identical(other.actionName, actionName) || other.actionName == actionName)&&(identical(other.status, status) || other.status == status)&&(identical(other.message, message) || other.message == message)&&(identical(other.errorCode, errorCode) || other.errorCode == errorCode)&&const DeepCollectionEquality().equals(other.data, data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,requestId,actionName,status,message,errorCode,const DeepCollectionEquality().hash(data));

@override
String toString() {
  return 'HostActionResult(requestId: $requestId, actionName: $actionName, status: $status, message: $message, errorCode: $errorCode, data: $data)';
}


}

/// @nodoc
abstract mixin class $HostActionResultCopyWith<$Res>  {
  factory $HostActionResultCopyWith(HostActionResult value, $Res Function(HostActionResult) _then) = _$HostActionResultCopyWithImpl;
@useResult
$Res call({
 String? requestId,@JsonKey(name: 'action') String? actionName, HostActionStatus status, String? message, String? errorCode, Map<String, dynamic> data
});




}
/// @nodoc
class _$HostActionResultCopyWithImpl<$Res>
    implements $HostActionResultCopyWith<$Res> {
  _$HostActionResultCopyWithImpl(this._self, this._then);

  final HostActionResult _self;
  final $Res Function(HostActionResult) _then;

/// Create a copy of HostActionResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? requestId = freezed,Object? actionName = freezed,Object? status = null,Object? message = freezed,Object? errorCode = freezed,Object? data = null,}) {
  return _then(_self.copyWith(
requestId: freezed == requestId ? _self.requestId : requestId // ignore: cast_nullable_to_non_nullable
as String?,actionName: freezed == actionName ? _self.actionName : actionName // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as HostActionStatus,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,errorCode: freezed == errorCode ? _self.errorCode : errorCode // ignore: cast_nullable_to_non_nullable
as String?,data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}

}


/// Adds pattern-matching-related methods to [HostActionResult].
extension HostActionResultPatterns on HostActionResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _HostActionResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _HostActionResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _HostActionResult value)  $default,){
final _that = this;
switch (_that) {
case _HostActionResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _HostActionResult value)?  $default,){
final _that = this;
switch (_that) {
case _HostActionResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? requestId, @JsonKey(name: 'action')  String? actionName,  HostActionStatus status,  String? message,  String? errorCode,  Map<String, dynamic> data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _HostActionResult() when $default != null:
return $default(_that.requestId,_that.actionName,_that.status,_that.message,_that.errorCode,_that.data);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? requestId, @JsonKey(name: 'action')  String? actionName,  HostActionStatus status,  String? message,  String? errorCode,  Map<String, dynamic> data)  $default,) {final _that = this;
switch (_that) {
case _HostActionResult():
return $default(_that.requestId,_that.actionName,_that.status,_that.message,_that.errorCode,_that.data);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? requestId, @JsonKey(name: 'action')  String? actionName,  HostActionStatus status,  String? message,  String? errorCode,  Map<String, dynamic> data)?  $default,) {final _that = this;
switch (_that) {
case _HostActionResult() when $default != null:
return $default(_that.requestId,_that.actionName,_that.status,_that.message,_that.errorCode,_that.data);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(checked: true, explicitToJson: true)
class _HostActionResult extends HostActionResult {
  const _HostActionResult({this.requestId, @JsonKey(name: 'action') this.actionName, required this.status, this.message, this.errorCode, final  Map<String, dynamic> data = const <String, dynamic>{}}): _data = data,super._();
  factory _HostActionResult.fromJson(Map<String, dynamic> json) => _$HostActionResultFromJson(json);

@override final  String? requestId;
@override@JsonKey(name: 'action') final  String? actionName;
@override final  HostActionStatus status;
@override final  String? message;
@override final  String? errorCode;
 final  Map<String, dynamic> _data;
@override@JsonKey() Map<String, dynamic> get data {
  if (_data is EqualUnmodifiableMapView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_data);
}


/// Create a copy of HostActionResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HostActionResultCopyWith<_HostActionResult> get copyWith => __$HostActionResultCopyWithImpl<_HostActionResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$HostActionResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _HostActionResult&&(identical(other.requestId, requestId) || other.requestId == requestId)&&(identical(other.actionName, actionName) || other.actionName == actionName)&&(identical(other.status, status) || other.status == status)&&(identical(other.message, message) || other.message == message)&&(identical(other.errorCode, errorCode) || other.errorCode == errorCode)&&const DeepCollectionEquality().equals(other._data, _data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,requestId,actionName,status,message,errorCode,const DeepCollectionEquality().hash(_data));

@override
String toString() {
  return 'HostActionResult(requestId: $requestId, actionName: $actionName, status: $status, message: $message, errorCode: $errorCode, data: $data)';
}


}

/// @nodoc
abstract mixin class _$HostActionResultCopyWith<$Res> implements $HostActionResultCopyWith<$Res> {
  factory _$HostActionResultCopyWith(_HostActionResult value, $Res Function(_HostActionResult) _then) = __$HostActionResultCopyWithImpl;
@override @useResult
$Res call({
 String? requestId,@JsonKey(name: 'action') String? actionName, HostActionStatus status, String? message, String? errorCode, Map<String, dynamic> data
});




}
/// @nodoc
class __$HostActionResultCopyWithImpl<$Res>
    implements _$HostActionResultCopyWith<$Res> {
  __$HostActionResultCopyWithImpl(this._self, this._then);

  final _HostActionResult _self;
  final $Res Function(_HostActionResult) _then;

/// Create a copy of HostActionResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? requestId = freezed,Object? actionName = freezed,Object? status = null,Object? message = freezed,Object? errorCode = freezed,Object? data = null,}) {
  return _then(_HostActionResult(
requestId: freezed == requestId ? _self.requestId : requestId // ignore: cast_nullable_to_non_nullable
as String?,actionName: freezed == actionName ? _self.actionName : actionName // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as HostActionStatus,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,errorCode: freezed == errorCode ? _self.errorCode : errorCode // ignore: cast_nullable_to_non_nullable
as String?,data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}


}

// dart format on
