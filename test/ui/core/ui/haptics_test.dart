import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tapeletter_app/ui/core/themes/colors.dart';
import 'package:tapeletter_app/ui/core/ui/buttons.dart';
import 'package:tapeletter_app/ui/core/ui/tappable.dart';

import '../../../../testing/app.dart';
import '../../../../testing/fonts.dart';
import '../../../../testing/record_harness.dart';

/// `HapticFeedback.*`가 플랫폼에 보내는 종류를 모은다.
List<String> recordHaptics(WidgetTester tester) {
  final calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        calls.add('${call.arguments}'.split('.').last);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return calls;
}

void main() {
  setUpAll(loadAppFonts);

  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('Tappable: 누르면 selectionClick, onTap이 없으면 울리지 않는다', (
    tester,
  ) async {
    final haptics = recordHaptics(tester);
    var n = 0;
    await tester.pumpWidget(
      host(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tappable(onTap: () => n++, child: const Text('켜짐')),
            const Tappable(onTap: null, child: Text('없음')),
          ],
        ),
      ),
    );
    await tester.tap(find.text('켜짐'));
    expect(n, 1);
    expect(haptics, ['selectionClick']);
    await tester.tap(find.text('없음'));
    expect(haptics, ['selectionClick']);
  });

  testWidgets('AppButton: 활성은 울리고 비활성(회색)은 눌러도 울리지 않는다', (tester) async {
    final haptics = recordHaptics(tester);
    var n = 0;
    await tester.pumpWidget(
      host(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppButton(label: '보내기', onTap: () => n++),
            AppButton(
              label: '칸 만들기',
              background: AppColors.disabled,
              onTap: () => n++,
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('보내기'));
    expect(haptics, ['selectionClick']);
    await tester.tap(find.text('칸 만들기'));
    expect(n, 2, reason: '비활성도 누르면 안내는 한다');
    expect(haptics, ['selectionClick']);
  });

  testWidgets('앱: 데크 키는 누르는 순간 mediumImpact, 비활성 키는 없음', (tester) async {
    useDesignScreen(tester);
    final h = RecordHarness();
    await tester.pumpWidget(testApp(h));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final haptics = recordHaptics(tester);

    // 비활성 PLAY
    await tester.tap(find.bySemanticsLabel('PLAY'));
    await tester.pump();
    expect(haptics, isEmpty);

    await tester.tap(find.bySemanticsLabel('REC'));
    await tester.pump();
    expect(haptics, ['mediumImpact']);
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.bySemanticsLabel('STOP'));
    await tester.pump();
    expect(haptics, ['mediumImpact', 'mediumImpact']);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('앱: 탭바 · 아이콘 · 설정 행(토글)은 selectionClick', (tester) async {
    useDesignScreen(tester);
    final h = RecordHarness();
    await tester.pumpWidget(testApp(h, initialLocation: '/shelf'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    final haptics = recordHaptics(tester);
    await tester.tap(find.bySemanticsLabel('마이'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(haptics, ['selectionClick']);
    await tester.tap(find.bySemanticsLabel('설정'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('알림'));
    await tester.pump();
    expect(haptics, ['selectionClick', 'selectionClick', 'selectionClick']);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('서랍: 길게 눌러 끌기 시작하면 mediumImpact', (tester) async {
    useDesignScreen(tester);
    final h = RecordHarness()..prefs.shelfViewValue = 'list';
    await tester.pumpWidget(testApp(h, initialLocation: '/shelf'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    final haptics = recordHaptics(tester);
    // 안 뜯은 소포(지현)는 끌 수 없다 (v10.2)
    var g = await tester.startGesture(tester.getCenter(find.text('지현').first));
    await tester.pump(const Duration(milliseconds: 700));
    expect(haptics, isEmpty);
    await g.cancel();
    await tester.pump(const Duration(seconds: 2));
    // 뜯은 테이프(수아)는 길게 누르면 끌기 시작
    await tester.ensureVisible(find.text('수아'));
    await tester.pump();
    g = await tester.startGesture(tester.getCenter(find.text('수아')));
    await tester.pump(const Duration(milliseconds: 700));
    expect(haptics, ['mediumImpact']);
    await g.up();
    await tester.pump(const Duration(seconds: 3));
  });
}
