import 'package:flutter/foundation.dart';

import '../../../data/model/api_error.dart';
import '../../../data/repositories/friend_repository.dart';
import '../../../domain/models/friend.dart';
import '../../../domain/models/friend_tapes.dart';
import '../../../utils/format.dart';
import '../../../utils/result.dart';
import '../../core/themes/tape_palette.dart';

/// 친구 화면 ViewModel — logic.js `fvOn`, `fromTapes`. `GET /friends/{userId}/tapes`.
class FriendViewModel extends ChangeNotifier {
  FriendViewModel({
    required FriendRepository friendRepository,
    required this.friendId,
  }) : _repo = friendRepository;

  final FriendRepository _repo;
  final String friendId;

  FriendTapes? _data;
  bool _failed = false;

  bool get loaded => _data != null;
  bool get failed => _failed;
  Friend? get friend => _data?.friend;
  String get name => _data?.friend.name ?? '';
  List<FriendTape> get tapes => _data?.items ?? const [];
  bool get empty => loaded && tapes.isEmpty;

  /// `(원래 이름 · )받은 테이프 N개 · 뜯지 않은 테이프 M개`, 모두 없으면 `받은 테이프 없음`
  /// — 별명이 있으면 제목이 별명이고 부제 맨 앞에 원래 이름 (`fvSub`)
  String get subtitle {
    final d = _data;
    if (d == null) return '';
    final parts = [
      ?d.friend.originalHint,
      if (d.items.isNotEmpty) '받은 테이프 ${d.items.length}개',
      if (d.unopenedCount > 0) '뜯지 않은 테이프 ${d.unopenedCount}개',
    ];
    return parts.isEmpty ? '받은 테이프 없음' : parts.join(' · ');
  }

  /// 행 날짜 `09.24`
  String dateOf(FriendTape t) => formatMonthDayTime(t.item.date);

  /// 행 부제 `3분 · 2026 생일`
  String subOf(FriendTape t) =>
      '${TapePalette.of(t.item.type).name} · ${t.where}';

  /// 행 오른쪽 길이 `0:34`
  String durOf(FriendTape t) => formatClock(t.item.duration.inSeconds);

  /// 별명 저장 — 비우면 원래 이름으로. 결과 문구를 돌려준다(토스트).
  Future<String> setNickname(String value) async {
    final r = await _repo.setNickname(friendId, value);
    switch (r) {
      case Ok():
        await load();
        return value.isEmpty ? '원래 이름으로 보여요' : '별명을 저장했어요';
      case Error(:final error):
        return error is ApiException
            ? error.message
            : '잠시 문제가 생겼어요. 다시 시도해 주세요';
    }
  }

  Future<void> load() async {
    final r = await _repo.getFriendTapes(friendId);
    switch (r) {
      case Ok<FriendTapes>(:final value):
        _data = value;
        _failed = false;
      case Error<FriendTapes>():
        _failed = true;
    }
    notifyListeners();
  }
}
