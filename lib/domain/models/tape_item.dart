import 'tape_tag.dart';
import 'tape_type.dart';

/// 받은 테이프 한 개 — 계약서 ShelfItem / logic.js `TapeItem`.
class TapeItem {
  const TapeItem({
    required this.id,
    required this.from,
    this.senderId,
    String? senderName,
    required this.date,
    required this.type,
    required this.duration,
    this.tag,
    this.opened = true,
    this.viaLink = false,
    this.groupId,
    this.memo,
  }) : senderName = senderName ?? from;

  final String id;

  /// 보낸 사람 이름
  final String from;

  /// 보낸 사람 userId. 탈퇴했으면 null
  final String? senderId;

  /// 보낸 사람의 원래 이름 ([from]은 별명이 있으면 별명). 답장 라벨에 쓴다.
  final String senderName;

  /// 받은 날짜 (`sentAt`)
  final DateTime date;
  final TapeType type;

  /// 녹음 길이 (서버가 변환 뒤 갱신한 실제 길이)
  final Duration duration;
  final TapeTag? tag;

  /// 소포를 뜯었는지. 칸에 들어간 테이프는 항상 참이다.
  final bool opened;

  /// 링크로 받았는지 ("N님과 친구가 되었어요" 칩)
  final bool viaLink;

  /// null = 분류 안 함
  final String? groupId;

  /// 받는 사람이 남긴 메모 (최대 40자, 없으면 null). 나에게만 보인다
  final String? memo;

  TapeItem copyWith({
    bool? opened,
    String? Function()? groupId,
    String? Function()? memo,
  }) => TapeItem(
    id: id,
    from: from,
    senderId: senderId,
    senderName: senderName,
    date: date,
    type: type,
    duration: duration,
    tag: tag,
    opened: opened ?? this.opened,
    viaLink: viaLink,
    groupId: groupId == null ? this.groupId : groupId(),
    memo: memo == null ? this.memo : memo(),
  );
}
