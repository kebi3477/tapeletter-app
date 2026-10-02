import 'dart:async';

import 'package:tapeletter_app/ui/core/ui/keep_all.dart';

/// 모든 위젯 시험 공통 설정.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // 화면 문구를 원래 글자로 찾도록 한글 낱말 잇기(keep-all)를 끈다.
  // 큰 글씨 점검(test/ui/large_text)은 켜서 줄바꿈을 확인한다.
  KeepAll.enabled = false;
  await testMain();
}
