import 'package:tapeletter_app/domain/models/tape_type.dart';
import 'package:tapeletter_app/ui/record/view_model/record_view_model.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../testing/fakes/repositories/fake_delivery_repository.dart';
import '../../../../testing/fakes/repositories/fake_recording_repository.dart';
import '../../../../testing/fakes/services/fake_recorder_service.dart';
import '../../../../testing/record_harness.dart';

void main() {
  const ms = Duration(milliseconds: 1);

  /// 녹음을 [seconds]초 하고 멈춘다.
  void record(FakeAsync async, RecordHarness h, double seconds) {
    h.vm.startRec();
    async.flushMicrotasks();
    async.elapse(ms * (seconds * 1000).round());
    h.vm.stopRec();
    async.flushMicrotasks();
  }

  group('불러오기', () {
    test('프로토타입 초기 데이터: 보유 {3:2, 5:0}, 친구 6명 즐겨찾기 먼저', () {
      fakeAsync((async) {
        final h = RecordHarness();
        h.vm.load();
        async.flushMicrotasks();
        expect(h.vm.wallet.credits, 120);
        expect(h.vm.wallet.ownedOf(TapeType.m1), 2);
        expect(h.vm.wallet.ownedOf(TapeType.m3), 0);
        // 계약서 정렬: 즐겨찾기 → lastAt 최근 순
        expect(h.vm.sortedFriends.map((f) => f.name), [
          '지현',
          '엄마',
          '하늘',
          '민수',
          '은비',
          '박과장님',
        ]);
        expect(h.vm.myName, '민경');
        expect(h.vm.mic, MicPermission.granted);
      });
    });
  });

  group('캐러셀', () {
    test('0개인 3분 테이프는 잠기고 녹음이 시작되지 않는다', () {
      fakeAsync((async) {
        final h = RecordHarness();
        h.vm.load();
        async.flushMicrotasks();
        expect(h.vm.isLocked(TapeType.s15), isFalse);
        expect(h.vm.isLocked(TapeType.m1), isFalse);
        expect(h.vm.isLocked(TapeType.m3), isTrue);

        h.vm.selectTape(TapeType.m3);
        expect(h.vm.curLocked, isTrue);
        h.vm.startRec();
        async.flushMicrotasks();
        expect(h.vm.phase, RecordPhase.idle);
        expect(h.recorder.calls, isNot(contains('start')));
      });
    });

    test('녹음 중에는 테이프를 바꿀 수 없다', () {
      fakeAsync((async) {
        final h = RecordHarness();
        h.vm.load();
        async.flushMicrotasks();
        h.vm.startRec();
        async.flushMicrotasks();
        h.vm.selectTape(TapeType.m1);
        expect(h.vm.tape, TapeType.s15);
      });
    });
  });

  group('녹음', () {
    test('250ms마다 0.25초씩 늘고 릴이 감긴다', () {
      fakeAsync((async) {
        final h = RecordHarness();
        h.vm.load();
        async.flushMicrotasks();
        h.vm.startRec();
        async.flushMicrotasks();
        expect(h.vm.phase, RecordPhase.rec);
        expect(h.vm.hidesTabs, isFalse);
        async.elapse(const Duration(seconds: 3));
        expect(h.vm.sec, 3);
        expect(h.vm.progress, closeTo(.2, 1e-9));
      });
    });

    test('15초에 닿으면 자동으로 멈추고 확인 화면으로 간다', () {
      fakeAsync((async) {
        final h = RecordHarness();
        h.vm.load();
        async.flushMicrotasks();
        h.vm.startRec();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 15));
        expect(h.vm.phase, RecordPhase.confirm);
        expect(h.vm.sec, 15);
        expect(h.recorder.calls, contains('stop'));
        expect(h.vm.hidesTabs, isTrue);
      });
    });

    test('앱이 가려지면 멈추고, 이어서 녹음하면 시간이 이어진다', () {
      fakeAsync((async) {
        final h = RecordHarness();
        h.vm.load();
        async.flushMicrotasks();
        h.vm.startRec();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 5));
        h.vm.onAppHidden();
        expect(h.vm.phase, RecordPhase.paused);
        expect(h.vm.pauseWhy, '앱이 잠시 닫혀서 녹음이 멈췄어요');
        async.elapse(const Duration(seconds: 3));
        expect(h.vm.sec, 5);

        h.vm.resumeRec();
        async.flushMicrotasks();
        expect(h.recorder.calls, contains('resume'));
        async.elapse(const Duration(seconds: 2));
        expect(h.vm.sec, 7);
      });
    });

    test('전화로 멈추면 이유가 다르고, 여기까지 쓰기로 확인 화면에 간다', () {
      fakeAsync((async) {
        final h = RecordHarness();
        h.vm.load();
        async.flushMicrotasks();
        h.vm.startRec();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 4));
        h.recorder.interrupt();
        async.flushMicrotasks();
        expect(h.vm.phase, RecordPhase.paused);
        expect(h.vm.pauseWhy, '전화가 와서 녹음이 멈췄어요');
        h.vm.useSoFar();
        async.flushMicrotasks();
        expect(h.vm.phase, RecordPhase.confirm);
        expect(h.vm.recorded, 4);
      });
    });

    test('마이크를 거부하면 거부 상태, 설정에서 켜고 돌아오면 토스트', () {
      fakeAsync((async) {
        final h = RecordHarness(
          recorder: FakeRecorderService(granted: false, grantOnRequest: false),
        );
        h.vm.load();
        async.flushMicrotasks();
        expect(h.vm.mic, MicPermission.unknown);
        h.vm.startRec();
        async.flushMicrotasks();
        expect(h.vm.mic, MicPermission.denied);
        expect(h.vm.phase, RecordPhase.idle);

        h.vm.openSettings();
        async.flushMicrotasks();
        expect(h.settings.opened, 1);
        h.recorder.granted = true;
        h.vm.onAppResumed();
        async.flushMicrotasks();
        expect(h.vm.mic, MicPermission.granted);
        expect(h.toast.message, '설정에서 마이크를 켜고 돌아왔어요');
      });
    });
  });

  group('변환', () {
    test('최소 1.5초 노이즈 뒤 자동으로 미리 듣기', () {
      fakeAsync((async) {
        final h = RecordHarness();
        h.vm.load();
        async.flushMicrotasks();
        record(async, h, 8);
        expect(h.vm.converting, isTrue);
        async.elapse(const Duration(milliseconds: 1400));
        expect(h.vm.converting, isTrue);
        expect(h.vm.convSlow, isFalse);
        async.elapse(const Duration(milliseconds: 100));
        expect(h.vm.converting, isFalse);
        expect(h.vm.playing, isTrue);
        expect(h.player.loaded, isNotNull);
        // 실제 파일 길이(가짜 플레이어 12초)를 쓴다.
        expect(h.vm.recorded, 12);
      });
    });

    test('1.4초를 넘기면 convSlow, 끝나면 풀린다', () {
      fakeAsync((async) {
        final h = RecordHarness(
          recordings: FakeRecordingRepository(
            convertDelay: const Duration(seconds: 4),
          ),
        );
        h.vm.load();
        async.flushMicrotasks();
        record(async, h, 8);
        async.elapse(const Duration(milliseconds: 1400));
        expect(h.vm.convSlow, isTrue);
        async.elapse(const Duration(seconds: 3));
        expect(h.vm.convSlow, isFalse);
        expect(h.vm.converting, isFalse);
        expect(h.vm.playing, isTrue);
      });
    });

    test('실패하면 convFail, 다시 시도는 업로드를 반복하지 않는다', () {
      fakeAsync((async) {
        final repo = FakeRecordingRepository(failConvert: true);
        final h = RecordHarness(recordings: repo);
        h.vm.load();
        async.flushMicrotasks();
        record(async, h, 8);
        async.elapse(const Duration(seconds: 2));
        expect(h.vm.convFail, isTrue);
        expect(h.vm.converting, isFalse);
        h.vm.goSend();
        expect(h.vm.phase, RecordPhase.confirm);

        repo.failConvert = false;
        h.vm.retryConvert();
        async.elapse(const Duration(seconds: 2));
        expect(h.vm.convFail, isFalse);
        expect(h.vm.playing, isTrue);
        expect(repo.uploads, 1);
        expect(repo.converts, 1);
        // 실패했던 녹음은 POST /recordings/{id}/retry
        expect(repo.retries, 1);
      });
    });

    test('‹ 뒤로 가면 변환을 버리고 테이프도 쓰지 않는다', () {
      fakeAsync((async) {
        final h = RecordHarness();
        h.vm.load();
        async.flushMicrotasks();
        h.vm.selectTape(TapeType.m1);
        record(async, h, 8);
        h.vm.backIdle();
        async.elapse(const Duration(seconds: 3));
        expect(h.vm.phase, RecordPhase.idle);
        expect(h.vm.playing, isFalse);
        expect(h.vm.sec, 0);
        expect(h.vm.wallet.ownedOf(TapeType.m1), 2);
      });
    });
  });

  group('받는 사람과 라벨', () {
    test('받는 사람이 없으면 pick, 친구를 고르면 110ms에 한 글자씩 타이핑', () {
      fakeAsync((async) {
        final h = RecordHarness();
        h.vm.load();
        async.flushMicrotasks();
        record(async, h, 8);
        async.elapse(const Duration(seconds: 2));
        expect(h.vm.sendCta, '누구에게 보낼까요?');
        h.vm.goSend();
        expect(h.vm.phase, RecordPhase.pick);
        expect(h.vm.playing, isFalse);

        final park = h.vm.sortedFriends.firstWhere((f) => f.name == '박과장님');
        h.vm.pickFriend(park);
        expect(h.vm.phase, RecordPhase.label);
        expect(h.vm.typedName, '');
        async.elapse(const Duration(milliseconds: 110));
        expect(h.vm.typedName, '박');
        async.elapse(const Duration(milliseconds: 330));
        expect(h.vm.typedName, '박과장님');

        h.vm.backPick();
        expect(h.vm.phase, RecordPhase.pick);
        h.vm.backConfirm();
        expect(h.vm.phase, RecordPhase.confirm);
        expect(h.vm.sendCta, '박과장님에게 보내기');
        h.vm.goSend();
        expect(h.vm.phase, RecordPhase.label);
      });
    });

    test('별은 바로 토글되고 정렬이 바뀐다', () {
      fakeAsync((async) {
        final h = RecordHarness();
        h.vm.load();
        async.flushMicrotasks();
        final minsu = h.vm.sortedFriends.firstWhere((f) => f.name == '민수');
        h.vm.toggleStar(minsu);
        async.flushMicrotasks();
        expect(h.vm.sortedFriends.take(3).map((f) => f.name), [
          '지현',
          '엄마',
          '민수',
        ]);
        expect(h.vm.sortedFriends[2].starred, isTrue);
      });
    });

    test('새 친구: 이름은 선택(비우면 "새 친구", linkName 없음), 8자까지', () {
      fakeAsync((async) {
        final h = RecordHarness();
        h.vm.load();
        async.flushMicrotasks();
        record(async, h, 8);
        async.elapse(const Duration(seconds: 2));
        h.vm.goSend();
        h.vm.pickNew();
        expect(h.vm.to!.isNew, isTrue);
        expect(h.vm.canSend, isTrue);
        expect(h.vm.typedName, '새 친구');

        h.vm.setNewName('가나다라마바사아자차');
        expect(h.vm.newName, '가나다라마바사아');
        expect(h.vm.typedName, '가나다라마바사아');
        h.vm.setNewName('  ');
        h.vm.setNewName('');
        expect(h.vm.typedName, '새 친구');

        h.vm.sendNow();
        expect(h.vm.phase, RecordPhase.sending);
        async.elapse(const Duration(seconds: 3));
        final to = h.deliveries.recipients.single;
        expect(to.isNew, isTrue);
        expect(to.linkName, isNull, reason: '비우면 linkName을 보내지 않는다');
        expect(to.name, '새 친구');
        async.elapse(const Duration(seconds: 3));
      });
    });
  });

  group('보내기', () {
    test('포장 2.7초 뒤 완료, 1분 테이프 1개 차감', () {
      fakeAsync((async) {
        final h = RecordHarness();
        h.vm.load();
        async.flushMicrotasks();
        h.vm.selectTape(TapeType.m1);
        h.deliveries.type = TapeType.m1;
        record(async, h, 8);
        async.elapse(const Duration(seconds: 2));
        h.vm.goSend();
        h.vm.pickFriend(h.vm.sortedFriends.firstWhere((f) => f.name == '하늘'));
        async.elapse(const Duration(seconds: 1));
        h.vm.sendNow();
        expect(h.vm.phase, RecordPhase.sending);
        async.elapse(const Duration(milliseconds: 2600));
        expect(h.vm.phase, RecordPhase.sending);
        expect(h.vm.sendState, SendState.success);
        async.elapse(const Duration(milliseconds: 100));
        expect(h.vm.phase, RecordPhase.sent);
        expect(h.vm.sentTitle, '하늘님에게 보냈어요');
        expect(h.vm.sentSub, '테이프는 이제 받는 사람만 들을 수 있어요');
        expect(h.vm.wallet.ownedOf(TapeType.m1), 1);

        h.vm.finish();
        expect(h.vm.phase, RecordPhase.idle);
        expect(h.vm.to, isNull);
        expect(h.vm.tape, TapeType.m1);
      });
    });

    test('마지막 1분 테이프를 보내면 완료 후 15초로 돌아간다', () {
      fakeAsync((async) {
        final h = RecordHarness();
        h.store.owned = {60: 1, 180: 0};
        h.deliveries.type = TapeType.m1;
        h.vm.load();
        async.flushMicrotasks();
        h.vm.selectTape(TapeType.m1);
        record(async, h, 8);
        async.elapse(const Duration(seconds: 2));
        h.vm.goSend();
        h.vm.pickFriend(h.vm.sortedFriends.first);
        h.vm.sendNow();
        async.elapse(const Duration(seconds: 3));
        expect(h.vm.phase, RecordPhase.sent);
        expect(h.vm.wallet.ownedOf(TapeType.m1), 0);
        h.vm.finish();
        expect(h.vm.tape, TapeType.s15);
      });
    });

    test('응답이 늦으면 박스가 72%에서 기다렸다가 0.828초 뒤 완료', () {
      fakeAsync((async) {
        final h = RecordHarness(
          deliveries: FakeDeliveryRepository(delay: const Duration(seconds: 3)),
        );
        h.vm.load();
        async.flushMicrotasks();
        record(async, h, 8);
        async.elapse(const Duration(seconds: 2));
        h.vm.goSend();
        h.vm.pickFriend(h.vm.sortedFriends.first);
        h.vm.sendNow();
        async.elapse(const Duration(milliseconds: 2900));
        expect(h.vm.phase, RecordPhase.sending);
        expect(h.vm.sendState, SendState.pending);
        async.elapse(const Duration(milliseconds: 100));
        expect(h.vm.sendState, SendState.success);
        async.elapse(const Duration(milliseconds: 827));
        expect(h.vm.phase, RecordPhase.sending);
        async.elapse(const Duration(milliseconds: 1));
        expect(h.vm.phase, RecordPhase.sent);
      });
    });

    test('실패는 1.7초에 보이고, 다시 보내기는 같은 Idempotency-Key를 쓴다', () {
      fakeAsync((async) {
        final delivery = FakeDeliveryRepository(
          delay: const Duration(milliseconds: 300),
          fail: true,
        );
        final h = RecordHarness(deliveries: delivery);
        h.vm.load();
        async.flushMicrotasks();
        record(async, h, 8);
        async.elapse(const Duration(seconds: 2));
        h.vm.goSend();
        h.vm.pickFriend(h.vm.sortedFriends.first);
        h.vm.sendNow();
        async.elapse(const Duration(milliseconds: 1699));
        expect(h.vm.sendFail, isFalse);
        async.elapse(const Duration(milliseconds: 1));
        expect(h.vm.sendFail, isTrue);
        expect(h.vm.phase, RecordPhase.sending);

        delivery.fail = false;
        h.vm.retrySend();
        expect(h.vm.sendFail, isFalse);
        expect(h.vm.sendAttempt, 1);
        async.elapse(const Duration(milliseconds: 2700));
        expect(h.vm.phase, RecordPhase.sent);
        expect(delivery.keys.toSet(), hasLength(1));
      });
    });

    test('돌아가기는 확인 화면으로', () {
      fakeAsync((async) {
        final h = RecordHarness(deliveries: FakeDeliveryRepository(fail: true));
        h.vm.load();
        async.flushMicrotasks();
        record(async, h, 8);
        async.elapse(const Duration(seconds: 2));
        h.vm.goSend();
        h.vm.pickFriend(h.vm.sortedFriends.first);
        h.vm.sendNow();
        async.elapse(const Duration(seconds: 2));
        h.vm.cancelSend();
        expect(h.vm.phase, RecordPhase.confirm);
        expect(h.vm.sendFail, isFalse);
        async.elapse(const Duration(seconds: 3));
        expect(h.vm.phase, RecordPhase.confirm);
      });
    });

    test('새 친구에게 보내면 링크 공유 후 토스트와 함께 대기로', () {
      fakeAsync((async) {
        final h = RecordHarness();
        h.vm.load();
        async.flushMicrotasks();
        record(async, h, 8);
        async.elapse(const Duration(seconds: 2));
        h.vm.goSend();
        h.vm.pickNew();
        h.vm.setNewName(' 유진 ');
        h.vm.sendNow();
        expect(h.vm.to!.name, '유진');
        async.elapse(const Duration(seconds: 3));
        expect(h.vm.phase, RecordPhase.sent);
        expect(h.vm.sentTitle, '테이프를 포장했어요');
        expect(h.vm.lastSent!.shareUrl, isNotNull);

        // 카카오톡을 열지 못하면 그대로 완료 화면
        h.share.result = false;
        h.vm.shareLink(ShareChannel.kakao);
        async.flushMicrotasks();
        expect(h.vm.phase, RecordPhase.sent);
        final k = h.share.kakao.single;
        expect(k.senderName, '민경');
        expect(k.title, '민경님이 목소리 테이프를 보냈어요');
        expect(
          k.url.toString(),
          startsWith('https://tapeletter.lab241.com/t/'),
        );
        expect(h.share.sms, isEmpty);
        expect(h.share.shared, isEmpty, reason: '공유 시트가 아니라 카카오톡');

        h.share.result = true;
        h.vm.shareLink(ShareChannel.sms);
        async.flushMicrotasks();
        expect(h.toast.message, '문자로 링크를 보냈어요');
        expect(h.vm.phase, RecordPhase.idle);
        final m = h.share.sms.single;
        expect(
          m.text,
          matches(
            r'^민경님이 목소리 테이프를 보냈어요 https://tapeletter\.lab241\.com/t/\S+$',
          ),
        );
      });
    });
  });
}
