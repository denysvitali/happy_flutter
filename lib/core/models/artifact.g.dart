// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'artifact.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ArtifactUpdateRequest _$ArtifactUpdateRequestFromJson(
  Map<String, dynamic> json,
) => ArtifactUpdateRequest();

Map<String, dynamic> _$ArtifactUpdateRequestToJson(
  ArtifactUpdateRequest instance,
) => <String, dynamic>{};

_Artifact _$ArtifactFromJson(Map<String, dynamic> json) => _Artifact(
  id: _asRequiredString(json['id']),
  header: _asRequiredString(json['header']),
  headerVersion: _asApiInt(json['headerVersion']),
  dataEncryptionKey: _asRequiredString(json['dataEncryptionKey']),
  seq: _asApiInt(json['seq']),
  createdAt: _asApiInt(json['createdAt']),
  updatedAt: _asApiInt(json['updatedAt']),
  body: json['body'] as String?,
  bodyVersion: _asApiIntNullable(json['bodyVersion']),
);

Map<String, dynamic> _$ArtifactToJson(_Artifact instance) => <String, dynamic>{
  'id': instance.id,
  'header': instance.header,
  'headerVersion': instance.headerVersion,
  'dataEncryptionKey': instance.dataEncryptionKey,
  'seq': instance.seq,
  'createdAt': instance.createdAt,
  'updatedAt': instance.updatedAt,
  'body': instance.body,
  'bodyVersion': instance.bodyVersion,
};

_ArtifactHeader _$ArtifactHeaderFromJson(Map<String, dynamic> json) =>
    _ArtifactHeader(
      title: json['title'] as String?,
      sessions: _stringListOrNull(json['sessions']),
      draft: json['draft'] as bool?,
    );

Map<String, dynamic> _$ArtifactHeaderToJson(_ArtifactHeader instance) =>
    <String, dynamic>{
      'title': instance.title,
      'sessions': instance.sessions,
      'draft': instance.draft,
    };

_ArtifactBody _$ArtifactBodyFromJson(Map<String, dynamic> json) =>
    _ArtifactBody(body: json['body'] as String?);

Map<String, dynamic> _$ArtifactBodyToJson(_ArtifactBody instance) =>
    <String, dynamic>{'body': instance.body};

_DecryptedArtifact _$DecryptedArtifactFromJson(Map<String, dynamic> json) =>
    _DecryptedArtifact(
      id: json['id'] as String,
      headerVersion: _asApiInt(json['headerVersion']),
      seq: _asApiInt(json['seq']),
      createdAt: _asApiInt(json['createdAt']),
      updatedAt: _asApiInt(json['updatedAt']),
      title: json['title'] as String?,
      sessions: _stringListOrNull(json['sessions']),
      draft: json['draft'] as bool?,
      body: json['body'] as String?,
      bodyVersion: _asApiIntNullable(json['bodyVersion']),
      isDecrypted: json['isDecrypted'] as bool? ?? true,
    );

Map<String, dynamic> _$DecryptedArtifactToJson(_DecryptedArtifact instance) =>
    <String, dynamic>{
      'id': instance.id,
      'headerVersion': instance.headerVersion,
      'seq': instance.seq,
      'createdAt': instance.createdAt,
      'updatedAt': instance.updatedAt,
      'title': instance.title,
      'sessions': instance.sessions,
      'draft': instance.draft,
      'body': instance.body,
      'bodyVersion': instance.bodyVersion,
      'isDecrypted': instance.isDecrypted,
    };

_ArtifactCreateRequest _$ArtifactCreateRequestFromJson(
  Map<String, dynamic> json,
) => _ArtifactCreateRequest(
  id: json['id'] as String,
  header: json['header'] as String,
  body: json['body'] as String,
  dataEncryptionKey: json['dataEncryptionKey'] as String,
);

Map<String, dynamic> _$ArtifactCreateRequestToJson(
  _ArtifactCreateRequest instance,
) => <String, dynamic>{
  'id': instance.id,
  'header': instance.header,
  'body': instance.body,
  'dataEncryptionKey': instance.dataEncryptionKey,
};

_ArtifactUpdateRequest _$ArtifactUpdateRequestFromJson(
  Map<String, dynamic> json,
) => _ArtifactUpdateRequest(
  header: json['header'] as String?,
  expectedHeaderVersion: (json['expectedHeaderVersion'] as num?)?.toInt(),
  body: json['body'] as String?,
  expectedBodyVersion: (json['expectedBodyVersion'] as num?)?.toInt(),
);

Map<String, dynamic> _$ArtifactUpdateRequestToJson(
  _ArtifactUpdateRequest instance,
) => <String, dynamic>{
  'header': instance.header,
  'expectedHeaderVersion': instance.expectedHeaderVersion,
  'body': instance.body,
  'expectedBodyVersion': instance.expectedBodyVersion,
};

_ArtifactUpdateResponse _$ArtifactUpdateResponseFromJson(
  Map<String, dynamic> json,
) => _ArtifactUpdateResponse(
  success: json['success'] as bool? ?? false,
  headerVersion: (json['headerVersion'] as num?)?.toInt(),
  bodyVersion: (json['bodyVersion'] as num?)?.toInt(),
  error: json['error'] as String?,
  currentHeaderVersion: (json['currentHeaderVersion'] as num?)?.toInt(),
  currentBodyVersion: (json['currentBodyVersion'] as num?)?.toInt(),
  currentHeader: json['currentHeader'] as String?,
  currentBody: json['currentBody'] as String?,
);

Map<String, dynamic> _$ArtifactUpdateResponseToJson(
  _ArtifactUpdateResponse instance,
) => <String, dynamic>{
  'success': instance.success,
  'headerVersion': instance.headerVersion,
  'bodyVersion': instance.bodyVersion,
  'error': instance.error,
  'currentHeaderVersion': instance.currentHeaderVersion,
  'currentBodyVersion': instance.currentBodyVersion,
  'currentHeader': instance.currentHeader,
  'currentBody': instance.currentBody,
};

_ArtifactFolder _$ArtifactFolderFromJson(Map<String, dynamic> json) =>
    _ArtifactFolder(
      id: _asRequiredString(json['id']),
      sessionId: _asRequiredString(json['sessionId']),
      name: _asRequiredString(json['name']),
      createdAt: (json['createdAt'] as num).toInt(),
      updatedAt: (json['updatedAt'] as num).toInt(),
      parentId: json['parentId'] as String?,
    );

Map<String, dynamic> _$ArtifactFolderToJson(_ArtifactFolder instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sessionId': instance.sessionId,
      'name': instance.name,
      'createdAt': instance.createdAt,
      'updatedAt': instance.updatedAt,
      'parentId': instance.parentId,
    };
