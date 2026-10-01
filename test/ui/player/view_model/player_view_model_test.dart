import 'package:tapeletter_app/data/repositories/friend_repository_remote.dart';
import 'package:tapeletter_app/data/repositories/shelf_repository_remote.dart';
import 'package:tapeletter_app/data/services/local/local_api_client.dart';
import 'package:tapeletter_app/data/services/local/local_behavior.dart';
import 'package:tapeletter_app/data/services/local/local_store.dart';
import 'package:tapeletter_app/data/services/sound_service.dart';
import 'package:tapeletter_app/domain/models/tape_repeat.dart';
import 'package:tapeletter_app/ui/core/ui/toast.dart';
import 'package:tapeletter_app/ui/player/view_model/player_view_model.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../testing/fakes/services/fake_audio_player_service.dart';
import '../../../../testing/fakes/services/fake_sound_service.dart';

void main() {
  late LocalStore store;
  late FakeAudioPlayerService player;
  late ToastController toast;
  late PlayerViewModel vm;
  late FakeSoundService sound;
  late ShelfRepositoryRemote shelf;

  PlayerViewModel make({LocalBehavior behavior = LocalBehavior.instant}) {
    store = LocalStore(clock: () => DateTime.utc(2026, 9, 25, 3));
    player = FakeAudioPlayerService(duration: null);
    toast = ToastController();
    sound = FakeSoundService();
    final api = LocalApiClient(store, behavior);
    shelf = ShelfRepositoryRemote(api);
    return PlayerViewModel(
      shelfRepository: shelf,
      friendRepository: FriendRepositoryRemote(api),
      player: player,
      toast: toast,
      sound: sound,
    );
  }

  String g1(int i) => store.groups[0].items[i].id;

  /// 칸 '2026 생일' [엄마 3분, 민수 15초, 수아 1분, 할머니 15초]의 [i]번째를 연다.
  void openGroup(FakeAsync async, int i) {
    vm.open(const GroupSource('g-1'), g1(i));
    async.flushMicrotasks();
    async.elapse(PlayerViewModel.openLoad);
  }

  test('칸 재생: 불러오는 중 0.7초 → 재생, 목록과 제목', () {
    fakeAsync((async) {
      vm = make();
      vm.open(const GroupSource('g-1'), g1(1));
      async.flushMicrotasks();
      expect(vm.queueName, '2026 생일');
      expect(vm.queue.map((x) => x.from), ['엄마', '민수', '수아', '할머니']);
      expect(vm.indexText, '2/4');
      expect(vm.load, TrackLoad.loading);
      async.elapse(const Duration(milliseconds: 699));
      expect(vm.load, TrackLoad.loading);
      async.elapse(const Duration(milliseconds: 1));
      expect(vm.load, TrackLoad.ready);
      expect(vm.playing, isTrue);
      expect(player.loaded, 'asset:///assets/audio/sample_20s.m4a');
      // 파일 길이를 모르면 서버 durationMs
      expect(vm.duration, 20);
    });
  });

  test('안 뜯은 소포: 뜯기 → 0.75초 뒤 재생 화면 → 0.7초 불러오기', () {
    fakeAsync((async) {
      vm = make();
      final id = store.unsorted.first.id;
      vm.open(const UnsortedSource(), id);
      async.flushMicrotasks();
      expect(vm.phase, ViewerPhase.parcel);
      expect(vm.queueName, '분류 안 함');

      vm.unwrap();
      expect(vm.phase, ViewerPhase.tearing);
      async.flushMicrotasks();
      expect(store.unsorted.first.opened, isTrue);
      async.elapse(const Duration(milliseconds: 750));
      expect(vm.phase, ViewerPhase.play);
      expect(vm.load, TrackLoad.loading);
      async.elapse(PlayerViewModel.openLoad);
      expect(vm.playing, isTrue);
    });
  });

  group('서랍이 꽉 찼을 때 소포 뜯기 (fullOpen)', () {
    // 처음 서랍: 뜯은 테이프 8개(칸 4+2+2) + 안 뜯은 소포 2개(세지 않음)
    void openParcel(FakeAsync async, int i) {
      vm.open(const UnsortedSource(), store.unsorted[i].id);
      async.flushMicrotasks();
      expect(vm.phase, ViewerPhase.parcel);
    }

    test('stored >= cap: 연출·효과음 없이 꽉 참 시트, 소포는 그대로', () {
      fakeAsync((async) {
        vm = make();
        store.cap = 8;
        openParcel(async, 0);
        vm.unwrap();
        async.flushMicrotasks();
        expect(vm.phase, ViewerPhase.parcel);
        expect(vm.fullOpen, isTrue);
        expect(vm.drawer!.stored, 8);
        expect(sound.played, isEmpty);
        expect(store.unsorted.first.opened, isFalse);
        expect(toast.message, isNull);
        vm.closeFullOpen();
        expect(vm.fullOpen, isFalse);
      });
    });

    test('경계: 한 자리 남으면 뜯고, 그다음 소포는 꽉 참', () {
      fakeAsync((async) {
        vm = make();
        store.cap = 9;
        openParcel(async, 0);
        vm.unwrap();
        expect(vm.phase, ViewerPhase.tearing);
        expect(sound.played, [UiSound.open]);
        async.flushMicrotasks();
        expect(store.unsorted.first.opened, isTrue);
        async.elapse(const Duration(seconds: 2));
        vm.dispose();

        vm = PlayerViewModel(
          shelfRepository: shelf,
          friendRepository: FriendRepositoryRemote(
            LocalApiClient(store, LocalBehavior.instant),
          ),
          player: player,
          toast: toast,
          sound: sound,
        );
        openParcel(async, 1);
        vm.unwrap();
        async.flushMicrotasks();
        expect(vm.fullOpen, isTrue);
        expect(vm.drawer!.stored, 9);
        expect(store.unsorted[1].opened, isFalse);
      });
    });

    test('서버 409 DRAWER_FULL(앱 상태가 늦음): 소포로 되돌리고 꽉 참 시트', () {
      fakeAsync((async) {
        vm = make();
        openParcel(async, 0);
        store.cap = 8; // 앱이 본 뒤에 꽉 찼다
        vm.unwrap();
        expect(vm.phase, ViewerPhase.tearing);
        async.flushMicrotasks();
        expect(vm.phase, ViewerPhase.parcel);
        expect(vm.queue.first.opened, isFalse);
        expect(vm.fullOpen, isTrue);
        expect(vm.drawer!.full, isTrue);
        expect(store.unsorted.first.opened, isFalse);
        async.elapse(const Duration(seconds: 2));
        expect(vm.phase, ViewerPhase.parcel, reason: '찢기 타이머가 취소됐다');
      });
    });

    test('서랍을 넓히면 다시 뜯을 수 있다', () {
      fakeAsync((async) {
        vm = make();
        store.cap = 8;
        openParcel(async, 0);
        vm.unwrap();
        async.flushMicrotasks();
        expect(vm.fullOpen, isTrue);
        vm.closeFullOpen();
        store.cap = 18;
        shelf.invalidate(); // 상점에서 서랍 넓히기
        async.flushMicrotasks();
        vm.unwrap();
        expect(vm.phase, ViewerPhase.tearing);
        async.flushMicrotasks();
        expect(store.unsorted.first.opened, isTrue);
        async.elapse(const Duration(seconds: 2));
      });
    });
  });

  test('이전: 3초 넘게 들었으면 처음부터, 아니면 앞 곡, 첫 곡이면 처음부터', () {
    fakeAsync((async) {
      vm = make();
      openGroup(async, 2);
      player.emitPosition(const Duration(seconds: 5));
      async.flushMicrotasks();
      expect(vm.pos, 5);
      vm.prev();
      async.flushMicrotasks();
      expect(vm.index, 2);
      expect(vm.pos, 0);

      player.emitPosition(const Duration(seconds: 2));
      async.flushMicrotasks();
      vm.prev();
      async.flushMicrotasks();
      expect(vm.index, 1);
      expect(vm.insertCount, 1);
      expect(vm.load, TrackLoad.loading);
      async.elapse(PlayerViewModel.skipLoad);
      expect(vm.playing, isTrue);

      vm.prev();
      async.flushMicrotasks();
      async.elapse(PlayerViewModel.skipLoad);
      expect(vm.index, 0);
      expect(vm.canPrev, isFalse);
      vm.prev();
      async.flushMicrotasks();
      expect(vm.index, 0);
    });
  });

  test('다음: 마지막 곡에서는 전체 반복일 때만 첫 곡으로', () {
    fakeAsync((async) {
      vm = make();
      openGroup(async, 3);
      expect(vm.canNext, isFalse);
      vm.next();
      expect(vm.index, 3);
      vm.cycleRepeat(); // all
      async.flushMicrotasks();
      expect(vm.canNext, isTrue);
      vm.next();
      expect(vm.index, 0);
    });
  });

  test('반복 모드: off → all → one → off, 토스트와 LoopMode.one', () {
    fakeAsync((async) {
      vm = make();
      openGroup(async, 0);
      expect(vm.repeat, TapeRepeat.off);
      vm.cycleRepeat();
      async.flushMicrotasks();
      expect(vm.repeat, TapeRepeat.all);
      expect(toast.message, '전체 반복');
      expect(player.loopOne, isFalse);
      vm.cycleRepeat();
      async.flushMicrotasks();
      expect(vm.repeat, TapeRepeat.one);
      expect(toast.message, '한 개 반복');
      expect(player.loopOne, isTrue);
      vm.cycleRepeat();
      async.flushMicrotasks();
      expect(vm.repeat, TapeRepeat.off);
      expect(toast.message, '순서대로 재생');
      expect(player.loopOne, isFalse);
    });
  });

  test('끝나면: 다음 곡 → 마지막이면 멈춤(off) / 첫 곡(all)', () {
    fakeAsync((async) {
      vm = make();
      openGroup(async, 2);
      player.complete();
      async.flushMicrotasks();
      expect(vm.index, 3);
      async.elapse(PlayerViewModel.skipLoad);
      player.complete();
      async.flushMicrotasks();
      expect(vm.index, 3);
      expect(vm.playing, isFalse);

      vm.cycleRepeat(); // all
      vm.play();
      async.flushMicrotasks();
      player.complete();
      async.flushMicrotasks();
      expect(vm.index, 0);
    });
  });

  test('한 곡뿐인 목록에서 전체 반복이면 처음부터 다시', () {
    fakeAsync((async) {
      vm = make();
      final id = store.unsorted.last.id; // 하늘 (안 뜯음)
      vm.open(const UnsortedSource(), id);
      async.flushMicrotasks();
      vm.unwrap();
      async.elapse(const Duration(milliseconds: 1500));
      vm.cycleRepeat(); // all
      async.flushMicrotasks();
      player.complete();
      async.flushMicrotasks();
      expect(vm.index, 0);
      expect(vm.playing, isTrue);
      expect(vm.pos, 0);
    });
  });

  test('불러오기 실패 → 다시 시도', () {
    fakeAsync((async) {
      vm = make();
      player.failLoad = true;
      openGroup(async, 0);
      expect(vm.load, TrackLoad.error);
      player.failLoad = false;
      vm.retry();
      async.elapse(PlayerViewModel.openLoad);
      expect(vm.load, TrackLoad.ready);
    });
  });

  test('서버가 재생 주소를 못 주면(loadFail) 오류', () {
    fakeAsync((async) {
      vm = make(
        behavior: const LocalBehavior(
          failMode: FailMode.loadFail,
          latency: Duration.zero,
        ),
      );
      openGroup(async, 0);
      expect(vm.load, TrackLoad.error);
    });
  });

  test('친구 목록 재생: "엄마님의 테이프"', () {
    fakeAsync((async) {
      vm = make();
      final first = store.groups[0].items[0].id;
      vm.open(const FriendSource('u-mom'), first);
      async.flushMicrotasks();
      expect(vm.queueName, '엄마님의 테이프');
      expect(vm.queue, hasLength(3));
      expect(vm.index, 0);
    });
  });

  test('닫으면 멈춘다', () {
    fakeAsync((async) {
      vm = make();
      openGroup(async, 0);
      vm.close();
      async.flushMicrotasks();
      expect(player.calls.last, 'stop');
    });
  });

  test('QueueSource 키 왕복', () {
    for (final s in const [
      GroupSource('g-1'),
      UnsortedSource(),
      FriendSource('u-mom'),
    ]) {
      expect(QueueSource.parse(s.key).key, s.key);
    }
  });
}
