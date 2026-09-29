import 'package:tapeletter_app/data/repositories/friend_repository_remote.dart';
import 'package:tapeletter_app/data/services/local/local_api_client.dart';
import 'package:tapeletter_app/data/services/local/local_behavior.dart';
import 'package:tapeletter_app/data/services/local/local_store.dart';
import 'package:tapeletter_app/ui/friend/view_model/friend_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../testing/dates.dart';

void main() {
  late FriendRepositoryRemote repo;

  setUp(() {
    repo = FriendRepositoryRemote(
      LocalApiClient(LocalStore(), LocalBehavior.instant),
    );
  });

  test('엄마: 받은 테이프 3개, 행 부제·길이', () async {
    final vm = FriendViewModel(friendRepository: repo, friendId: 'u-mom');
    await vm.load();
    expect(vm.name, '엄마');
    expect(vm.subtitle, '받은 테이프 3개');
    final t = vm.tapes.first;
    expect(vm.dateOf(t), at(3, 14));
    expect(vm.subOf(t), '3분 · 2026 생일');
    expect(vm.durOf(t), '0:48');
  });

  test('지현: 뜯지 않은 테이프만', () async {
    final vm = FriendViewModel(friendRepository: repo, friendId: 'u-jihyun');
    await vm.load();
    expect(vm.subtitle, '뜯지 않은 테이프 1개');
    expect(vm.empty, isTrue);
  });

  test('민수: 받은 1개', () async {
    final vm = FriendViewModel(friendRepository: repo, friendId: 'u-minsu');
    await vm.load();
    expect(vm.subtitle, '받은 테이프 1개');
  });

  test('없는 친구면 실패', () async {
    final vm = FriendViewModel(friendRepository: repo, friendId: 'u-x');
    await vm.load();
    expect(vm.failed, isTrue);
  });
}
