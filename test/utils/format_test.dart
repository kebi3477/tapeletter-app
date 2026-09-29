import 'package:flutter_test/flutter_test.dart';
import 'package:tapeletter_app/utils/format.dart';

void main() {
  test('formatMonthDayTime: logic.js at(x) — MM.DD HH:mm, 24시간, 0 채움', () {
    expect(formatMonthDayTime(DateTime(2026, 9, 4, 7, 5)), '09.04 07:05');
    expect(formatMonthDayTime(DateTime(2026, 12, 31, 23, 59)), '12.31 23:59');
  });

  test('UTC 시각은 기기 시간대로 바꿔서 쓴다 (날짜도 함께)', () {
    final utc = DateTime.utc(2026, 9, 24, 20, 30);
    final l = utc.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    expect(
      formatMonthDayTime(utc),
      '${two(l.month)}.${two(l.day)} ${two(l.hour)}:${two(l.minute)}',
    );
    expect(formatMonthDay(utc), '${two(l.month)}.${two(l.day)}');
  });
}
