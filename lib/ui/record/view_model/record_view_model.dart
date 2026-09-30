import 'dart:async';

import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';

import '../../../data/repositories/delivery_repository.dart';
import '../../../data/repositories/friend_repository.dart';
import '../../../data/repositories/recording_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/repositories/wallet_repository.dart';
import '../../../data/services/app_settings_service.dart';
import '../../../data/services/audio_player_service.dart';
import '../../../data/services/recorder_service.dart';
import '../../../data/services/sound_service.dart';
import '../../../data/services/share_service.dart';
import '../../../domain/models/friend.dart';
import '../../../domain/models/me.dart';
import '../../../domain/models/recipient.dart';
import '../../../domain/models/recording.dart';
import '../../../domain/models/sent_tape.dart';
import '../../../domain/models/tape_type.dart';
import '../../../domain/models/user.dart';
import '../../../domain/models/wallet.dart';
import '../../../utils/idempotency.dart';
import '../../../utils/result.dart';
import '../../core/ui/toast.dart';

/// 녹음 흐름 단계 — logic.js `state.phase`.
///
/// `idle → rec (↔ paused) → confirm → pick → label → sending → sent`
enum RecordPhase { idle, rec, paused, confirm, pick, label, sending, sent }

enum MicPermission { unknown, granted, denied }

/// 포장·발송 중 서버 응답 상태.
enum SendState { pending, success, failed }

enum ShareChannel { kakao, sms }

/// 녹음 탭 ViewModel. 프로토타입 `Component`의 녹음 관련 state와 핸들러를 옮겼다.
class RecordViewModel extends ChangeNotifier {
  RecordViewModel({
    required UserRepository userRepository,
    required FriendRepository friendRepository,
    required WalletRepository walletRepository,
    required RecordingRepository recordingRepository,
    required DeliveryRepository deliveryRepository,
    required this._recorder,
    required this._player,
    required this._share,
    required this._settings,
    required this._toast,
    this._sound = const NoSoundService(),
  }) : _users = userRepository,
       _friendsRepo = friendRepository,
       _walletRepo = walletRepository,
       _recordings = recordingRepository,
       _deliveries = deliveryRepository {
    _friendsRepo.addListener(_loadFriends);
    _walletRepo.addListener(_loadWallet);
    _users.addListener(_loadName);
    _subs.add(_player.position.listen(_onPosition));
    _subs.add(_player.completed.listen((_) => _onPreviewEnd()));
    _subs.add(
      _recorder.onInterrupted.listen((_) => pauseRec('전화가 와서 녹음이 멈췄어요')),
    );
  }

  // 원본 타이밍 (logic.js)
  /// 녹음 타이머 `every('rec', 250)`
  static const tick = Duration(milliseconds: 250);

  /// 변환 노이즈를 최소로 보여주는 시간 `later('conv', 1500)`
  static const convertMin = Duration(milliseconds: 1500);

  /// 이 시간을 넘기면 "조금 오래 걸리고 있어요" `later('slow', 1400)`
  static const convertSlowAfter = Duration(milliseconds: 1400);

  /// 라벨 타이핑 간격 `every('type', 110)`
  static const typeInterval = Duration(milliseconds: 110);

  /// 보내기 실패를 보여주는 시점 `later('send', 1700)`
  static const sendFailAt = Duration(milliseconds: 1700);

  /// 포장 → 완료 `later('send', 2700)`
  static const sendTotal = Duration(milliseconds: 2700);

  /// `fly 2.6s`의 72% 지점. 여기까지는 박스가 제자리에 있다.
  static const flyHold = Duration(milliseconds: 1872);

  /// 날아가는 구간(28%) + 완료까지 남은 0.1초
  static const flyTail = Duration(milliseconds: 828);

  final UserRepository _users;
  final FriendRepository _friendsRepo;
  final WalletRepository _walletRepo;
  final RecordingRepository _recordings;
  final DeliveryRepository _deliveries;
  final RecorderService _recorder;
  final AudioPlayerService _player;
  final ShareService _share;
  final AppSettingsService _settings;
  final ToastController _toast;

  /// 효과음 — REC 뒤 on.wav가 끝나면 녹음, STOP은 녹음을 멈춘 뒤 off.wav
  final SoundService _sound;
  final List<StreamSubscription<void>> _subs = [];

  // ── 상태 ───────────────────────────────────────────
  RecordPhase _phase = RecordPhase.idle;
  TapeType _tape = TapeType.s15;
  double _sec = 0;
  double _recorded = 0;
  double _pos = 0;
  bool _playing = false;
  bool _converting = false;
  bool _convSlow = false;
  bool _convFail = false;
  Recipient? _to;
  int _typed = 0;
  String _newName = '';
  bool _sendFail = false;
  SendState _sendState = SendState.pending;
  int _sendAttempt = 0;
  String _pauseWhy = '';
  MicPermission _mic = MicPermission.unknown;
  String _myName = '';

  Wallet _wallet = const Wallet(credits: 0, owned: {}, adsLeft: 0);
  List<Friend> _friends = const [];
  SentTape? _lastSent;

  String? _filePath;
  Recording? _recording;
  String? _idemKey;
  String? _idemFor;
  bool _openedSettings = false;
  bool _starting = false;

  /// REC를 눌러 on.wav가 울리는 중 (녹음은 소리가 끝난 뒤 시작한다)
  bool _arming = false;
  bool get arming => _arming;
  bool _convertFailedOnce = false;

  Timer? _tickTimer;
  Timer? _typeTimer;
  final List<Timer> _convTimers = [];
  final List<Timer> _sendTimers = [];
  int _convGen = 0;
  int _sendGen = 0;

  // ── 읽기 ───────────────────────────────────────────
  RecordPhase get phase => _phase;
  TapeType get tape => _tape;
  double get sec => _sec;
  double get recorded => _recorded;
  double get pos => _pos;
  bool get playing => _playing;
  bool get converting => _converting;
  bool get convSlow => _convSlow;
  bool get convFail => _convFail;
  Recipient? get to => _to;
  String get newName => _newName;
  bool get sendFail => _sendFail;
  SendState get sendState => _sendState;

  /// 다시 보내기를 누를 때마다 바뀐다. 발송 애니메이션을 처음부터 다시 튼다.
  int get sendAttempt => _sendAttempt;
  String get pauseWhy => _pauseWhy;
  MicPermission get mic => _mic;
  String get myName => _myName;
  Wallet get wallet => _wallet;
  SentTape? get lastSent => _lastSent;

  int get maxSeconds => _tape.seconds;

  /// 녹음 진행률 (릴 감김)
  double get progress => (_sec / maxSeconds).clamp(0, 1);

  /// 미리 듣기 진행률
  double get previewProgress =>
      _recorded > 0 ? (_pos / _recorded).clamp(0, 1) : 0;

  bool isLocked(TapeType t) => !_wallet.canUse(t);

  /// 지금 고른 테이프가 0개라 녹음할 수 없는지 (`curLocked`)
  bool get curLocked => isLocked(_tape);

  /// 탭바를 숨기는 단계 (`showTabs`의 반대)
  bool get hidesTabs => const {
    RecordPhase.confirm,
    RecordPhase.pick,
    RecordPhase.label,
    RecordPhase.sending,
    RecordPhase.sent,
  }.contains(_phase);

  bool get showToChip => _phase == RecordPhase.idle && _to != null;

  /// 즐겨찾기 먼저 (`sorted`)
  List<Friend> get sortedFriends => [
    ..._friends.where((f) => f.starred),
    ..._friends.where((f) => !f.starred),
  ];

  /// 라벨 카드의 받는 사람 칸 (`typedName`)
  String get typedName {
    final t = _to;
    if (t == null) return '';
    // 비우면 "새 친구" (`s.newName || '새 친구'`)
    if (t.isNew) return _newName.isEmpty ? Recipient.unnamed : _newName;
    return t.name.characters.take(_typed).toString();
  }

  /// 확인 화면 하단 버튼 문구 (`sendCta`)
  String get sendCta {
    final t = _to;
    return t != null && !t.isNew ? '${t.name}에게 보내기' : '누구에게 보낼까요?';
  }

  /// 보내기 버튼 (`sendBg` 항상 `#111`) — 새 친구 이름은 선택 입력 (v3)
  bool get canSend => true;

  bool get sentToNew => _to?.isNew == true;

  String get sentTitle =>
      sentToNew ? '테이프를 포장했어요' : '${_to?.name ?? ''}님에게 보냈어요';

  String get sentSub => sentToNew
      ? '링크를 보내면 테이프가 전달돼요.\n받으면 서로 친구가 돼요.'
      : '테이프는 이제 받는 사람만 들을 수 있어요';

  // ── 불러오기 ────────────────────────────────────────
  Future<void> load() async {
    final me = await _users.getMe();
    if (me is Ok<Me>) _myName = me.value.name;
    await _loadWallet();
    await _loadFriends();
    try {
      if (await _recorder.hasPermission(request: false)) {
        _mic = MicPermission.granted;
      }
    } catch (_) {
      // 권한 확인이 안 되는 환경이면 녹음 버튼을 누를 때 다시 묻는다.
    }
    notifyListeners();
  }

  Future<void> _loadName() async {
    final me = await _users.getMe();
    if (me is Ok<Me>) {
      _myName = me.value.name;
      notifyListeners();
    }
  }

  Future<void> _loadWallet() async {
    final r = await _walletRepo.getWallet();
    if (r is Ok<Wallet>) {
      _wallet = r.value;
      notifyListeners();
    }
  }

  Future<void> _loadFriends() async {
    final r = await _friendsRepo.getFriends();
    if (r is Ok<List<Friend>>) {
      _friends = r.value;
      notifyListeners();
    }
  }

  // ── 대기: 테이프 고르기 ──────────────────────────────
  /// 캐러셀에서 테이프를 고른다 (`swDown`의 pointerup).
  void selectTape(TapeType t) {
    if (_phase != RecordPhase.idle) return;
    _tape = t;
    _sec = 0;
    notifyListeners();
  }

  void clearTo() {
    _to = null;
    notifyListeners();
  }

  /// 다른 화면에서 "녹음해서 보내기"로 들어올 때 (`recTo`).
  void recordTo(Friend friend) {
    if (_phase != RecordPhase.idle) return;
    // 테이프 라벨처럼 상대가 보는 곳은 원래 이름
    _to = Recipient.friend(friendId: friend.id, name: friend.originalName);
    _sec = 0;
    notifyListeners();
  }

  // ── 녹음 ───────────────────────────────────────────
  /// 녹음 시작. [keep]이면 멈춘 곳에서 이어서 녹음한다 (`startRec(true)`).
  Future<void> startRec({bool keep = false}) async {
    final resuming = keep && _phase == RecordPhase.paused;
    if (_starting || (_phase != RecordPhase.idle && !resuming)) return;
    if (curLocked) return;
    _starting = true;
    try {
      if (_mic != MicPermission.granted) {
        final ok = await _recorder.hasPermission(request: true);
        if (!ok) {
          _mic = MicPermission.denied;
          notifyListeners();
          return;
        }
        _mic = MicPermission.granted;
      }
      // on.wav가 녹음에 들어가지 않도록 소리가 끝난 뒤(0.54s) 녹음을 시작한다.
      // 데크는 그동안 STOP을 가운데로 미는 0.45s 애니메이션을 끝낸다.
      _arming = true;
      notifyListeners();
      try {
        await _sound.play(UiSound.on);
      } finally {
        _arming = false;
      }
      if (resuming) {
        await _recorder.resume();
      } else {
        _sec = 0;
        await _recorder.start();
      }
    } catch (_) {
      _toast.show('녹음을 시작하지 못했어요');
      return;
    } finally {
      _starting = false;
    }
    _phase = RecordPhase.rec;
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(tick, (_) => _onTick());
    notifyListeners();
  }

  void _onTick() {
    final max = maxSeconds.toDouble();
    if (_sec + .25 >= max) {
      _sec = max;
      notifyListeners();
      stopRec();
      return;
    }
    _sec += .25;
    notifyListeners();
  }

  /// 녹음 끝 → 확인 화면 → 변환 (`stopRec`).
  Future<void> stopRec() async {
    if (_phase != RecordPhase.rec && _phase != RecordPhase.paused) return;
    _tickTimer?.cancel();
    _phase = RecordPhase.confirm;
    _recorded = _sec;
    _pos = 0;
    _playing = false;
    _recording = null;
    _convertFailedOnce = false;
    _converting = true;
    notifyListeners();
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {
      path = null;
    }
    // 녹음기를 먼저 멈추고 나서 off.wav
    unawaited(_sound.play(UiSound.off));
    _filePath = path;
    await convert();
  }

  /// 녹음 멈춤 (전화·백그라운드) — `pauseRec(why)`.
  void pauseRec(String why) {
    if (_phase != RecordPhase.rec) return;
    _tickTimer?.cancel();
    _phase = RecordPhase.paused;
    _pauseWhy = why;
    notifyListeners();
    unawaited(_recorder.pause().catchError((_) {}));
  }

  Future<void> resumeRec() => startRec(keep: true);

  /// 여기까지 쓰기
  Future<void> useSoFar() => stopRec();

  void onAppHidden() => pauseRec('앱이 잠시 닫혀서 녹음이 멈췄어요');

  /// 설정에서 돌아왔을 때 마이크 권한을 다시 확인한다.
  Future<void> onAppResumed() async {
    if (_mic != MicPermission.denied) return;
    bool ok;
    try {
      ok = await _recorder.hasPermission(request: false);
    } catch (_) {
      ok = false;
    }
    if (!ok) return;
    _mic = MicPermission.granted;
    if (_openedSettings) _toast.show('설정에서 마이크를 켜고 돌아왔어요');
    _openedSettings = false;
    notifyListeners();
  }

  Future<void> openSettings() async {
    _openedSettings = true;
    await _settings.openAppSettings();
  }

  // ── 확인: 변환과 미리 듣기 ────────────────────────────
  /// 테이프 소리로 변환 (`convert`). 최소 1.5초는 노이즈를 보여준다.
  Future<void> convert() async {
    final gen = ++_convGen;
    _cancelTimers(_convTimers);
    _converting = true;
    _convSlow = false;
    _convFail = false;
    notifyListeners();

    var minDone = false;
    Result<Recording>? result;

    void finish() {
      if (gen != _convGen || !minDone || result == null) return;
      _cancelTimers(_convTimers);
      _converting = false;
      _convSlow = false;
      switch (result) {
        case Ok<Recording>(:final value):
          _recording = value;
          notifyListeners();
          _startPreview(value, gen);
        case Error<Recording>():
          _convFail = true;
          _convertFailedOnce = _recording != null;
          notifyListeners();
      }
    }

    _convTimers.add(
      Timer(convertSlowAfter, () {
        // 결과가 아직 없을 때만 "조금 오래 걸리고 있어요"를 보여준다.
        if (gen != _convGen || !_converting || result != null) return;
        _convSlow = true;
        notifyListeners();
      }),
    );
    _convTimers.add(
      Timer(convertMin, () {
        minDone = true;
        finish();
      }),
    );

    result = await _uploadAndConvert();
    finish();
  }

  Future<Result<Recording>> _uploadAndConvert() async {
    try {
      var rec = _recording;
      if (rec == null) {
        final path = _filePath;
        if (path == null) return Result.error(Exception('녹음 파일이 없어요'));
        final up = await _recordings.upload(
          filePath: path,
          type: _tape,
          duration: Duration(milliseconds: (_recorded * 1000).round()),
        );
        switch (up) {
          case Ok<Recording>(:final value):
            rec = value;
            _recording = value;
          case Error<Recording>(:final error):
            return Result.error(error);
        }
      }
      // 변환에 실패했던 녹음은 `POST /recordings/{id}/retry`로 다시 변환한다.
      return _convertFailedOnce
          ? await _recordings.retry(rec.id)
          : await _recordings.convert(rec.id);
    } on Exception catch (e) {
      return Result.error(e);
    }
  }

  Future<void> _startPreview(Recording rec, int gen) async {
    final url = rec.previewUrl;
    if (url == null) return;
    try {
      final d = await _player.load(url);
      if (gen != _convGen) return;
      if (rec.duration > Duration.zero) {
        _recorded = rec.duration.inMilliseconds / 1000;
      }
      if (d != null && d > Duration.zero) {
        _recorded = d.inMilliseconds / 1000;
      }
    } catch (_) {
      return;
    }
    await play();
  }

  /// 다시 시도
  Future<void> retryConvert() => convert();

  Future<void> play() async {
    if (_converting || _convFail) return;
    if (_pos >= _recorded) {
      _pos = 0;
      await _player.seek(Duration.zero);
    }
    _playing = true;
    notifyListeners();
    await _player.play();
  }

  Future<void> pause() async {
    if (!_playing) return;
    _playing = false;
    notifyListeners();
    await _player.pause();
  }

  Future<void> togglePlay() => _playing ? pause() : play();

  /// 데크 PLAY — 재생 시작은 on.wav, 멈춤은 off.wav
  Future<void> pressPlay() async {
    if (_playing) return pressStop();
    if (_converting || _convFail) return;
    unawaited(_sound.play(UiSound.on));
    await play();
  }

  /// 데크 STOP — 재생 중이면 멈추고 off.wav
  Future<void> pressStop() async {
    if (!_playing) return;
    unawaited(_sound.play(UiSound.off));
    await pause();
  }

  /// 확인 화면에서 데크 키를 쓸 수 있는지 (`ready` — 변환이 끝났고 실패하지 않음)
  bool get previewReady =>
      _phase == RecordPhase.confirm && !_converting && !_convSlow && !_convFail;

  /// REW — 처음으로 (`pos: 0`)
  Future<void> rewind() async {
    _pos = 0;
    notifyListeners();
    await _player.seek(Duration.zero);
  }

  /// FF — 5초 앞으로 (`min(recorded, pos + 5)`)
  Future<void> fastForward() async {
    _pos = (_pos + fastForwardSeconds).clamp(0, _recorded).toDouble();
    notifyListeners();
    await _player.seek(Duration(milliseconds: (_pos * 1000).round()));
  }

  /// 데크 FF가 한 번에 넘기는 초
  static const fastForwardSeconds = 5;

  void _onPosition(Duration d) {
    if (!_playing) return;
    _pos = (d.inMilliseconds / 1000).clamp(0, _recorded);
    notifyListeners();
  }

  void _onPreviewEnd() {
    if (!_playing) return;
    _playing = false;
    _pos = _recorded;
    notifyListeners();
  }

  /// ‹ 뒤로 → 대기. 테이프는 쓰지 않는다 (`backIdle`).
  void backIdle() {
    _stopPreview();
    _convGen++;
    _cancelTimers(_convTimers);
    _converting = false;
    _convSlow = false;
    _convFail = false;
    _phase = RecordPhase.idle;
    _sec = 0;
    _recording = null;
    notifyListeners();
  }

  /// 처음부터 다시 녹음 (`redoRec`)
  void redoRec() => backIdle();

  void _stopPreview() {
    if (_playing) {
      _playing = false;
      unawaited(_player.pause().catchError((_) {}));
    }
  }

  /// 확인 화면 하단 버튼 (`goSend`)
  void goSend() {
    if (_converting || _convFail) return;
    final t = _to;
    if (t != null && !t.isNew) {
      toLabel(t);
      return;
    }
    _stopPreview();
    _phase = RecordPhase.pick;
    notifyListeners();
  }

  // ── 받는 사람 ───────────────────────────────────────
  Future<void> toggleStar(Friend f) async {
    final prev = _friends;
    _friends = [
      for (final x in _friends)
        x.id == f.id ? x.copyWith(starred: !x.starred) : x,
    ];
    notifyListeners();
    final r = await _friendsRepo.setStarred(f.id, !f.starred);
    if (r is Error) {
      _friends = prev;
      notifyListeners();
    }
  }

  void pickFriend(Friend f) =>
      toLabel(Recipient.friend(friendId: f.id, name: f.originalName));

  void pickNew() => toLabel(const Recipient.newFriend());

  void backConfirm() {
    _phase = RecordPhase.confirm;
    notifyListeners();
  }

  // ── 라벨 ───────────────────────────────────────────
  /// `toLabel(to)`
  void toLabel(Recipient to) {
    _stopPreview();
    _to = to;
    _phase = RecordPhase.label;
    _newName = '';
    notifyListeners();
    if (!to.isNew) _typeName(to.name);
  }

  void _typeName(String name) {
    _typed = 0;
    final total = name.characters.length;
    _typeTimer?.cancel();
    _typeTimer = Timer.periodic(typeInterval, (t) {
      if (_typed >= total) {
        t.cancel();
        return;
      }
      _typed++;
      notifyListeners();
    });
  }

  void setNewName(String value) {
    _newName = value.characters.take(User.maxNameLength).toString();
    notifyListeners();
  }

  /// `backPick`
  void backPick() {
    _typeTimer?.cancel();
    final t = _to;
    final known = _friends.any((f) => f.id == t?.friendId);
    _phase = (t?.isNew ?? false) || known
        ? RecordPhase.pick
        : RecordPhase.confirm;
    notifyListeners();
  }

  // ── 보내기 ─────────────────────────────────────────
  /// `sendNow`
  void sendNow() {
    final t = _to;
    if (t == null) return;
    final typed = _newName.trim();
    _typeTimer?.cancel();
    // 새 친구 이름을 비우면 linkName을 보내지 않는다 → 서버·화면 모두 "새 친구"
    _to = t.isNew
        ? Recipient.newFriend(linkName: typed.isEmpty ? null : typed)
        : t;
    final keyFor = '${_recording?.id}|${t.friendId ?? ''}|${_to!.linkName}';
    if (_idemFor != keyFor) {
      _idemKey = newIdempotencyKey();
      _idemFor = keyFor;
    }
    _phase = RecordPhase.sending;
    _sendFail = false;
    notifyListeners();
    _playSend();
    _runSend();
  }

  void _runSend() {
    final gen = ++_sendGen;
    _cancelTimers(_sendTimers);
    _sendState = SendState.pending;
    var failGate = false;
    var holdReached = false;

    void toSent() {
      if (gen != _sendGen) return;
      _cancelTimers(_sendTimers);
      _phase = RecordPhase.sent;
      notifyListeners();
    }

    void showFail() {
      if (gen != _sendGen) return;
      // 실패 패널이 뜨면 보내기 소리를 끊는다
      unawaited(_sound.stop(UiSound.send));
      _sendFail = true;
      notifyListeners();
    }

    _sendTimers.add(
      Timer(sendFailAt, () {
        failGate = true;
        if (_sendState == SendState.failed) showFail();
      }),
    );
    _sendTimers.add(Timer(flyHold, () => holdReached = true));
    _sendTimers.add(
      Timer(sendTotal, () {
        if (_sendState == SendState.success) toSent();
      }),
    );

    final rec = _recording;
    final to = _to!;
    final Future<Result<SentTape>> call = rec == null
        ? Future.value(Result.error(Exception('녹음이 없어요')))
        : _deliveries.send(
            recordingId: rec.id,
            to: to,
            idempotencyKey: _idemKey!,
          );
    call.then((r) {
      if (gen != _sendGen) return;
      switch (r) {
        case Ok<SentTape>(:final value):
          _lastSent = value;
          _sendState = SendState.success;
          notifyListeners();
          // 보유 테이프와 친구 lastAt이 서버에서 바뀌었다.
          _walletRepo.invalidate();
          _friendsRepo.invalidate();
          // 박스가 72%에서 기다리고 있었다면 남은 비행 뒤에 완료한다.
          // 아니면 2.7초 타이머가 완료시킨다.
          if (holdReached) _sendTimers.add(Timer(flyTail, toSent));
        case Error<SentTape>():
          _sendState = SendState.failed;
          if (failGate) showFail();
      }
    });
  }

  /// 다시 보내기
  void retrySend() {
    if (_phase != RecordPhase.sending) return;
    _sendFail = false;
    _sendAttempt++;
    notifyListeners();
    _playSend();
    _runSend();
  }

  /// 보내기 연출(`tapeIn`)이 시작될 때 send.wav — 완료 화면까지 이어진다
  void _playSend() => unawaited(_sound.play(UiSound.send));

  /// 돌아가기 → 확인 화면
  void cancelSend() {
    _sendGen++;
    unawaited(_sound.stop(UiSound.send));
    _cancelTimers(_sendTimers);
    _phase = RecordPhase.confirm;
    _sendFail = false;
    notifyListeners();
  }

  // ── 완료 ───────────────────────────────────────────
  /// 확인 (`finish`)
  void finish() {
    _phase = RecordPhase.idle;
    _to = null;
    _sec = 0;
    _lastSent = null;
    _recording = null;
    _idemKey = null;
    _idemFor = null;
    if (curLocked) _tape = TapeType.s15;
    notifyListeners();
  }

  /// 카카오톡·문자로 링크 보내기 (`shareKakao` · `shareSms`).
  /// 카카오톡(없으면 웹 공유)이나 문자 앱을 열면 원본처럼 토스트 후 완료한다.
  /// 두 앱 모두 실제로 보냈는지는 알려 주지 않는다.
  Future<void> shareLink(ShareChannel channel) async {
    final sent = _lastSent;
    final url = sent?.shareUrl;
    if (sent == null || url == null) return;
    final message = TapeLinkMessage(
      senderName: myName,
      tapeName: sent.type.label,
      url: url,
    );
    final opened = switch (channel) {
      ShareChannel.kakao => await _share.shareKakao(message),
      ShareChannel.sms => await _share.shareSms(message),
    };
    if (!opened) return;
    _toast.show(
      channel == ShareChannel.kakao ? '카카오톡으로 링크를 보냈어요' : '문자로 링크를 보냈어요',
    );
    finish();
  }

  void _cancelTimers(List<Timer> timers) {
    for (final t in timers) {
      t.cancel();
    }
    timers.clear();
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _typeTimer?.cancel();
    _cancelTimers(_convTimers);
    _cancelTimers(_sendTimers);
    for (final s in _subs) {
      s.cancel();
    }
    _friendsRepo.removeListener(_loadFriends);
    _walletRepo.removeListener(_loadWallet);
    _users.removeListener(_loadName);
    super.dispose();
  }
}
