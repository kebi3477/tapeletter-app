import '../data/repositories/auth_repository.dart';
import '../data/repositories/friend_repository.dart';
import '../data/repositories/shelf_repository.dart';
import '../data/repositories/user_repository.dart';
import '../data/repositories/wallet_repository.dart';

/// 앱이 백그라운드에서 돌아오면(resumed) 서버에서 바뀌었을 수 있는 값 — 서랍·크레딧·친구·내 정보 —
/// 을 저장소에 알려 다시 불러오게 한다. 마지막 갱신 뒤 [minGap]이 지나지 않았으면 건너뛴다.
class ResumeRefresh {
  ResumeRefresh({
    required this.auth,
    required this.users,
    required this.friends,
    required this.wallet,
    required this.shelf,
    DateTime Function()? clock,
    this.minGap = const Duration(seconds: 30),
  }) : _clock = clock ?? DateTime.now {
    _last = _clock();
  }

  final AuthRepository auth;
  final UserRepository users;
  final FriendRepository friends;
  final WalletRepository wallet;
  final ShelfRepository shelf;
  final Duration minGap;
  final DateTime Function() _clock;
  late DateTime _last;

  /// 다시 불러오게 했으면 true
  bool onResumed() {
    if (auth.status != AuthStatus.signedIn) return false;
    final now = _clock();
    if (now.difference(_last) < minGap) return false;
    _last = now;
    users.invalidate();
    friends.invalidate();
    wallet.invalidate();
    shelf.invalidate();
    return true;
  }
}
