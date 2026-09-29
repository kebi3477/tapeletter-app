import 'package:tapeletter_app/data/repositories/shelf_repository_remote.dart';
import 'package:tapeletter_app/data/services/local/local_api_client.dart';
import 'package:tapeletter_app/data/services/local/local_behavior.dart';
import 'package:tapeletter_app/data/services/local/local_store.dart';
import 'package:tapeletter_app/ui/core/ui/toast.dart';
import 'package:tapeletter_app/ui/shelf/view_model/shelf_view_model.dart';
import 'package:tapeletter_app/data/services/app_prefs.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../testing/dates.dart';

void main() {
  late LocalStore store;
  late ToastController toast;
  late ShelfViewModel vm;

  ShelfViewModel make(FakeAsync async, {AppPrefs? prefs}) {
    store = LocalStore(clock: () => DateTime.utc(2026, 9, 25, 3));
    toast = ToastController();
    final v = ShelfViewModel(
      shelfRepository: ShelfRepositoryRemote(
        LocalApiClient(store, LocalBehavior.instant),
      ),
      toast: toast,
      prefs: prefs,
    )..load();
    async.flushMicrotasks();
    return v;
  }

  List<String> names(String? groupId) =>
      vm.shelf.itemsOf(groupId).map((x) => x.from).toList();

  List<String> serverNames(int gi) =>
      store.groups[gi].items.map((x) => x.sender.name).toList();

  String idOf(String groupId, String from) =>
      vm.shelf.itemsOf(groupId).firstWhere((x) => x.from == from).id;

  test('불러오기: 보관량 10/12, 거의 참, 칸 3개', () {
    fakeAsync((async) {
      vm = make(async);
      expect(vm.capText, '10/12');
      expect(vm.capFull, isFalse);
      expect(vm.capNear, isTrue);
      expect(vm.fullOn, isFalse);
      expect(vm.emptyOn, isFalse);
      expect(names(null), ['지현', '하늘']);
      expect(vm.itemSub(vm.shelf.unsorted.first), '${at(9, 24)} · 1분 · 소포 도착');
      expect(
        vm.itemSub(vm.shelf.groups.first.items.first),
        '${at(3, 14)} · 3분',
      );
    });
  });

  test('꽉 참 배너와 빈 서랍', () {
    fakeAsync((async) {
      vm = make(async);
      store.cap = 10;
      vm.load();
      async.flushMicrotasks();
      expect(vm.fullOn, isTrue);
      expect(vm.capFull, isTrue);
      expect(vm.capNear, isFalse);

      store.unsorted = [];
      store.groups = [];
      vm.load();
      async.flushMicrotasks();
      expect(vm.emptyOn, isTrue);
      expect(vm.fullOn, isFalse);
    });
  });

  group('드래그 이동 인덱스', () {
    test('같은 칸 아래로: 빠진 자리만큼 한 칸 당긴다', () {
      fakeAsync((async) {
        vm = make(async);
        // [엄마, 민수, 수아, 할머니] — 엄마를 할머니 앞(3)에 놓는다
        vm.startDrag(idOf('g-1', '엄마'));
        vm.dragOver(const DropTarget('g-1', 3));
        vm.endDrag();
        async.flushMicrotasks();
        expect(names('g-1'), ['민수', '수아', '엄마', '할머니']);
        expect(serverNames(0), ['민수', '수아', '엄마', '할머니']);
        expect(toast.message, isNull, reason: '같은 칸 안에서는 토스트가 없다');
      });
    });

    test('같은 칸 위로', () {
      fakeAsync((async) {
        vm = make(async);
        vm.moveByDrop(idOf('g-1', '할머니'), const DropTarget('g-1', 1));
        async.flushMicrotasks();
        expect(names('g-1'), ['엄마', '할머니', '민수', '수아']);
        expect(serverNames(0), ['엄마', '할머니', '민수', '수아']);
      });
    });

    test('같은 칸 맨 끝(마지막 행 아래쪽 절반)', () {
      fakeAsync((async) {
        vm = make(async);
        vm.moveByDrop(idOf('g-1', '엄마'), const DropTarget('g-1', 4));
        async.flushMicrotasks();
        expect(names('g-1'), ['민수', '수아', '할머니', '엄마']);
        expect(serverNames(0), ['민수', '수아', '할머니', '엄마']);
      });
    });

    test('다른 칸으로: 토스트와 반짝임 1.2초', () {
      fakeAsync((async) {
        vm = make(async);
        final id = idOf('g-1', '수아');
        vm.moveByDrop(id, const DropTarget('g-2', 1));
        async.flushMicrotasks();
        expect(names('g-2'), ['박과장님', '수아', '은비']);
        expect(names('g-1'), ['엄마', '민수', '할머니']);
        expect(serverNames(1), ['박과장님', '수아', '은비']);
        expect(toast.message, '‘승진 축하’ 칸으로 옮겼어요');
        expect(vm.landedId, id);
        async.elapse(const Duration(milliseconds: 1200));
        expect(vm.landedId, isNull);
      });
    });

    test('분류 안 함 맨 앞으로 (칸 제목 위 드롭)', () {
      fakeAsync((async) {
        vm = make(async);
        vm.moveByDrop(idOf('g-3', '엄마'), const DropTarget(null, 0));
        async.flushMicrotasks();
        expect(names(null), ['엄마', '지현', '하늘']);
        expect(vm.shelf.unsorted.first.opened, isTrue);
        expect(toast.message, '분류 안 함으로 옮겼어요');
      });
    });

    test('안 뜯은 소포: 분류 안 함 안에서는 순서를 바꾸고, 칸에는 못 넣는다', () {
      fakeAsync((async) {
        vm = make(async);
        final jihyun = vm.shelf.unsorted.first.id;
        vm.moveByDrop(jihyun, const DropTarget(null, 2));
        async.flushMicrotasks();
        expect(names(null), ['하늘', '지현']);
        expect(vm.shelf.unsorted.last.opened, isFalse);
        expect(store.unsorted.map((x) => x.sender.name), ['하늘', '지현']);

        vm.moveByDrop(jihyun, const DropTarget('g-1', 0));
        async.flushMicrotasks();
        expect(names(null), ['하늘', '지현']);
        expect(names('g-1'), hasLength(4));
        expect(toast.message, '소포를 먼저 뜯어 주세요');
      });
    });

    test('드롭 위치 없이 놓으면 그대로', () {
      fakeAsync((async) {
        vm = make(async);
        vm.startDrag(idOf('g-1', '엄마'));
        expect(vm.draggingId, isNotNull);
        vm.endDrag();
        async.flushMicrotasks();
        expect(vm.dragging, isFalse);
        expect(names('g-1'), ['엄마', '민수', '수아', '할머니']);
      });
    });

    test('서버가 거절하면 되돌리고 오류 문구를 토스트로', () {
      fakeAsync((async) {
        vm = make(async);
        // 서버에서만 칸이 사라진 상황
        store.groups = store.groups.where((g) => g.id != 'g-2').toList();
        vm.moveTo(idOf('g-1', '민수'), 'g-2');
        async.flushMicrotasks();
        expect(names('g-1'), ['엄마', '민수', '수아', '할머니']);
        expect(toast.message, '칸을 찾을 수 없어요');
      });
    });
  });

  test('옮기기 시트: 그 칸 맨 뒤로', () {
    fakeAsync((async) {
      vm = make(async);
      vm.moveTo(idOf('g-1', '엄마'), 'g-3');
      async.flushMicrotasks();
      expect(names('g-3'), ['엄마', '엄마', '엄마']);
      expect(vm.shelf.group('g-3')!.items.last.date.month, 3);
      expect(toast.message, '‘엄마 목소리’ 칸으로 옮겼어요');
    });
  });

  test('칸 추가(비우면 "새 칸")·이름 바꾸기·지우기', () {
    fakeAsync((async) {
      vm = make(async);
      vm.addGroup('  ');
      async.flushMicrotasks();
      expect(vm.shelf.groups.last.name, '새 칸');
      expect(toast.message, '‘새 칸’ 칸을 만들었어요');

      vm.renameGroup('g-1', '생일');
      async.flushMicrotasks();
      expect(vm.shelf.groups.first.name, '생일');
      expect(store.groups.first.name, '생일');

      vm.deleteGroup('g-2');
      async.flushMicrotasks();
      expect(vm.shelf.groups.map((g) => g.name), ['생일', '엄마 목소리', '새 칸']);
      expect(names(null), ['지현', '하늘', '박과장님', '은비']);
      expect(vm.shelf.unsorted.last.opened, isTrue);
      expect(toast.message, '칸을 지웠어요 · 테이프는 분류 안 함으로');
      expect(vm.capText, '10/12');
    });
  });

  test('테이프 지우기', () {
    fakeAsync((async) {
      vm = make(async);
      vm.deleteItem(idOf('g-2', '은비'));
      async.flushMicrotasks();
      expect(names('g-2'), ['박과장님']);
      expect(vm.capText, '9/12');
      expect(toast.message, '테이프를 지웠어요');
    });
  });

  test('처음 들어올 때만 0.65초 스켈레톤', () {
    fakeAsync((async) {
      vm = make(async);
      vm.enter();
      expect(vm.skeleton, isTrue);
      async.elapse(const Duration(milliseconds: 649));
      expect(vm.skeleton, isTrue);
      async.elapse(const Duration(milliseconds: 1));
      expect(vm.skeleton, isFalse);
      vm.enter();
      expect(vm.skeleton, isFalse);
    });
  });

  test('보기: 기본은 책장형, 바꾸면 기기에 기억', () {
    fakeAsync((async) {
      final prefs = MemoryAppPrefs();
      vm = make(async, prefs: prefs);
      expect(vm.view, ShelfView.shelf);
      vm.setView(ShelfView.list);
      async.flushMicrotasks();
      expect(vm.view, ShelfView.list);
      expect(prefs.shelfViewValue, 'list');

      // 다음 실행: 기억한 보기를 쓴다
      final again = make(async, prefs: prefs);
      expect(again.view, ShelfView.list);
    });
  });
}
