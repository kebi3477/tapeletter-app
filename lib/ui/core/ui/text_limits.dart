import 'package:flutter/services.dart';

/// 입력칸 글자 수 제한 — 한글·이모지도 한 글자(grapheme)로 센다.
///
/// 한글을 조합하는 중에도 [max]를 넘지 않는다 (`MaxLengthEnforcement.enforced`).
/// 예전의 `truncateAfterCompositionEnds`는 조합이 끝날 때까지 넘친 글자를 보여 줬다.
/// 이미 [max]자면 새 글자(조합 시작 자모 포함)를 받지 않고, 마지막 글자의 받침 조합처럼
/// 글자 수가 늘지 않는 입력은 그대로 받는다. iOS·Android 모두 같은 방식이다.
TextInputFormatter maxCharacters(int max) => LengthLimitingTextInputFormatter(
  max,
  maxLengthEnforcement: MaxLengthEnforcement.enforced,
);
