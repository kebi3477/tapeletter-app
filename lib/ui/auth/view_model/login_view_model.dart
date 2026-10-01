import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../core/ui/toast.dart';

enum LoginProvider { kakao, apple, google }

/// 로그인 (`auLogin`) — 카카오·Apple(iOS)·Google(Android), 누르면 "연결 중…" (최소 0.7초).
class LoginViewModel extends ChangeNotifier {
  LoginViewModel({required this._auth, required this._toast});

  /// `later('auth', 700)`
  static const connectingTime = Duration(milliseconds: 700);

  /// 카카오톡·Apple 창에서 앱으로 돌아온 뒤 이만큼 지나도 로그인이 끝나지 않으면
  /// "연결 중…"을 풀고 다시 누를 수 있게 한다 (SDK가 결과를 주지 않는 경우).
  static const resumeGrace = Duration(seconds: 3);

  final AuthRepository _auth;
  final ToastController _toast;
  LoginProvider? _busy;
  int _attempt = 0;
  Timer? _resumeTimer;
  bool _disposed = false;

  /// "연결 중…"인 버튼
  LoginProvider? get busy => _busy;

  Future<void> signIn(LoginProvider p) => _run(p, switch (p) {
    LoginProvider.kakao => _auth.signInKakao,
    LoginProvider.apple => _auth.signInApple,
    LoginProvider.google => _auth.signInGoogle,
  });

  /// 개발 로그인 (숨은 진입점)
  Future<void> signInDev() => _run(
    LoginProvider.kakao,
    () => _auth.signInDev(key: 'minkyung', name: '민경'),
  );

  Future<void> _run(
    LoginProvider p,
    Future<SignInResult> Function() call,
  ) async {
    if (_busy != null) return;
    final attempt = ++_attempt;
    _resumeTimer?.cancel();
    _busy = p;
    notifyListeners();
    final results = await Future.wait<Object?>([
      call(),
      Future<void>.delayed(connectingTime),
    ]);
    // 이미 풀어 준 시도의 늦은 결과: 성공이면 관문이 알아서 넘기고, 실패는 조용히 버린다.
    if (attempt != _attempt) return;
    _resumeTimer?.cancel();
    final r = results.first! as SignInResult;
    if (r is SignInFailed) _toast.show(r.message);
    // 로그인에 성공하면 관문이 다음 화면으로 넘기면서 이 ViewModel을 버린다.
    if (_disposed) return;
    _busy = null;
    notifyListeners();
  }

  /// 앱이 다시 앞으로 왔다 (카카오톡·Apple 창에서 돌아옴).
  void onResumed() {
    if (_busy == null || _disposed) return;
    final attempt = _attempt;
    _resumeTimer?.cancel();
    _resumeTimer = Timer(resumeGrace, () {
      if (attempt != _attempt || _busy == null || _disposed) return;
      // 조용히 로그인 화면으로 되돌린다.
      _attempt++;
      _busy = null;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _resumeTimer?.cancel();
    super.dispose();
  }
}
