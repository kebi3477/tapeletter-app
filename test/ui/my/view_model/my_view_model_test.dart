import 'package:tapeletter_app/data/repositories/auth_repository.dart';
import 'package:tapeletter_app/data/repositories/delivery_repository_remote.dart';
import 'package:tapeletter_app/data/repositories/wallet_repository_remote.dart';
import 'package:tapeletter_app/domain/models/sent_tape.dart';
import 'package:tapeletter_app/domain/models/tape_type.dart';
import 'package:tapeletter_app/ui/my/view_model/credit_history_view_model.dart';
import 'package:tapeletter_app/ui/my/view_model/my_view_model.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../testing/record_harness.dart';

void main() {
  late RecordHarness h;
  late MyViewModel vm;

  void setup(FakeAsync async) {
    h = RecordHarness();
    vm = h.myVm..load();
    async.flushMicrotasks();
  }

  test('불러오기: 이름·크레딧·통계·보유·계정·버전', () {
    fakeAsync((async) {
      setup(async);
      expect(vm.name, '민경');
      expect(vm.credits, 120);
      expect(vm.receivedCount, 10);
      expect(vm.sentCount, 4);
      expect(vm.friendCount, 6);
      expect(vm.ownedOf(TapeType.m1), 2);
      expect(vm.providerText, '카카오');
      expect(vm.version, '1.0.0');
      expect(vm.blockedCountText, '없음');
      expect(vm.friends.first.name, '지현');
    });
  });

  test('보낸 테이프 상태 문구 (목록·상세)', () {
    SentTape s(SentStatus st, {DateTime? opened}) => SentTape(
      id: 'x',
      status: st,
      to: '엄마',
      date: DateTime(2026, 9, 10),
      type: TapeType.m1,
      openedAt: opened,
    );
    expect(MyViewModel.sentStatus(s(SentStatus.linkPending)), '링크 대기');
    expect(MyViewModel.sentStatus(s(SentStatus.linkExpired)), '링크 만료');
    expect(MyViewModel.sentStatus(s(SentStatus.unopened)), '안 뜯음');
    expect(
      MyViewModel.sentStatus(
        s(SentStatus.opened, opened: DateTime(2026, 9, 11)),
      ),
      '09.11 들음',
    );
    expect(
      MyViewModel.sentDetailStatus(s(SentStatus.linkPending)),
      '아직 아무도 받지 않았어요',
    );
    expect(
      MyViewModel.sentDetailStatus(s(SentStatus.linkExpired)),
      '링크가 만료됐어요',
    );
    expect(
      MyViewModel.sentDetailStatus(s(SentStatus.unopened)),
      '아직 소포를 안 뜯었어요',
    );
    expect(
      MyViewModel.sentDetailStatus(
        s(SentStatus.opened, opened: DateTime(2026, 9, 11)),
      ),
      '09.11에 들었어요',
    );
    expect(MyViewModel.canReshare(s(SentStatus.linkPending)), isTrue);
    expect(MyViewModel.canReshare(s(SentStatus.linkExpired)), isTrue);
    expect(MyViewModel.canReshare(s(SentStatus.opened)), isFalse);
  });

  test('프로토타입 보낸 기록 4개 상태', () {
    fakeAsync((async) {
      setup(async);
      // FakeDeliveryRepository 대신 로컬 서버를 쓰는 repository로 확인
      final r = DeliveryRepositoryRemote(h.api);
      late List<SentTape> list;
      r.getSent().then((v) => list = ((v as dynamic).value as SentPage).items);
      async.flushMicrotasks();
      expect(list.map(MyViewModel.sentStatus), [
        '링크 대기',
        '09.11 들음',
        '안 뜯음',
        '06.02 들음',
      ]);
    });
  });

  test('이름 수정: 8자 제한, 비우면 원래 이름', () {
    fakeAsync((async) {
      setup(async);
      vm.startEditName();
      expect(vm.nameDraft, '민경');
      vm.setNameDraft('가나다라마바사아자');
      expect(vm.nameDraft, '가나다라마바사아');
      vm.commitName();
      async.flushMicrotasks();
      expect(vm.name, '가나다라마바사아');
      expect(h.store.name, '가나다라마바사아');

      vm.startEditName();
      vm.setNameDraft('   ');
      vm.commitName();
      async.flushMicrotasks();
      expect(vm.name, '가나다라마바사아');
    });
  });

  test('즐겨찾기 토글', () {
    fakeAsync((async) {
      setup(async);
      final minsu = vm.friends.firstWhere((f) => f.name == '민수');
      vm.toggleStar(minsu);
      async.flushMicrotasks();
      expect(vm.friends.take(3).map((f) => f.name), ['지현', '엄마', '민수']);
      expect(h.store.friends.firstWhere((f) => f.name == '민수').starred, isTrue);
    });
  });

  test('친구 삭제', () {
    fakeAsync((async) {
      setup(async);
      final eunbi = vm.friends.firstWhere((f) => f.name == '은비');
      vm.removeFriend(eunbi);
      async.flushMicrotasks();
      expect(vm.friends.map((f) => f.name), isNot(contains('은비')));
      expect(h.toast.message, '은비님을 목록에서 뺐어요');
      expect(vm.friendCount, 5);
    });
  });

  test('차단 → 목록에서 빠지고 차단 목록에 → 해제하면 즐겨찾기까지 돌아온다', () {
    fakeAsync((async) {
      setup(async);
      final mom = vm.friends.firstWhere((f) => f.name == '엄마');
      vm.block(mom);
      async.flushMicrotasks();
      expect(vm.friends.map((f) => f.name), isNot(contains('엄마')));
      expect(vm.blocked.map((b) => b.name), ['엄마']);
      expect(vm.blockedCountText, '1명');
      expect(h.toast.message, '엄마님을 차단했어요');
      // 녹음 받는 사람 목록에서도 빠진다
      h.vm.load();
      async.flushMicrotasks();
      expect(h.vm.sortedFriends.map((f) => f.name), isNot(contains('엄마')));

      vm.unblock(vm.blocked.first);
      async.flushMicrotasks();
      expect(vm.blocked, isEmpty);
      expect(h.toast.message, '엄마님 차단을 풀었어요');
      final back = vm.friends.firstWhere((f) => f.name == '엄마');
      expect(back.starred, isTrue);
    });
  });

  test('알림 토글', () {
    fakeAsync((async) {
      setup(async);
      expect(vm.notificationsOn, isTrue);
      vm.toggleNotifications();
      async.flushMicrotasks();
      expect(vm.notificationsOn, isFalse);
      expect(h.store.notificationsEnabled, isFalse);
    });
  });

  test('링크 다시 공유하기 → 공유 시트', () {
    fakeAsync((async) {
      setup(async);
      vm.reshare(
        vm.sent.isEmpty
            ? SentTape(
                id: 's-1',
                status: SentStatus.linkPending,
                to: '유진',
                date: DateTime(2026, 9, 22),
                type: TapeType.s15,
                link: true,
              )
            : vm.sent.first,
      );
      async.flushMicrotasks();
      expect(h.deliveries.reshares, 1);
      expect(
        h.share.shared.last,
        contains('https://tapeletter.lab241.com/t/again'),
      );
    });
  });

  test('약관·개인정보·문의 링크', () {
    fakeAsync((async) {
      setup(async);
      vm.openDoc(AppDoc.terms);
      vm.openDoc(AppDoc.privacy);
      vm.openDoc(AppDoc.contact);
      async.flushMicrotasks();
      expect(h.links.opened.map((u) => u.toString()), [
        'https://tapeletter.lab241.com/terms',
        'https://tapeletter.lab241.com/privacy',
        'mailto:kebi3477@naver.com',
      ]);
    });
  });

  test('로그아웃 / 회원 탈퇴', () {
    fakeAsync((async) {
      setup(async);
      vm.logout();
      async.flushMicrotasks();
      expect(h.auth.status, AuthStatus.signedOut);

      h.store.credits = 3;
      late bool done;
      vm.withdraw().then((v) => done = v);
      async.flushMicrotasks();
      expect(done, isTrue);
      expect(h.toast.message, '탈퇴했어요. 그동안 고마웠어요');
      expect(h.store.credits, 120, reason: '메모리 서버는 초기 상태로 돌아간다');
    });
  });

  test('크레딧 내역: 커서 페이지, +/− 표기', () {
    fakeAsync((async) {
      final hh = RecordHarness();
      for (var i = 0; i < 40; i++) {
        hh.api.grantAdReward(); // 하루 3번만 들어간다
      }
      final history = CreditHistoryViewModel(
        walletRepository: WalletRepositoryRemote(hh.api),
      )..load();
      async.flushMicrotasks();
      expect(history.credits, 150);
      expect(history.entries, hasLength(8));
      expect(history.hasMore, isFalse);
      expect(CreditHistoryViewModel.amountText(history.entries.first), '+10');
      final purchase = history.entries.firstWhere((e) => e.amount < 0);
      expect(CreditHistoryViewModel.amountText(purchase), '−30');
      expect(CreditHistoryViewModel.dateText(purchase), '09.20');
    });
  });

  test('보낸 테이프 커서 페이지', () {
    fakeAsync((async) {
      h = RecordHarness();
      h.deliveries.pageSize = 3;
      vm = h.myVm..load();
      async.flushMicrotasks();
      expect(vm.sent, hasLength(3));
      expect(vm.hasMoreSent, isTrue);
      vm.loadMoreSent();
      async.flushMicrotasks();
      expect(vm.sent.map((s) => s.to), ['유진', '엄마', '민수', '박과장님']);
      expect(vm.hasMoreSent, isFalse);
      vm.loadMoreSent();
      async.flushMicrotasks();
      expect(vm.sent, hasLength(4));
    });
  });
}
