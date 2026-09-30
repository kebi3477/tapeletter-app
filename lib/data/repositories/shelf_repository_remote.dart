import '../../domain/models/shelf.dart';
import '../../domain/models/tape_audio.dart';
import '../../domain/models/tape_item.dart';
import '../../utils/result.dart';
import '../model/mappers.dart';
import '../model/shelf_dto.dart';
import '../services/api/api_client.dart';
import '../services/audio_cache.dart';
import 'repository_guard.dart';
import 'shelf_repository.dart';

class ShelfRepositoryRemote extends ShelfRepository {
  ShelfRepositoryRemote(this._api, {this._cache});

  final ApiClient _api;

  /// 받은 오디오 파일 (delivery id 키). 없으면 매번 재생 URL로 스트리밍한다.
  final AudioCache? _cache;

  Future<Result<T>> _mutate<T>(Future<T> Function() call) async {
    final r = await guard(call);
    notifyListeners();
    return r;
  }

  @override
  Future<Result<Shelf>> getShelf() =>
      guard(() async => (await _api.getShelf()).toDomain());

  @override
  Future<Result<ShelfGroup>> createGroup(String name) =>
      _mutate(() async => (await _api.createGroup(name)).toDomain());

  @override
  Future<Result<ShelfGroup>> renameGroup(String groupId, String name) =>
      _mutate(() async => (await _api.renameGroup(groupId, name)).toDomain());

  @override
  Future<Result<void>> deleteGroup(String groupId) =>
      _mutate(() => _api.deleteGroup(groupId));

  @override
  Future<Result<TapeItem>> moveItem(
    String itemId, {
    required String? groupId,
    required String? afterId,
  }) => _mutate(
    () async => (await _api.moveShelfItem(
      itemId,
      MoveShelfItemRequest(groupId: groupId, afterId: afterId),
    )).toDomain(),
  );

  @override
  Future<Result<TapeItem>> setMemo(String itemId, String? memo) => _mutate(
    () async =>
        (await _api.setShelfItemMemo(itemId, SetMemoRequest(memo))).toDomain(),
  );

  @override
  Future<Result<void>> deleteItem(String itemId) => _mutate(() async {
    await _api.deleteShelfItem(itemId);
    await _cache?.remove(itemId).catchError((_) {});
  });

  @override
  Future<Result<TapeItem>> getItem(String itemId) =>
      guard(() async => (await _api.getDelivery(itemId)).toDomain());

  @override
  Future<Result<TapeItem>> open(String itemId) =>
      _mutate(() async => (await _api.openDelivery(itemId)).toDomain());

  /// 캐시에 있으면 그 파일, 없으면 재생 URL을 받아 파일로 내려받는다.
  /// 내려받기가 실패하면 URL로 바로 재생한다.
  @override
  Future<Result<TapeAudio>> audioUrl(String itemId) => guard(() async {
    final cache = _cache;
    final hit = await cache?.find(itemId);
    if (hit != null) {
      return TapeAudio(
        url: hit.path,
        expiresAt: _never,
        duration: Duration.zero, // 파일 길이는 플레이어가 잰다
      );
    }
    final a = (await _api.getDeliveryAudio(itemId)).toDomain();
    final remote = a.url.startsWith('http://') || a.url.startsWith('https://');
    if (cache == null || !remote) return a;
    try {
      final f = await cache.save(itemId, a.url);
      return TapeAudio(url: f.path, expiresAt: _never, duration: a.duration);
    } catch (_) {
      return a;
    }
  });

  static final _never = DateTime.utc(9999);
}
