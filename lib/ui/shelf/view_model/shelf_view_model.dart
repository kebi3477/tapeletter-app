import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/model/api_error.dart';
import '../../../data/repositories/friend_repository.dart';
import '../../../data/repositories/shelf_repository.dart';
import '../../../data/services/app_prefs.dart';
import '../../../domain/models/shelf.dart';
import '../../../domain/models/tape_item.dart';
import '../../../utils/format.dart';
import '../../../utils/result.dart';
import '../../core/themes/tape_palette.dart';
import '../../core/ui/toast.dart';

/// 서랍 보기 — logic.js `shelfView`.
enum ShelfView { list, shelf }

/// 드롭 위치 — logic.js `dropT { gi, idx }`. [groupId]가 null이면 분류 안 함(gi −1).
@immutable
class DropTarget {
  const DropTarget(this.groupId, this.index);

  final String? groupId;
  final int index;

  @override
  bool operator ==(Object other) =>
      other is DropTarget && other.groupId == groupId && other.index == index;

  @override
  int get hashCode => Object.hash(groupId, index);

  @override
  String toString() => 'DropTarget(${groupId ?? 'unsorted'}, $index)';
}

/// 서랍 탭 ViewModel — logic.js의 서랍 부분(`itemRow`, `dragEnd`, `moveTo`, 칸 시트).
class ShelfViewModel extends ChangeNotifier {
  ShelfViewModel({
    required ShelfRepository shelfRepository,
    required this._toast,
    this._prefs,
    this._friends,
  }) : _repo = shelfRepository {
    _repo.addListener(_onRepoChanged);
    // 별명이 바뀌면 서랍의 보낸 사람 이름도 바뀐다
    _friends?.addListener(_onRepoChanged);
    _restoreView();
    _restoreCoach();
  }

  /// 탭에 처음 들어갈 때 스켈레톤 `later('skel', 650)`
  static const skeletonTime = Duration(milliseconds: 650);

  /// 옮긴 행 반짝임 `flash 1.2s`
  static const landTime = Duration(milliseconds: 1200);

  static const unsortedName = '분류 안 함';

  final ShelfRepository _repo;
  final ToastController _toast;

  /// 사용자가 고른 보기를 기억한다
  final AppPrefs? _prefs;

  final FriendRepository? _friends;

  Shelf _shelf = Shelf.empty;
  bool _loaded = false;
  bool _seen = false;
  bool _skeleton = false;

  /// 기본은 책장형. 사용자가 바꾼 적 있으면 그 보기.
  ShelfView _view = ShelfView.shelf;
  bool _viewChosen = false;
  String? _dragId;
  DropTarget? _drop;
  String? _landed;
  Timer? _skelTimer;
  Timer? _landTimer;

  /// 낙관적 변경 중에는 저장소 알림으로 다시 불러오지 않는다.
  int _pending = 0;

  Shelf get shelf => _shelf;
  bool get loaded => _loaded;
  bool get skeleton => _skeleton;
  ShelfView get view => _view;
  String? get draggingId => _dragId;
  DropTarget? get dropTarget => _drop;
  String? get landedId => _landed;
  bool get dragging => _dragId != null;

  // ── 헤더·배너 (`capText`, `capInk`, `capOn`, `fullOn`, `emptyOn`) ──
  String get capText => formatDrawerCount(_shelf.stored, _shelf.cap);
  bool get capFull => _shelf.stored >= _shelf.cap;

  /// 목록 아래 "서랍이 거의 찼어요"
  bool get capNear =>
      _shelf.stored >= _shelf.cap - 2 && _shelf.stored < _shelf.cap;

  /// "서랍이 꽉 찼어요" 배너
  bool get fullOn => _shelf.stored >= _shelf.cap && _shelf.stored > 0;

  /// 빈 서랍 — 분류 안 함도 칸도 없을 때
  bool get emptyOn => _loaded && _shelf.isEmpty;

  // ── 도착한 소포 / 분류 안 함 (v10.2) ──────────────────
  /// 도착한 소포 — 분류 안 함의 안 뜯은 소포 (`parcelList`). 데이터는 그대로 `unsorted` 하나.
  List<TapeItem> get parcels =>
      _shelf.unsorted.where((x) => !x.opened).toList();

  /// 분류 안 함 구역에 보일 뜯은 테이프와 원래 `unsorted` 인덱스 (`inboxOpenList`, 드롭 위치에 쓴다)
  List<(int, TapeItem)> get openedUnsorted => [
    for (final (i, x) in _shelf.unsorted.indexed)
      if (x.opened) (i, x),
  ];

  /// 분류 안 함 개수 = 뜯은 미분류 수 (`inboxCount`)
  String get unsortedCountText => '${openedUnsorted.length}개';

  /// 도착한 소포 행 부제 `09.24 12:20 · 1분` — 구역이 상태를 설명하므로 "소포 도착" 생략
  String parcelSub(TapeItem x) =>
      '${formatMonthDayTime(x.date)} · ${TapePalette.of(x.type).name}';

  /// 행 부제 `메모 · 09.24 14:23 · 1분 · 소포 도착`.
  /// 메모는 분류 안 함의 안 뜯은 소포에서는 숨긴다 (`x.memo && (!inbox || x.opened)`).
  String itemSub(TapeItem x) {
    final parcel = x.groupId == null && !x.opened;
    final memo = x.memo != null && !parcel ? '${x.memo} · ' : '';
    return '$memo${formatMonthDayTime(x.date)} · ${TapePalette.of(x.type).name}'
        '${parcel ? ' · 소포 도착' : ''}';
  }

  /// ⋯ 시트 부제 `09.24 14:23 · 칸 이름`
  String sheetSub(TapeItem x) =>
      '${formatMonthDayTime(x.date)} · ${whereOf(x)}';

  String whereOf(TapeItem x) =>
      x.groupId == null ? unsortedName : (_shelf.group(x.groupId!)?.name ?? '');

  /// 칸으로 옮길 수 있는지. 안 뜯은 소포는 분류 안 함 안에서 순서만 바꿀 수 있다
  /// (계약서 `PATCH /shelf/items` `409 TAPE_NOT_OPENED`).
  bool canMove(TapeItem x) => x.opened;

  /// 안 뜯은 소포를 칸에 놓았을 때 (계약서 `TAPE_NOT_OPENED` 문구)
  static const notOpenedMessage = '소포를 먼저 뜯어 주세요';

  /// 옮기기 시트에서 꽉 찬 칸을 눌렀을 때 (`moveTo` → `gFull`)
  static const groupFullMessage = '한 칸에는 테이프를 10개까지 넣을 수 있어요';

  /// 끌어다 놓은 칸이 꽉 찼을 때 (`dragEnd` → `gFull`), 서버 `GROUP_FULL`
  static String groupFullDropMessage(String name) =>
      '‘$name’ 칸이 꽉 찼어요 · 한 칸에 10개까지';

  /// 칸 헤더 개수 (`groupList.count`): `4/10`, 꽉 차면 `10/10 · 꽉 참`
  String groupCountText(ShelfGroup g) => groupFull(g)
      ? '${g.items.length}/${g.cap} · 꽉 참'
      : '${g.items.length}/${g.cap}';

  /// 옮기기 시트 개수 (`moveTargets.count`): `4/10`, 꽉 차면 `꽉 참 10/10`
  String moveCountText(ShelfGroup g) => groupFull(g)
      ? '꽉 참 ${g.items.length}/${g.cap}'
      : '${g.items.length}/${g.cap}';

  /// 칸이 꽉 찼다 (`items.length >= 10`) — 개수 레드, 옮기기 시트에서 흐린 이름
  bool groupFull(ShelfGroup g) => g.full;

  /// [item]을 [groupId]로 옮길 수 있는지 (`!gFull`)
  bool hasRoom(TapeItem item, String? groupId) => !_noRoom(item, groupId);

  /// [item]을 다른 칸 [groupId]로 넣을 자리가 없는지. 같은 칸 안의 순서 바꾸기와
  /// 분류 안 함은 제한이 없다.
  bool _noRoom(TapeItem item, String? groupId) {
    if (groupId == null || item.groupId == groupId) return false;
    final g = _shelf.group(groupId);
    return g != null && g.full;
  }

  // ── 불러오기 ─────────────────────────────────────
  Future<void> load() async {
    final r = await _repo.getShelf();
    if (r is Ok<Shelf>) {
      _shelf = r.value;
      _loaded = true;
      notifyListeners();
    }
  }

  /// 낙관적 변경 중에 온 알림 (푸시·다른 화면) — 끝나면 다시 불러온다
  bool _stale = false;

  void _onRepoChanged() {
    if (_pending == 0) {
      load();
    } else {
      _stale = true;
    }
  }

  void _settle() {
    _pending--;
    if (_pending == 0 && _stale) {
      _stale = false;
      load();
    }
  }

  /// 탭에 들어올 때. 처음이면 0.65초 스켈레톤 (`goTab`).
  void enter() {
    if (_seen) return;
    _seen = true;
    // 화면 initState에서 부르므로 알리지 않는다 (곧바로 그 화면이 이 값을 읽는다).
    _skeleton = true;
    _skelTimer = Timer(skeletonTime, () {
      _skeleton = false;
      notifyListeners();
    });
  }

  void setView(ShelfView v) {
    _viewChosen = true;
    if (_view == v) return;
    _view = v;
    notifyListeners();
    unawaited(_prefs?.setShelfView(v.name).catchError((_) {}));
  }

  /// 책꽂이 코치마크를 봤는지 — 기기에 저장한 값을 불러오기 전에는 보인 것으로 친다(깜빡임 방지)
  bool _coachDone = true;

  /// 책꽂이 코치마크 (`coachOn`): 처음 테이프가 있는 서랍을 책꽂이로 볼 때 한 번
  bool get coachOn =>
      !_coachDone &&
      _view == ShelfView.shelf &&
      _loaded &&
      !emptyOn &&
      _shelf.unsorted.isNotEmpty &&
      !_skeleton;

  /// 알겠어요 (`coachOk`) · 첫 드래그 성공
  void dismissCoach() {
    if (_coachDone) return;
    _coachDone = true;
    notifyListeners();
    unawaited(_prefs?.setShelfCoachDone().catchError((_) {}));
  }

  Future<void> _restoreCoach() async {
    try {
      final done = await _prefs?.shelfCoachDone() ?? true;
      if (done == _coachDone) return;
      _coachDone = done;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _restoreView() async {
    try {
      final saved = await _prefs?.shelfView();
      final v = ShelfView.values.where((x) => x.name == saved).firstOrNull;
      // 불러오는 사이에 사용자가 이미 바꿨으면 그대로 둔다
      if (v == null || _viewChosen || v == _view) return;
      _view = v;
      notifyListeners();
    } catch (_) {}
  }

  // ── 드래그 정렬 (`rowDown` / `dragMove` / `dragEnd`) ──
  void startDrag(String itemId) {
    final x = _shelf.find(itemId);
    // 안 뜯은 소포는 끌 수 없다 (`rowDown` sealed, v10.2)
    if (x == null || (x.groupId == null && !x.opened)) return;
    _dragId = itemId;
    _drop = null;
    notifyListeners();
  }

  /// 손가락 아래 드롭 위치. null이면 이전 위치를 유지한다.
  void dragOver(DropTarget? target) {
    if (_dragId == null || target == null || target == _drop) return;
    _drop = target;
    notifyListeners();
  }

  void cancelDrag() {
    _dragId = null;
    _drop = null;
    notifyListeners();
  }

  /// 놓기. 드롭 위치가 없으면 아무 일도 없다.
  Future<void> endDrag() async {
    final id = _dragId, t = _drop;
    _dragId = null;
    _drop = null;
    if (id == null || t == null) {
      notifyListeners();
      return;
    }
    dismissCoach();
    await moveByDrop(id, t);
  }

  /// 드롭 위치로 옮긴다 (`dragEnd`). 같은 칸 안에서 아래로 옮기면 빠진 자리만큼 한 칸 당긴다.
  Future<void> moveByDrop(String itemId, DropTarget t) async {
    final from = _shelf.find(itemId);
    if (from == null) return;
    if (t.groupId != null && _shelf.group(t.groupId!) == null) return;
    if (t.groupId != null && !canMove(from)) {
      _toast.show(notOpenedMessage);
      notifyListeners();
      return;
    }
    if (_noRoom(from, t.groupId)) {
      // 꽉 찬 칸에 놓으면 제자리로 되돌린다
      _toast.show(groupFullDropMessage(_shelf.group(t.groupId!)!.name));
      notifyListeners();
      return;
    }
    var idx = t.index;
    if (from.groupId == t.groupId) {
      final oi = _shelf.itemsOf(t.groupId).indexWhere((x) => x.id == itemId);
      if (oi < idx) idx--;
    }
    await _move(from, t.groupId, idx, toastIfCross: true);
  }

  /// 옮기기 시트 — 그 칸 맨 뒤로 (`moveTo`).
  Future<void> moveTo(String itemId, String? groupId) async {
    final from = _shelf.find(itemId);
    if (from == null) return;
    if (_noRoom(from, groupId)) {
      _toast.show(groupFullMessage);
      return;
    }
    await _move(from, groupId, null, toastAlways: true);
  }

  Future<void> _move(
    TapeItem item,
    String? groupId,
    int? index, {
    bool toastIfCross = false,
    bool toastAlways = false,
  }) async {
    if (groupId != null && !canMove(item)) return;
    final prev = _shelf;
    final removed = _without(prev, item.id);
    final target = [...removed.itemsOf(groupId)];
    final at = (index ?? target.length).clamp(0, target.length);
    final afterId = at > 0 ? target[at - 1].id : null;
    target.insert(at, item.copyWith(groupId: () => groupId));
    _shelf = _withList(removed, groupId, target);
    _landOn(item.id);
    notifyListeners();

    final name = groupId == null
        ? unsortedName
        : '‘${_shelf.group(groupId)!.name}’ 칸';
    if (toastAlways || (toastIfCross && item.groupId != groupId)) {
      _toast.show('$name으로 옮겼어요');
    }

    _pending++;
    final r = await _repo.moveItem(item.id, groupId: groupId, afterId: afterId);
    _settle();
    if (r case Error(:final error)) {
      _shelf = prev;
      final full =
          error is ApiException && error.code == ApiErrorCode.groupFull;
      _toast.show(
        full && groupId != null
            ? groupFullDropMessage(prev.group(groupId)?.name ?? '')
            : _message(error),
      );
      notifyListeners();
    }
  }

  void _landOn(String id) {
    _landed = id;
    _landTimer?.cancel();
    _landTimer = Timer(landTime, () {
      _landed = null;
      notifyListeners();
    });
  }

  // ── ⋯ 시트 ────────────────────────────────────────
  /// 메모 최대 글자 수 (계약서: 최대 40자)
  static const int memoMax = 40;

  /// 메모 저장 (`mmSave`) · 지우기 (`mmDel`). 앞뒤 공백을 빼고 비면 지운다.
  /// 토스트: 메모를 남겼어요 / 메모를 고쳤어요 / 메모를 지웠어요.
  /// 서버가 거절하면 되돌리고 false.
  Future<bool> setMemo(TapeItem item, String draft) async {
    final memo = draft.trim().isEmpty ? null : draft.trim();
    final prev = _shelf;
    _shelf = _mapItem(prev, item.id, (x) => x.copyWith(memo: () => memo));
    notifyListeners();
    _toast.show(
      memo == null ? '메모를 지웠어요' : (item.memo == null ? '메모를 남겼어요' : '메모를 고쳤어요'),
    );
    _pending++;
    final r = await _repo.setMemo(item.id, memo);
    _settle();
    if (r case Error(:final error)) {
      _shelf = prev;
      _toast.show(_message(error));
      notifyListeners();
      return false;
    }
    return true;
  }

  /// 지우기 (`itemDel`)
  Future<void> deleteItem(String itemId) async {
    final prev = _shelf;
    _shelf = _without(prev, itemId);
    notifyListeners();
    _toast.show('테이프를 지웠어요');
    _pending++;
    final r = await _repo.deleteItem(itemId);
    _settle();
    if (r case Error(:final error)) {
      _shelf = prev;
      _toast.show(_message(error));
      notifyListeners();
    }
  }

  // ── 칸 시트 (`saveGroup`, `deleteGroup`) ──────────────
  static const int groupNameMax = 12;

  /// 시트에서 보여 줄 토스트 (`say`)
  void toast(String message) => _toast.show(message);

  Future<void> addGroup(String draft) async {
    final r = await _repo.createGroup(_groupName(draft));
    switch (r) {
      case Ok<ShelfGroup>(:final value):
        _shelf = _shelf.copyWith(groups: [..._shelf.groups, value]);
        notifyListeners();
        _toast.show('‘${value.name}’ 칸을 만들었어요');
      case Error<ShelfGroup>(:final error):
        _toast.show(_message(error));
    }
  }

  Future<void> renameGroup(String groupId, String draft) async {
    final name = _groupName(draft);
    final prev = _shelf;
    _shelf = _shelf.copyWith(
      groups: [
        for (final g in _shelf.groups)
          g.id == groupId ? g.copyWith(name: name) : g,
      ],
    );
    notifyListeners();
    _pending++;
    final r = await _repo.renameGroup(groupId, name);
    _settle();
    if (r case Error(:final error)) {
      _shelf = prev;
      _toast.show(_message(error));
      notifyListeners();
    }
  }

  /// 칸 지우기 — 안에 있던 테이프는 분류 안 함 맨 뒤로, 뜯은 상태로.
  Future<void> deleteGroup(String groupId) async {
    final g = _shelf.group(groupId);
    if (g == null) return;
    final prev = _shelf;
    _shelf = _shelf.copyWith(
      groups: _shelf.groups.where((x) => x.id != groupId).toList(),
      unsorted: [
        ..._shelf.unsorted,
        for (final x in g.items) x.copyWith(opened: true, groupId: () => null),
      ],
    );
    notifyListeners();
    _toast.show('칸을 지웠어요 · 테이프는 분류 안 함으로');
    _pending++;
    final r = await _repo.deleteGroup(groupId);
    _settle();
    if (r case Error(:final error)) {
      _shelf = prev;
      _toast.show(_message(error));
      notifyListeners();
    }
  }

  /// 비우면 "새 칸" (`draft.trim() || '새 칸'`)
  static String _groupName(String draft) =>
      draft.trim().isEmpty ? '새 칸' : draft.trim();

  static String _message(Exception e) =>
      e is ApiException ? e.message : '잠시 문제가 생겼어요. 다시 시도해 주세요';

  static Shelf _without(Shelf s, String id) => s.copyWith(
    unsorted: s.unsorted.where((x) => x.id != id).toList(),
    groups: [
      for (final g in s.groups)
        g.copyWith(items: g.items.where((x) => x.id != id).toList()),
    ],
  );

  static Shelf _mapItem(Shelf s, String id, TapeItem Function(TapeItem) f) =>
      s.copyWith(
        unsorted: [for (final x in s.unsorted) x.id == id ? f(x) : x],
        groups: [
          for (final g in s.groups)
            g.copyWith(items: [for (final x in g.items) x.id == id ? f(x) : x]),
        ],
      );

  static Shelf _withList(Shelf s, String? groupId, List<TapeItem> items) =>
      groupId == null
      ? s.copyWith(unsorted: items)
      : s.copyWith(
          groups: [
            for (final g in s.groups)
              g.id == groupId ? g.copyWith(items: items) : g,
          ],
        );

  @override
  void dispose() {
    _skelTimer?.cancel();
    _landTimer?.cancel();
    _repo.removeListener(_onRepoChanged);
    _friends?.removeListener(_onRepoChanged);
    super.dispose();
  }
}
