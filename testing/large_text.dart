import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 큰 글씨(v10.4) 점검 — 지금 화면의 글자들을 훑어 문제를 모은다.
///
/// - 넘침: RenderFlex overflow 등 레이아웃 오류 ([LayoutErrors])
/// - 잘림: 글자 높이가 자리보다 커서 아래가 잘린 글 (고정 높이 행·버튼)
/// - 한글 줄바꿈: 띄어쓰기가 아닌 곳(낱말 가운데)에서 줄이 바뀐 글 (`word-break: keep-all`)
List<String> textIssues(WidgetTester tester) {
  final issues = <String>[];
  for (final e in find.byType(RichText).evaluate()) {
    final ro = e.renderObject;
    if (ro is! RenderParagraph || !ro.hasSize || !ro.attached) continue;
    if (!_visible(ro)) continue;
    final text = ro.text.toPlainText(includeSemanticsLabels: false);
    if (text.trim().isEmpty) continue;
    final natural = ro.getMaxIntrinsicHeight(ro.size.width);
    if (natural > ro.size.height + 1) {
      issues.add(
        '잘림 "${_short(text)}" (${ro.size.height.toStringAsFixed(1)} < ${natural.toStringAsFixed(1)})',
      );
    }
    final mid = _midWordBreak(ro, text);
    if (mid != null) {
      issues.add(
        '낱말 가운데 줄바꿈 "${_short(text.replaceAll('\u2060', ''))}" @ "$mid"',
      );
    }
  }
  return issues;
}

bool _visible(RenderObject ro) {
  // 화면 밖(Offstage, 다른 탭)은 건너뛴다
  RenderObject? p = ro;
  while (p != null) {
    if (p is RenderOffstage && p.offstage) return false;
    if (p is RenderOpacity && p.opacity == 0) return false;
    if (p is RenderAnimatedOpacity && p.opacity.value == 0) return false;
    p = p.parent;
  }
  return true;
}

bool _hangul(int c) => c >= 0xAC00 && c <= 0xD7A3;

/// 두 한글 음절 사이에서 줄이 바뀌었으면 그 자리
String? _midWordBreak(RenderParagraph ro, String text) {
  if (ro.size.height < 1) return null;
  final units = text.codeUnits;
  double? prevY;
  for (var i = 0; i < units.length; i++) {
    final y = ro.getOffsetForCaret(TextPosition(offset: i), Rect.zero).dy;
    if (prevY != null && y > prevY + 1 && i > 0) {
      // 낱말 잇기 문자(U+2060)는 건너뛰고 앞뒤 글자를 본다
      var a = i - 1;
      while (a > 0 && units[a] == 0x2060) {
        a--;
      }
      var b = i;
      while (b < units.length - 1 && units[b] == 0x2060) {
        b++;
      }
      if (_hangul(units[a]) && _hangul(units[b])) {
        final before = text.substring(0, b).replaceAll('\u2060', '');
        final after = text.substring(b).replaceAll('\u2060', '');
        final from = (before.length - 3).clamp(0, before.length);
        return '${before.substring(from)}|${after.substring(0, after.length.clamp(0, 3))}';
      }
    }
    prevY = y;
  }
  return null;
}

String _short(String s) {
  final one = s.replaceAll('\n', '⏎');
  return one.length > 30 ? '${one.substring(0, 30)}…' : one;
}

/// 테스트 동안 레이아웃 오류(넘침 등)를 모은다. [stop]을 부르면 원래대로.
class LayoutErrors {
  LayoutErrors() {
    _prev = FlutterError.onError;
    FlutterError.onError = (d) {
      final s = d.exceptionAsString();
      // 원인 위젯 위치 ("The relevant error-causing widget was: Column file:line")
      final where = RegExp(r'lib/[\w/]+\.dart:\d+')
          .firstMatch(d.toString())
          ?.group(0);
      errors.add('${s.split('\n').first}${where == null ? '' : ' ($where)'}');
    };
  }

  late final FlutterExceptionHandler? _prev;
  final List<String> errors = [];

  void stop() => FlutterError.onError = _prev;
}

/// 낱말 잇기 문자를 빼고 [text]와 같은 글자를 찾는다 (큰 글씨 점검은 keep-all을 켠다)
Finder findPlainText(String text) => find.byWidgetPredicate(
  (w) => w is Text && (w.data ?? '').replaceAll('\u2060', '') == text,
);
