import 'package:flutter/foundation.dart';

/// 한글 줄바꿈을 띄어쓰기 단위로 (`word-break: keep-all`, v10.4).
///
/// Flutter는 한글 음절 사이 어디서나 줄을 바꾼다. 띄어쓰기가 아닌 곳에 낱말 잇기
/// 문자(U+2060 WORD JOINER, 폭 0·보이지 않음)를 넣어 낱말 가운데에서는 줄이 바뀌지 않게 한다.
/// 한 줄보다 긴 낱말은 그래도 글자 단위로 넘어간다(`overflow-wrap: anywhere`).
String keepAll(String text) {
  if (!KeepAll.enabled || text.isEmpty) return text;
  final out = StringBuffer();
  int? prev;
  for (final r in text.runes) {
    if (prev != null &&
        !_space(prev) &&
        !_space(r) &&
        (_hangul(prev) || _hangul(r))) {
      out.writeCharCode(_joiner);
    }
    out.writeCharCode(r);
    prev = r;
  }
  return out.toString();
}

/// 이미 [keepAll]을 거친 글에서 잇기 문자를 뺀다 (글자 수 세기·비교용)
String stripKeepAll(String text) =>
    text.replaceAll(String.fromCharCode(_joiner), '');

abstract final class KeepAll {
  /// 위젯 시험은 `find.text('원래 문구')`로 찾으므로 test/flutter_test_config.dart가 끈다.
  /// 큰 글씨 점검 시험만 켠다.
  @visibleForTesting
  static bool enabled = true;
}

const _joiner = 0x2060;

bool _hangul(int c) =>
    (c >= 0xAC00 && c <= 0xD7A3) || (c >= 0x3131 && c <= 0x318E);

bool _space(int c) => c == 0x20 || c == 0x0A || c == 0x09 || c == 0x3000;
