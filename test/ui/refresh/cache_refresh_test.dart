import 'package:tapeletter_app/config/resume_refresh.dart';
import 'package:tapeletter_app/data/model/friend_dto.dart';
import 'package:tapeletter_app/data/repositories/auth_repository.dart';
import 'package:tapeletter_app/data/repositories/friend_repository_remote.dart';
import 'package:tapeletter_app/data/repositories/shelf_repository_remote.dart';
import 'package:tapeletter_app/data/services/local/local_api_client.dart';
import 'package:tapeletter_app/data/services/local/local_behavior.dart';
import 'package:tapeletter_app/data/services/local/local_store.dart';
import 'package:tapeletter_app/ui/core/ui/toast.dart';
import 'package:tapeletter_app/ui/friend/view_model/friend_view_model.dart';
import 'package:tapeletter_app/ui/my/view_model/credit_history_view_model.dart';
import 'package:tapeletter_app/ui/player/view_model/player_view_model.dart';
import 'package:tapeletter_app/ui/shelf/view_model/shelf_view_model.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../testing/fakes/services/fake_audio_player_service.dart';
import '../../../testing/record_harness.dart';

/// 값을 바꾸는 동작 → 그 값을 들고 있는 다른 화면(ViewModel)에 바로 반영.
void main() {
  group('서랍 꽉 참 판단 (재생 화면)', () {
    late LocalStore store;
    late ShelfRepositoryRemote shelf;
    late PlayerViewModel vm;

    PlayerViewModel make() {
      final api = LocalApiClient(store, LocalBehavior.instant);
      return PlayerViewModel(
        shelfRepository: shelf,
        friendRepository: FriendRepositoryRemote(api),
        player: FakeAudioPlayerService(duration: null),
        toast: ToastController(),
      );
    }

    void setup() {
      store = LocalStore(clock: () => DateTime.utc(2026, 9, 25, 3))..cap = 8;
      shelf = ShelfRepositoryRemote(
        LocalApiClient(store, LocalBehavior.instant),
      );
      vm = make();
    }

    void openParcel(FakeAsync async) {
      vm.open(
        const UnsortedSource(),
        store.unsorted.firstWhere((x) => !x.opened).id,
      );
      async.flushMicrotasks();
      expect(vm.phase, ViewerPhase.parcel);
    }

    test('꽉 참 → (재생 화면을 연 채) 서랍에서 지우기 → 바로 뜯기 성공', () {
      fakeAsync((async) {
        setup();
        openParcel(async);
        vm.unwrap();
        async.flushMicrotasks();
        expect(vm.fullOpen, isTrue);
        vm.closeFullOpen();
        shelf.deleteItem(store.groups[1].items.first.id);
        async.flushMicrotasks();
        vm.unwrap();
        async.flushMicrotasks();
        expect(vm.fullOpen, isFalse);
        expect(vm.phase, ViewerPhase.tearing);
        expect(store.unsorted.first.opened, isTrue);
        async.elapse(const Duration(seconds: 2));
      });
    });

    test('꽉 참 → 다른 기기에서 지움(알림 없음) → 뜯을 때 다시 확인해 성공', () {
      fakeAsync((async) {
        setup();
        openParcel(async);
        expect(vm.drawer!.full, isTrue);
        store.groups[1].items = store.groups[1].items.sublist(1);
        vm.unwrap();
        async.flushMicrotasks();
        expect(vm.fullOpen, isFalse);
        expect(store.unsorted.first.opened, isTrue);
        async.elapse(const Duration(seconds: 2));
      });
    });

    test('여는 중에 끝난 지우기도 놓치지 않는다', () {
      fakeAsync((async) {
        setup();
        // 여는 요청이 끝나기 전에 지우기가 끝나 알림이 온다
        vm.open(const UnsortedSource(), store.unsorted.first.id);
        shelf.deleteItem(store.groups[1].items.first.id);
        async.flushMicrotasks();
        expect(vm.phase, ViewerPhase.parcel);
        expect(vm.drawer!.full, isFalse);
        vm.unwrap();
        expect(vm.phase, ViewerPhase.tearing);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 2));
      });
    });

    test('넓히기 구매(저장소 알림) → 바로 뜯기 성공', () {
      fakeAsync((async) {
        setup();
        openParcel(async);
        vm.unwrap();
        async.flushMicrotasks();
        expect(vm.fullOpen, isTrue);
        vm.closeFullOpen();
        store.cap = 18;
        shelf.invalidate();
        async.flushMicrotasks();
        vm.unwrap();
        expect(vm.phase, ViewerPhase.tearing);
        async.flushMicrotasks();
        expect(store.unsorted.first.opened, isTrue);
        async.elapse(const Duration(seconds: 2));
      });
    });

    test('다른 칸으로 옮기기·분류 안 함으로 옮기기는 보관량을 바꾸지 않는다', () {
      fakeAsync((async) {
        setup();
        final id = store.groups[0].items.first.id;
        shelf.moveItem(id, groupId: null, afterId: null);
        async.flushMicrotasks();
        openParcel(async);
        vm.unwrap();
        async.flushMicrotasks();
        expect(vm.fullOpen, isTrue, reason: '뜯은 테이프 8개 그대로');
      });
    });
  });

  group('다른 화면 반영', () {
    test('서랍에서 지우면 상점 서랍 카드(stored)와 마이 통계가 바로 바뀐다', () {
      fakeAsync((async) {
        final h = RecordHarness();
        h.shopVm.load();
        h.myVm.load();
        async.flushMicrotasks();
        expect(h.shopVm.stored, 8);
        expect(h.myVm.receivedCount, 10);
        h.shelf.deleteItem(h.store.groups[1].items.first.id);
        async.flushMicrotasks();
        expect(h.shopVm.stored, 7);
        expect(h.myVm.receivedCount, 9);
        expect(h.myVm.received, hasLength(9));
      });
    });

    test('소포를 뜯으면 상점 서랍 카드가 바로 바뀐다', () {
      fakeAsync((async) {
        final h = RecordHarness();
        h.shopVm.load();
        async.flushMicrotasks();
        h.shelf.open(h.store.unsorted.first.id);
        async.flushMicrotasks();
        expect(h.shopVm.stored, 9);
      });
    });

    test('친구 화면: 다른 곳에서 별명을 바꾸거나 소포를 뜯으면 다시 불러온다', () {
      fakeAsync((async) {
        final h = RecordHarness();
        final vm = FriendViewModel(
          friendRepository: h.friends,
          shelfRepository: h.shelf,
          friendId: 'u-jihyun',
        )..load();
        async.flushMicrotasks();
        expect(vm.subtitle, '뜯지 않은 테이프 1개');
        h.friends.setNickname('u-jihyun', '지현이');
        async.flushMicrotasks();
        expect(vm.name, '지현이');
        h.shelf.open(h.store.unsorted.first.id);
        async.flushMicrotasks();
        expect(vm.subtitle, contains('받은 테이프 1개'));
        vm.dispose();
        h.friends.invalidate(); // 닫은 뒤 알림은 무시
        async.flushMicrotasks();
      });
    });

    test('크레딧 내역: 보는 중 크레딧이 바뀌면 다시 불러온다', () {
      fakeAsync((async) {
        final h = RecordHarness();
        final vm = CreditHistoryViewModel(walletRepository: h.wallet)..load();
        async.flushMicrotasks();
        expect(vm.credits, 120);
        h.store.credits = 150;
        h.wallet.invalidate();
        async.flushMicrotasks();
        expect(vm.credits, 150);
        vm.dispose();
      });
    });

    test('서랍 화면: 옮기는 중에 온 알림(새 소포 푸시)도 끝나면 반영', () {
      fakeAsync((async) {
        final h = RecordHarness();
        final vm = ShelfViewModel(shelfRepository: h.shelf, toast: h.toast)
          ..load();
        async.flushMicrotasks();
        final id = h.store.groups[0].items.first.id;
        vm.moveTo(id, null); // 서버 응답 전
        h.store.unsorted = h.store.unsorted.sublist(1); // 서버에서 바뀜
        h.shelf.invalidate(); // 푸시
        async.flushMicrotasks();
        expect(vm.shelf.unsorted.map((x) => x.id), isNot(contains('nope')));
        expect(
          vm.shelf.unsorted.length,
          h.store.unsorted.length,
          reason: '끝난 뒤 서버 상태로 다시 불러왔다',
        );
      });
    });
  });

  group('앱이 돌아오면(resumed) 다시 불러오기', () {
    test('30초 지나면 서랍·크레딧·친구·내 정보를 다시, 그 전엔 건너뜀', () {
      fakeAsync((async) {
        final h = RecordHarness();
        var now = DateTime(2026, 9, 25, 12);
        final r = ResumeRefresh(
          auth: h.auth,
          users: h.users,
          friends: h.friends,
          wallet: h.wallet,
          shelf: h.shelf,
          clock: () => now,
        );
        h.auth.restore();
        h.vm.load();
        h.shopVm.load();
        async.flushMicrotasks();
        expect(h.auth.status, AuthStatus.signedIn);

        // 다른 기기에서: 친구가 생기고 선물이 오고 테이프가 지워졌다
        h.store.friends = [
          ...h.store.friends,
          FriendDto(
            userId: 'u-x',
            name: '새봄',
            starred: false,
            lastAt: LocalStore.d(9, 25),
          ),
        ];
        h.store.credits = 200;
        h.store.groups[1].items = h.store.groups[1].items.sublist(1);

        now = now.add(const Duration(seconds: 10));
        expect(r.onResumed(), isFalse);
        async.flushMicrotasks();
        expect(h.vm.wallet.credits, 120);

        now = now.add(const Duration(seconds: 30));
        expect(r.onResumed(), isTrue);
        async.flushMicrotasks();
        expect(h.vm.wallet.credits, 200);
        expect(h.vm.sortedFriends.map((f) => f.name), contains('새봄'));
        expect(h.shopVm.stored, 7);
        expect(h.shopVm.credits, 200);
      });
    });
  });
}
