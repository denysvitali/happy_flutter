// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AuthCredentials _$AuthCredentialsFromJson(Map<String, dynamic> json) =>
    _AuthCredentials(
      token: json['token'] as String,
      secret: json['secret'] as String,
    );

Map<String, dynamic> _$AuthCredentialsToJson(_AuthCredentials instance) =>
    <String, dynamic>{'token': instance.token, 'secret': instance.secret};
