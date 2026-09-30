import 'json.dart';

/// 받은 테이프 — 계약서 §2 ShelfItem.
class ShelfItemDto {
  const ShelfItemDto({
    required this.id,
    required this.sender,
    required this.tapeType,
    required this.durationMs,
    required this.tag,
    required this.sentAt,
    required this.opened,
    this.openedAt,
    required this.viaLink,
    this.groupId,
    this.groupName,
    this.memo,
  });

  final String id;
  final UserRefDto sender;
  final int tapeType;
  final int durationMs;

  /// `birthday` · `congrats` · `thinking`
  final String? tag;
  final DateTime sentAt;
  final bool opened;
  final DateTime? openedAt;
  final bool viaLink;

  /// null = 분류 안 함
  final String? groupId;

  /// 친구 화면 응답에만 붙는다 (칸이 없으면 null)
  final String? groupName;

  /// 받는 사람이 남긴 메모 (없으면 null). 나에게만 보인다
  final String? memo;

  factory ShelfItemDto.fromJson(Json j) => ShelfItemDto(
    id: j['id'] as String,
    sender: UserRefDto.fromJson(j['sender'] as Json),
    tapeType: j['tapeType'] as int,
    durationMs: j['durationMs'] as int,
    tag: j['tag'] as String?,
    sentAt: parseDate(j['sentAt']),
    opened: j['opened'] as bool,
    openedAt: parseDateOrNull(j['openedAt']),
    viaLink: j['viaLink'] as bool,
    groupId: j['groupId'] as String?,
    groupName: j['groupName'] as String?,
    memo: j['memo'] as String?,
  );

  Json toJson() => {
    'id': id,
    'sender': sender.toJson(),
    'tapeType': tapeType,
    'durationMs': durationMs,
    'tag': tag,
    'sentAt': dateToJson(sentAt),
    'opened': opened,
    'openedAt': openedAt == null ? null : dateToJson(openedAt!),
    'viaLink': viaLink,
    'groupId': groupId,
    'groupName': ?groupName,
    'memo': memo,
  };

  ShelfItemDto copyWith({
    UserRefDto? sender,
    bool? opened,
    DateTime? openedAt,
    String? Function()? groupId,
    String? Function()? groupName,
    String? Function()? memo,
  }) => ShelfItemDto(
    id: id,
    sender: sender ?? this.sender,
    tapeType: tapeType,
    durationMs: durationMs,
    tag: tag,
    sentAt: sentAt,
    opened: opened ?? this.opened,
    openedAt: openedAt ?? this.openedAt,
    viaLink: viaLink,
    groupId: groupId == null ? this.groupId : groupId(),
    groupName: groupName == null ? this.groupName : groupName(),
    memo: memo == null ? this.memo : memo(),
  );
}

/// `{ userId, name, nickname }` — 탈퇴한 사용자면 `userId: null`.
class UserRefDto {
  const UserRefDto({required this.userId, required this.name, this.nickname});

  final String? userId;
  final String name;

  /// 내가 붙인 별명 (계약서 §2 별명). 화면에는 `nickname ?? name`.
  final String? nickname;

  String get displayName => nickname ?? name;

  factory UserRefDto.fromJson(Json j) => UserRefDto(
    userId: j['userId'] as String?,
    name: j['name'] as String,
    nickname: j['nickname'] as String?,
  );

  Json toJson() => {'userId': userId, 'name': name, 'nickname': nickname};
}

class ShelfGroupDto {
  const ShelfGroupDto({
    required this.id,
    required this.name,
    required this.items,
  });

  final String id;
  final String name;
  final List<ShelfItemDto> items;

  factory ShelfGroupDto.fromJson(Json j) => ShelfGroupDto(
    id: j['id'] as String,
    name: j['name'] as String,
    items: parseList(j['items'], ShelfItemDto.fromJson),
  );

  Json toJson() => {
    'id': id,
    'name': name,
    'items': items.map((e) => e.toJson()).toList(),
  };
}

/// `GET /shelf`
class ShelfDto {
  const ShelfDto({
    required this.stored,
    required this.cap,
    required this.full,
    this.unopenedCount = 0,
    required this.unsorted,
    required this.groups,
  });

  final int stored;
  final int cap;
  final bool full;

  /// 분류 안 함의 안 뜯은 소포 수 (= `Me.drawer.unopenedCount`)
  final int unopenedCount;
  final List<ShelfItemDto> unsorted;
  final List<ShelfGroupDto> groups;

  factory ShelfDto.fromJson(Json j) => ShelfDto(
    stored: j['stored'] as int,
    cap: j['cap'] as int,
    full: j['full'] as bool,
    unopenedCount: (j['unopenedCount'] as int?) ?? 0,
    unsorted: parseList(j['unsorted'], ShelfItemDto.fromJson),
    groups: parseList(j['groups'], ShelfGroupDto.fromJson),
  );

  Json toJson() => {
    'stored': stored,
    'cap': cap,
    'full': full,
    'unopenedCount': unopenedCount,
    'unsorted': unsorted.map((e) => e.toJson()).toList(),
    'groups': groups.map((e) => e.toJson()).toList(),
  };
}

/// `PATCH /shelf/items/{id}` 요청 — 드래그 정렬·옮기기.
class MoveShelfItemRequest {
  const MoveShelfItemRequest({required this.groupId, required this.afterId});

  /// null = 분류 안 함
  final String? groupId;

  /// 바로 앞 테이프 id, null = 맨 앞
  final String? afterId;

  Json toJson() => {'groupId': groupId, 'afterId': afterId};
}

/// `PUT /shelf/items/{id}/memo` 요청 — 메모. null·빈 값이면 지운다.
class SetMemoRequest {
  const SetMemoRequest(this.memo);

  final String? memo;

  Json toJson() => {'memo': memo};
}

/// `GET /deliveries/{id}/audio`
class AudioUrlDto {
  const AudioUrlDto({
    required this.url,
    required this.expiresAt,
    required this.durationMs,
  });

  final String url;
  final DateTime expiresAt;
  final int durationMs;

  factory AudioUrlDto.fromJson(Json j) => AudioUrlDto(
    url: j['url'] as String,
    expiresAt: parseDate(j['expiresAt']),
    durationMs: j['durationMs'] as int,
  );

  Json toJson() => {
    'url': url,
    'expiresAt': dateToJson(expiresAt),
    'durationMs': durationMs,
  };
}
