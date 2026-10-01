import 'package:tapeletter_app/data/model/friend_dto.dart';
import 'package:tapeletter_app/data/services/local/local_store.dart';
import 'package:tapeletter_app/ui/record/view_model/record_view_model.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../testing/record_harness.dart';

/// 녹음의 받는 사람 목록(`pick`)이 새 친구·별명 변경을 바로 반영한다.
void main() {
  const ms = Duration(milliseconds: 1);

  /// 불러온 뒤 8초 녹음하고 변환까지 기다린다.
  RecordHarness ready(FakeAsync async) {
    final h = RecordHarness();
    h.vm.load();
    async.flushMicrotasks();
    h.vm.startRec();
    async.flushMicrotasks();
    async.elapse(ms * 8000);
    h.vm.stopRec();
    async.flushMicrotasks();
    async.elapse(const Duration(seconds: 2));
    return h;
  }

  List<String> names(RecordHarness h) =>
      h.vm.sortedFriends.map((f) => f.name).toList();

  test('링크로 받아 친구가 되면 바로 녹음 → pick에 새 친구', () {
    fakeAsync((async) {
      final h = ready(async);
      expect(names(h), isNot(contains('유진')));
      h.shareRepo.open('abc');
      async.flushMicrotasks();
      h.shareRepo.claim('abc');
      async.flushMicrotasks();
      expect(names(h), contains('유진'), reason: '받자마자 친구 목록이 갱신된다');
      h.vm.goSend();
      async.flushMicrotasks();
      expect(h.vm.phase, RecordPhase.pick);
      expect(names(h), contains('유진'));
    });
  });

  test('내 링크를 상대가 받음(claimed 푸시): pick에 들어가면 최신 목록', () {
    fakeAsync((async) {
      final h = ready(async);
      // 서버에서 친구가 생겼다 — 앱은 푸시로 알기만 하고 친구 저장소는 알리지 않았다
      h.store.friends = [
        ...h.store.friends,
        FriendDto(
          userId: 'u-new',
          name: '새봄',
          starred: false,
          lastAt: LocalStore.d(9, 25),
        ),
      ];
      h.users.invalidate();
      async.flushMicrotasks();
      h.vm.goSend();
      async.flushMicrotasks();
      expect(h.vm.phase, RecordPhase.pick);
      expect(names(h), contains('새봄'));
    });
  });

  test('별명을 바꾸면 pick 목록에 바로 반영', () {
    fakeAsync((async) {
      final h = ready(async);
      final park = h.vm.sortedFriends.firstWhere((f) => f.name == '박과장님');
      h.friends.setNickname(park.id, '과장님');
      async.flushMicrotasks();
      expect(names(h), contains('과장님'));
      expect(names(h), isNot(contains('박과장님')));
    });
  });

  test('차단·삭제하면 pick 목록에서 빠진다', () {
    fakeAsync((async) {
      final h = ready(async);
      final minsu = h.vm.sortedFriends.firstWhere((f) => f.name == '민수');
      h.friends.remove(minsu.id);
      async.flushMicrotasks();
      expect(names(h), isNot(contains('민수')));
      final eunbi = h.vm.sortedFriends.firstWhere((f) => f.name == '은비');
      h.friends.block(eunbi.id);
      async.flushMicrotasks();
      expect(names(h), isNot(contains('은비')));
    });
  });
}
