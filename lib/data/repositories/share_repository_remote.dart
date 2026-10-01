import '../../domain/models/share_link.dart';
import '../../domain/models/tape_tag.dart';
import '../../domain/models/tape_type.dart';
import '../../utils/idempotency.dart';
import '../../utils/result.dart';
import '../model/mappers.dart';
import '../services/api/api_client.dart';
import 'repository_guard.dart';
import 'friend_repository.dart';
import 'share_repository.dart';
import 'shelf_repository.dart';

class ShareRepositoryRemote implements ShareRepository {
  ShareRepositoryRemote(this._api, this._shelf, [this._friends]);

  final ApiClient _api;

  /// 받으면 서랍이 바뀐다
  final ShelfRepository _shelf;

  /// 받으면 보낸 사람과 서로 친구가 된다 — 친구 목록을 쓰는 화면(녹음 받는 사람 등)이 다시 불러온다
  final FriendRepository? _friends;
  final Map<String, String> _keys = {};
  final Map<String, ShareLink> _opened = {};

  @override
  Future<Result<ShareLink>> open(String token) => guard(() async {
    final s = await _api.getShare(token);
    return _opened[token] = ShareLink(
      token: token,
      claimed: s.state == 'claimed',
      deliveryId: s.deliveryId,
      senderName: s.sender.displayName,
      senderId: s.sender.userId,
      type: TapeType.fromCode(s.tapeType),
      duration: Duration(milliseconds: s.durationMs),
      tag: TapeTag.fromCode(s.tag),
      sentAt: s.sentAt,
    );
  });

  @override
  ShareLink? peek(String token) => _opened[token];

  @override
  Future<Result<ClaimedTape>> claim(String token) async {
    // 같은 링크를 다시 받으면 같은 키 (재시도해도 한 번만)
    final key = _keys.putIfAbsent(token, newIdempotencyKey);
    final r = await guard(() async {
      final c = await _api.claimShare(token, idempotencyKey: key);
      return ClaimedTape(item: c.item.toDomain(), friend: c.friend?.toDomain());
    });
    if (r is Ok) {
      _opened.remove(token);
      _shelf.invalidate();
      _friends?.invalidate();
    }
    return r;
  }
}
