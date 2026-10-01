import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/model/api_error.dart';
import '../../../data/repositories/friend_repository.dart';
import '../../../data/repositories/share_repository.dart';
import '../../../domain/models/share_link.dart';
import '../../../data/repositories/shelf_repository.dart';
import '../../../domain/models/friend_tapes.dart';
import '../../../domain/models/tape_repeat.dart';
import '../../../domain/models/shelf.dart';
import '../../../domain/models/tape_audio.dart';
import '../../../domain/models/tape_item.dart';
import '../../../data/services/audio_player_service.dart';
import '../../../data/services/sound_service.dart';
import '../../../utils/result.dart';
import '../../core/ui/toast.dart';

/// 재생 목록의 출처 — logic.js `viewer.src`
/// (칸 인덱스 | `'inbox'` | `'f:친구이름'`).
sealed class QueueSource {
  const QueueSource();

  /// URL 쿼리 `src` 값
  String get key;

  static QueueSource parse(String key) {
    if (key.startsWith('group:')) return GroupSource(key.substring(6));
    if (key.startsWith('friend:')) return FriendSource(key.substring(7));
    if (key.startsWith('link:')) return LinkSource(key.substring(5));
    return const UnsortedSource();
  }
}

/// 칸 전체
class GroupSource extends QueueSource {
  const GroupSource(this.groupId);

  final String groupId;

  @override
  String get key => 'group:$groupId';
}

/// 분류 안 함 — 그 테이프 하나만
class UnsortedSource extends QueueSource {
  const UnsortedSource();

  @override
  String get key => 'unsorted';
}

/// 아직 받지 않은 링크 테이프 — 뜯을 때 받는다 (`POST /share/{token}/claim`)
class LinkSource extends QueueSource {
  const LinkSource(this.token);

  final String token;

  @override
  String get key => 'link:$token';
}

/// 그 친구가 보낸 테이프 전부 (친구 화면 "모두 재생")
class FriendSource extends QueueSource {
  const FriendSource(this.friendId);

  final String friendId;

  @override
  String get key => 'friend:$friendId';
}

/// 소포 → 뜯는 중 → 재생 (`vPhase`)
enum ViewerPhase { parcel, tearing, play }

/// 곡 불러오기 (`vLoad`)
enum TrackLoad { loading, error, ready }

/// 테이프 재생 오버레이 ViewModel — logic.js `openItem`, `vPlay`, `vEnd`, `goTrack`, `unwrap`, `loadTrack`.
class PlayerViewModel extends ChangeNotifier {
  PlayerViewModel({
    required ShelfRepository shelfRepository,
    required FriendRepository friendRepository,
    ShareRepository? shareRepository,
    required this._player,
    required this._toast,
    this._sound = const NoSoundService(),
  }) : _shelf = shelfRepository,
       _friends = friendRepository,
       _share = shareRepository {
    _subs.add(_player.position.listen(_onPosition));
    _subs.add(_player.completed.listen((_) => _onEnd()));
    // 서랍을 넓히거나 정리하면 꽉 참 여부를 다시 본다
    _shelf.addListener(_onShelfChanged);
  }

  /// 테이프를 열 때 불러오기 표시 `loadTrack(700)`
  static const openLoad = Duration(milliseconds: 700);

  /// 곡을 넘길 때 `loadTrack(500)`
  static const skipLoad = Duration(milliseconds: 500);

  /// 소포가 찢어지고 재생 화면으로 `later('tear', 750)`
  static const tearTime = Duration(milliseconds: 750);

  /// 이전: 이만큼 넘게 들었으면 처음부터
  static const restartAfter = 3.0;

  final ShelfRepository _shelf;
  final FriendRepository _friends;
  final ShareRepository? _share;
  final AudioPlayerService _player;
  final ToastController _toast;

  /// 효과음 — 소포를 뜯는 순간 open.wav
  final SoundService _sound;

  final List<StreamSubscription<void>> _subs = [];

  QueueSource? _source;
  bool _linkChip = true;
  String _queueName = '';
  List<TapeItem> _queue = const [];
  int _index = -1;
  ViewerPhase _phase = ViewerPhase.play;
  TrackLoad _load = TrackLoad.loading;
  double _pos = 0;
  Duration? _loadedDuration;
  bool _playing = false;
  TapeRepeat _rep = TapeRepeat.off;
  int _insN = 0;
  int _loadGen = 0;
  Timer? _tearTimer;
  bool _closed = false;
  bool _claiming = false;

  /// 소포 화면에서 본 서랍 — 꽉 찼으면(`stored >= cap`) 뜯기 연출을 시작하지 않는다.
  Shelf? _drawer;
  bool _rechecking = false;
  bool _fullOpen = false;
  (LinkErrorKind, String?)? _linkError;

  QueueSource? get source => _source;

  /// 서랍이 꽉 차 소포를 못 뜯는다 → 서랍 꽉 참 시트 (`sheet.kind === 'fullOpen'`)
  bool get fullOpen => _fullOpen;

  /// 꽉 참 시트의 칸별 보관 카드에 쓸 서랍
  Shelf? get drawer => _drawer;

  /// 시트를 닫았다
  void closeFullOpen() {
    if (!_fullOpen) return;
    _fullOpen = false;
    notifyListeners();
  }

  Future<void> _checkDrawer() async {
    final s = await _shelf.getShelf();
    if (s is Ok<Shelf>) _drawer = s.value;
  }

  /// 서랍이 바뀌었다(지우기·옮기기·넓히기·다른 화면의 뜯기). 화면을 여는 중이어도 다시 본다 —
  /// 예전에는 소포 화면(parcel)일 때만 다시 봐서, 여는 사이에 끝난 지우기를 놓쳤다.
  void _onShelfChanged() {
    if (_closed || _phase == ViewerPhase.tearing) return;
    unawaited(_checkDrawer());
  }

  /// 링크 테이프를 받지 못했다 (이미 받음·만료) → 링크 오류 화면으로
  (LinkErrorKind, String?)? get linkError => _linkError;

  /// 받는 중 (`POST /share/{token}/claim`)
  bool get claiming => _claiming;

  /// 링크로 받은 소포의 "○○님과 친구가 되었어요" 칩 (`viaLink`)
  bool get showLinkChip => _linkChip && (current?.viaLink ?? false);
  List<TapeItem> get queue => _queue;
  int get index => _index;
  TapeItem? get current =>
      _index >= 0 && _index < _queue.length ? _queue[_index] : null;
  ViewerPhase get phase => _phase;
  TrackLoad get load => _load;
  double get pos => _pos;
  bool get playing => _playing;
  TapeRepeat get repeat => _rep;

  /// 곡이 바뀔 때마다 늘어난다. 테이프 `insert`/`insert2` 애니메이션을 번갈아 다시 튼다.
  int get insertCount => _insN;

  /// 목록 제목 (`vQueueName`)
  String get queueName => _queueName;

  /// `vIdx` `2/4`
  String get indexText => '${_index + 1}/${_queue.length}';

  /// 이 곡 길이(초). 불러온 파일 길이를 먼저 쓰고, 없으면 서버 `durationMs`.
  double get duration {
    final d = _loadedDuration ?? current?.duration ?? Duration.zero;
    return d.inMilliseconds / 1000;
  }

  double get progress => duration > 0 ? (_pos / duration).clamp(0, 1) : 0;

  /// 이전 버튼 흐림 (`prevOp`)
  bool get canPrev => _index > 0 || _pos > 0;

  /// 다음 버튼 흐림 (`nextOp`)
  bool get canNext =>
      _index < _queue.length - 1 ||
      (_rep == TapeRepeat.all && _queue.length > 1);

  // ── 열기 ─────────────────────────────────────────
  /// 테이프를 연다 (`openItem`). 안 뜯은 소포면 소포 화면부터.
  Future<void> open(
    QueueSource source,
    String itemId, {
    bool linkChip = true,
  }) async {
    _source = source;
    _linkChip = linkChip;
    switch (source) {
      case GroupSource(:final groupId):
        final r = await _shelf.getShelf();
        if (r is Ok<Shelf>) {
          final g = r.value.group(groupId);
          _queue = g?.items ?? const [];
          _queueName = g?.name ?? '';
        }
      case UnsortedSource():
        final r = await _shelf.getItem(itemId);
        if (r is Ok<TapeItem>) _queue = [r.value];
        _queueName = '분류 안 함';
      case FriendSource(:final friendId):
        final r = await _friends.getFriendTapes(friendId);
        if (r is Ok<FriendTapes>) {
          _queue = [for (final x in r.value.items) x.item];
          _queueName = '${r.value.friend.name}님의 테이프';
        }
      case LinkSource(:final token):
        // 받기 전: 소포만 보여 준다. 칩은 받은 뒤 친구가 됐을 때.
        _linkChip = false;
        _queueName = '분류 안 함';
        var link = _share?.peek(token);
        if (link == null) {
          final r = await _share?.open(token);
          if (r case Error(:final error)) {
            _linkError = linkErrorOf(error);
          } else if (r case Ok(:final value)) {
            link = value;
          }
        }
        if (link != null) _queue = [link.parcel];
        itemId = 'link:$token';
    }
    if (_closed) return;
    _index = _queue.indexWhere((x) => x.id == itemId);
    final item = current;
    if (item == null) {
      _load = TrackLoad.error;
      notifyListeners();
      return;
    }
    if (!item.opened) {
      // 서랍이 꽉 찼는지 미리 본다 (뜯은 테이프 수 >= 한도). 못 불러오면 서버가 정한다.
      await _checkDrawer();
      if (_closed) return;
      _phase = ViewerPhase.parcel;
      notifyListeners();
      return;
    }
    _phase = ViewerPhase.play;
    notifyListeners();
    _loadTrack(openLoad);
  }

  /// 링크 테이프 받기 — 성공하면 서랍의 그 테이프로 바꾸고, 친구가 됐으면 칩.
  Future<TapeItem?> _claim(String token) async {
    final share = _share;
    if (share == null || _claiming) return null;
    _claiming = true;
    notifyListeners();
    final r = await share.claim(token);
    _claiming = false;
    if (_closed) return null;
    switch (r) {
      case Ok(:final value):
        _linkChip = value.friend != null;
        _queue = [value.item];
        _index = 0;
        return value.item;
      case Error(:final error):
        final kind = linkErrorOf(error);
        if (kind != null) {
          _linkError = kind;
        } else {
          _toast.show(
            error is ApiException ? error.message : '잠시 문제가 생겼어요. 다시 시도해 주세요',
          );
        }
        notifyListeners();
        return null;
    }
  }

  /// ⋯ 메뉴에서 메모를 바꿨을 때 (`setMemo`) — 라벨과 재생 리스트에 바로 보인다.
  /// 저장은 서랍 ViewModel이 한다.
  void applyMemo(String itemId, String? memo) {
    if (_closed) return; // 서버가 늦게 거절했을 때 이미 닫혔을 수 있다
    _queue = [
      for (final x in _queue) x.id == itemId ? x.copyWith(memo: () => memo) : x,
    ];
    notifyListeners();
  }

  /// 소포 뜯기 (`unwrap`) — `POST /deliveries/{id}/open`.
  /// 링크 테이프면 먼저 받는다 (`POST /share/{token}/claim`).
  Future<void> unwrap() async {
    var item = current;
    if (_phase != ViewerPhase.parcel || item == null) return;
    if (_source case LinkSource(:final token) when item.id == 'link:$token') {
      item = await _claim(token);
      if (item == null || _phase != ViewerPhase.parcel) return;
    }
    // 꽉 찬 서랍: 소포는 그대로 두고 꽉 참 시트 (효과음·연출 없음).
    // 꽉 찼다고 알고 있으면 막기 전에 한 번 더 확인한다 (다른 화면·기기에서 지웠을 수 있다).
    if (_drawer?.full ?? false) {
      if (_rechecking) return;
      _rechecking = true;
      await _checkDrawer();
      _rechecking = false;
      if (_closed || _phase != ViewerPhase.parcel) return;
    }
    if (_drawer?.full ?? false) {
      _fullOpen = true;
      notifyListeners();
      return;
    }
    _phase = ViewerPhase.tearing;
    unawaited(_sound.play(UiSound.open));
    _queue = [
      for (final x in _queue) x.id == item.id ? x.copyWith(opened: true) : x,
    ];
    notifyListeners();
    _tearTimer = Timer(tearTime, () {
      if (_closed) return;
      _phase = ViewerPhase.play;
      notifyListeners();
      _loadTrack(openLoad);
    });
    final r = await _shelf.open(item.id);
    if (r case Error(:final error) when !_closed) {
      _tearTimer?.cancel();
      _phase = ViewerPhase.parcel;
      _queue = [
        for (final x in _queue) x.id == item.id ? x.copyWith(opened: false) : x,
      ];
      if (error is ApiException && error.code == ApiErrorCode.drawerFull) {
        // 앱이 본 서랍이 늦었다 — 다시 받아 꽉 참 시트로
        await _checkDrawer();
        if (_closed) return;
        _fullOpen = true;
      } else {
        _toast.show(
          error is ApiException ? error.message : '잠시 문제가 생겼어요. 다시 시도해 주세요',
        );
      }
      notifyListeners();
    }
  }

  // ── 불러오기 (`loadTrack`) ──────────────────────────
  /// 불러오는 중을 최소 [minShow] 보여 주고, 재생 주소를 받아 재생한다.
  Future<void> _loadTrack(Duration minShow) async {
    final gen = ++_loadGen;
    final item = current;
    if (item == null) return;
    _load = TrackLoad.loading;
    _playing = false;
    _pos = 0;
    _loadedDuration = null;
    notifyListeners();
    unawaited(_player.pause().catchError((_) {}));

    final minDone = Future<void>.delayed(minShow);
    TapeAudio? audio;
    Duration? d;
    var failed = false;
    try {
      final r = await _shelf.audioUrl(item.id);
      if (r is Ok<TapeAudio>) {
        audio = r.value;
        d = await _player.load(audio.url);
      } else {
        failed = true;
      }
    } catch (_) {
      failed = true;
    }
    await minDone;
    if (gen != _loadGen || _closed) return;
    if (failed) {
      _load = TrackLoad.error;
      notifyListeners();
      return;
    }
    // 파일 길이 → 서버가 준 길이 → 서랍의 durationMs (캐시 파일은 서버 길이가 없다)
    _loadedDuration = (d != null && d > Duration.zero)
        ? d
        : (audio!.duration > Duration.zero ? audio.duration : null);
    _load = TrackLoad.ready;
    await _player.setLoopOne(_rep == TapeRepeat.one);
    await play();
  }

  /// 다시 시도 (`vRetry`)
  Future<void> retry() => _loadTrack(openLoad);

  // ── 재생 ─────────────────────────────────────────
  Future<void> play() async {
    if (_load != TrackLoad.ready) return;
    if (_pos >= duration) {
      _pos = 0;
      await _player.seek(Duration.zero);
    }
    _playing = true;
    notifyListeners();
    await _player.play();
  }

  Future<void> pause() async {
    _playing = false;
    notifyListeners();
    await _player.pause();
  }

  Future<void> togglePlay() => _playing ? pause() : play();

  void _onPosition(Duration p) {
    if (!_playing) return;
    _pos = (p.inMilliseconds / 1000).clamp(0, duration);
    notifyListeners();
  }

  /// 끝났을 때 (`vEnd`): one이면 반복, 다음 곡이 있으면 다음 곡, all이면 첫 곡, off면 멈춤.
  void _onEnd() {
    if (!_playing) return;
    _pos = duration;
    if (_rep == TapeRepeat.one) {
      _restart();
      return;
    }
    if (_index < _queue.length - 1) {
      goTrack(_index + 1);
      return;
    }
    if (_rep == TapeRepeat.all) {
      if (_queue.length > 1) {
        goTrack(0);
      } else {
        _restart();
      }
      return;
    }
    _playing = false;
    notifyListeners();
  }

  Future<void> _restart() async {
    _pos = 0;
    await _player.seek(Duration.zero);
    await play();
  }

  /// 곡 넘김 (`goTrack`)
  void goTrack(int i) {
    if (i < 0 || i >= _queue.length) return;
    _index = i;
    _insN++;
    _loadTrack(skipLoad);
  }

  /// 이전 (`vPrev`): 3초 넘게 들었거나 첫 곡이면 처음부터, 아니면 앞 곡.
  Future<void> prev() async {
    if (_pos > restartAfter || _index <= 0) {
      await _restart();
    } else {
      goTrack(_index - 1);
    }
  }

  /// 다음 (`vNext`)
  void next() {
    if (_index < _queue.length - 1) {
      goTrack(_index + 1);
    } else if (_rep == TapeRepeat.all && _queue.length > 1) {
      goTrack(0);
    }
  }

  /// 반복 (`vRepeat`) — off → all → one, 모드 이름을 토스트로.
  Future<void> cycleRepeat() async {
    _rep = _rep.next;
    notifyListeners();
    _toast.show(_rep.label);
    await _player.setLoopOne(_rep == TapeRepeat.one);
  }

  /// 닫기 (`closeViewer`)
  Future<void> close() async {
    _closed = true;
    _loadGen++;
    _tearTimer?.cancel();
    _playing = false;
    await _player.stop();
  }

  @override
  void dispose() {
    _closed = true;
    _shelf.removeListener(_onShelfChanged);
    _tearTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    unawaited(_player.stop().catchError((_) {}));
    super.dispose();
  }
}
