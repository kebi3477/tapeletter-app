import 'package:flutter/foundation.dart';

import '../../domain/models/shelf.dart';
import '../../domain/models/tape_audio.dart';
import '../../domain/models/tape_item.dart';
import '../../utils/result.dart';

/// 서랍 (`/shelf`)과 받은 테이프 (`/deliveries/{id}`). 바뀌면 리스너에게 알린다.
abstract class ShelfRepository extends ChangeNotifier {
  Future<Result<Shelf>> getShelf();

  /// 칸 추가 (1~12자, 비우면 "새 칸")
  Future<Result<ShelfGroup>> createGroup(String name);

  Future<Result<ShelfGroup>> renameGroup(String groupId, String name);

  /// 칸 지우기 — 안에 있던 테이프는 분류 안 함으로 간다.
  Future<Result<void>> deleteGroup(String groupId);

  /// 테이프 옮기기·정렬. [groupId] null = 분류 안 함, [afterId] null = 맨 앞.
  Future<Result<TapeItem>> moveItem(
    String itemId, {
    required String? groupId,
    required String? afterId,
  });

  /// 테이프 메모 (나에게만 보임, 최대 40자). null·빈 값이면 지운다.
  Future<Result<TapeItem>> setMemo(String itemId, String? memo);

  Future<Result<void>> deleteItem(String itemId);

  /// 받은 테이프 하나 (푸시로 들어올 때)
  Future<Result<TapeItem>> getItem(String itemId);

  /// 소포 뜯기 (`POST /deliveries/{id}/open`)
  Future<Result<TapeItem>> open(String itemId);

  /// 서랍 넓히기 등 다른 곳에서 바뀌었을 때 다시 불러오라고 알린다.
  void invalidate() => notifyListeners();

  /// 재생 주소 (`GET /deliveries/{id}/audio`, 받는 사람만, 짧은 만료)
  Future<Result<TapeAudio>> audioUrl(String itemId);
}
