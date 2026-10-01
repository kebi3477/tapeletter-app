import 'package:tapeletter_app/ui/core/ui/text_limits.dart';
import 'package:tapeletter_app/ui/shelf/widgets/shelf_list_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../testing/app.dart';
import '../../../../testing/fonts.dart';
import '../../../../testing/record_harness.dart';

/// 한글 조합 중에도 글자 수 제한을 넘지 않는다.
void main() {
  setUpAll(loadAppFonts);

  TextEditingValue v(String text, {TextRange composing = TextRange.empty}) =>
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
        composing: composing,
      );

  /// [text] 맨 끝 [n]글자가 조합 중
  TextEditingValue composingTail(String text, [int n = 1]) => v(
    text,
    composing: TextRange(start: text.length - n, end: text.length),
  );

  group('maxCharacters', () {
    final f = maxCharacters(12);
    final full = '가나다라마바사아자차카타'; // 12자

    test('12자에서 다음 글자의 첫 자모(조합 중)를 받지 않는다', () {
      final r = f.formatEditUpdate(v(full), composingTail('$fullㄱ'));
      expect(r.text, full);
    });

    test('마지막 글자의 받침 조합처럼 글자 수가 늘지 않으면 받는다', () {
      final old = composingTail('가나다라마바사아자차카가');
      final r = f.formatEditUpdate(old, composingTail('가나다라마바사아자차카각'));
      expect(r.text, '가나다라마바사아자차카각');
    });

    test('붙여넣기로 넘치면 12자에서 자른다, 이모지도 한 글자', () {
      final r = f.formatEditUpdate(v('가'), v('😀' * 15));
      expect(r.text.characters.length, 12);
    });

    test('11자에서 조합 중인 12번째 글자는 받는다', () {
      final r = f.formatEditUpdate(
        v('가나다라마바사아자차카'),
        composingTail('가나다라마바사아자차카ㅌ'),
      );
      expect(r.text, '가나다라마바사아자차카ㅌ');
    });
  });

  Future<void> compose(WidgetTester tester, String text) async {
    tester.testTextInput.updateEditingValue(composingTail(text));
    await tester.pump();
  }

  testWidgets('칸 이름: 12자에서 한글 조합 중에도 더 적히지 않고 카운터 12/12', (tester) async {
    useDesignScreen(tester);
    final h = RecordHarness()..prefs.shelfViewValue = 'list';
    await tester.pumpWidget(testApp(h, initialLocation: '/shelf'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.bySemanticsLabel('칸 추가'));
    await tester.pumpAndSettle();
    await tester.showKeyboard(find.byType(TextField));
    const full = '가나다라마바사아자차카타';
    await compose(tester, full);
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: full,
        selection: const TextSelection.collapsed(offset: 12),
      ),
    );
    await tester.pump();
    await compose(tester, '$fullㅎ');
    await compose(tester, '$full하');
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, full);
    expect(find.text('12/12'), findsOneWidget);
  });

  testWidgets('메모: 40자에서 한글 조합 중에도 더 적히지 않는다', (tester) async {
    useDesignScreen(tester);
    final h = RecordHarness()..prefs.shelfViewValue = 'list';
    await tester.pumpWidget(testApp(h, initialLocation: '/shelf'));
    await tester.pump(const Duration(milliseconds: 700));
    final row = find.ancestor(
      of: find.text('은비'),
      matching: find.byType(ShelfRow),
    );
    await tester.tap(
      find.descendant(of: row, matching: find.byType(MoreButton)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('메모 남기기'));
    await tester.pumpAndSettle();
    await tester.showKeyboard(find.byType(TextField));
    final full = '가' * 40;
    tester.testTextInput.updateEditingValue(v(full));
    await tester.pump();
    await compose(tester, '$fullㄴ');
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, full);
    expect(find.text('40/40'), findsOneWidget);
  });
}
